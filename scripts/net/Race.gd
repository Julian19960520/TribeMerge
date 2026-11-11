## Race presentation model; commands use the shared reducer.
extends Node

signal updated

const POLL := 30.0
const DASH := 0.7
const MATCH_SEC := 1.5

var info := {}
var ok := false
var loading := false
var fetched_once := false
var _last_ms := -1
var _watchers: Array = []
var _disp := {}
var _score_seen := -1.0
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
	G.changed.connect(_on_progress_changed)

func _on_progress_changed() -> void:
	if _watched(): fetch()

func online() -> bool:
	return Replay.authorized

func now() -> float:
	return G.now()

# ---------------------------------------------------------------- 拉取

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

func _process(_delta: float) -> void:
	if _stale() and _watched(): fetch()

func fetch() -> void:
	_last_ms = Time.get_ticks_msec()
	_absorb(LocalRace.state())
	ok = Replay.authorized
	fetched_once = true
	updated.emit()

func _absorb(d: Dictionary) -> void:
	# 先记下每个人现在显示到哪，新快照从这里接着往前插值
	var shown := {}
	for m in members():
		shown[int(m.get("slot", 0))] = score_of(m)
	info = d
	for member in members():
		if bool(member.get("me", false)):
			var score := float(member.get("score", 0))
			if _score_seen >= 0 and score > _score_seen: _my_dash_ms = Time.get_ticks_msec()
			_score_seen = score
	var t0 := Time.get_ticks_msec()
	for m in members():
		var slot := int(m.get("slot", 0))
		var to := float(m.get("score", 0.0))
		var from: float = minf(float(shown.get(slot, to)), to)
		_disp[slot] = {"from": from, "to": to, "steps": _steps(from, to, slot), "t0": t0}

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
	return LocalRace.rules()

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

func racing() -> bool:
	var g := group()
	return not g.is_empty() and str(g.get("state", "")) != "ended" and now() < float(g.get("end", 0))

func matching() -> bool:
	return joined() and (Time.get_ticks_msec() < _match_until or str(group().get("state", "")) == "matching")

func ended() -> bool:
	return joined() and str(group().get("state", "")) == "ended"

func pending_result() -> Dictionary:
	for r in results():
		if r is Dictionary and str(r.get("group", {}).get("id", "")) == str(group().get("id", "")):
			return r
	return results()[0] if not results().is_empty() else {}

func secs_left() -> int:
	return maxi(0, int(float(group().get("end", 0)) - now()))



func score_of(m: Dictionary) -> float:
	var slot := int(m.get("slot", 0))
	var tg := target()
	if bool(m.get("me", false)):
		return minf(tg, float(m.get("score", 0.0)))
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





func join() -> Dictionary:
	var result: Dictionary = Replay.perform("race_join")
	_disp.clear()
	_absorb(LocalRace.state())
	if result.get("ok", false): _match_until = Time.get_ticks_msec() + int(MATCH_SEC * 1000)
	updated.emit()
	return result

func claim(res: Dictionary) -> Dictionary:
	var result: Dictionary = Replay.perform("race_claim", {"id": str(res.get("group", {}).get("id", ""))})
	_absorb(LocalRace.state())
	updated.emit()
	return result
