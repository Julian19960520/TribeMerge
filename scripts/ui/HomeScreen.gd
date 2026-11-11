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
var _go_ix := -1
var _go_tw: Tween
var _go_n := 0
var _go_q: Array[Callable] = []
## 0 原位，1 滑入，2 到位，3 等滑出，4 滑出
var _go_phase := 0
var _village: DrawBox
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
	_village = UI.box(self, Rect2(0, 0, 720, 1480), func(ci, sz): Paint.village(ci, sz, G.builds, G.level, _hide))
	# 「兄弟，我发现」小人在村里溜达（在牌子和按钮下面，只在小人身上接点击）
	var walkers := TribeWalkersScript.new()
	add_child(walkers)
	_spots_root = Control.new()
	_spots_root.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_spots_root)
	_build_spots()

	# 左上两张小卡：通行证、部落礼包（同一套黄色卡片）
	var ev := UI.hit(self, Rect2(14, 148, 100, 124), func(): G.main.open("pass"))
	ev.extra = func(ci, sz):
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PASS_K)
		_paint_pass(ci, sz / PASS_K)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UI.lbl(ev, "通行证", Rect2(0, 74, 100, 24), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	_event_lbl = UI.lbl(ev, "", Rect2(24, 98, 72, 20), 13, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 4, Art.INK)

	# 部落礼包占用原每日特惠位置。
	add_child(preload("res://scripts/ui/GiftChainCard.gd").new())
	# 赶大集（付费限时礼包）在部落礼包下面，只在这期进行中显示
	add_child(preload("res://scripts/ui/SpreeCard.gd").new())

	var gear := UI.btn(self, Rect2(626, 150, 80, 80), "", "teal", func(): G.main.open("settings"))
	gear.is_round = true
	gear.glyph = "gear"

	# 排行榜：齿轮下面一枚奖杯
	var rank := UI.btn(self, Rect2(626, 246, 80, 80), "", "teal", func(): RankPopupScript.open())
	rank.is_round = true
	rank.extra = func(ci, sz): Sprites.draw(ci, "tribe_trophy", Rect2(sz * 0.5 + TribeSprites.TROPHY_BOX.position, TribeSprites.TROPHY_BOX.size))
	UI.lbl(self, "排行", Rect2(616, 322, 100, 30), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)

	var build := UI.btn(self, Rect2(16, 1316, 124, 128), "", "wood", _open_next_build)
	build.extra = func(ci, sz): Paint.hammer(ci, sz * 0.5 + Vector2(0, -6), 1.1)
	UI.lbl(build, "建造", Rect2(0, 86, 124, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var bk := UI.btn(self, Rect2(150, 1330, 110, 112), "", "hide", func(): G.main.open("book"))
	bk.extra = func(ci, sz):
		Paint.book(ci, sz * 0.5 + Vector2(0, -10), 0.9)
		if G.rules.board.book_prize_count() > 0:
			Paint.badge_num(ci, Vector2(sz.x - 18, 16), 4)
	UI.lbl(bk, "图鉴", Rect2(0, 72, 110, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var cd := UI.btn(self, Rect2(270, 1330, 110, 112), "", "hide", func(): G.main.open("event"))
	cd.extra = func(ci, sz): Paint.cards_icon(ci, sz * 0.5 + Vector2(0, -10), 0.85)
	UI.lbl(cd, "卡册", Rect2(0, 72, 110, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	cd.visible = G.rules.progression.feature_unlocked(Data.CARD_LEVEL)
	_cards_btn = cd
	go = UI.btn(self, Rect2(398, 1310, 306, 136), "去合成", "green", func(): G.main.show_screen("board"), 54)
	_go_ix = go.get_index()
	go.extra = func(ci, sz):
		Art.item(ci, "fruit_2", Vector2(sz.x - 34, 20), 56)
		Art.item(ci, "roast_7", Vector2(30, sz.y - 22), 50)

	G.changed.connect(_build_spots)

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
	var tw := f.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := Vector2(mc.x - tw * 0.5, mc.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	ci.draw_string_outline(f, tp, lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Art.INK)
	ci.draw_string(f, tp, lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
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

func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if active and _spots_dirty: _build_spots()

func _process(delta: float) -> void:
	_clock_elapsed += delta
	if _event_lbl and _clock_elapsed >= 1.0:
		_clock_elapsed = fmod(_clock_elapsed, 1.0)
		_event_lbl.text = G.fmt_time(G.rules.clock.pass_secs_left())

func _build_spots() -> void:
	_spots_dirty = true
	if _cards_btn != null:
		_cards_btn.visible = G.rules.progression.feature_unlocked(Data.CARD_LEVEL)
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
	_village.queue_redraw()

## 区域木牌：名字 + 进度条；未开放显示等级；钱够下一件时右上角亮红点
func _paint_tag(ci: CanvasItem, sz: Vector2, id: String) -> void:
	var b := Data.build_def(id)
	var total := Data.build_stages(b)
	var st := clampi(int(G.builds.get(id, 0)), 0, total)
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
	ci.draw_string_outline(f, tp, name, HORIZONTAL_ALIGNMENT_LEFT, sz.x - 56, fs, 5, Art.INK)
	ci.draw_string(f, tp, name, HORIZONTAL_ALIGNMENT_LEFT, sz.x - 56, fs, Color.WHITE)
	if open:
		var bar := Rect2(48, 33, sz.x - 62, 9)
		if st > 0:
			var fill := Rect2(bar.position, Vector2(maxf(9.0, bar.size.x * float(st) / float(maxi(total, 1))), bar.size.y))
			Sprites.draw(ci, "tribe_tag_fill", fill, Art.MOSS if not done else Art.OCHRE)
	else:
		var t := "Lv.%d 开放" % Data.build_unlock(b)
		ci.draw_string_outline(G.font_body, Vector2(48, 44), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Art.INK)
		ci.draw_string(G.font_body, Vector2(48, 44), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffe7a8"))
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
		G.main.toast("部落已经全部建好啦！" if all_done else "升级主角等级，开放新的建造区域")
		return
	G.main.open("build", id)

# ---------------------------------------------------------------- 建造动画

func is_building() -> bool:
	return _build_fx != null and is_instance_valid(_build_fx)

## 部件从地基里敲出来：锤子敲三下扬起尘土 → 部件弹起落地 → 星星散开 → 领奖
func play_build(area: String, idx: int, kind: String, part_name: String, rewards: Array) -> void:
	if is_building():
		_build_fx.queue_free()
	_hide = {area: idx}
	_village.queue_redraw()
	var at := TribeArt.part_at(area, idx)
	var h := float(TribeArt._HEIGHT.get(kind, 80)) * TribeArt.VS
	var fx := Control.new()
	fx.size = size
	fx.mouse_filter = MOUSE_FILTER_STOP
	add_child(fx)
	_build_fx = fx
	var st := {"t": 0.0, "hits": 0, "popped": false}
	var dur := 2.3
	var box := UI.box(fx, Rect2(Vector2.ZERO, size), func(ci, _sz): _paint_build(ci, at, kind, h, float(st["t"])), false)
	var lbl := UI.lbl(fx, "%s 建成！" % part_name, Rect2(at.x - 200, at.y - h - 70, 400, 50), 32, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	lbl.position.x = clampf(lbl.position.x, -60.0, size.x - 340.0)
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
		_village.queue_redraw()
		_build_spots()
		fx.queue_free()
		_build_fx = null
		if not rewards.is_empty():
			G.main.present_rewards(rewards))

func _paint_build(ci: CanvasItem, at: Vector2, kind: String, h: float, t: float) -> void:
	var glow_a := clampf(t / 0.2, 0.0, 1.0) * (1.0 - clampf((t - 1.8) / 0.5, 0.0, 1.0))
	ci.draw_colored_polygon(Art.ell(at, Vector2(70, 26), 3, 0.0, 24, 0.0, 0.0), Color(1, 0.9, 0.5, 0.35 * glow_a))
	if t < 1.05:
		# 施工中：半透明剪影一点点长高，锤子敲三下
		var grow := clampf(t / 1.0, 0.0, 1.0)
		TribeArt.part(ci, kind, at, TribeArt.VS, Vector2(1.0, 0.15 + 0.55 * grow), "_flat", Color(1, 0.97, 0.88, 0.4 + 0.15 * sin(t * 30.0)))
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
		TribeArt.part(ci, kind, at, TribeArt.VS, Vector2(sx, sy))
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
