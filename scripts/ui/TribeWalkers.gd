extends Control
## 部落里走来走去的「兄弟，我发现」小人。
## 沿着村里的几条小路在路口之间溜达，走到路口有时停下来发呆，偶尔冒一句「兄弟，我发现……」。
## 点一下小人也会说一句。人数跟着开工的区域变多。只在小人身上接收点击，别处点击穿透到下面。

const Meme := preload("res://scripts/Meme.gd")

## 路口（主页坐标）和路口之间的小路
const NODES := [
	Vector2(80, 742), Vector2(240, 742), Vector2(360, 742), Vector2(480, 742), Vector2(640, 742),
	Vector2(244, 860), Vector2(476, 860),
	Vector2(80, 1012), Vector2(240, 1012), Vector2(480, 1012), Vector2(640, 1012),
	Vector2(300, 1262), Vector2(420, 1262),
]
const EDGES := [[0, 1], [1, 2], [2, 3], [3, 4], [1, 5], [3, 6], [5, 8], [6, 9], [7, 8], [9, 10], [8, 11], [9, 12], [11, 12]]
const SPEED := 38.0
const HIT := Vector2(56, 96)
## 两次自动冒话之间至少隔多久（秒）
const CHAT_GAP := Vector2(5.0, 9.0)
const SAY_TIME := 4.2

var _walkers: Array = []
var _adj := {}
var _rng := RandomNumberGenerator.new()
var _chat_cd := 3.0
var _t := 0.0

func _ready() -> void:
	size = Vector2(720, 1480)
	mouse_filter = MOUSE_FILTER_STOP
	_rng.randomize()
	for e in EDGES:
		_adj.get_or_add(e[0], []).append(e[1])
		_adj.get_or_add(e[1], []).append(e[0])
	_sync_count()
	G.changed.connect(_sync_count)

## 开工的区域越多，村里的人越多：2～8 个
func _want_count() -> int:
	var n := 2
	for b in Data.BUILDS:
		if b is Dictionary and int(G.builds.get(str(b.get("id", "")), 0)) > 0:
			n += 1
	return clampi(n, 2, 8)

func _sync_count() -> void:
	var want := mini(_want_count(), Data.PEOPLE.size() if not Data.PEOPLE.is_empty() else 8)
	while _walkers.size() < want:
		var at := _rng.randi_range(0, NODES.size() - 1)
		var w := {
			"role": _walkers.size(),
			"pos": NODES[at],
			"from": at,
			"to": at,
			"wait": _rng.randf_range(0.0, 2.0),
			"face": 1.0 if _rng.randf() < 0.5 else -1.0,
			"phase": _rng.randf() * 10.0,
			"say": "",
			"say_t": 0.0,
		}
		_walkers.append(w)
	while _walkers.size() > want:
		_walkers.pop_back()

func _process(d: float) -> void:
	if not is_visible_in_tree():
		return
	_t += d
	_chat_cd -= d
	for w in _walkers:
		if float(w["say_t"]) > 0.0:
			w["say_t"] = float(w["say_t"]) - d
		if float(w["wait"]) > 0.0:
			w["wait"] = float(w["wait"]) - d
			if float(w["wait"]) <= 0.0:
				_pick_next(w)
			continue
		var target: Vector2 = NODES[int(w["to"])]
		var p: Vector2 = w["pos"]
		var step := SPEED * d
		w["phase"] = float(w["phase"]) + d
		if p.distance_to(target) <= step:
			w["pos"] = target
			w["from"] = w["to"]
			if _rng.randf() < 0.4:
				w["wait"] = _rng.randf_range(1.2, 3.2)
				if _chat_cd <= 0.0 and not _anyone_talking():
					_say(w)
			else:
				_pick_next(w)
		else:
			var dir := (target - p).normalized()
			if absf(dir.x) > 0.2:
				w["face"] = signf(dir.x)
			w["pos"] = p + dir * step
	queue_redraw()

func _pick_next(w: Dictionary) -> void:
	var opts: Array = _adj.get(int(w["from"]), [])
	if opts.is_empty():
		return
	w["to"] = opts[_rng.randi_range(0, opts.size() - 1)]
	w["wait"] = 0.0

func _anyone_talking() -> bool:
	for w in _walkers:
		if float(w["say_t"]) > 0.0:
			return true
	return false

func _say(w: Dictionary) -> void:
	for o in _walkers:
		o["say_t"] = 0.0
	w["say"] = Meme.line()
	w["say_t"] = SAY_TIME
	_chat_cd = _rng.randf_range(CHAT_GAP.x, CHAT_GAP.y) + SAY_TIME

func _walker_rect(w: Dictionary) -> Rect2:
	var p: Vector2 = w["pos"]
	return Rect2(p - Vector2(HIT.x * 0.5, HIT.y), HIT)

## 只有点在小人身上才接住点击，其余地方穿透给下面的村庄和牌子
func _has_point(point: Vector2) -> bool:
	for w in _walkers:
		if _walker_rect(w).has_point(point):
			return true
	return false

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var best = null
		for w in _walkers:
			if _walker_rect(w).has_point(e.position) and (best == null or float(w["pos"].y) > float(best["pos"].y)):
				best = w
		if best != null:
			_say(best)
			best["wait"] = maxf(float(best["wait"]), 2.0)
			Sfx.play("pop")
			accept_event()

func _draw() -> void:
	var order := _walkers.duplicate()
	order.sort_custom(func(a, b): return float(a["pos"].y) < float(b["pos"].y))
	for w in order:
		Meme.walker(self, int(w["role"]), w["pos"], float(w["phase"]), float(w["face"]), float(w["wait"]) <= 0.0)
	for w in order:
		var st := float(w["say_t"])
		if st > 0.0:
			var a := clampf(st / 0.3, 0.0, 1.0) * clampf((SAY_TIME - st) / 0.15, 0.0, 1.0)
			Meme.bubble(self, w["pos"] + Vector2(0, -104), str(w["say"]), a)
