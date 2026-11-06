extends Node
## 篝火竞速客户端（异步联机活动第一期，设计见 DESIGN.md「十三」）。比赛收集香蕉：1 分 = 1 根香蕉。
## 不限时、12 级解锁：随时点「匹配」开一局（假匹配：对手全是影子，客户端播 MATCH_SEC 秒匹配动画）。
## 不是自动加载：第一次用时由 inst() 挂到 G 下面（/root/G/Race）。
## - 只在活动界面（棋盘顶上的赛道、竞速弹窗）显示时每 30 秒 GET /v1/race 一次；没人看就不拉。
## - 对手的分数在两次快照之间插值：把这 30 秒里涨的分拆成几次「冲刺」，分散在接下来 30 秒里播，看起来像有人在交单。
## - 自己的分数 = 服务器记的分 + Cloud 里还没交上去的交单事件的理论火苗（交单时立刻往前冲，服务器结算为准）。
## - 报名、领奖走 Cloud.act（带幂等键，先把排队的事件交掉）。

signal updated

const POLL := 30.0
const DASH := 0.7
const MATCH_SEC := 3.0

## 最近一次 GET /v1/race 的结果（schedule / current / results / title / rules）
var info := {}
var ok := false
var loading := false
var fetched_once := false
var _last_ms := -1
var _watchers: Array = []
## slot → {"from", "to", "steps": [[秒, 分], ...], "t0": 收到快照的 ticks}
var _disp := {}
var _flush_t := -1.0
## 假匹配动画播到什么时候（ticks 毫秒）
var _match_until := -1

static func inst() -> Node:
	var g := (Engine.get_main_loop() as SceneTree).root.get_node("G")
	var n := g.get_node_or_null("Race")
	if n == null:
		n = load("res://scripts/net/Race.gd").new()
		n.name = "Race"
		g.add_child(n)
	return n

func _ready() -> void:
	G.order_delivered.connect(_on_order)

func _cloud() -> Node:
	return get_node_or_null("/root/Cloud")

func online() -> bool:
	var c := _cloud()
	return c != null and c.can_talk()

func now() -> float:
	return G.now()

# ---------------------------------------------------------------- 拉取

## 活动界面显示时调用：登记自己，太久没拉就马上拉一次
func watch(n: Node) -> void:
	if not _watchers.has(n):
		_watchers.append(n)
	if _stale():
		fetch()

func _stale() -> bool:
	return _last_ms < 0 or Time.get_ticks_msec() - _last_ms >= int(POLL * 1000.0)

func _watched() -> bool:
	_watchers = _watchers.filter(func(n): return is_instance_valid(n))
	for n in _watchers:
		if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			return true
	return false

func _process(delta: float) -> void:
	if _flush_t >= 0.0:
		_flush_t -= delta
		if _flush_t < 0.0:
			_flush_events()
	if not loading and _stale() and _watched():
		fetch()

func fetch() -> void:
	if loading:
		return
	_last_ms = Time.get_ticks_msec()
	if not G.server_mode():
		LocalRace.tick()
		info=LocalRace.state()
		ok=true
		updated.emit()
		return
	if not online():
		ok = false
		updated.emit()
		return
	loading = true
	var r: Array = await _cloud()._call("GET", "/v1/race", null)
	loading = false
	_last_ms = Time.get_ticks_msec()
	if int(r[0]) == 200 and r[1] is Dictionary:
		_absorb(r[1])
		ok = true
		fetched_once = true
	else:
		ok = false
	updated.emit()

func _absorb(d: Dictionary) -> void:
	# 先记下每个人现在显示到哪，新快照从这里接着往前插值
	var shown := {}
	for m in members():
		shown[int(m.get("slot", 0))] = score_of(m)
	info = d
	var t0 := Time.get_ticks_msec()
	for m in members():
		var slot := int(m.get("slot", 0))
		var to := float(m.get("score", 0.0))
		var from: float = minf(float(shown.get(slot, to)), to)
		_disp[slot] = {"from": from, "to": to, "steps": _steps(from, to, slot), "t0": t0}

## 把 from → to 拆成 1～4 次冲刺，时间分散在 POLL 秒里
func _steps(from: float, to: float, slot: int) -> Array:
	var diff := to - from
	if diff <= 0.05:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(slot) + str(to))
	var n := clampi(int(round(diff / 18.0)), 1, 4)
	var out := []
	var acc := from
	for k in n:
		var t := (float(k) + rng.randf_range(0.1, 0.9)) * POLL / float(n) * 0.9
		acc = to if k == n - 1 else acc + diff / float(n) * rng.randf_range(0.7, 1.3)
		out.append([t, minf(acc, to)])
	return out

# ---------------------------------------------------------------- 状态

func unlock_level() -> int:
	return int(rules().get("unlock_level", 12))

func unlocked() -> bool:
	return G.gm_activities or G.level >= unlock_level()

func current() -> Dictionary:
	return info.get("current", {}) if info.get("current") is Dictionary else {}

func group() -> Dictionary:
	var c := current()
	return c.get("group", {}) if c.get("group") is Dictionary else {}

func members() -> Array:
	var g := group()
	return g.get("members", []) if g.get("members") is Array else []

func rules() -> Dictionary:
	if not G.server_mode(): return LocalRace.rules()
	return info.get("rules", {}) if info.get("rules") is Dictionary else {}

func target() -> float:
	return float(group().get("target", rules().get("target", 300)))

func results() -> Array:
	return info.get("results", []) if info.get("results") is Array else []

func title() -> Dictionary:
	var t = info.get("title")
	if t is Dictionary and float(t.get("until", 0)) > now():
		return t
	return {}

func joined() -> bool:
	return not group().is_empty()

## 正在比（报名了、没结束、没过点）
func racing() -> bool:
	var g := group()
	return not g.is_empty() and str(g.get("state", "")) != "ended" and now() < float(g.get("end", 0))

## 点了匹配、动画还在播
func matching() -> bool:
	return joined() and (Time.get_ticks_msec() < _match_until or str(group().get("state", "")) == "matching")

## 这一局比完了、还没领奖
func ended() -> bool:
	return joined() and str(group().get("state", "")) == "ended"

## 上一局待领的结算（就是 current 那局）
func pending_result() -> Dictionary:
	for r in results():
		if r is Dictionary and str(r.get("group", {}).get("id", "")) == str(group().get("id", "")):
			return r
	return results()[0] if not results().is_empty() else {}

func secs_left() -> int:
	return maxi(0, int(float(group().get("end", 0)) - now()))

## 还没交给服务器的交单事件的理论火苗（只算报名之后的）
func pending_mine() -> float:
	if not G.server_mode(): return 0.0
	var c := _cloud()
	if c == null or not racing():
		return 0.0
	var s := 0.0
	for e in c.events:
		if e is Dictionary and str(e.get("type", "")) == "order" and e.get("order") is Dictionary:
			s += OrderRoll.total(e["order"].get("items", []))
	return s

## 现在应该显示的分数
func score_of(m: Dictionary) -> float:
	var slot := int(m.get("slot", 0))
	var tg := target()
	if bool(m.get("me", false)):
		return minf(tg, float(m.get("score", 0.0)) + pending_mine())
	var d = _disp.get(slot)
	if not (d is Dictionary):
		return float(m.get("score", 0.0))
	var el := float(Time.get_ticks_msec() - int(d["t0"])) / 1000.0
	var v := float(d["from"])
	for st in d["steps"]:
		var t: float = st[0]
		if el >= t + DASH:
			v = float(st[1])
		elif el > t:
			var u := (el - t) / DASH
			v = lerpf(v, float(st[1]), 1.0 - pow(1.0 - u, 3.0))
			break
		else:
			break
	return minf(v, tg)

## 正在冲刺（给赛道画尘土、晃脑袋用）：0～1
func dash_of(m: Dictionary) -> float:
	var d = _disp.get(int(m.get("slot", 0)))
	if bool(m.get("me", false)):
		return clampf(1.0 - float(Time.get_ticks_msec() - _my_dash_ms) / (DASH * 1000.0), 0.0, 1.0)
	if not (d is Dictionary):
		return 0.0
	var el := float(Time.get_ticks_msec() - int(d["t0"])) / 1000.0
	for st in d["steps"]:
		var t: float = st[0]
		if el > t and el < t + DASH:
			return 1.0 - (el - t) / DASH
	return 0.0

## 当前名次（按显示分数；到线的按到线时间）
func place_of(m: Dictionary) -> int:
	if m.get("place") != null:
		return int(m["place"])
	var me_s := score_of(m)
	var k := 1
	for o in members():
		if int(o.get("slot", 0)) == int(m.get("slot", 0)):
			continue
		var os := score_of(o)
		if os > me_s or (os == me_s and int(o.get("slot", 0)) < int(m.get("slot", 0))):
			k += 1
	return k

func me() -> Dictionary:
	for m in members():
		if bool(m.get("me", false)):
			return m
	return {}

# ---------------------------------------------------------------- 交单 → 自己往前冲，尽快把事件交给服务器

var _my_dash_ms := -100000

func _on_order(_items: Array) -> void:
	if not racing():
		return
	_my_dash_ms = Time.get_ticks_msec()
	if not G.server_mode():
		LocalRace.order(_items)
		info=LocalRace.state()
		updated.emit()
		return
	# 比赛中把交单事件 3 秒内单独交掉（不等 60 秒的快照合并），对手那边看到的进度更及时
	if _flush_t < 0.0:
		_flush_t = 3.0

func _flush_events() -> void:
	var c := _cloud()
	if c == null or not c.can_talk() or c.events.is_empty():
		return
	if c._busy:
		_flush_t = 2.0
		return
	var okk: bool = await c._send_events()
	if okk and _watched():
		_last_ms = -1  # 交完马上拉一次，看到服务器认的分

# ---------------------------------------------------------------- 报名 / 领奖

func join() -> Dictionary:
	if not G.server_mode():
		var r:=LocalRace.join()
		info=LocalRace.state()
		if r.get("ok",false):_match_until=Time.get_ticks_msec()+int(MATCH_SEC*1000)
		updated.emit()
		return r
	var c := _cloud()
	if c == null:
		return {"ok": false, "message": "连不上服务器，请稍后再试"}
	var r: Dictionary = await c.act("/v1/race/join")
	if r.get("ok", false):
		info["current"] = r.get("current", {})
		_match_until = Time.get_ticks_msec() + int(MATCH_SEC * 1000.0)
		_disp.clear()
		_last_ms = -1
		updated.emit()
	return r

## 领一场的奖励。成功时服务器已经发了（货币先减掉，UI 动画再加回来），返回 rewards。
func claim(res: Dictionary) -> Dictionary:
	if not G.server_mode():
		var r:=LocalRace.claim(str(res.get("group",{}).get("id","")))
		info=LocalRace.state()
		updated.emit()
		return r
	var c := _cloud()
	var gid := str(res.get("group", {}).get("id", ""))
	var rw: Array = res.get("me", {}).get("reward", []) if res.get("me", {}).get("reward") is Array else []
	if int(res.get("me", {}).get("place", 0)) not in [1, 2, 3]: rw = []
	if c == null:
		return {"ok": false, "message": "连不上服务器，请稍后再试"}
	var r: Dictionary = await c.act("/v1/race/claim", {"group": gid}, rw)
	if r.get("ok", false) or str(r.get("error", "")) == "already_claimed":
		info["results"] = results().filter(func(x): return str(x.get("group", {}).get("id", "")) != gid)
		if str(group().get("id", "")) == gid:
			info["current"] = {}
		if r.get("title") is Dictionary:
			info["title"] = r["title"]
		updated.emit()
	return r
