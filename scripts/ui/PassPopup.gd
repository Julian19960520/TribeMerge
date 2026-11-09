class_name PassPopup
extends RefCounted
## 丰收通行证。头图固定，奖励轨道单独滚动。
## 轨道从下往上走：最下面是起点篝火，第 1 级在底部，越往上级别越高，最顶上是循环宝箱。
## 一根图腾木柱，火光从底部沿柱子往上爬到当前进度；每级一个节点。
## 柱子左边一列免费奖励，右边两列：贵宾奖励（贵宾、超级贵宾都能领）、超级贵宾奖励（只有超级贵宾能领）。

const HEAD_Y := 128.0
const TRACK_TOP := 480.0
const VIEW_H := 1480.0 - TRACK_TOP
const ROW := 178.0
const PAD_TOP := 30.0
const BASE_H := 200.0
const LEFT_X := 14.0
const VIP_X := 292.0
const SUPER_X := 504.0
const CARD_W := 202.0
const CARD_H := 148.0
const BAND_H := 40.0
const MID_X := 252.0
const NODE_R := 34.0
const GLOW := 12.0

const BG_TOP := Color("432b1b")
const BG_BOT := Color("2b1a0f")
const CLOTH := Color("e6cfa2")
const CLOTH_D := Color("d2b684")
const CLOTH_L := Color("f1dfb8")
const PREM := Color("f6d48a")
const PREM_D := Color("e2a94e")
const SUPER := Color("cfe8df")
const SUPER_D := Color("86c7bb")
const DIM_TXT := Color("8a6a48")

static func screen() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 1.0
	p.set_meta("fullscreen", true)
	UI.box(p.box, Rect2(0, 0, 720, 1480), _paint_bg, false)
	var fs := Popups.fullscreen(p, TRACK_TOP)
	var sc: Scroller = fs[0]
	var root: Control = fs[1]
	var n := Data.PASS_LEVELS.size()
	var list_h := _list_h()
	var track := UI.box(root, Rect2(0, TRACK_TOP, 720, list_h), _paint_track)
	var cards: Array = []
	for i in n:
		var lv := i + 1
		var y := TRACK_TOP + _node_y(lv) - CARD_H * 0.5
		cards.append(_card(p, root, Rect2(LEFT_X, y, CARD_W, CARD_H), "free", lv))
		cards.append(_card(p, root, Rect2(VIP_X, y, CARD_W, CARD_H), "prem", lv))
		cards.append(_card(p, root, Rect2(SUPER_X, y, CARD_W, CARD_H), "super", lv))
	# 循环宝箱横跨贵宾、超级两列
	var ey := TRACK_TOP + _node_y(n + 1) - CARD_H * 0.5
	cards.append(_card(p, root, Rect2(VIP_X, ey, SUPER_X + CARD_W - VIP_X, CARD_H), "endless", 0))
	var pulse := _pulse(root)
	sc.set_length(list_h)
	sc.jump_to(_node_y(_focus_lv()) - VIEW_H * 0.58)
	# 头部：标题、剩余时间、等级、进度、购买
	var head := UI.box(p.box, Rect2(0, HEAD_Y, 720, TRACK_TOP - HEAD_Y), _paint_head)
	UI.title(p.box, "丰收通行证", Rect2(150, HEAD_Y + 30, 420, 76), 38)
	var time_lbl := UI.lbl(p.box, "", Rect2(292, HEAD_Y + 116, 176, 40), 22, Art.INK)
	var lv_lbl := UI.lbl(p.box, "", Rect2(24, HEAD_Y + 216, 100, 52), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 7, Art.INK, true)
	var goal_lbl := UI.lbl(p.box, "", Rect2(138, HEAD_Y + 190, 260, 32), 20, Art.ROPE, HORIZONTAL_ALIGNMENT_LEFT)
	var prog_lbl := UI.lbl(p.box, "", Rect2(134, HEAD_Y + 226, 264, 36), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	var act := UI.btn(p.box, Rect2(428, HEAD_Y + 200, 266, 78), "", "green", func(): G.main.open("pass_buy"), 30)
	act.extra = _price_tag
	UI.lbl(p.box, "免费", Rect2(LEFT_X, HEAD_Y + 306, CARD_W, 40), 24, Art.INK, HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
	UI.lbl(p.box, "贵宾", Rect2(VIP_X + 16, HEAD_Y + 306, CARD_W - 16, 40), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	UI.lbl(p.box, "超级贵宾", Rect2(SUPER_X + 16, HEAD_Y + 306, CARD_W - 16, 40), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	var refresh := func():
		var reached := G.pass_reached()
		time_lbl.text = G.fmt_time(G.pass_secs_left())
		lv_lbl.text = str(reached)
		if reached >= n:
			goal_lbl.text = "已满级" + ("，循环宝箱开启中" if G.pass_tier == 2 else "")
		else:
			goal_lbl.text = "再积累 %d 分升到 %d 级" % [maxi(0, _need_left()), reached + 1]
		prog_lbl.text = G.pass_prog_text()
		act.visible = G.pass_tier < 2
		act.text = "升级超级" if G.pass_tier == 1 else "激活贵宾"
		act.queue_redraw()
		head.queue_redraw()
		track.queue_redraw()
		for c in cards:
			_sync_card(c)
		_place_pulse(pulse)
	refresh.call()
	Popups.live(p, G.changed, refresh)
	var clock := Timer.new()
	clock.wait_time = 1.0
	clock.autostart = true
	p.add_child(clock)
	clock.timeout.connect(func():
		if is_instance_valid(time_lbl):
			time_lbl.text = G.fmt_time(G.pass_secs_left()))
	return p

# ---------------------------------------------------------------- 轨道几何（轨道内坐标，0 在轨道顶）

static func _list_h() -> float:
	return PAD_TOP + float(Data.PASS_LEVELS.size() + 1) * ROW + BASE_H

## 节点中心 y。lv = 0 是底部起点篝火，1..n 是各级，n+1 是顶上的循环宝箱。
static func _node_y(lv: int) -> float:
	var n := Data.PASS_LEVELS.size()
	if lv <= 0:
		return PAD_TOP + float(n + 1) * ROW + 62.0
	var k := n + 1 - mini(lv, n + 1)
	return PAD_TOP + float(k) * ROW + ROW * 0.5

## 火光爬到的高度
static func _fill_y() -> float:
	var n := Data.PASS_LEVELS.size()
	var reached := G.pass_reached()
	if reached >= n:
		return _node_y(n + 1) if G.pass_tier == 2 else _node_y(n)
	return lerpf(_node_y(reached), _node_y(reached + 1), G.pass_frac())

static func _need_left() -> int:
	var parts := G.pass_prog_text().split("/")
	if parts.size() < 2:
		return 0
	return int(parts[1]) - int(parts[0])

## 打开时停在哪一级：最低一个能领的，没有就停在正在攒的那一级
static func _focus_lv() -> int:
	var n := Data.PASS_LEVELS.size()
	for lv in range(1, n + 1):
		for track in ["free", "prem", "super"]:
			if _state(track, lv) == "ready":
				return lv
	if G.pass_reached() >= n:
		return n + 1
	return G.pass_reached() + 1

## 一张奖励卡的状态：ready 能领 / done 已领 / future 等级没到 / lock 档位不够（贵宾列要贵宾，超级列要超级贵宾）
## track：free / prem（贵宾）/ super（超级贵宾）/ endless（循环宝箱，lv = 0）
static func _state(track: String, lv: int) -> String:
	if track == "endless":
		if G.pass_tier != 2:
			return "lock"
		return "ready" if G.pass_endless_ready() > 0 else "future"
	if G.pass_got_in(track, lv):
		return "done"
	if lv > G.pass_reached():
		return "future"
	if G.pass_tier < _tier_need(track):
		return "lock"
	return "ready"

static func _tier_need(track: String) -> int:
	match track:
		"prem": return 1
		"super", "endless": return 2
	return 0

static func _rewards(track: String, lv: int) -> Array:
	if track == "endless":
		return [["chest_1", 1]]
	return Data.PASS_LEVELS[lv - 1].get(track, [])

# ---------------------------------------------------------------- 奖励卡

## 卡片是一个按钮，里面套一张自绘卡（按下时跟着按钮一起压扁）；能领的卡轻轻呼吸
static func _card(p: PopupBase, root: Control, r: Rect2, track: String, lv: int) -> Dictionary:
	var b := TButton.new()
	b.position = r.position
	b.size = r.size
	b.style = "none"
	b.name = "claim_%s_%d" % [track, lv]
	root.add_child(b)
	var art := UI.box(b, Rect2(-GLOW, -GLOW, r.size.x + GLOW * 2.0, r.size.y + GLOW * 2.0), func(ci, sz): _paint_card(ci, sz - Vector2(GLOW, GLOW) * 2.0, track, lv))
	art.pivot_offset = art.size * 0.5
	var c := {"btn": b, "art": art, "track": track, "lv": lv, "tw": null}
	b.pressed.connect(func(): _tap(p, c))
	return c

static func _sync_card(c: Dictionary) -> void:
	var art: DrawBox = c["art"]
	art.queue_redraw()
	var ready := _state(str(c["track"]), int(c["lv"])) == "ready"
	var tw: Tween = c["tw"]
	if ready and tw == null:
		tw = art.create_tween().set_loops()
		tw.tween_property(art, "scale", Vector2(1.035, 1.035), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(art, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		c["tw"] = tw
	elif not ready and tw != null:
		tw.kill()
		c["tw"] = null
		art.scale = Vector2.ONE

static func _tap(p: PopupBase, c: Dictionary) -> void:
	var track: String = c["track"]
	var lv: int = c["lv"]
	var st := _state(track, lv)
	if st == "lock" and track != "endless":
		G.main.open("pass_buy")
		return
	if st == "future" and track != "endless":
		G.main.toast("%d 级解锁" % lv)
		return
	if st == "done" or c.get("busy", false):
		return
	# 服务器模式下领取要等服务器回话，期间别让同一张卡再点
	c["busy"] = true
	var rw: Array
	match track:
		"endless": rw = await G.claim_pass_endless()
		"super": rw = await G.claim_pass_super(lv)
		"prem": rw = await G.claim_pass_prem(lv)
		_: rw = await G.claim_pass_free(lv)
	c["busy"] = false
	var b: TButton = c["btn"]
	if rw.is_empty() or not is_instance_valid(b) or not b.is_inside_tree():
		if not rw.is_empty():
			G.main.present_rewards(rw)
		return
	var rect := b.get_global_rect()
	_burst(p, rect.get_center() + Vector2(0, -BAND_H * 0.5))
	var node := b.get_parent() as Control
	_node_flash(node, Vector2(MID_X, b.position.y + CARD_H * 0.5) if lv > 0 else Vector2(MID_X, TRACK_TOP + _node_y(Data.PASS_LEVELS.size() + 1)))
	_give(rw, rect)

## 火种、贝壳、琥珀直接从卡上飞进顶栏；有物品的走全屏领奖
static func _give(rw: Array, rect: Rect2) -> void:
	var simple := true
	for x in rw:
		var id := str(x[0])
		var t := ""
		if Data.DISHES.has(id) or Data.CHAINS.has(Data.chain(id)):
			t = Data.type_of(id)
		if not t in ["energy", "shell", "amber", "sand"]:
			simple = false
	if not simple:
		G.main.present_rewards(rw)
		return
	var spots := _reward_spots(Rect2(rect.position, rect.size), rw)
	Rewards.grant(rw, func(k): return spots[k] if k < spots.size() else rect.get_center())

## 每件奖励图标的中心（卡片坐标系）
static func _reward_spots(r: Rect2, rewards: Array) -> Array:
	var out: Array = []
	var n := rewards.size()
	var gap := minf(118.0, r.size.x * 0.5) if n > 1 else 0.0
	var icon_s := 76.0 if n <= 1 else 52.0
	var f := G.font_title
	var fs := 24 if n <= 1 else 19
	var cy := r.position.y + (r.size.y - BAND_H) * 0.5 + 2.0
	for i in n:
		var text := "×%d" % int(rewards[i][1])
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pair := icon_s * 0.62 + 6.0 + tw
		var cx := r.get_center().x + (float(i) - (n - 1) * 0.5) * gap
		out.append(Vector2(cx - pair * 0.5 + icon_s * 0.42, cy))
	return out

static func _paint_card(ci: CanvasItem, size: Vector2, track: String, lv: int) -> void:
	var st := _state(track, lv)
	var rewards := _rewards(track, lv)
	var r := Rect2(Vector2(GLOW, GLOW), size)
	var seed := lv * 3 + ["free", "prem", "super", "endless"].find(track) + 40
	# 卡底（外框、布面、布条、缝线、骨珠）是预生成贴图；压暗用同形状的白图染色
	Sprites.draw(ci, "ev_pass_card_%s_%s" % [track, "ready" if st == "ready" else "idle"], r)
	var band := Rect2(r.position.x, r.end.y - BAND_H, r.size.x, BAND_H)
	_paint_rewards(ci, Rect2(r.position, Vector2(r.size.x, r.size.y)), rewards)
	var bc := band.get_center()
	match st:
		"ready":
			var pr := Rect2(bc.x - 66, band.position.y - 6, 132, 44)
			Paint.button(ci, pr, "green", seed)
			_center_text(ci, pr.get_center() + Vector2(0, -3), "领取", 24)
			if lv == 0 and G.pass_endless_ready() > 1:
				_count_badge(ci, Vector2(r.end.x - 18, r.position.y + 18), G.pass_endless_ready())
		"done":
			Sprites.draw(ci, "ev_pass_card_shade", r, Color(0.32, 0.2, 0.1, 0.38))
			_band_text(ci, bc, "已领取", Color("5a3d24"))
			Paint.check_mark(ci, Vector2(r.end.x - 26, r.position.y + 26), 1.5)
		"future":
			Sprites.draw(ci, "ev_pass_card_shade", r, Color(0.14, 0.08, 0.04, 0.42))
			if lv == 0:
				_band_text(ci, bc, "每 %d 分开一箱" % Data.pass_need(Data.PASS_LEVELS.size() - 1), Color("f1dfb8"))
			else:
				Paint.glyph(ci, "lock", Vector2(bc.x - 50, bc.y + 1), 1.1)
				_band_text(ci, bc + Vector2(14, 0), "%d 级解锁" % lv, Color("f1dfb8"))
		"lock":
			if lv == 0:
				Sprites.draw(ci, "ev_pass_card_shade", r, Color(0.14, 0.08, 0.04, 0.3))
			Paint.glyph(ci, "lock", Vector2(bc.x - 56, bc.y + 1), 1.1)
			_band_text(ci, bc + Vector2(14, 0), "贵宾可领" if track == "prem" else "超级贵宾", Color.WHITE)

## 多边形 y >= cut 的部分（凸的圆角矩形，按扫描切开就行）
static func _clip_bottom(pts: PackedVector2Array, cut: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := pts.size()
	for i in m:
		var a := pts[i]
		var b := pts[(i + 1) % m]
		if a.y >= cut:
			out.append(a)
		if (a.y >= cut) != (b.y >= cut):
			var t := (cut - a.y) / (b.y - a.y)
			out.append(a.lerp(b, t))
	return out

static func _count_badge(ci: CanvasItem, c: Vector2, n: int) -> void:
	ci.draw_circle(c, 17, Art.INK)
	ci.draw_circle(c, 14, Art.CLAY)
	_center_text(ci, c, str(n), 18)

static func _band_text(ci: CanvasItem, c: Vector2, text: String, col: Color) -> void:
	var f := G.font_title
	var fs := 20
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(c.x - w * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	if col.get_luminance() > 0.6:
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Art.INK)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

static func _paint_rewards(ci: CanvasItem, rect: Rect2, rewards: Array) -> void:
	var n := rewards.size()
	var f := G.font_title
	var fs := 24 if n <= 1 else 19
	var icon_s := 76.0 if n <= 1 else 52.0
	var spots := _reward_spots(rect, rewards)
	for i in n:
		var text := "×%d" % int(rewards[i][1])
		var c: Vector2 = spots[i]
		Sprites.draw(ci, "ev_ell_shadow", Rect2(c + Vector2(-icon_s * 0.36, icon_s * 0.26), Vector2(icon_s * 0.72, icon_s * 0.2)), Color(0.35, 0.2, 0.08, 0.18))
		Art.item(ci, str(rewards[i][0]), c, icon_s)
		var baseline := c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5 + icon_s * 0.12
		_outlined(ci, Vector2(c.x + icon_s * 0.3, baseline), text, fs, Color.WHITE, f)

# ---------------------------------------------------------------- 领取反馈

static func _burst(p: PopupBase, c: Vector2) -> void:
	var d := UI.box(p.box, Rect2(c - Vector2(130, 130), Vector2(260, 260)), func(ci, sz):
		Sprites.draw(ci, "ev_pass_burst", Rect2(Vector2.ZERO, sz))
	, false)
	d.pivot_offset = d.size * 0.5
	d.scale = Vector2(0.3, 0.3)
	var tw := d.create_tween().set_parallel(true)
	tw.tween_property(d, "scale", Vector2(1.15, 1.15), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "rotation", 0.5, 0.6)
	tw.tween_property(d, "modulate:a", 0.0, 0.3).set_delay(0.3)
	tw.chain().tween_callback(d.queue_free)
	Sfx.play("pop", 1.2)

static func _node_flash(root: Control, c: Vector2) -> void:
	var d := UI.box(root, Rect2(c - Vector2(80, 80), Vector2(160, 160)), func(ci, sz):
		var o: Vector2 = sz * 0.5
		ci.draw_circle(o, 64, Color(Art.FIRE2, 0.35))
		ci.draw_circle(o, 46, Color(1, 1, 1, 0.55))
		ci.draw_arc(o, 56, 0, TAU, 40, Color.WHITE, 5.0, true)
	, false)
	d.pivot_offset = d.size * 0.5
	d.scale = Vector2(0.5, 0.5)
	var tw := d.create_tween().set_parallel(true)
	tw.tween_property(d, "scale", Vector2(1.3, 1.3), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(d, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(d.queue_free)

## 正在攒的那一级节点外面一圈呼吸的光环
static func _pulse(root: Control) -> DrawBox:
	var d := UI.box(root, Rect2(0, 0, 150, 150), func(ci, sz):
		var o: Vector2 = sz * 0.5
		ci.draw_circle(o, 60, Color(Art.TEAL, 0.22))
		ci.draw_arc(o, 56, 0, TAU, 44, Color("bff3e8"), 5.0, true)
	, false)
	d.pivot_offset = d.size * 0.5
	d.z_index = 0
	var tw := d.create_tween().set_loops()
	tw.tween_property(d, "scale", Vector2(1.18, 1.18), 0.75).from(Vector2(0.72, 0.72)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(d, "modulate:a", 0.0, 0.75).from(1.0).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.25)
	return d

static func _place_pulse(d: DrawBox) -> void:
	var n := Data.PASS_LEVELS.size()
	var reached := G.pass_reached()
	d.visible = reached < n
	if reached < n:
		d.position = Vector2(MID_X, TRACK_TOP + _node_y(reached + 1)) - d.size * 0.5
		d.get_parent().move_child(d, 1)

# ---------------------------------------------------------------- 购买

static func buy() -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(32, 188, 656, 1120)
	Popups.frame(p, r, "丰收通行证", Art.CLAY)
	UI.box(p.box, Rect2(r.position.x + 36, r.position.y + 48, r.size.x - 72, 250), _paint_hoard)
	var tw := 292.0
	var th := 700.0
	var y := r.position.y + 318.0
	_ticket(p, Rect2(r.position.x + 24, y, tw, th), false)
	_ticket(p, Rect2(r.end.x - 24 - tw, y, tw, th), true)
	return p

static func _ticket(p: PopupBase, r: Rect2, super_vip: bool) -> void:
	UI.box(p.box, r, func(ci, sz): _paint_ticket(ci, sz, not super_vip))
	UI.lbl(p.box, "超级贵宾" if super_vip else "贵宾", Rect2(r.position.x + 12, r.position.y + 20, r.size.x - 24, 50), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	UI.lbl(p.box, "解锁贵宾 + 超级两列奖励" if super_vip else "解锁贵宾一列奖励", Rect2(r.position.x + 12, r.position.y + 96, r.size.x - 24, 36), 22, Color("6b4a2a"))
	UI.lbl(p.box, "+", Rect2(r.position.x, r.position.y + 136, r.size.x, 48), 40, Art.MOSS, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	if super_vip:
		var x1 := r.position.x + 78.0
		var x2 := r.end.x - 86.0
		var iy := r.position.y + 230.0
		UI.icon(p.box, "fire_2", Vector2(x1, iy), 86)
		UI.lbl(p.box, "×150", Rect2(x1 - 50, iy + 44, 100, 32), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		UI.icon(p.box, "chest_1", Vector2(x2, iy), 86)
		UI.lbl(p.box, "解锁循环奖励", Rect2(x2 - 72, iy + 48, 150, 32), 16, Color("6b4a2a"))
		var y2 := iy + 146.0
		UI.icon(p.box, "token_1", Vector2(x1, y2), 80)
		UI.lbl(p.box, "×10", Rect2(x1 - 50, y2 + 42, 100, 32), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		UI.lbl(p.box, "订单额外 +1 积分", Rect2(x2 - 78, y2 - 8, 156, 64), 18, Color("6b4a2a"))
		_stamp(p, r)
	else:
		UI.icon(p.box, "fire_2", r.position + Vector2(r.size.x * 0.5, 268), 110)
		UI.lbl(p.box, "×150", Rect2(r.position.x, r.position.y + 322, r.size.x, 44), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 7, Art.INK, true)
	var owned := G.pass_tier >= (2 if super_vip else 1)
	var b := UI.btn(p.box, Rect2(r.position.x + 24, r.end.y - 108, r.size.x - 48, 80), "¥%d" % G.pass_cny("super" if super_vip else "vip"), "green", Callable(), 40)
	b.title_font = false  # 标题字体里没有「¥」
	if owned:
		b.text = "已拥有"
		b.enabled = false
	elif super_vip:
		b.pressed.connect(func(): _do_super(p))
		if G.pass_tier == 1:
			# 已经是贵宾：只补差价，原价划掉
			var full := "原价 ¥%d" % int(G.PASS_CNY["super"])
			var note := UI.lbl(p.box, full + "，贵宾补差价", Rect2(r.position.x + 12, r.end.y - 150, r.size.x - 24, 34), 19, Art.CLAY)
			UI.box(p.box, note.get_rect(), func(ci, sz):
				var f: Font = G.font_body
				var tw: float = f.get_string_size(full + "，贵宾补差价", HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
				var fw: float = f.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
				var x0: float = (sz.x - tw) * 0.5 + f.get_string_size("原价 ", HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
				ci.draw_line(Vector2(x0 - 2, sz.y * 0.52), Vector2((sz.x - tw) * 0.5 + fw + 2, sz.y * 0.52), Art.CLAY, 2.0)
			, false)
	else:
		b.pressed.connect(func(): _do_vip(p))

static func _stamp(p: PopupBase, r: Rect2) -> void:
	var s := Rect2(r.end.x - 78, r.position.y - 8, 92, 92)
	UI.box(p.box, s, func(ci, sz):
		Sprites.draw(ci, "ev_pass_stamp", Rect2(Vector2.ZERO, sz)))
	var lab := UI.lbl(p.box, "超值", Rect2(s.position.x, s.position.y + 26, s.size.x, 40), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	lab.pivot_offset = lab.size * 0.5
	lab.rotation = 0.18

static func _do_vip(p: PopupBase) -> void:
	if not await G.buy_pass_vip():
		return
	p.close()
	G.main.toast("已激活贵宾：火种 ×150，贵宾奖励已开放")

static func _do_super(p: PopupBase) -> void:
	var fresh := G.pass_tier == 0
	if not await G.buy_pass_super():
		return
	p.close()
	if fresh:
		G.main.toast("已激活超级贵宾：火种 ×150，通行证 +10，超级奖励和循环宝箱已开放")
	else:
		G.main.toast("已升级超级贵宾：通行证 +10，超级奖励和循环宝箱已开放")

# ---------------------------------------------------------------- 背景、头部

static func _paint_bg(ci: CanvasItem, sz: Vector2) -> void:
	Paint.vgrad(ci, Rect2(0, 0, sz.x, 330), Color("8fd0d4"), Color("f0deb0"))
	Paint.vgrad(ci, Rect2(0, 330, sz.x, sz.y - 330), BG_TOP, BG_BOT)

static func _paint_head(ci: CanvasItem, sz: Vector2) -> void:
	# 天空和远景（头部局部坐标，0 = 顶栏下沿）
	Paint.hills(ci, 120, sz.x, 22, Color("7fb48a"), 2, 190)
	Paint.hills(ci, 150, sz.x, 12, Color("5c9a68"), 6, 190)
	Paint.palm(ci, Vector2(30, 176), 110, 3, Color("3f7a40"))
	Paint.palm(ci, Vector2(694, 180), 96, 8, Color("4a8a4a"))
	Paint.heroine(ci, Vector2(88, 118), 76)
	Paint.mascot(ci, Vector2(636, 108), 82)
	Paint.banner(ci, Rect2(150, 26, 420, 84), Art.CLAY)
	Paint.pill(ci, Rect2(252, 116, 216, 40), 11)
	Paint.glyph(ci, "clock", Vector2(278, 136), 1.15)
	# 兽皮状态条
	var band := Rect2(0, 172, sz.x, 128)
	ci.draw_rect(band, Art.LEATHER)
	ci.draw_rect(Rect2(0, band.position.y, sz.x, 6), Art.LEATHER_D)
	ci.draw_rect(Rect2(0, band.end.y - 4, sz.x, 4), Art.LEATHER_D)
	Art.dashed(ci, PackedVector2Array([Vector2(8, band.position.y + 14), Vector2(sz.x - 8, band.position.y + 14)]), 9.0, 7.0, Art.ROPE, 2.0)
	Art.dashed(ci, PackedVector2Array([Vector2(8, band.end.y - 14), Vector2(sz.x - 8, band.end.y - 14)]), 9.0, 7.0, Art.ROPE, 2.0)
	# 等级徽章：一块嵌在兽皮上的赭石圆章
	var mc := Vector2(74, band.position.y + 70)
	Sprites.draw(ci, "ev_pass_medal", Rect2(mc - Vector2(48, 48), Vector2(96, 96)))
	# 进度条
	Paint.bar(ci, Rect2(134, band.position.y + 54, 264, 36), G.pass_frac(), Art.FIRE, 14)
	# 列标题：左边布、右边赭石
	var strip := Rect2(0, 300, sz.x, sz.y - 300)
	ci.draw_rect(strip, BG_TOP)
	var tabs := [[LEFT_X, CLOTH, 0], [VIP_X, Art.OCHRE, 1], [SUPER_X, Art.TEAL, 2]]
	for k in tabs.size():
		var x: float = tabs[k][0]
		Sprites.draw(ci, "ev_pass_tab_%d" % k, Rect2(x, 308, CARD_W, 38))
		var need: int = tabs[k][2]
		if need == 0:
			continue
		if G.pass_tier < need:
			Paint.glyph(ci, "lock", Vector2(x + 26, 328), 1.15)
		else:
			Paint.check_mark(ci, Vector2(x + 24, 327), 0.95)
	# 图腾柱顶：一张刻出来的脸
	Sprites.draw(ci, "ev_pass_totem", Rect2(MID_X - 34, 326 - 28, 68, 60))

## 购买按钮右上角的价签：人民币价格（贵宾 ¥30，超级贵宾 ¥68）
static func _price_tag(ci: CanvasItem, sz: Vector2) -> void:
	var price := "¥%d" % G.pass_cny("super" if G.pass_tier == 1 else "vip")
	var r := Rect2(sz.x - 84, -20, 92, 38)
	Sprites.draw(ci, "ev_pass_price", r)
	# 标题字体里没有「¥」，价签用正文字体
	var f := G.font_body
	var w := f.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var pos := Vector2(r.get_center().x - w * 0.5, r.get_center().y + (f.get_ascent(24) - f.get_descent(24)) * 0.5)
	_outlined(ci, pos, price, 24, Color.WHITE, f)

# ---------------------------------------------------------------- 轨道：图腾柱、节点、起点篝火

static func _paint_track(ci: CanvasItem, sz: Vector2) -> void:
	var n := Data.PASS_LEVELS.size()
	var reached := G.pass_reached()
	# 帐篷里的布纹：几道很淡的竖条
	for k in 9:
		if k % 2 == 0:
			ci.draw_rect(Rect2(float(k) * 80.0, 0, 80, sz.y), Color(1, 0.9, 0.7, 0.025))
	var top_y := 0.0
	var base_y := _node_y(0)
	var fill_y := _fill_y()
	# 连到卡片的绳子（先画，压在柱子和节点下面）
	for lv in range(1, n + 1):
		var y := _node_y(lv)
		var lit := lv <= reached
		_rope(ci, LEFT_X + CARD_W - 4, MID_X - NODE_R, y, lit, lv)
		_rope(ci, MID_X + NODE_R, VIP_X + 4, y, lit, lv + 20)
	_rope(ci, MID_X + NODE_R + 6, VIP_X + 4, _node_y(n + 1), reached >= n, 60)
	# 柱身
	var pole := Rect2(MID_X - 18, top_y, 36, base_y - top_y)
	ci.draw_rect(pole.grow(3), Art.INK)
	ci.draw_rect(pole, Art.WOOD)
	ci.draw_rect(Rect2(pole.position.x, top_y, 6, pole.size.y), Color(1, 1, 1, 0.12))
	ci.draw_rect(Rect2(pole.end.x - 7, top_y, 7, pole.size.y), Color(0, 0, 0, 0.14))
	var ch := Rect2(MID_X - 8, top_y, 16, base_y - top_y)
	ci.draw_rect(ch.grow(2), Art.INK)
	ci.draw_rect(ch, Color("2a1a10"))
	# 火光从底部往上爬
	if fill_y < base_y:
		var fr := Rect2(ch.position.x, fill_y, ch.size.x, base_y - fill_y)
		ci.draw_rect(fr, Art.FIRE)
		ci.draw_rect(Rect2(fr.position.x + 3, fr.position.y, 5, fr.size.y), Art.FIRE2)
	# 绳结：每两级之间缠一道
	for lv in range(0, n + 1):
		var y := (_node_y(lv) + _node_y(lv + 1)) * 0.5
		_lash(ci, y, fill_y <= y)
	# 火光顶端的小火苗
	if reached < n:
		Sprites.draw(ci, "ev_pass_flame", Rect2(MID_X - 28, fill_y - 6 - 18, 56, 36))
	# 节点
	for lv in range(1, n + 1):
		_node(ci, lv, reached)
	_endless_node(ci, reached >= n)
	_endless_note(ci)
	_base(ci, base_y)

static func _rope(ci: CanvasItem, x0: float, x1: float, y: float, lit: bool, seed: int) -> void:
	var a := Vector2(x0, y)
	var b := Vector2(x1, y)
	ci.draw_line(a, b, Art.INK, 9.0)
	ci.draw_line(a, b, Art.ROPE if lit else Color("8a7458"), 5.0)
	var k := 0.0
	while k < 1.0:
		var p := a.lerp(b, k)
		ci.draw_line(p + Vector2(-2, -3), p + Vector2(2, 3), Color(Art.INK, 0.35), 1.5)
		k += 10.0 / maxf(1.0, x1 - x0)
	var m := a.lerp(b, 0.5)
	ci.draw_circle(m, 7.0, Art.INK)
	ci.draw_circle(m, 5.0, Art.BONE if lit else Color("b8a88c"))

static func _lash(ci: CanvasItem, y: float, lit: bool) -> void:
	for k in 3:
		var yy := y - 9.0 + float(k) * 7.0
		ci.draw_line(Vector2(MID_X - 21, yy + 3), Vector2(MID_X + 21, yy - 3), Art.INK, 6.0)
		ci.draw_line(Vector2(MID_X - 20, yy + 3), Vector2(MID_X + 20, yy - 3), Art.ROPE if lit else Color("9c8664"), 3.5)

static func _node(ci: CanvasItem, lv: int, reached: int) -> void:
	var c := Vector2(MID_X, _node_y(lv))
	var done := lv <= reached
	var cur := lv == reached + 1
	Sprites.draw(ci, "ev_pass_node_" + ("done" if done else ("cur" if cur else "idle")), Rect2(c - Vector2(NODE_R, NODE_R), Vector2(NODE_R, NODE_R) * 2.0))
	if done or cur:
		_center_text(ci, c, str(lv), 28)
	else:
		var f := G.font_title
		var w := f.get_string_size(str(lv), HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		ci.draw_string(f, Vector2(c.x - w * 0.5, c.y + (f.get_ascent(28) - f.get_descent(28)) * 0.5), str(lv), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("a8977f"))

static func _endless_node(ci: CanvasItem, lit: bool) -> void:
	var c := Vector2(MID_X, _node_y(Data.PASS_LEVELS.size() + 1))
	Sprites.draw(ci, "ev_pass_endless_" + ("lit" if lit else "dim"), Rect2(c - Vector2(52, 52), Vector2(104, 104)))
	Art.item(ci, "chest_1", c + Vector2(0, -4), 52)
	if not lit:
		Sprites.draw(ci, "ev_pass_endless_shade", Rect2(c - Vector2(33, 33), Vector2(66, 66)), Color(0.2, 0.13, 0.08, 0.5))

## 循环那一行左边的说明，挂一块小木牌
static func _endless_note(ci: CanvasItem) -> void:
	var y := _node_y(Data.PASS_LEVELS.size() + 1)
	var r := Rect2(LEFT_X + 8, y - 52, CARD_W - 16, 104)
	for x in [r.position.x + 30, r.end.x - 30]:
		ci.draw_line(Vector2(x, r.position.y - 20), Vector2(x, r.position.y + 6), Art.INK, 5.0)
		ci.draw_line(Vector2(x, r.position.y - 20), Vector2(x, r.position.y + 6), Art.ROPE, 2.5)
	Sprites.draw(ci, "ev_pass_note", r)
	var f := G.font_title
	var lines := ["满级之后", "每 %d 分再开一箱" % Data.pass_need(Data.PASS_LEVELS.size() - 1)]
	for i in lines.size():
		var fs := 22 if i == 0 else 18
		var w := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_outlined(ci, Vector2(r.get_center().x - w * 0.5, r.position.y + 42 + i * 34), lines[i], fs, Art.FIRE2 if i == 0 else Art.BONE, f)

## 柱脚：石堆上一团篝火，写着「起点」
static func _base(ci: CanvasItem, y: float) -> void:
	var c := Vector2(MID_X, y)
	Sprites.draw(ci, "ev_pass_base", Rect2(c + Vector2(-136, 6), Vector2(272, 70)))
	Art.item(ci, "fire_3", c + Vector2(0, -4), 92)
	var f := G.font_title
	var w := f.get_string_size("起点", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_outlined(ci, Vector2(c.x - w * 0.5, c.y + 84), "起点", 24, Art.ROPE, f)

# ---------------------------------------------------------------- 购买页画面

static func _paint_ticket(ci: CanvasItem, sz: Vector2, vip: bool) -> void:
	Sprites.draw(ci, "ev_pass_ticket_" + ("vip" if vip else "super"), Rect2(2, 8, sz.x - 4, sz.y - 14))


static func _paint_hoard(ci: CanvasItem, sz: Vector2) -> void:
	Sprites.draw(ci, "ev_ell_shadow", Rect2(sz.x * 0.12, sz.y * 0.78 - 28, sz.x * 0.76, 56), Color(0.45, 0.24, 0.08, 0.28))
	var spots := [Vector2(0.18, 0.60), Vector2(0.34, 0.70), Vector2(0.50, 0.74), Vector2(0.66, 0.70), Vector2(0.82, 0.60), Vector2(0.28, 0.50), Vector2(0.72, 0.48)]
	var scales := [58.0, 70.0, 62.0, 72.0, 56.0, 54.0, 60.0]
	var tilt := [-0.3, 0.15, -0.1, 0.25, 0.35, -0.2, 0.1]
	for i in spots.size():
		Art.item(ci, Art.AMBER_ICON, Vector2(spots[i].x * sz.x, spots[i].y * sz.y), scales[i], true, tilt[i])
	Art.item(ci, "chest_1", Vector2(sz.x * 0.5, sz.y * 0.40), 170)
	Art.item(ci, Art.AMBER_ICON, Vector2(sz.x * 0.30, sz.y * 0.84), 74, true, 0.2)
	Art.item(ci, Art.AMBER_ICON, Vector2(sz.x * 0.50, sz.y * 0.88), 54, true, -0.15)
	Art.item(ci, Art.AMBER_ICON, Vector2(sz.x * 0.70, sz.y * 0.84), 68, true, -0.3)

static func _center_text(ci: CanvasItem, c: Vector2, text: String, fs: int) -> void:
	var f := G.font_title
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(c.x - w * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	_outlined(ci, pos, text, fs, Color.WHITE, f)

static func _outlined(ci: CanvasItem, pos: Vector2, text: String, fs: int, col: Color, font: Font) -> void:
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Art.INK)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
