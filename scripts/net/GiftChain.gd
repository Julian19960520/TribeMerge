extends Node
## 礼包链（法币直购活动）客户端，设计见 DESIGN.md「礼包链（直购活动）」。
## 不是自动加载：第一次用时由 inst() 挂到 G 下面（/root/G/GiftChain）。
## - 进度全在服务器：GET /v1/gift-chain 拿本期队列和队首；客户端只显示服务器返回的结果。
## - 免费步 POST /v1/gift-chain/claim；付费步 POST /v1/gift-chain/order 下单 → 支付（现在是 mock 回调）→ 服务器验单后发奖。
## - 连不上服务器：免费步也不能领，显示「需要联网」。队列用本地 data/gift_chain.json 当预览。

signal updated

const DATA := "res://data/gift_chain.json"

## 最近一次服务器返回的 chain（cycle / ends_at / step / total / visible / done / free_ready / steps）
var info := {}
var ok := false
var loading := false
var fetched_once := false
var busy := false
var _local := {}

static func inst() -> Node:
	var g := (Engine.get_main_loop() as SceneTree).root.get_node("G")
	var n := g.get_node_or_null("GiftChain")
	if n == null:
		n = load("res://scripts/net/GiftChain.gd").new()
		n.name = "GiftChain"
		g.add_child(n)
	return n

func _cloud() -> Node:
	return get_node_or_null("/root/Cloud")

func online() -> bool:
	if Replay.active: return Replay.authorized
	var c := _cloud()
	return c != null and c.enabled and c.can_talk()

# ---------------------------------------------------------------- 读

func fetch() -> void:
	if Replay.active:
		_absorb(Replay.gift_view())
		updated.emit()
		return
	if loading:
		return
	if not online():
		ok = false
		updated.emit()
		return
	loading = true
	var r: Array = await _cloud()._call("GET", "/v1/gift-chain", null)
	loading = false
	if int(r[0]) == 200 and (r[1] as Dictionary).get("chain") is Dictionary:
		_absorb(r[1]["chain"])
	else:
		ok = false
	updated.emit()

func _absorb(chain: Dictionary) -> void:
	info = chain
	ok = true
	fetched_once = true

## 服务器给的队列；还没拿到就用本地配置当预览（整条从第 1 步开始）
func steps() -> Array:
	if info.get("steps") is Array:
		return info["steps"]
	if _local.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_local = d if d is Dictionary else {"steps": []}
	var out := []
	var ss: Array = _local.get("steps", [])
	for i in ss.size():
		var p := float(ss[i].get("price", 0))
		out.append({"i": i, "price": p, "price_str": _yuan(p) if p > 0.0 else "", "rewards": ss[i].get("rewards", []),
			"tag": str(ss[i].get("tag", ""))})
	return out

func head() -> int:
	return int(info.get("step", 0))

func total() -> int:
	return steps().size()

func visible_n() -> int:
	return int(info.get("visible", 3))

func done() -> bool:
	return ok and head() >= total()

## 队首是免费步、而且现在能领（入口亮红点）
func free_ready() -> bool:
	return ok and online() and bool(info.get("free_ready", false))

func ends_at() -> float:
	return float(info.get("ends_at", 0))

func step(i: int) -> Dictionary:
	var ss := steps()
	return ss[i] if i >= 0 and i < ss.size() else {}

static func is_paid(s: Dictionary) -> bool:
	return float(s.get("price", 0)) > 0.0

## 价格按钮上的字（人民币价格档）。接应用商店后换成商店给的本地化价格。
static func price_text(s: Dictionary) -> String:
	var t := str(s.get("price_str", ""))
	return t if t != "" else _yuan(float(s.get("price", 0)))

static func _yuan(p: float) -> String:
	return ("¥%d" % int(p)) if is_equal_approx(p, roundf(p)) else ("¥%.2f" % p)

# ---------------------------------------------------------------- 领 / 买（返回 {"ok", "rewards"}；奖励由调用方播动画入账）

func claim(i: int) -> Dictionary:
	if Replay.active:
		var result: Dictionary = Replay.perform("gift", {"step": i})
		fetch()
		return result
	var s := step(i)
	if s.is_empty() or is_paid(s):
		return {"ok": false, "message": "这一步需要购买"}
	if not online():
		return {"ok": false, "error": "offline", "message": "需要联网才能领取"}
	busy = true
	var rw: Array = s.get("rewards", [])
	var r: Dictionary = await _cloud().act("/v1/gift-chain/claim", {"step": i}, rw)
	busy = false
	return _after(r, rw)

func buy(i: int) -> Dictionary:
	if Replay.active: return {"ok": false, "message": "购买需要联网验证，支付渠道尚未接通"}
	var s := step(i)
	if s.is_empty() or not is_paid(s):
		return {"ok": false, "message": "这一步是免费的"}
	if not online():
		return {"ok": false, "error": "offline", "message": "需要联网才能购买"}
	busy = true
	var c := _cloud()
	var o: Dictionary = await c.act("/v1/gift-chain/order", {"step": i})
	if not o.get("ok", false):
		busy = false
		return _after(o, [])
	# 现在是 mock 支付：直接走「支付成功回调」。正式接入时这里拉起应用商店，拿到收据交给服务器验单，服务器验过才发货。
	var rw: Array = s.get("rewards", [])
	var paid: Dictionary = await c.act("/v1/payments/mock/%s/pay" % str(o.get("order_id", "")), {}, rw)
	busy = false
	if paid.get("ok", false) and str(paid.get("status", "")) != "paid":
		paid["ok"] = false
		paid["message"] = "支付没有完成"
	return _after(paid, rw)

func _after(r: Dictionary, rw: Array) -> Dictionary:
	if r.get("chain") is Dictionary:
		_absorb(r["chain"])
	if r.get("ok", false):
		var give: Dictionary = r.get("give", {}) if r.get("give") is Dictionary else {}
		var got: Array = give.get("rewards", rw) if give.get("rewards") is Array else rw
		updated.emit()
		return {"ok": true, "rewards": got}
	if str(r.get("error", "")) in ["already_claimed", "not_head", "chain_done"]:
		fetch()
	else:
		updated.emit()
	return {"ok": false, "error": str(r.get("error", "")), "message": str(r.get("message", "连不上服务器，请稍后再试"))}
