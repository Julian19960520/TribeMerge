class_name HomeScreen
extends Control

var _spot_nodes: Dictionary = {}
var spot_created_count := 0
var _spots_dirty := false
var _clock_elapsed := 0.0
var _spots_root: Control
var _event_lbl: Label
var go: TButton
var _cards_btn: TButton
var _book_btn: TButton
var _map_btn: TButton
## 按等级开放的左上卡片和排行按钮：[节点, 功能 id]
var _gated: Array = []
var _go_ix := -1
var _go_tw: Tween
var _go_n := 0
var _go_q: Array[Callable] = []
## 0 原位，1 滑入，2 到位，3 等滑出，4 滑出
var _go_phase := 0
var _village: DrawBox
var _ground: DrawBox
var _front: DrawBox
## 部落大地图层（TribeArt.WORLD 大小），position 就是镜头偏移
var _world: Control
var _arrow: TButton
## 拖动：按下位置、是否已经拖起来、上一帧位置、松手后的惯性速度
var _press_at := Vector2.ZERO
var _pressing := false
var _dragging := false
var _last_drag := Vector2.ZERO
var _fling := Vector2.ZERO
var _cam_tw: Tween
## 屏幕上能看清村庄的区域（扣掉顶栏和底部按钮）
const VIEW_FOCUS := Vector2(360, 760)
const DRAG_START := 14.0
## {区域 id: 部件下标}：正在播建造动画的那件，村庄层先不画
var _hide := {}
var _build_fx: Control
const PASS_K := 0.8
const RankPopupScript := preload("res://scripts/ui/RankPopup.gd")
const TribeWalkersScript := preload("res://scripts/ui/TribeWalkers.gd")
## 部落区域的界面图登记（这里只用它的尺寸常量）
const TribeSprites := preload("res://scripts/sprites/tribe.gd")
const CARD_YELLOW := Color("e7b45a")
const CARD_YELLOW_L := Color("f2c66e")

func _ready() -> void:
	size = Vector2(720, 1480)
	mouse_filter = MOUSE_FILTER_IGNORE
	# 部落大地图：比屏幕大，手指拖动看；村庄、走动的小人、地块牌子、建造动画都在 _world 里，按钮固定在屏幕上
	var view := Control.new()
	view.size = size
	view.clip_contents = true
	view.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(view)
	_world = Control.new()
	_world.size = TribeArt.WORLD
	_world.mouse_filter = MOUSE_FILTER_IGNORE
	view.add_child(_world)
	# 三层：地面和后排树、前排树都是静止的，只在建造变化时重画；只有建筑层跟着沸腾线重绘，拖动和动画才不卡
	_ground = UI.box(_world, Rect2(Vector2.ZERO, TribeArt.WORLD), func(_ci, _sz): Paint.village_ground(_ci, G.builds, G.level), false)
	_village = UI.box(_world, Rect2(Vector2.ZERO, TribeArt.WORLD), func(ci, _sz): TribeArt.village(ci, G.builds, G.level, _hide))
	_front = UI.box(_world, Rect2(Vector2.ZERO, TribeArt.WORLD), func(_ci, _sz): Paint.village_front(_ci, G.builds, G.level), false)
	# 「兄弟，我发现」小人在村里溜达（在牌子和按钮下面，只在小人身上接点击）
	var walkers := TribeWalkersScript.new()
	_world.add_child(walkers)
	_spots_root = Control.new()
	_spots_root.mouse_filter = MOUSE_FILTER_IGNORE
	_world.add_child(_spots_root)
	_build_spots()
	# 下一处要建的地方在屏幕外时，屏幕边上一个箭头指过去，点一下镜头滑过去
	_arrow = UI.hit(self, Rect2(0, 0, 96, 96), func(): focus_next(true))
	_arrow.extra = func(ci, sz): _paint_arrow(ci, sz)
	_arrow.visible = false
	focus_next(false)

	# 左上两张小卡：通行证、部落礼包（同一套黄色卡片）
	var ev := UI.hit(self, Rect2(14, 148, 100, 124), func(): G.main.open("pass"))
	ev.extra = func(ci, sz):
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PASS_K)
		_paint_pass(ci, sz / PASS_K)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UI.lbl(ev, TextCatalog.source("developer.host.2f0a2b5a01ff"), Rect2(0, 74, 100, 24), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	_event_lbl = UI.lbl(ev, "", Rect2(24, 98, 72, 20), 13, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 4, Art.INK)
	_gated.append([ev, "pass"])

	# 部落礼包占用原每日特惠位置。
	var gift: Control = preload("res://scripts/ui/GiftChainCard.gd").new()
	add_child(gift)
	_gated.append([gift, "gift"])
	# 赶大集（付费限时礼包）在部落礼包下面，只在这期进行中显示
	add_child(preload("res://scripts/ui/SpreeCard.gd").new())

	var gear := UI.btn(self, Rect2(626, 150, 80, 80), "", "teal", func(): G.main.open("settings"))
	gear.is_round = true
	gear.glyph = "gear"

	# 排行榜：齿轮下面一枚奖杯
	var rank := UI.btn(self, Rect2(626, 246, 80, 80), "", "teal", func(): RankPopupScript.open())
	rank.is_round = true
	rank.extra = func(ci, sz): Sprites.draw(ci, "tribe_trophy", Rect2(sz * 0.5 + TribeSprites.TROPHY_BOX.position, TribeSprites.TROPHY_BOX.size))
	var rank_lbl := UI.lbl(self, TextCatalog.source("ui.homescreen.f70136801523"), Rect2(616, 322, 100, 30), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	_gated.append([rank, "rank"])
	_gated.append([rank_lbl, "rank"])

	_map_btn = UI.btn(self, Rect2(626, 350, 80, 80), TextCatalog.source("ui.homescreen.41ab2e0ecbec"), "teal", func(): G.main.open("map"), 25)
	var build := UI.btn(self, Rect2(16, 1316, 124, 128), "", "wood", _open_next_build)
	build.extra = func(ci, sz): Paint.hammer(ci, sz * 0.5 + Vector2(0, -6), 1.1)
	UI.lbl(build, TextCatalog.source("ui.homescreen.cefdf764cd74"), Rect2(0, 86, 124, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var bk := UI.btn(self, Rect2(150, 1330, 110, 112), "", "hide", func(): G.main.open("book"))
	bk.extra = func(ci, sz):
		Paint.book(ci, sz * 0.5 + Vector2(0, -10), 0.9)
		if G.rules.board.book_prize_count() > 0:
			Paint.badge_num(ci, Vector2(sz.x - 18, 16), 4)
	UI.lbl(bk, TextCatalog.source("ui.homescreen.06169ded8b7b"), Rect2(0, 72, 110, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	_book_btn = bk
	var cd := UI.btn(self, Rect2(270, 1330, 110, 112), "", "hide", func(): G.main.open("event"))
	cd.extra = func(ci, sz): Paint.cards_icon(ci, sz * 0.5 + Vector2(0, -10), 0.85)
	UI.lbl(cd, TextCatalog.source("developer.host.600fd878d296"), Rect2(0, 72, 110, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	cd.visible = G.rules.progression.feature_unlocked(Data.CARD_LEVEL)
	_cards_btn = cd
	go = UI.btn(self, Rect2(398, 1310, 306, 136), TextCatalog.source("ui.homescreen.a2bebd02a1d3"), "green", func(): G.main.show_screen("board"), 54)
	_go_ix = go.get_index()
	go.extra = func(ci, sz):
		Art.item(ci, "fruit_2", Vector2(sz.x - 34, 20), 56)
		Art.item(ci, "roast_7", Vector2(30, sz.y - 22), 50)

	G.changed.connect(_build_spots)
	_build_spots()

## 通行证按钮：青色兽皮卡上一枚琥珀勋章（带当前等级）、两条飘带，底部是到下一级的进度；买了通行证换金边。
## 卡底是预生成的图（tribe_pass / tribe_pass_prem），这里只叠等级数字、进度、时钟和红点。
func _paint_pass(ci: CanvasItem, sz: Vector2) -> void:
	var prem := G.pass_tier > 0
	Sprites.draw(ci, "tribe_pass_prem" if prem else "tribe_pass", Rect2(Vector2.ZERO, TribeSprites.PASS_SIZE))
	var card := Rect2(10, 4, sz.x - 20, 92)
	var mc := Vector2(sz.x * 0.5, 38)
	var f := G.font_title
	var lv := str(maxi(G.rules.progression.pass_reached(), 0) + 1)
	var fs := 24 if lv.length() < 2 else 20
	var tw := f.get_string_size(TextCatalog.resolve(lv), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := Vector2(mc.x - tw * 0.5, mc.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	ci.draw_string_outline(f, tp, TextCatalog.resolve(lv), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Art.INK)
	ci.draw_string(f, tp, TextCatalog.resolve(lv), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# 到下一级的进度
	var bar := Rect2(card.position.x + 12, card.end.y - 20, card.size.x - 24, 11)
	var fr := G.rules.progression.pass_frac()
	if fr > 0.0:
		Sprites.draw(ci, "tribe_pass_fill", Rect2(bar.position, Vector2(maxf(11.0, bar.size.x * fr), bar.size.y)))
	# 剩余时间小牌
	Paint.glyph(ci, "clock", Vector2(24, 134), 0.55, Color("ffe7a8"))
	if G.rules.progression.pass_claimable():
		var c := Vector2(sz.x - 14, 8)
		var bounce := absf(sin(float(Time.get_ticks_msec()) / 260.0)) * 4.0
		c.y -= bounce
		Paint.badge_num(ci, c, 9)
		var w := f.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var pos := Vector2(c.x - w * 0.5, c.y + (f.get_ascent(20) - f.get_descent(20)) * 0.5)
		ci.draw_string_outline(f, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Art.INK)
		ci.draw_string(f, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

# ---------------------------------------------------------------- 镜头：拖动、惯性、对准地块

## 镜头偏移夹在地图范围内（按当前缩放后的地图大小算）
func _clamp_cam(p: Vector2) -> Vector2:
	var w := TribeArt.WORLD * _zoom()
	return Vector2(clampf(p.x, size.x - w.x, 0.0), clampf(p.y, size.y - w.y, 0.0))

## 缩放：最小刚好铺满屏幕，最大 1.6 倍
const ZOOM_MAX := 1.6
func _zoom() -> float:
	return _world.scale.x if _world != null else 1.0

func _zoom_min() -> float:
	return maxf(size.x / TribeArt.WORLD.x, size.y / TribeArt.WORLD.y)

## 以主页坐标里的 anchor 为中心缩放（手指中点 / 鼠标位置下的那块地不动）
func zoom_at(anchor: Vector2, factor: float) -> void:
	var z0 := _zoom()
	var z1 := clampf(z0 * factor, _zoom_min(), ZOOM_MAX)
	if is_equal_approx(z0, z1): return
	if _cam_tw != null and _cam_tw.is_valid(): _cam_tw.kill()
	_fling = Vector2.ZERO
	var wp := (anchor - _world.position) / z0
	_world.scale = Vector2.ONE * z1
	_world.position = _clamp_cam(anchor - wp * z1)

## 屏幕事件坐标 → 主页坐标
func _to_home(p: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * p

## 把地图上的点 at 放到屏幕的 VIEW_FOCUS 处
func focus_on(at: Vector2, animate: bool) -> void:
	var to := _clamp_cam(VIEW_FOCUS - at * _zoom())
	_fling = Vector2.ZERO
	if _cam_tw != null and _cam_tw.is_valid(): _cam_tw.kill()
	if not animate or _world == null:
		if _world != null: _world.position = to
		return
	_cam_tw = create_tween()
	_cam_tw.tween_property(_world, "position", to, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## 对准下一处要建的地块（没有就对准篝火广场）
func focus_next(animate: bool) -> void:
	var id := G.rules.progression.next_build_id()
	focus_on(TribeArt.area_at(id if id != "" else "fire"), animate)

## 能不能拖：在部落页、没有弹窗、没有新手引导的黑罩、没在播建造动画（引导期间没有黑罩时照样能拖）
func _can_drag() -> bool:
	if not is_visible_in_tree() or is_building() or G.main == null or G.main.popup_layer.get_child_count() > 0:
		return false
	var guide = G.main.get("_guide")
	return not (guide != null and is_instance_valid(guide) and guide.visible)

## 双指缩放：按下的手指 {index: 位置}
var _touches := {}
var _pinch_d := 0.0
var _pinching := false
## 双指松开后跟着来的那次模拟鼠标抬起不算点击
var _eat_release := false
var _mouse_up_in_pinch := false

func _input(e: InputEvent) -> void:
	if _world == null:
		return
	# 双指：记下每根手指；两根手指时按距离变化缩放，期间不拖动
	if e is InputEventScreenTouch:
		if e.pressed: _touches[e.index] = e.position
		else: _touches.erase(e.index)
		if _touches.size() >= 2 and _can_drag():
			if not _pinching: _mouse_up_in_pinch = false
			_pinching = true
			_pressing = false
			_dragging = false
			var ps: Array = _touches.values()
			_pinch_d = (ps[0] as Vector2).distance_to(ps[1])
		elif _touches.is_empty() and _pinching:
			_pinching = false
			_eat_release = not _mouse_up_in_pinch
		return
	if e is InputEventScreenDrag:
		if not _touches.has(e.index): return
		_touches[e.index] = e.position
		if _pinching and _touches.size() >= 2:
			var ps: Array = _touches.values()
			var d := (ps[0] as Vector2).distance_to(ps[1])
			if _pinch_d > 1.0 and d > 1.0:
				zoom_at(_to_home(((ps[0] as Vector2) + (ps[1] as Vector2)) * 0.5), d / _pinch_d)
			_pinch_d = d
			get_viewport().set_input_as_handled()
		return
	if e is InputEventMagnifyGesture and _can_drag():
		zoom_at(_to_home(e.position), e.factor)
		return
	# 鼠标滚轮
	if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _can_drag():
			zoom_at(_to_home(e.position), 1.1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1)
			get_viewport().set_input_as_handled()
		return
	if _pinching:
		# 双指期间，系统模拟出来的鼠标事件不拖地图；松手时也别当成点击
		if e is InputEventMouseButton or e is InputEventMouseMotion: get_viewport().set_input_as_handled()
		if e is InputEventMouseButton and not e.pressed: _mouse_up_in_pinch = true
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pressing = _can_drag()
			_dragging = false
			_press_at = e.position
			_last_drag = e.position
			_fling = Vector2.ZERO
		else:
			if _dragging or _eat_release:
				# 拖过了就不算点击，免得松手时点到牌子或小人
				get_viewport().set_input_as_handled()
			_pressing = false
			_dragging = false
			_eat_release = false
	elif e is InputEventMouseMotion and _pressing:
		if not _dragging and e.position.distance_to(_press_at) > DRAG_START:
			_dragging = true
			if _cam_tw != null and _cam_tw.is_valid(): _cam_tw.kill()
		if _dragging:
			var d: Vector2 = (e.position - _last_drag) * _world_scale()
			_world.position = _clamp_cam(_world.position + d)
			_fling = d / maxf(get_process_delta_time(), 0.008)
			_last_drag = e.position
			get_viewport().set_input_as_handled()

## 事件坐标是屏幕像素，主页按 720 宽缩放；换算回主页坐标
func _world_scale() -> float:
	var k := get_global_transform_with_canvas().get_scale().x
	return 1.0 / k if k > 0.0 else 1.0

func _update_camera(delta: float) -> void:
	if not _dragging and _fling.length() > 20.0:
		_world.position = _clamp_cam(_world.position + _fling * delta)
		_fling *= pow(0.04, delta)
	elif not _dragging:
		_fling = Vector2.ZERO
	# 下一处要建的地块在屏幕外：屏幕边上显示箭头
	var id := G.rules.progression.next_build_id()
	var show := id != "" and not G.tutorial_on
	if show:
		var p := TribeArt.area_at(id) * _zoom() + _world.position
		var inner := Rect2(60, 230, size.x - 120, 1020)
		show = not inner.has_point(p)
		if show:
			var c := Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
			_arrow.position = c - _arrow.size * 0.5
			_arrow.set_meta("dir", (p - c).normalized())
	if _arrow.visible != show: _arrow.visible = show
	if show: _arrow.queue_redraw()

func _paint_arrow(ci: CanvasItem, sz: Vector2) -> void:
	var c := sz * 0.5
	var dir: Vector2 = _arrow.get_meta("dir", Vector2.DOWN)
	var bob := sin(float(Time.get_ticks_msec()) / 220.0) * 5.0
	ci.draw_circle(c, 34, Color(0, 0, 0, 0.18))
	ci.draw_circle(c, 31, Art.BONE)
	Paint.hammer(ci, c, 0.42)
	var tip := c + dir * (44.0 + bob)
	var side := dir.orthogonal() * 14.0
	ci.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 22.0 + side, tip - dir * 22.0 - side]), Color("e0a24a"))
	Art.outline(ci, PackedVector2Array([tip, tip - dir * 22.0 + side, tip - dir * 22.0 - side, tip]), 2.0, Art.INK)

func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if active and _spots_dirty: _build_spots()

## 建筑层直接重画；地面和前排树很大，只在开放的地块变了时才重画（G.changed 每秒都会来，不能每次都画）
var _lots_sig := ""
func _redraw_village() -> void:
	_village.queue_redraw()
	var sig := str(Paint._opened(G.builds, G.level))
	if sig == _lots_sig: return
	_lots_sig = sig
	if _ground != null: _ground.queue_redraw()
	if _front != null: _front.queue_redraw()

func _process(delta: float) -> void:
	_update_camera(delta)
	_clock_elapsed += delta
	if _event_lbl and _clock_elapsed >= 1.0:
		_clock_elapsed = fmod(_clock_elapsed, 1.0)
		_event_lbl.text = TextCatalog.resolve(G.fmt_time(G.rules.clock.pass_secs_left()))

func _build_spots() -> void:
	_spots_dirty = true
	if _map_btn != null: _map_btn.visible = G.level >= 5 and int(G.builds.get("fire", 0)) >= 4
	if _book_btn != null: _book_btn.visible = not G.tutorial_on or G.level >= 5 and int(G.builds.get("fire", 0)) >= 4
	if _cards_btn != null:
		_cards_btn.visible = G.rules.progression.feature_unlocked(Data.CARD_LEVEL)
	for pair in _gated:
		if is_instance_valid(pair[0]): pair[0].visible = not G.tutorial_on and G.rules.progression.feature_unlocked(Data.feature_level(str(pair[1])))
	if not is_visible_in_tree(): return
	_spots_dirty = false
	var wanted := {}
	for b in Data.BUILDS:
		var id: String = b["id"]
		wanted[id] = true
		var tag: TButton = _spot_nodes.get(id)
		if tag == null:
			tag = UI.hit(_spots_root, Rect2(TribeArt.tag_at(id) - Vector2(74, 26), Vector2(148, 52)), _open_build.bind(id))
			tag.extra = func(ci, sz): _paint_tag(ci, sz, id)
			_spot_nodes[id] = tag
			spot_created_count += 1
		tag.queue_redraw()
	for id in _spot_nodes.keys():
		if wanted.has(id): continue
		_spot_nodes[id].queue_free()
		_spot_nodes.erase(id)
	_redraw_village()

## 区域木牌：名字 + 进度条；未开放显示等级；钱够下一件时右上角亮红点
func _paint_tag(ci: CanvasItem, sz: Vector2, id: String) -> void:
	var b := Data.build_def(id)
	var prog: Dictionary = G.rules.progression.build_progress(id)
	var total := int(prog["total"])
	var st := int(prog["done"])
	var open := G.rules.progression.build_open(id)
	var done := st >= total
	var seed := absi(id.hash()) % 90
	Sprites.draw(ci, TribeSprites.tag_key(id, open), Rect2(Vector2.ZERO, TribeSprites.TAG_SIZE))
	var ic := Vector2(28, sz.y * 0.5)
	if not open:
		Paint.glyph(ci, "lock", ic, 0.9)
	elif done:
		Paint.check_mark(ci, ic, 0.8)
	else:
		Paint.hammer(ci, ic, 0.36)
	var f := G.font_title
	var fs := 20
	var name := str(b.get("name", id))
	var tp := Vector2(48, 26)
	ci.draw_string_outline(f, tp, TextCatalog.resolve(name), HORIZONTAL_ALIGNMENT_LEFT, sz.x - 56, fs, 5, Art.INK)
	ci.draw_string(f, tp, TextCatalog.resolve(name), HORIZONTAL_ALIGNMENT_LEFT, sz.x - 56, fs, Color.WHITE)
	if open:
		var bar := Rect2(48, 33, sz.x - 62, 9)
		if st > 0:
			var fill := Rect2(bar.position, Vector2(maxf(9.0, bar.size.x * float(st) / float(maxi(total, 1))), bar.size.y))
			Sprites.draw(ci, "tribe_tag_fill", fill, Art.MOSS if not done else Art.OCHRE)
	else:
		var t := TextCatalog.fill(TextCatalog.source("ui.homescreen.1f67da2b53a5"), Data.build_unlock(b)) if not G.rules.progression.feature_unlocked(Data.build_unlock(b)) else TextCatalog.source("ui.homescreen.bebe53ada85d")
		ci.draw_string_outline(G.font_body, Vector2(48, 44), TextCatalog.resolve(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Art.INK)
		ci.draw_string(G.font_body, Vector2(48, 44), TextCatalog.resolve(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffe7a8"))
	if open and not done and G.shells >= G.rules.progression.build_cost(id):
		var c := Vector2(sz.x - 8, 6)
		Paint.badge_num(ci, c, seed + 4)
		var bf := G.font_title
		var w := bf.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var pos := Vector2(c.x - w * 0.5, c.y + (bf.get_ascent(20) - bf.get_descent(20)) * 0.5)
		ci.draw_string_outline(bf, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Art.INK)
		ci.draw_string(bf, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

func _open_build(id: String) -> void:
	if is_building():
		return
	G.main.open("build", id)

func _open_next_build() -> void:
	if is_building():
		return
	var id := G.rules.progression.next_build_id()
	if id == "":
		var all_done := true
		for b in Data.BUILDS:
			if int(G.builds.get(str(b["id"]), 0)) < Data.build_stages(b):
				all_done = false
		G.main.toast(TextCatalog.source("ui.homescreen.c91ca0a16fee") if all_done else TextCatalog.source("ui.homescreen.da3219beab24"))
		return
	focus_on(TribeArt.area_at(id), true)
	G.main.open("build", id)

# ---------------------------------------------------------------- 建造动画

func is_building() -> bool:
	return _build_fx != null and is_instance_valid(_build_fx)

## 部件从地基里敲出来：锤子敲三下扬起尘土 → 部件弹起落地 → 星星散开 → 领奖。
## 分几次建的部件：from/to 是这次建之前、之后的进度（0..1），没建满时长到半成品，标题写 step（如「2/3」）。
func play_build(area: String, idx: int, kind: String, part_name: String, rewards: Array, from := 0.0, to := 1.0, step := "") -> void:
	if is_building():
		_build_fx.queue_free()
	_hide = {area: idx}
	_redraw_village()
	var at := TribeArt.part_at(area, idx)
	focus_on(at, true)
	var h := float(TribeArt._HEIGHT.get(kind, 80)) * TribeArt.VS
	var fx := Control.new()
	fx.size = TribeArt.WORLD
	fx.mouse_filter = MOUSE_FILTER_STOP
	_world.add_child(fx)
	_build_fx = fx
	var st := {"t": 0.0, "hits": 0, "popped": false}
	var dur := 2.3
	var box := UI.box(fx, Rect2(Vector2.ZERO, TribeArt.WORLD), func(ci, _sz): _paint_build(ci, at, kind, h, float(st["t"]), from, to), false)
	var title := TextCatalog.fill(TextCatalog.source("ui.homescreen.28c5830c2172"), part_name) if step == "" else "%s %s" % [TextCatalog.resolve(part_name), step]
	var lbl := UI.lbl(fx, title, Rect2(at.x - 200, at.y - h - 70, 400, 50), 32, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	lbl.position.x = clampf(lbl.position.x, -60.0, TribeArt.WORLD.x - 340.0)
	lbl.modulate.a = 0.0
	lbl.pivot_offset = lbl.size * 0.5
	var tw := fx.create_tween()
	tw.tween_method(func(t: float):
		st["t"] = t
		var due := 0 if t < 0.12 else mini(3, int((t - 0.12) / 0.3) + 1)
		while int(st["hits"]) < due:
			st["hits"] = int(st["hits"]) + 1
			Sfx.play("tap", 0.8 + 0.15 * float(st["hits"]))
			if int(st["hits"]) == 1:
				Sfx.play("crumble")
		if t >= 1.05 and not bool(st["popped"]):
			st["popped"] = true
			Sfx.play("pop")
			Sfx.play("merge", 1.1)
			lbl.scale = Vector2(0.6, 0.6)
			var lt := lbl.create_tween().set_parallel(true)
			lt.tween_property(lbl, "modulate:a", 1.0, 0.18)
			lt.tween_property(lbl, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			lt.tween_property(lbl, "position:y", lbl.position.y - 26.0, 1.0)
		box.queue_redraw()
	, 0.0, dur, dur)
	tw.tween_callback(func():
		_hide = {}
		_redraw_village()
		_build_spots()
		fx.queue_free()
		_build_fx = null
		if not rewards.is_empty():
			G.main.present_rewards(rewards))

func _paint_build(ci: CanvasItem, at: Vector2, kind: String, h: float, t: float, from := 0.0, to := 1.0) -> void:
	var glow_a := clampf(t / 0.2, 0.0, 1.0) * (1.0 - clampf((t - 1.8) / 0.5, 0.0, 1.0))
	ci.draw_colored_polygon(Art.ell(at, Vector2(70, 26), 3, 0.0, 24, 0.0, 0.0), Color(1, 0.9, 0.5, 0.35 * glow_a))
	if t < 1.05:
		# 施工中：半透明剪影一点点长高，锤子敲三下
		var grow := clampf(t / 1.0, 0.0, 1.0)
		if from > 0.0:
			# 已经建过几次：先画现在的半成品，上面一层剪影跟着敲击慢慢长
			TribeArt.part_stage(ci, kind, at, TribeArt.VS, from)
			TribeArt.part(ci, kind, at, TribeArt.VS, Vector2(1.0, lerpf(from, to, grow)), "_flat", Color(1, 0.97, 0.88, 0.18 + 0.1 * sin(t * 30.0)))
		else:
			TribeArt.part(ci, kind, at, TribeArt.VS, Vector2(1.0, (0.15 + 0.55 * grow) * to), "_flat", Color(1, 0.97, 0.88, 0.4 + 0.15 * sin(t * 30.0)))
		Sprites.draw(ci, "tribe_build_ring", Rect2(at - Vector2(40, 17), Vector2(80, 34)))
		var swing := -1.2
		if t >= 0.12:
			var ph := fmod(t - 0.12, 0.3) / 0.3
			swing = -1.2 + 1.6 * pow(ph, 2.2) if ph < 0.75 else 0.4 - 1.6 * (ph - 0.75) / 0.25
		_hammer_at(ci, at + Vector2(54, -h * 0.4 - 24), -swing)
	else:
		# 弹出来：先拉高再压扁再回正
		var u := clampf((t - 1.05) / 0.5, 0.0, 1.0)
		var sy := 1.0 + sin(u * PI * 2.2) * 0.22 * (1.0 - u)
		var sx := 1.0 - (sy - 1.0) * 0.6
		if u < 0.16:
			sy = lerpf(0.5, 1.22, u / 0.16)
			sx = lerpf(1.2, 0.88, u / 0.16)
		TribeArt.part_stage(ci, kind, at, TribeArt.VS, to, "", Vector2(sx, sy))
	for k in 3:
		_dust(ci, at, t - (0.12 + 0.3 * float(k) + 0.22), 4, k * 11)
	_dust(ci, at, t - 1.05, 8, 50)
	if t > 1.05:
		var u := clampf((t - 1.05) / 1.0, 0.0, 1.0)
		var c := at + Vector2(0, -h * 0.5)
		var ring := Art.ell(c, Vector2(1, 1) * (30.0 + u * 120.0), 7, 0.0, 28, 0.0, 0.0)
		Art.outline(ci, ring, 5.0 * (1.0 - u) + 0.5, Color(1, 0.95, 0.7, 0.8 * (1.0 - u)))
		for k in 10:
			var a := TAU * float(k) / 10.0 + 0.3
			var d := 30.0 + u * (90.0 + Art.srnd(k) * 50.0)
			var p := c + Vector2(cos(a), sin(a) * 0.8) * d + Vector2(0, u * u * 40.0)
			var r := 9.0 * (1.0 - u * 0.7)
			Sprites.at(ci, "tribe_star", p, r / TribeSprites.STAR_R, 0.0, Color(1, 0.9 if k % 2 == 0 else 0.75, 0.4, 1.0 - u * u))

func _dust(ci: CanvasItem, at: Vector2, dt: float, n: int, seed: int) -> void:
	if dt < 0.0 or dt > 0.6:
		return
	var u := dt / 0.6
	for k in n:
		var a := PI + PI * (float(k) + 0.5) / float(n) + (Art.srnd(seed + k) - 0.5) * 0.4
		var p := at + Vector2(cos(a) * (20.0 + u * 60.0), sin(a) * (6.0 + u * 22.0) - u * 10.0 + 6.0)
		var r := 10.0 + u * 12.0 + Art.srnd(seed + k * 3) * 6.0
		Sprites.at(ci, "tribe_dust", p, r / TribeSprites.DUST_R, 0.0, Color(0.93, 0.85, 0.7, 0.75 * (1.0 - u)))

## 锤子：pivot 是握把末端，ang 为 0 时锤头朝左敲在地基上
func _hammer_at(ci: CanvasItem, pivot: Vector2, ang: float) -> void:
	ci.draw_set_transform(pivot, ang, Vector2.ONE * 0.9)
	Sprites.draw(ci, "tribe_hammer", TribeSprites.HAMMER_BOX)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- 去合成

func present_go(then: Callable) -> void:
	if go == null or not then.is_valid():
		return
	# 已在顶层并停住（含离开倒计时）：取消倒计时，本批马上飞
	if _go_phase == 2 or _go_phase == 3:
		_stop_go_tw()
		_go_phase = 2
		then.call()
		return
	_go_q.append(then)
	if _go_phase == 1:
		return
	if _go_phase == 0:
		_lift_go()
	_slide_go_in()

func go_center() -> Vector2:
	return Vector2(398, 1310) + Vector2(306, 136) * 0.5

func arm_go(n: int) -> void:
	_go_n += n

func release_go() -> void:
	if _go_n <= 0:
		return
	_go_n -= 1
	if _go_n > 0 or not _go_q.is_empty() or _go_phase != 2:
		return
	_go_phase = 3
	_stop_go_tw()
	_go_tw = create_tween()
	_go_tw.tween_interval(0.35)
	_go_tw.tween_callback(_start_go_out)

func recall_go() -> void:
	if go == null:
		return
	_stop_go_tw()
	_go_q.clear()
	_dock_go()

func _lift_go() -> void:
	var fx: Control = G.main.fx_layer
	if go.get_parent() != fx:
		go.reparent(fx)
	fx.move_child(go, 0)
	go.position = Vector2(398, 1480)

func _slide_go_in() -> void:
	_stop_go_tw()
	_go_phase = 1
	go.position = Vector2(398, go.position.y)
	_go_tw = create_tween()
	_go_tw.tween_property(go, "position:y", 1310.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_go_tw.tween_callback(_on_go_in)

func _on_go_in() -> void:
	if _go_phase != 1:
		return
	_go_phase = 2
	while not _go_q.is_empty():
		var cb: Callable = _go_q.pop_front()
		cb.call()

func _start_go_out() -> void:
	if _go_n > 0 or not _go_q.is_empty() or _go_phase != 3:
		return
	_go_phase = 4
	_go_tw = create_tween()
	_go_tw.tween_property(go, "position:y", 1480.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_go_tw.tween_callback(_finish_go_out)

func _finish_go_out() -> void:
	if _go_phase != 4:
		return
	_dock_go()

func _dock_go() -> void:
	_go_phase = 0
	if go.get_parent() != self:
		go.reparent(self)
	var ix := _go_ix
	if ix < 0 or ix >= get_child_count():
		ix = get_child_count() - 1
	move_child(go, ix)
	go.position = Vector2(398, 1310)

func _stop_go_tw() -> void:
	if _go_tw != null and _go_tw.is_valid():
		_go_tw.kill()
	_go_tw = null
