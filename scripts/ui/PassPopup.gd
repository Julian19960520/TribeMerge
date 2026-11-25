class_name PassPopup
extends RefCounted
const Payments := preload("res://scripts/net/Payments.gd")
const Meme := preload("res://scripts/Meme.gd")
## 丰收通行证。头图固定，奖励轨道单独滚动。
## 轨道从下往上走：最下面是起点篝火，第 1 级在底部，越往上级别越高，最顶上是循环宝箱。
## 一根图腾木柱，火光从底部沿柱子往上爬到当前进度；每级一个节点。
## 柱子左边一列免费奖励，右边两列：贵宾奖励（贵宾、超级贵宾都能领）、超级贵宾奖励（只有超级贵宾能领）。

const HEAD_Y := 128.0
const TRACK_TOP := 480.0
const VIEW_H := 1480.0 - TRACK_TOP
const ROW := 178.0
const PAD_TOP := 30.0
const BASE_H := 48.0
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
const SMILE_GOLD := Color("ffd24c")
const SMILE_SHADE := Color("f2a827")
const SMILE_CHEEK := Color("ef7e5d")

## 当前酋长整体满意度比例 [0.0, 1.0]，用于驱动顶部笑脸从平静无极插值到开怀大笑
static func satisfaction_ratio() -> float:
	var n := maxf(1.0, float(Data.PASS_LEVELS.size()))
	return clampf((float(G.rules.progression.pass_reached()) + G.rules.progression.pass_frac()) / n, 0.0, 1.0)

## 无极插值笑脸绘制函数：t ∈ [0.0, 1.0]
## t = 0.0：平嘴、平静圆眼、几乎无腮红；
## t ≈ 0.5：温柔微笑、温暖腮红；
## t = 1.0：张开嘴哈哈大笑（露小舌头）、弯弯笑眼、饱满腮红。
static func draw_smile_lerp(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	var k := clampf(t, 0.0, 1.0)
	var outline := maxf(2.0, r * 0.14)
	var face_col := Color("f4d786").lerp(SMILE_GOLD, k)
	var shade_col := Color("d9b252").lerp(SMILE_SHADE, k)
	ci.draw_circle(c + Vector2(0, r * 0.12), r + outline * 0.6, Color(0, 0, 0, 0.22))
	ci.draw_circle(c, r + outline, Art.INK)
	ci.draw_circle(c, r, shade_col)
	ci.draw_circle(c + Vector2(0, -r * 0.06), r * 0.92, face_col)
	ci.draw_circle(c + Vector2(-r * 0.30, -r * 0.34), r * 0.24, Color(1, 1, 1, lerpf(0.28, 0.48, k)))
	# 腮红：随 t 渐显渐大
	var cheek_a := lerpf(0.06, 0.76, k)
	var cheek_r := maxf(1.8, r * lerpf(0.10, 0.20, k))
	for sx in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(sx * r * 0.48, r * 0.14), cheek_r, Color(SMILE_CHEEK, cheek_a))
	# 眼睛：t <= 0.65 为圆眼，0.55~0.80 平滑过渡到开心弯眼
	var stroke := maxf(1.8, r * 0.11)
	var dot_blend := 1.0 - clampf((k - 0.55) / 0.22, 0.0, 1.0)
	var arc_blend := clampf((k - 0.55) / 0.25, 0.0, 1.0)
	if dot_blend > 0.01:
		var eye_r := maxf(1.4, r * 0.13) * dot_blend
		for sx in [-1.0, 1.0]:
			var ec := c + Vector2(sx * r * 0.32, -r * lerpf(0.12, 0.16, k))
			ci.draw_circle(ec, eye_r, Art.INK)
			if r >= 14.0 and dot_blend > 0.4:
				ci.draw_circle(ec + Vector2(-eye_r * 0.28, -eye_r * 0.28), eye_r * 0.34, Color(1, 1, 1, dot_blend))
	if arc_blend > 0.01 and r >= 12.0:
		var arch_h := r * lerpf(0.06, 0.19, clampf((k - 0.55) / 0.45, 0.0, 1.0))
		var arch_w := r * 0.18
		for sx in [-1.0, 1.0]:
			var ec := c + Vector2(sx * r * 0.33, -r * 0.11)
			var pts := PackedVector2Array()
			for i in 9:
				var u := float(i) / 8.0
				var x := lerpf(-arch_w, arch_w, u)
				var y := -sin(u * PI) * arch_h
				pts.append(ec + Vector2(x, y))
			ci.draw_polyline(pts, Color(Art.INK, arc_blend), stroke, true)
	# 嘴巴：0.0 平直 -> 0.55 弯曲微笑 -> 1.0 张开嘴大笑（带口腔与小舌头）
	var half_w := r * lerpf(0.28, 0.44, k)
	var corner_y := c.y + r * lerpf(0.24, 0.10, k)
	var ml := Vector2(c.x - half_w, corner_y)
	var mr := Vector2(c.x + half_w, corner_y)
	var smile_t := clampf(k / 0.55, 0.0, 1.0)
	var open_t := clampf((k - 0.55) / 0.45, 0.0, 1.0)
	var closed_dip := r * 0.36 * smile_t
	var top_ctrl := Vector2(c.x, corner_y + lerpf(closed_dip, r * 0.06, open_t))
	var bot_ctrl := Vector2(c.x, corner_y + lerpf(closed_dip, r * 0.64, open_t))
	var top_pts := PackedVector2Array()
	var bot_pts := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		var inv := 1.0 - u
		top_pts.append(ml * (inv * inv) + top_ctrl * (2.0 * inv * u) + mr * (u * u))
		bot_pts.append(ml * (inv * inv) + bot_ctrl * (2.0 * inv * u) + mr * (u * u))
	if open_t > 0.02:
		var poly := PackedVector2Array()
		for pt in top_pts: poly.append(pt)
		for i in range(bot_pts.size() - 1, -1, -1): poly.append(bot_pts[i])
		ci.draw_colored_polygon(poly, Color("7a261e"))
		if open_t > 0.22 and r >= 12.0:
			var t_scale := clampf((open_t - 0.22) / 0.78, 0.0, 1.0)
			var tc := Vector2(c.x, corner_y + r * lerpf(0.26, 0.34, t_scale))
			ci.draw_colored_polygon(Art.ell(tc, Vector2(half_w * 0.46 * t_scale, r * 0.12 * t_scale), 11, 0.0, 12), Color("ef6f6c"))
		ci.draw_polyline(top_pts, Art.INK, stroke * 0.9, true)
		ci.draw_polyline(bot_pts, Art.INK, stroke, true)
	else:
		ci.draw_polyline(top_pts, Art.INK, stroke, true)

## 兼容固定表情入口（订单卡、主页入口等处）：mood 2 = 微笑，3 = 大笑
static func draw_smile(ci: CanvasItem, c: Vector2, r: float, mood: int = 2) -> void:
	draw_smile_lerp(ci, c, r, 0.52 if mood <= 2 else 0.92)

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
	UI.title(p.box, TextCatalog.source("ui.passpopup.d8d93e607627"), Rect2(150, HEAD_Y + 30, 420, 76), 38)
	var time_lbl := UI.lbl(p.box, "", Rect2(292, HEAD_Y + 116, 176, 40), 22, Art.INK)
	var lv_lbl := UI.lbl(p.box, "", Rect2(24, HEAD_Y + 216, 100, 52), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 7, Art.INK, true)
	var goal_lbl := UI.lbl(p.box, "", Rect2(138, HEAD_Y + 190, 276, 32), 20, Art.ROPE, HORIZONTAL_ALIGNMENT_LEFT)
	var prog_lbl := UI.lbl(p.box, "", Rect2(154, HEAD_Y + 226, 244, 36), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	var act := UI.btn(p.box, Rect2(428, HEAD_Y + 200, 266, 78), "", "green", func(): G.main.open("pass_buy"), 30)
	act.extra = _price_tag
	UI.lbl(p.box, TextCatalog.source("developer.pass_editor.649a0fc7237e"), Rect2(LEFT_X, HEAD_Y + 306, CARD_W, 40), 24, Art.INK, HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
	UI.lbl(p.box, TextCatalog.source("ui.passpopup.3c95d9cf581a"), Rect2(VIP_X + 16, HEAD_Y + 306, CARD_W - 16, 40), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	UI.lbl(p.box, TextCatalog.source("ui.passpopup.d5f15b62c0dd"), Rect2(SUPER_X + 16, HEAD_Y + 306, CARD_W - 16, 40), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	var refresh := func():
		var reached := G.rules.progression.pass_reached()
		time_lbl.text = TextCatalog.resolve(G.fmt_time(G.rules.clock.pass_secs_left()))
		lv_lbl.text = TextCatalog.resolve(str(reached))
		if reached >= n:
			goal_lbl.text = TextCatalog.resolve(TextCatalog.source("ui.passpopup.d6d8e1de4a98") + (TextCatalog.source("ui.passpopup.78d451afe011") if G.pass_tier == 2 else ""))
		else:
			goal_lbl.text = TextCatalog.resolve(TextCatalog.fill(TextCatalog.source("ui.passpopup.a0257d07f1bd"), [maxi(0, _need_left()), reached + 1]))
		prog_lbl.text = TextCatalog.resolve(G.rules.progression.pass_prog_text())
		act.visible = G.pass_tier < 2
		act.text = TextCatalog.resolve(TextCatalog.source("ui.passpopup.773660b8a7be") if G.pass_tier == 1 else TextCatalog.source("ui.passpopup.42d2ad8fbbb3"))
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
			time_lbl.text = TextCatalog.resolve(G.fmt_time(G.rules.clock.pass_secs_left())))
	return p

# ---------------------------------------------------------------- 轨道几何（轨道内坐标，0 在轨道顶）

static func _list_h() -> float:
	return PAD_TOP + float(Data.PASS_LEVELS.size() + 1) * ROW + BASE_H

## 节点中心 y。lv = 0 是底部柱脚端点，1..n 是各级，n+1 是顶上的循环宝箱。
static func _node_y(lv: int) -> float:
	var n := Data.PASS_LEVELS.size()
	if lv <= 0:
		return PAD_TOP + float(n + 1) * ROW + 12.0
	var k := n + 1 - mini(lv, n + 1)
	return PAD_TOP + float(k) * ROW + ROW * 0.5

## 火光爬到的高度
static func _fill_y() -> float:
	var n := Data.PASS_LEVELS.size()
	var reached := G.rules.progression.pass_reached()
	if reached >= n:
		return _node_y(n + 1) if G.pass_tier == 2 else _node_y(n)
	return lerpf(_node_y(reached), _node_y(reached + 1), G.rules.progression.pass_frac())

static func _need_left() -> int:
	var parts := G.rules.progression.pass_prog_text().split("/")
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
	if G.rules.progression.pass_reached() >= n:
		return n + 1
	return G.rules.progression.pass_reached() + 1

## 一张奖励卡的状态：ready 能领 / done 已领 / future 等级没到 / lock 档位不够（贵宾列要贵宾，超级列要超级贵宾）
## track：free / prem（贵宾）/ super（超级贵宾）/ endless（循环宝箱，lv = 0）
static func _state(track: String, lv: int) -> String:
	if track == "endless":
		if G.pass_tier != 2:
			return "lock"
		return "ready" if G.rules.progression.pass_endless_ready() > 0 else "future"
	if G.rules.progression.pass_got_in(track, lv):
		return "done"
	if lv > G.rules.progression.pass_reached():
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
	return Data.for_pass(G.level, Data.PASS_LEVELS[lv - 1].get(track, []))

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
		G.main.toast(TextCatalog.fill(TextCatalog.source("ui.passpopup.545750bbfba5"), lv))
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
	RewardPresenter.present(rw, func(k): return spots[k] if k < spots.size() else rect.get_center())

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
		var tw := f.get_string_size(TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
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
			_center_text(ci, pr.get_center() + Vector2(0, -3), TextCatalog.source("ui.duelpopup.844ab9477225"), 24)
			if lv == 0 and G.rules.progression.pass_endless_ready() > 1:
				_count_badge(ci, Vector2(r.end.x - 18, r.position.y + 18), G.rules.progression.pass_endless_ready())
		"done":
			Sprites.draw(ci, "ev_pass_card_shade", r, Color(0.32, 0.2, 0.1, 0.38))
			_band_text(ci, bc, TextCatalog.source("notice.sevenday.426e458a4124"), Color("5a3d24"))
			Paint.check_mark(ci, Vector2(r.end.x - 26, r.position.y + 26), 1.5)
		"future":
			Sprites.draw(ci, "ev_pass_card_shade", r, Color(0.14, 0.08, 0.04, 0.42))
			if lv == 0:
				_band_text(ci, bc, TextCatalog.fill(TextCatalog.source("ui.passpopup.3edea80ffde5"), Data.pass_need(Data.PASS_LEVELS.size() - 1)), Color("f1dfb8"))
			else:
				Paint.glyph(ci, "lock", Vector2(bc.x - 50, bc.y + 1), 1.1)
				_band_text(ci, bc + Vector2(14, 0), TextCatalog.fill(TextCatalog.source("ui.passpopup.545750bbfba5"), lv), Color("f1dfb8"))
		"lock":
			if lv == 0:
				Sprites.draw(ci, "ev_pass_card_shade", r, Color(0.14, 0.08, 0.04, 0.3))
			Paint.glyph(ci, "lock", Vector2(bc.x - 56, bc.y + 1), 1.1)
			_band_text(ci, bc + Vector2(14, 0), TextCatalog.source("ui.passpopup.3fdee4d3367d") if track == "prem" else TextCatalog.source("ui.passpopup.d5f15b62c0dd"), Color.WHITE)

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
	var w := f.get_string_size(TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(c.x - w * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	if col.get_luminance() > 0.6:
		ci.draw_string_outline(f, pos, TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Art.INK)
	ci.draw_string(f, pos, TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

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
		Art.item(ci, Rewards.before_cards(str(rewards[i][0])), c, icon_s)
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
	d.z_index = 1
	var tw := d.create_tween().set_loops()
	tw.tween_property(d, "scale", Vector2(1.18, 1.18), 0.75).from(Vector2(0.72, 0.72)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(d, "modulate:a", 0.0, 0.75).from(1.0).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.25)
	return d

static func _place_pulse(d: DrawBox) -> void:
	var n := Data.PASS_LEVELS.size()
	var reached := G.rules.progression.pass_reached()
	d.visible = reached < n
	if reached < n:
		d.position = Vector2(MID_X, TRACK_TOP + _node_y(reached + 1)) - d.size * 0.5
		var host := d.get_parent()
		host.move_child(d, host.get_child_count() - 1)

# ---------------------------------------------------------------- 购买

static func buy() -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(32, 188, 656, 1120)
	Popups.frame(p, r, TextCatalog.source("ui.passpopup.d8d93e607627"), Art.CLAY)
	UI.box(p.box, Rect2(r.position.x + 36, r.position.y + 48, r.size.x - 72, 250), _paint_hoard)
	var tw := 292.0
	var th := 700.0
	var y := r.position.y + 318.0
	_ticket(p, Rect2(r.position.x + 24, y, tw, th), false)
	_ticket(p, Rect2(r.end.x - 24 - tw, y, tw, th), true)
	return p

static func _ticket(p: PopupBase, r: Rect2, super_vip: bool) -> void:
	UI.box(p.box, r, func(ci, sz): _paint_ticket(ci, sz, not super_vip))
	UI.lbl(p.box, TextCatalog.source("ui.passpopup.d5f15b62c0dd") if super_vip else TextCatalog.source("ui.passpopup.3c95d9cf581a"), Rect2(r.position.x + 12, r.position.y + 20, r.size.x - 24, 50), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	UI.lbl(p.box, TextCatalog.source("ui.passpopup.fb0afee81a21") if super_vip else TextCatalog.source("ui.passpopup.4b290ba3765d"), Rect2(r.position.x + 12, r.position.y + 96, r.size.x - 24, 36), 22, Color("6b4a2a"))
	UI.lbl(p.box, "+", Rect2(r.position.x, r.position.y + 136, r.size.x, 48), 40, Art.MOSS, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	if super_vip:
		var x1 := r.position.x + 78.0
		var x2 := r.end.x - 86.0
		var iy := r.position.y + 230.0
		UI.icon(p.box, "fire_2", Vector2(x1, iy), 86)
		UI.lbl(p.box, "×150", Rect2(x1 - 50, iy + 44, 100, 32), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		UI.icon(p.box, "chest_1", Vector2(x2, iy), 86)
		UI.lbl(p.box, TextCatalog.source("ui.passpopup.4e3e80e36d77"), Rect2(x2 - 72, iy + 48, 150, 32), 16, Color("6b4a2a"))
		var y2 := iy + 146.0
		UI.box(p.box, Rect2(x1 - 44, y2 - 44, 88, 88), func(ci, sz): draw_smile(ci, sz * 0.5, 32.0, 3), false)
		UI.lbl(p.box, "×10", Rect2(x1 - 50, y2 + 42, 100, 32), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		UI.lbl(p.box, TextCatalog.source("ui.passpopup.86c69f176f11"), Rect2(x2 - 78, y2 - 8, 156, 64), 18, Color("6b4a2a"))
		_stamp(p, r)
	else:
		UI.icon(p.box, "fire_2", r.position + Vector2(r.size.x * 0.5, 268), 110)
		UI.lbl(p.box, "×150", Rect2(r.position.x, r.position.y + 322, r.size.x, 44), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 7, Art.INK, true)
	var owned := G.pass_tier >= (2 if super_vip else 1)
	var b := UI.btn(p.box, Rect2(r.position.x + 24, r.end.y - 108, r.size.x - 48, 80), PriceBook.product_text("pass:upgrade" if super_vip and G.pass_tier == 1 else ("pass:super" if super_vip else "pass:vip")), "green", Callable(), 40)
	b.title_font = false  # 标题字体里没有「¥」
	if owned:
		b.text = TextCatalog.resolve(TextCatalog.source("ui.passpopup.70ddc4059890"))
		b.enabled = false
	elif super_vip:
		b.pressed.connect(func(): _do_super(p))
		if G.pass_tier == 1:
			# 已经是贵宾：只补差价，原价划掉
			var full := TextCatalog.fill(TextCatalog.source("ui.passpopup.9d7c86d01728"), int(G.PASS_CNY["super"]))
			var note := UI.lbl(p.box, full + TextCatalog.source("ui.passpopup.6160dd496345"), Rect2(r.position.x + 12, r.end.y - 150, r.size.x - 24, 34), 19, Art.CLAY)
			UI.box(p.box, note.get_rect(), func(ci, sz):
				var f: Font = G.font_body
				var tw: float = f.get_string_size(TextCatalog.resolve(full + TextCatalog.source("ui.passpopup.6160dd496345")), HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
				var fw: float = f.get_string_size(TextCatalog.resolve(full), HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
				var x0: float = (sz.x - tw) * 0.5 + f.get_string_size(TextCatalog.resolve(TextCatalog.source("ui.passpopup.e3e9fb6561bf")), HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
				ci.draw_line(Vector2(x0 - 2, sz.y * 0.52), Vector2((sz.x - tw) * 0.5 + fw + 2, sz.y * 0.52), Art.CLAY, 2.0)
			, false)
	else:
		b.pressed.connect(func(): _do_vip(p))

static func _stamp(p: PopupBase, r: Rect2) -> void:
	var s := Rect2(r.end.x - 78, r.position.y - 8, 92, 92)
	UI.box(p.box, s, func(ci, sz):
		Sprites.draw(ci, "ev_pass_stamp", Rect2(Vector2.ZERO, sz)))
	var lab := UI.lbl(p.box, TextCatalog.source("ui.passpopup.52f6f555189a"), Rect2(s.position.x, s.position.y + 26, s.size.x, 40), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	lab.pivot_offset = lab.size * 0.5
	lab.rotation = 0.18

static func _do_vip(p: PopupBase) -> void:
	if not await _purchase(p, "pass:vip"):
		return
	G.main.toast(TextCatalog.source("ui.passpopup.48e1690f8d94"))

static func _do_super(p: PopupBase) -> void:
	var fresh := G.pass_tier == 0
	if not await _purchase(p, "pass:super"):
		return
	if fresh:
		G.main.toast(TextCatalog.source("ui.passpopup.e856abda78fa"))
	else:
		G.main.toast(TextCatalog.source("ui.passpopup.f77ab985688a"))

static func _purchase(p: PopupBase, product: String) -> bool:
	var r: Dictionary = await Payments.buy(product)
	if not r.get("ok", false):
		G.main.toast(str(r.get("message", TextCatalog.source("notice.ufooffer.b9eb30abfda8"))))
		return false
	if is_instance_valid(p): p.close()
	RewardPresenter.present(r.get("rewards", []), func(_k): return Vector2(360, 700))
	return true

# ---------------------------------------------------------------- 背景、头部

static func _paint_bg(ci: CanvasItem, sz: Vector2) -> void:
	Paint.vgrad(ci, Rect2(0, 0, sz.x, 310), Color("efb558"), Color("fbe4ac"))
	Paint.vgrad(ci, Rect2(0, 310, sz.x, sz.y - 310), BG_TOP, BG_BOT)

static func _paint_head(ci: CanvasItem, sz: Vector2) -> void:
	# 酋长恩典庆典头图（局部坐标，0 = 顶栏下沿，172 = 兽皮条上沿）
	var sun := Vector2(sz.x * 0.5, 112.0)
	for k in 9:
		var a0 := -PI + float(k) * (PI / 9.0) + 0.04
		var a1 := a0 + (PI / 18.0)
		var p1 := sun + Vector2(cos(a0), sin(a0)) * 420.0
		var p2 := sun + Vector2(cos(a1), sin(a1)) * 420.0
		var ray := PackedVector2Array([sun, Vector2(p1.x, clampf(p1.y, -20.0, 172.0)), Vector2(p2.x, clampf(p2.y, -20.0, 172.0))])
		ci.draw_colored_polygon(ray, Color(1.0, 0.96, 0.82, 0.24))
	# 暖金部落远山
	Paint.hills(ci, 126, sz.x, 20, Color("c68446"), 2, 174)
	Paint.hills(ci, 150, sz.x, 11, Color("9e5e32"), 6, 174)
	# 顶部两侧庆典彩旗绳
	var bunting_cols := [Art.TEAL, Art.CLAY, SMILE_GOLD]
	for side in [-1.0, 1.0]:
		var p0 := Vector2(0.0 if side < 0.0 else sz.x, 8.0)
		var p1 := Vector2(184.0 if side < 0.0 else sz.x - 184.0, 24.0)
		ci.draw_line(p0, p1, Art.INK, 3.0)
		for f_i in 5:
			var t0 := (float(f_i) + 0.1) / 5.2
			var t1 := (float(f_i) + 0.9) / 5.2
			var a := p0.lerp(p1, t0)
			var b := p0.lerp(p1, t1)
			var tip := a.lerp(b, 0.5) + Vector2(0, 22.0)
			var flag := PackedVector2Array([a, b, tip])
			Art.fill(ci, flag, bunting_cols[f_i % bunting_cols.size()], 2.0)
	# 左侧主角：大酋长（roles[0] = chief）+ 暖金光晕 + 随满意度无极变化的心情气泡
	var sat := satisfaction_ratio()
	ci.draw_circle(Vector2(90, 116), 60.0, Color(1.0, 0.95, 0.76, 0.42))
	Meme.draw_portrait(ci, 0, Rect2(14, 6, 148, 166))
	var bub := Vector2(150, 52)
	ci.draw_circle(bub + Vector2(-14, 14), 5.0, Art.INK)
	ci.draw_circle(bub + Vector2(-14, 14), 3.2, Color.WHITE)
	ci.draw_circle(bub, 20.0, Art.INK)
	ci.draw_circle(bub, 17.5, Color("fff7e0"))
	draw_smile_lerp(ci, bub, 13.5, sat)
	# 右侧：酋长恩典宝藏堆（宝箱 + 琥珀 + 星芒）
	ci.draw_colored_polygon(Art.ell(Vector2(624, 154), Vector2(68, 15), 21, 0.0, 18), Color(0.28, 0.14, 0.05, 0.32))
	Art.item(ci, "chest_1", Vector2(636, 118), 86)
	Art.item(ci, "amber_4", Vector2(586, 138), 42, true, -0.15)
	ci.draw_colored_polygon(Art.star_pts(Vector2(674, 76), 13, 4.5, 4, 3), Color("fff6cf"))
	ci.draw_colored_polygon(Art.star_pts(Vector2(576, 94), 9, 3.2, 4, 5), Color("fff6cf"))
	# 标题横幅顶部羽冠装饰 + 横幅主体
	var crest_c := Vector2(sz.x * 0.5, 32.0)
	var feather_cols := [Art.BONE, Art.TEAL, Art.CLAY, Art.TEAL, Art.BONE]
	for k in 5:
		var ang := -PI * 0.5 + float(k - 2) * 0.34
		var flen := 30.0 if k == 2 else (26.0 if absi(k - 2) == 1 else 22.0)
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x) * 7.5
		var fpoly := PackedVector2Array([crest_c - perp * 0.5, crest_c + dir * flen * 0.65 - perp, crest_c + dir * flen, crest_c + dir * flen * 0.65 + perp, crest_c + perp * 0.5])
		Art.fill(ci, fpoly, feather_cols[k], 2.2)
	Paint.banner(ci, Rect2(168, 28, 384, 82), Art.CLAY)
	ci.draw_circle(Vector2(sz.x * 0.5, 28.0), 8.5, Art.INK)
	ci.draw_circle(Vector2(sz.x * 0.5, 28.0), 6.0, SMILE_GOLD)
	Paint.pill(ci, Rect2(252, 118, 216, 38), 11)
	Paint.glyph(ci, "clock", Vector2(278, 137), 1.15)
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
	# 满意度进度条（左侧嵌一枚随满意度无极变化的笑脸）
	Paint.bar(ci, Rect2(148, band.position.y + 54, 250, 36), G.rules.progression.pass_frac(), SMILE_SHADE, 14)
	draw_smile_lerp(ci, Vector2(146, band.position.y + 72), 20.0, sat)
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
	# 图腾柱顶：随当前满意度从平静→微笑→大笑无极插值的笑脸徽章
	draw_smile_lerp(ci, Vector2(MID_X, 326), 27.0, sat)

## 购买按钮右上角的价签：人民币价格（贵宾 ¥30，超级贵宾 ¥68）
static func _price_tag(ci: CanvasItem, sz: Vector2) -> void:
	var price := PriceBook.product_text("pass:upgrade" if G.pass_tier == 1 else "pass:vip")
	var r := Rect2(sz.x - 84, -20, 92, 38)
	Sprites.draw(ci, "ev_pass_price", r)
	# 标题字体里没有「¥」，价签用正文字体
	var f := G.font_body
	var w := f.get_string_size(TextCatalog.resolve(price), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var pos := Vector2(r.get_center().x - w * 0.5, r.get_center().y + (f.get_ascent(24) - f.get_descent(24)) * 0.5)
	_outlined(ci, pos, price, 24, Color.WHITE, f)

# ---------------------------------------------------------------- 轨道：图腾柱、节点、起点篝火

static func _paint_track(ci: CanvasItem, sz: Vector2) -> void:
	var n := Data.PASS_LEVELS.size()
	var reached := G.rules.progression.pass_reached()
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
	# 满意度金光从底部往上爬
	if fill_y < base_y:
		var fr := Rect2(ch.position.x, fill_y, ch.size.x, base_y - fill_y)
		ci.draw_rect(fr, SMILE_SHADE)
		ci.draw_rect(Rect2(fr.position.x + 3, fr.position.y, 5, fr.size.y), SMILE_GOLD)
	# 绳结：每两级之间缠一道
	for lv in range(0, n + 1):
		var y := (_node_y(lv) + _node_y(lv + 1)) * 0.5
		_lash(ci, y, fill_y <= y)
	# 进度顶端的笑脸（随满意度无极变化）
	if reached < n:
		draw_smile_lerp(ci, Vector2(MID_X, fill_y), 18.0, satisfaction_ratio())
	# 节点
	for lv in range(1, n + 1):
		_node(ci, lv, reached)
	_endless_node(ci, reached >= n)
	_endless_note(ci)

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
		var w := f.get_string_size(TextCatalog.resolve(str(lv)), HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		ci.draw_string(f, Vector2(c.x - w * 0.5, c.y + (f.get_ascent(28) - f.get_descent(28)) * 0.5), TextCatalog.resolve(str(lv)), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("a8977f"))

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
	var lines := [TextCatalog.source("ui.passpopup.4a594183282e"), TextCatalog.fill(TextCatalog.source("ui.passpopup.aa4f64d7ba63"), Data.pass_need(Data.PASS_LEVELS.size() - 1))]
	for i in lines.size():
		var fs := 22 if i == 0 else 18
		var w := f.get_string_size(TextCatalog.resolve(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_outlined(ci, Vector2(r.get_center().x - w * 0.5, r.position.y + 42 + i * 34), lines[i], fs, Art.FIRE2 if i == 0 else Art.BONE, f)

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
	var w := f.get_string_size(TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(c.x - w * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	_outlined(ci, pos, text, fs, Color.WHITE, f)

static func _outlined(ci: CanvasItem, pos: Vector2, text: String, fs: int, col: Color, font: Font) -> void:
	ci.draw_string_outline(font, pos, TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Art.INK)
	ci.draw_string(font, pos, TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
