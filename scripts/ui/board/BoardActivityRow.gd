class_name BoardActivityRow
extends RefCounted
## Explicit control bindings; no access to another view's private fields.
const GAP := 4.0
const STASH_RECT := Rect2(6, 38, 118, 226)
const BASE_RECT := Rect2(126, 38, 142, 226)
const HAMMER_W := 130.0
const ENTRY_W := 104.0
const ActivityPointsFx := preload("res://scripts/ui/board/ActivityPointsFx.gd")
var host: Control
var orders: Scroller
var stash: Control
var stash_button: TButton
var base: TButton
var hammer: TButton
var cards: OrderStrip
var entries: Array
var _stash_open := false
var _hammer_on := false
var _row_tween: Tween
var _shown_was: Array = []

func _init(owner: Control, bindings: Dictionary) -> void:
	host = owner
	orders = bindings["orders"]
	stash = bindings["stash"]
	stash_button = bindings["stash_button"]
	base = bindings["base"]
	hammer = bindings["hammer"]
	cards = bindings["cards"]
	entries = ActivityEntries.create(orders.content, Vector2(ENTRY_W, BASE_RECT.size.y))
	# 活动入口和主角卡、订单卡同一高度：名字底边对齐卡片底边
	for entry in entries: (entry["view"] as Control).position.y = BASE_RECT.position.y - 4.0

func refresh(animate := true) -> void:
	var open := not G.stash.is_empty()
	var build := G.rules.progression.next_build_id()
	var can_build := build != "" and G.shells >= G.rules.progression.build_cost(build)
	var shown := []
	var targets := []
	var x := BASE_RECT.position.x if open else STASH_RECT.position.x
	for entry in entries:
		var show: bool = not G.tutorial_on and entry["visible"].call()
		shown.append(show)
		var view: Control = entry["view"]
		view.visible = show
		targets.append([view, x])
		if show: x += ENTRY_W + GAP
	targets.append([base, x])
	x += BASE_RECT.size.x + GAP
	targets.append([hammer, x])
	# OrderStrip preserves its historical local x=272 origin.
	var card_x := x + (HAMMER_W + GAP if can_build else 0.0) + GAP - 272.0
	targets.append([cards, card_x])
	orders.set_length(cards.right_edge + card_x)
	if open == _stash_open and can_build == _hammer_on and shown == _shown_was: return
	if _row_tween != null and _row_tween.is_valid(): _row_tween.kill()
	var stash_changed := open != _stash_open
	var hammer_changed := can_build != _hammer_on
	_stash_open = open
	_hammer_on = can_build
	_shown_was = shown
	stash_button.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	hammer.mouse_filter = Control.MOUSE_FILTER_STOP if can_build else Control.MOUSE_FILTER_IGNORE
	if not animate or not host.is_visible_in_tree():
		stash.visible = open
		stash.scale = Vector2.ONE if open else Vector2.ZERO
		hammer.visible = can_build
		hammer.scale = Vector2.ONE
		for target in targets: target[0].position.x = float(target[1])
		return
	if open: stash.visible = true
	if can_build:
		hammer.visible = true
		if hammer_changed: hammer.scale = Vector2.ZERO
	_row_tween = host.create_tween().set_parallel(true)
	if stash_changed: _scale(stash, open)
	if hammer_changed: _scale(hammer, can_build)
	for target in targets:
		_row_tween.tween_property(target[0], "position:x", float(target[1]), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_row_tween.chain().tween_callback(func():
		if not _stash_open: stash.visible = false
		if not _hammer_on: hammer.visible = false)

func _scale(control: Control, open: bool) -> void:
	_row_tween.tween_property(control, "scale", Vector2.ONE if open else Vector2.ZERO, 0.22 if open else 0.16).set_trans(Tween.TRANS_BACK if open else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)

func order_delivered(origin: Vector2, fossil_earned: bool) -> void:
	# 新版篝火竞速记的是活动积分，香蕉不再飞，改由 points_fly 飞分数
	var race_points := int(LocalRace.state().get("current", {}).get("group", {}).get("pv", 1)) >= ActivityPoints.VERSION
	for entry in entries:
		var id: String = entry["id"]
		if (id == "race" and not race_points) or id == "merge" or (id == "fossil" and fossil_earned):
			entry["view"].fly_from(origin)

## 活动积分：每个拿到分的活动各飞一份「图标 +分数」，错开一点出发。
## rise：先弹到冒出点上方（负）还是下方（正）；订单卡在顶上，交单的分往下弹到棋盘上。
func points_fly(origin: Vector2, gains: Array, rise := -64.0) -> void:
	var k := 0
	for gain in gains:
		for entry in entries:
			if entry["id"] != str(gain["id"]):
				continue
			var dx := 104.0 * (float(k) - float(gains.size() - 1) * 0.5)
			var at := origin
			at.x = clampf(at.x, 60.0 + 104.0 * float(gains.size() - 1) * 0.5, 660.0 - 104.0 * float(gains.size() - 1) * 0.5)
			ActivityPointsFx.play(G.main.fx_layer, origin, entry["view"], str(gain["id"]), int(gain["n"]), 0.1 * k, at - origin + Vector2(dx, rise))
			k += 1
