class_name Offers
extends Node
## 付费限时礼包（data/offers.json）：
## - spree「赶大集」：13 级起自动开一期（1 小时），开期时自动弹一次；每期限购 N 次；期满后冷却 20 小时。
## - energy「火种大礼包」：体力用完点生产器、或点顶栏体力时开一期（10 分钟），三档各限购 1 次；期满后冷却 4 小时。
## 状态在 G.offers：{kind: {"start", "end", "next_at", "bought": {档位: 次数}}}；赶大集这期弹没弹过记在 G.settings.spree_popped。
## 服务器模式：开期 POST /v1/offer/open，购买 POST /v1/offer/order → mock 支付回调到账（PayOrder kind = offer），
## 服务器按 server/app/offers.py 同一规则校验；单机（--cloud-off）按下面的本地规则，购买直接到账（演示）。
## 节点挂在 /root/G/Offers 下，只负责「赶大集」开期和自动弹出。

const DATA := "res://data/offers.json"
static var _config: Dictionary = {}
static var busy := false
static var _retry_at: Dictionary = {}
var _clock := 0.0

static func inst() -> Node:
	var g := (Engine.get_main_loop() as SceneTree).root.get_node("G")
	var n := g.get_node_or_null("Offers")
	if n == null:
		n = load("res://scripts/events/Offers.gd").new()
		n.name = "Offers"
		g.add_child(n)
	return n

static func config() -> Dictionary:
	if _config.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_config = d if d is Dictionary else {}
	return _config

static func cfg(kind: String) -> Dictionary:
	var c = config().get(kind, {})
	return c if c is Dictionary else {}

static func tiers(kind: String) -> Array:
	var t = cfg(kind).get("tiers", [])
	return t if t is Array else []

static func tier(kind: String, k: int) -> Dictionary:
	var ts := tiers(kind)
	return ts[k] if k >= 0 and k < ts.size() else {}

static func state(kind: String) -> Dictionary:
	var s = G.offers.get(kind, {})
	return s if s is Dictionary else {}

static func unlocked(kind: String) -> bool:
	return not G.tutorial_on and G.level >= int(cfg(kind).get("min_level", 999))

## 这一期正在进行（开期了、没过期）
static func active(kind: String) -> bool:
	var s := state(kind)
	return not s.is_empty() and G.now() >= float(s.get("start", 0)) and G.now() < float(s.get("end", 0))

## 现在能开新一期（解锁了、冷却完了、这期没在进行）
static func can_open(kind: String) -> bool:
	return unlocked(kind) and not active(kind) and G.now() >= float(state(kind).get("next_at", 0))

static func remaining(kind: String) -> int:
	return maxi(0, int(ceil(float(state(kind).get("end", 0)) - G.now()))) if active(kind) else 0

static func bought(kind: String, k: int) -> int:
	var b = state(kind).get("bought", {})
	return int(b.get(str(k), 0)) if b is Dictionary else 0

static func left(kind: String, k: int) -> int:
	return maxi(0, int(tier(kind, k).get("limit", 0)) - bought(kind, k))

## 这一期还有没买完的档位
static func any_left(kind: String) -> bool:
	for k in tiers(kind).size():
		if left(kind, k) > 0: return true
	return false

static func price_text(kind: String, k: int) -> String:
	return "¥%d" % int(tier(kind, k).get("price_cny", 0))

## 礼包估值（琥珀当量）：和 server/app/offers.py value() 同一张表
static func value(rewards: Array) -> float:
	var total := 0.0
	for rw in rewards:
		var id := str(rw[0])
		var n := int(rw[1])
		match Rewards.kind(id):
			"amber": total += n
			"energy": total += n * 0.4
			"shell": total += n * 0.1
			"sand": total += n * 5.0
			"chest": total += 15.0 * n
			"pack": total += 20.0 * n
			_:
				if Data.type_of(id) == "gen": total += 10.0 * pow(2.0, Data.lv(id) - 1) * n
	return total

# ---------------------------------------------------------------- 开期

## 开一期。返回开没开成（已经在进行也算 true）。
static func open_window(kind: String) -> bool:
	if active(kind): return true
	if not can_open(kind) or busy: return false
	if G.server_mode():
		if G.now() < float(_retry_at.get(kind, 0.0)): return false
		busy = true
		var r: Dictionary = await G._cloud().act("/v1/offer/open", {"offer": kind})
		busy = false
		# 服务器不让开（等级 / 冷却以服务器为准）或连不上：一分钟内不再问
		if not r.get("ok", false): _retry_at[kind] = G.now() + 60.0
		return r.get("ok", false) and active(kind)
	var c := cfg(kind)
	var t := G.now()
	var end := t + int(c.get("duration_sec", 600))
	G.offers[kind] = {"start": t, "end": end, "next_at": end + int(c.get("cooldown_sec", 0)), "bought": {}}
	G.save_game()
	return true

## 体力入口（体力用完点生产器、点顶栏体力）该不该先弹火种大礼包：这期还有没买完的，或者能开新一期
static func wants_energy() -> bool:
	return (active("energy") and any_left("energy")) or can_open("energy")

## 开火种大礼包（需要时先开期）；开不成就回到琥珀买体力。
static func open_energy() -> void:
	if await open_window("energy") and any_left("energy") and is_instance_valid(G.main):
		G.main.open("energy_offer")
		return
	if is_instance_valid(G.main): G.main.open("energy_amber")

# ---------------------------------------------------------------- 购买

## 返回 {"ok", "rewards"} 或 {"ok": false, "message"}。成功时奖励已入账（调用方只播动画用 rewards 起点）。
static func buy(kind: String, k: int, from: Callable = Callable()) -> Dictionary:
	if busy: return {"ok": false, "message": ""}
	var t := tier(kind, k)
	if t.is_empty(): return {"ok": false, "message": "没有这一档"}
	if not active(kind): return {"ok": false, "message": "礼包已结束，下次再来"}
	if left(kind, k) <= 0: return {"ok": false, "message": "这一档已经买完了"}
	var rw: Array = t.get("rewards", [])
	busy = true
	if G.server_mode():
		var cloud = G._cloud()
		var o: Dictionary = await cloud.act("/v1/offer/order", {"offer": kind, "tier": k})
		if not o.get("ok", false):
			busy = false
			return {"ok": false, "message": str(o.get("message", "购买失败"))}
		# 现在是 mock 支付：直接走「支付成功回调」。正式接入时这里拉起应用商店，收据交服务器验单后才发货。
		var paid: Dictionary = await cloud.act("/v1/payments/mock/%s/pay" % str(o.get("order_id", "")), {}, rw)
		if not paid.get("ok", false) or str(paid.get("status", "")) != "paid":
			busy = false
			return {"ok": false, "message": str(paid.get("message", "支付没有完成"))}
	else:
		var s := state(kind)
		var b: Dictionary = s.get("bought", {})
		b[str(k)] = int(b.get(str(k), 0)) + 1
		s["bought"] = b
	busy = false
	# 琥珀、贝币在服务器模式下已用 minus 先减掉，这里加回来；体力、物品本地入账（服务器记了额度）
	Rewards.grant(rw, from)
	G.save_game()
	return {"ok": true, "rewards": rw}

# ---------------------------------------------------------------- 赶大集：自动开期 + 弹一次

func _process(delta: float) -> void:
	_clock += delta
	if _clock < 1.0: return
	_clock = 0.0
	tick()

func tick() -> void:
	if not is_instance_valid(G.main) or not bool(cfg("spree").get("auto_popup", true)): return
	if can_open("spree"):
		await open_window("spree")
	# 每期只自动弹一次：记在本机设置里（服务器状态会整份覆盖 G.offers）
	var start := float(state("spree").get("start", 0))
	if not active("spree") or float(G.settings.get("spree_popped", 0)) == start or not any_left("spree"): return
	# 只在没有其他弹窗、在村子或棋盘时弹
	if G.main.popup_layer.get_child_count() > 0 or not G.main.screen in ["home", "board"]: return
	G.settings["spree_popped"] = start
	G.save_game()
	G.main.open("spree")
