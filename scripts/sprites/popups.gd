extends RefCounted
## 弹窗（集市、图鉴、建造、储物洞、领奖、引导……）的界面图登记和原始画法。
## 只给「生成物品图.bat」用；游戏里只用 Sprites.draw / Sprites.at 贴这里生成的图。
## 定位固定的大块画面按原坐标登记一块区域（见 _region），运行时用同一个 Rect 贴回去。
## 登记格式见 scripts/BakeSprites.gd。

# ---------------------------------------------------------------- 固定区域（运行时同样用这些 Rect 贴图）

const ENERGY := Rect2(0, 0, 540, 400)
const HOWTO_CARD := Rect2(90, 330, 200, 100)
const HOWTO_HAND := Rect2(248, 808, 104, 116)
const HOWTO_BUB := Rect2(580, 880, 80, 80)
const HOWTO_ARROWS := [
	[Vector2(330, 360), Vector2(500, 450), 0.4],
	[Vector2(520, 660), Vector2(380, 760), 0.4],
	[Vector2(360, 960), Vector2(480, 1010), -0.4],
]
const STORE_HERO := Rect2(30, 236, 660, 262)
const BOOK_TAB := Rect2(0, 3, 102, 82)
const LI_ART := Rect2(80, 380, 560, 300)
const LI_ARROW := Rect2(606, 786, 52, 52)
const EVENT_FLAGS := Rect2(0, 170, 720, 140)
const EVENT_PANEL := Rect2(60, 350, 600, 190)
const RIBBON := Rect2(-6, 168, 232, 56)
const INV_FRAME := Rect2(30, 300, 660, 880)
const INV_LEDGE := Rect2(48, 1026, 624, 124)
const INV_SIGN := Rect2(240, 300, 240, 96)
const INV_SHELF := Rect2(0, 100, 620, 40)
const INV_SLOT := Rect2(4, 4, 100, 102)
const CC_CARD := Rect2(0, 0, 184, 316)
const AD_SCREEN := Rect2(0, 0, 548, 328)
const AD_REWARD := Rect2(0, 0, 320, 76)
## 领奖台座、光芒按这个半径生成，运行时按 r / RW_R 缩放
const RW_R := 105.0
const SPARK_R := 8.0

static func entries() -> Array:
	var out: Array = []
	# 分节标题两边的短线和小星（白色，运行时按颜色染）
	out.append({"key": "pop_sec_line", "w": 200, "h": 6, "pad": 3, "nine": [6, 3, 6, 3],
		"draw": func(ci, r): Art.ln(ci, Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), 2.0, Color.WHITE, 1)})
	out.append({"key": "pop_sec_star", "w": 14, "h": 14, "pad": 3,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.star_pts(r.get_center(), 6, 2.5, 4, 3), Color.WHITE)})
	# 体力弹窗插画：底 / 中（洞口描边 + 彩旗）/ 顶（木牌 + 外框）
	out.append(_region("pop_energy_bg", ENERGY, 6, func(ci): live_energy_bg(ci, ENERGY.size)))
	out.append(_region("pop_energy_mid", ENERGY, 6, func(ci): live_energy_mid(ci, ENERGY.size)))
	out.append(_region("pop_energy_top", ENERGY, 6, func(ci): live_energy_top(ci, ENERGY.size)))
	# 玩法说明
	out.append(_region("pop_howto_card", HOWTO_CARD, 6, func(ci): live_howto_card(ci)))
	out.append(_region("pop_howto_hand", HOWTO_HAND, 6, func(ci): live_howto_hand(ci)))
	out.append(_region("pop_howto_bub", HOWTO_BUB, 6, func(ci): live_howto_bub(ci)))
	for k in HOWTO_ARROWS.size():
		var a: Array = HOWTO_ARROWS[k]
		out.append(_region("pop_howto_arrow%d" % k, arrow_rect(a[0], a[1], a[2]), 4, func(ci): live_arrow(ci, a[0], a[1], a[2])))
	# 通用卡片：底（阴影 + 墨边）+ 白色身子（运行时染色）
	out.append({"key": "pop_card18_base", "w": 160, "h": 236, "pad": 14, "nine": [30, 30, 30, 30],
		"draw": func(ci, r): live_card_base(ci, r, 18, 0.8, 105)})
	out.append({"key": "pop_card18_fill", "w": 160, "h": 236, "pad": 4, "nine": [30, 30, 30, 30],
		"draw": func(ci, r): live_card_fill(ci, r, 18, 0.8, 105)})
	out.append({"key": "pop_card20_base", "w": 208, "h": 250, "pad": 14, "nine": [32, 32, 32, 32],
		"draw": func(ci, r): live_card_base(ci, r, 20, 1.0, 300)})
	out.append({"key": "pop_card20_fill", "w": 208, "h": 250, "pad": 4, "nine": [32, 32, 32, 32],
		"draw": func(ci, r): live_card_fill(ci, r, 20, 1.0, 300)})
	out.append({"key": "pop_inner14", "w": 188, "h": 164, "pad": 3, "nine": [24, 24, 24, 24],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 14, 310, 0.6), Color.WHITE)})
	out.append({"key": "pop_bar_hl", "w": 300, "h": 30, "pad": 2, "nine": [16, 12, 16, 12],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 12, 126, 0.3), Color.WHITE)})
	out.append({"key": "pop_spot_shadow", "w": 66, "h": 14, "pad": 3,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.ell(r.get_center(), Vector2(32, 6), 115, 0.0, 14), Color.WHITE)})
	# 小签：墨边底 + 白色身子
	out.append({"key": "pop_tag_base", "w": 100, "h": 28, "pad": 5, "nine": [14, 12, 14, 12],
		"draw": func(ci, r): Art.dilate(ci, Art.rrect(r, 12, 120, 0.4), 2.5, Art.INK)})
	out.append({"key": "pop_tag_fill", "w": 100, "h": 28, "pad": 2, "nine": [14, 12, 14, 12],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 12, 120, 0.4), Color.WHITE)})
	out.append({"key": "pop_seal", "w": 76, "h": 76, "pad": 5,
		"draw": func(ci, r): Art.fill(ci, Art.star_pts(r.get_center(), 36, 30, 12, 5), Art.CLAY, 3.0)})
	out.append(_region("pop_store_hero", STORE_HERO, 14, func(ci): live_store_hero(ci)))
	# 浅色胶囊、格子（白色身子 + 白色细描边，运行时各自染色）
	out.append({"key": "pop_pill20", "w": 320, "h": 40, "pad": 3, "nine": [22, 18, 22, 18],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 20, 131, 0.6), Color.WHITE)})
	out.append({"key": "pop_slot16_fill", "w": 104, "h": 104, "pad": 3, "nine": [22, 22, 22, 22],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 16, 150, 0.6), Color.WHITE)})
	out.append({"key": "pop_slot16_line", "w": 104, "h": 104, "pad": 3, "nine": [22, 22, 22, 22],
		"draw": func(ci, r): Art.outline(ci, Art.rrect(r, 16, 150, 0.6), 2.0, Color.WHITE)})
	out.append({"key": "pop_slot22_fill", "w": 300, "h": 200, "pad": 3, "nine": [30, 30, 30, 30],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 22, 403, 0.8), Color.WHITE)})
	out.append({"key": "pop_slot22_line", "w": 300, "h": 200, "pad": 3, "nine": [30, 30, 30, 30],
		"draw": func(ci, r): Art.outline(ci, Art.rrect(r, 22, 403, 0.8), 2.0, Color.WHITE)})
	out.append({"key": "pop_bcard_on", "w": 172, "h": 160, "pad": 8, "nine": [26, 26, 26, 26],
		"draw": func(ci, r): live_build_card_on(ci, r)})
	# 图鉴页签
	for on in [true, false]:
		out.append({"key": "pop_booktab_" + ("on" if on else "off"), "w": int(BOOK_TAB.size.x), "h": int(BOOK_TAB.size.y), "pad": 6,
			"draw": func(ci, r): live_book_tab(ci, r, on)})
	out.append({"key": "pop_info_arrow", "w": 11, "h": 14, "pad": 3,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.poly([r.position, r.position + Vector2(11, 7), r.position + Vector2(0, 14)], 1), Color(0.75, 0.6, 0.4, 0.8))})
	# 全屏领奖
	out.append({"key": "pop_rw_burst", "w": int(RW_R * 2.0), "h": int(RW_R * 2.0), "pad": 3,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.star_pts(r.get_center(), RW_R * 0.98, RW_R * 0.62, 8, 40, 0.0), Color.WHITE)})
	out.append({"key": "pop_rw_plate", "w": 152, "h": 44, "pad": 6,
		"draw": func(ci, r): live_rw_plate(ci, r.get_center(), RW_R)})
	out.append({"key": "pop_sparkle", "w": 36, "h": 36, "pad": 2,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.star_pts(r.get_center(), SPARK_R * 2.2, SPARK_R * 0.6, 4, 1), Color.WHITE)})
	out.append({"key": "pop_rw_badge", "w": 100, "h": 36, "pad": 5, "nine": [20, 18, 20, 18],
		"draw": func(ci, r): live_rw_badge(ci, r)})
	# 主角等级
	out.append(_region("pop_li_art_base", LI_ART, 6, func(ci): Art.dilate(ci, Art.rrect(LI_ART, 22, 401, 0.8), 3.0, Art.INK)))
	out.append(_region("pop_li_ground", LI_ART, 4, func(ci): live_li_ground(ci)))
	out.append(_region("pop_li_art_line", LI_ART, 6, func(ci): Art.outline(ci, Art.rrect(LI_ART, 22, 401, 0.8), 3.0, Art.LEATHER_D)))
	out.append(_region("pop_li_arrow", LI_ARROW, 4, func(ci): live_li_arrow(ci)))
	# 丰收祭
	out.append({"key": "pop_album_ring", "w": 200, "h": 200, "pad": 8,
		"draw": func(ci, r): live_album_ring(ci, r.get_center())})
	out.append({"key": "pop_album_disc", "w": 176, "h": 176, "pad": 3,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.ell(r.get_center(), Vector2(88, 88), 210, 0.0, 32), Color.WHITE)})
	out.append(_region("pop_ribbon_base", RIBBON, 6, func(ci): Art.dilate(ci, _ribbon(), 3.0, Art.INK)))
	out.append(_region("pop_ribbon_fill", RIBBON, 3, func(ci): ci.draw_colored_polygon(_ribbon(), Color.WHITE)))
	out.append(_region("pop_event_flags", EVENT_FLAGS, 4, func(ci): live_event_flags(ci)))
	out.append(_region("pop_event_panel", EVENT_PANEL, 6, func(ci): live_event_panel(ci)))
	# 引导：挖洞格子的金边框（中间透明）
	out.append({"key": "pop_guide_frame", "w": 120, "h": 120, "pad": 6, "nine": [26, 26, 26, 26],
		"draw": func(ci, r): live_guide_frame(ci, r)})
	# 输入框、选择面板（这些控件不随线条沸腾重绘，只生成一帧）
	out.append({"key": "pop_field", "w": 200, "h": 56, "pad": 3, "nine": [16, 16, 16, 16], "static": true,
		"draw": func(ci, r): live_field(ci, r)})
	out.append({"key": "pop_sheet", "w": 300, "h": 300, "pad": 6, "nine": [44, 44, 44, 44], "static": true,
		"draw": func(ci, r): live_sheet(ci, r)})
	for on in [true, false]:
		out.append({"key": "pop_choice_" + ("on" if on else "off"), "w": 100, "h": 94, "pad": 6, "nine": [26, 26, 26, 26],
			"draw": func(ci, r): live_choice(ci, r, on)})
	# 储物洞
	out.append(_region("pop_inv_frame", INV_FRAME, 18, func(ci): live_inv_frame(ci)))
	out.append(_region("pop_inv_ledge", INV_LEDGE, 6, func(ci): live_inv_ledge(ci)))
	out.append(_region("pop_inv_sign", INV_SIGN, 6, func(ci): live_inv_sign(ci)))
	out.append(_region("pop_inv_shelf", INV_SHELF, 4, func(ci): live_inv_shelf(ci, Vector2(620, 126)), {"static": true}))
	out.append(_region("pop_inv_niche", INV_SLOT, 4, func(ci): live_inv_niche(ci, INV_SLOT)))
	out.append(_region("pop_inv_next", INV_SLOT, 4, func(ci): live_inv_next(ci, INV_SLOT)))
	out.append(_region("pop_inv_rocks", INV_SLOT, 8, func(ci): live_inv_rocks(ci)))
	# 自选宝箱卡片：普通 / 选中 / 变暗，外加盖暗用的白色身子
	for st in ["n", "on", "dim"]:
		out.append(_region("pop_cc_card_" + st, CC_CARD, 14, func(ci): live_cc_card(ci, CC_CARD.size, st == "on", st == "dim", 0)))
	out.append(_region("pop_cc_dimmer", CC_CARD, 4, func(ci): ci.draw_colored_polygon(Art.rrect(CC_CARD, 22, 801, 0.8), Color.WHITE)))
	# 看广告
	out.append({"key": "pop_ad_track", "w": 200, "h": 26, "pad": 5, "nine": [16, 13, 16, 13],
		"draw": func(ci, r): live_ad_track(ci, r)})
	out.append(_region("pop_ad_reward", AD_REWARD, 6, func(ci): live_ad_reward(ci, AD_REWARD.size)))
	out.append(_region("pop_ad_frame", AD_SCREEN, 14, func(ci): live_ad_frame(ci, AD_SCREEN.size)))
	out.append(_region("pop_ad_line", AD_SCREEN, 4, func(ci): Art.outline(ci, Art.rrect(Rect2(Vector2(14, 14), AD_SCREEN.size - Vector2(28, 28)), 16, 906, 0.4), 2.5, Art.INK)))
	return out

## 按原坐标画在 area 里的一块：生成时平移到内容区，运行时 Sprites.draw(ci, key, area) 贴回原处
static func _region(key: String, area: Rect2, pad: int, fn: Callable, extra: Dictionary = {}) -> Dictionary:
	var paint := func(ci: CanvasItem, r: Rect2) -> void:
		ci.draw_set_transform(r.position - area.position)
		fn.call(ci)
		ci.draw_set_transform(Vector2.ZERO)
	var e := {"key": key, "w": int(area.size.x), "h": int(area.size.y), "pad": pad, "draw": paint}
	e.merge(extra)
	return e

# ---------------------------------------------------------------- 体力

static func live_energy_bg(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2.ZERO, sz), 22, 101, 0.8), Color("c9a06a"))
	ci.draw_colored_polygon(_energy_cave(sz), Color("8fd0d4"))

static func _energy_cave(sz: Vector2) -> PackedVector2Array:
	var cave := PackedVector2Array()
	for k in 17:
		var a := PI + PI * float(k) / 16.0
		cave.append(Vector2(sz.x * 0.72, sz.y * 0.62) + Vector2(cos(a) * 130.0, sin(a) * 170.0))
	return cave

## 洞口描边 + 一串彩旗（画在远山之后、棕榈之前）
static func live_energy_mid(ci: CanvasItem, sz: Vector2) -> void:
	Art.outline(ci, _energy_cave(sz), 4.0, Color(0.4, 0.25, 0.1, 0.6))
	var string := []
	for k in 9:
		string.append(Vector2(sz.x * float(k) / 8.0, 24 + sin(float(k) / 8.0 * PI) * 30.0))
	Art.pl(ci, string, 2.5, Art.WOOD_D, 3)
	for k in 8:
		var p: Vector2 = string[k].lerp(string[k + 1], 0.5)
		var cols := [Art.CLAY, Art.OCHRE, Art.TEAL, Art.BONE]
		ci.draw_colored_polygon(Art.poly([p + Vector2(-16, -4), p + Vector2(16, -4), p + Vector2(0, 26)], k), cols[k % 4])

## 木牌 + 绳 + 整块外框描边（画在物品之后）
static func live_energy_top(ci: CanvasItem, sz: Vector2) -> void:
	var plank := Art.rrect(Rect2(40, sz.y * 0.76, 170, 70), 10, 102, 0.8)
	Art.dilate(ci, plank, 3.0, Art.INK)
	ci.draw_colored_polygon(plank, Art.WOOD)
	Art.ln(ci, Vector2(120, sz.y * 0.76), Vector2(120, sz.y * 0.70), 4.0, Art.ROPE, 1)
	Art.outline(ci, Art.rrect(Rect2(Vector2.ZERO, sz), 22, 101, 0.8), 3.0, Art.LEATHER_D)

# ---------------------------------------------------------------- 玩法说明

static func live_howto_card(ci: CanvasItem) -> void:
	var card := Art.rrect(HOWTO_CARD, 20, 111, 0.8)
	Art.dilate(ci, card, 3.0, Art.INK)
	ci.draw_colored_polygon(card, Art.BONE)

static func live_howto_hand(ci: CanvasItem) -> void:
	Art.fill(ci, Art.ell(Vector2(310, 880), Vector2(26, 34), 112, 0.08, 16, -0.6), Color("f1c49a"), 3.0)
	Art.fill(ci, Art.capsule(Vector2(296, 862), Vector2(270, 830), 8.0, 113), Color("f1c49a"), 3.0)

static func live_howto_bub(ci: CanvasItem) -> void:
	Art.fill(ci, Art.ell(Vector2(620, 920), Vector2(36, 36), 114, 0.03, 18), Art.BONE, 3.0)

static func _arrow_pts(a: Vector2, b: Vector2, bend: float) -> Array:
	var m := a.lerp(b, 0.5) + (b - a).orthogonal() * bend
	var pts := []
	for k in 13:
		var t := float(k) / 12.0
		pts.append(a.lerp(m, t).lerp(m.lerp(b, t), t))
	return pts

static func live_arrow(ci: CanvasItem, a: Vector2, b: Vector2, bend: float) -> void:
	var pts := _arrow_pts(a, b, bend)
	var m := a.lerp(b, 0.5) + (b - a).orthogonal() * bend
	Art.pl(ci, pts, 18.0, Art.INK, 1)
	Art.pl(ci, pts, 11.0, Art.MOSS, 1)
	var d := (b - m).normalized()
	var n := d.orthogonal()
	Art.fill(ci, Art.poly([b + d * 22.0, b + n * 22.0, b - n * 22.0], 2), Art.MOSS, 3.0)

## 箭头外接框（整数像素），生成和贴图都用它
static func arrow_rect(a: Vector2, b: Vector2, bend: float) -> Rect2:
	var pts := _arrow_pts(a, b, bend)
	var m := a.lerp(b, 0.5) + (b - a).orthogonal() * bend
	var d := (b - m).normalized()
	var n := d.orthogonal()
	pts.append_array([b + d * 22.0, b + n * 22.0, b - n * 22.0])
	var bb := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		bb = bb.expand(p)
	bb = bb.grow(12)
	var p0 := bb.position.floor()
	return Rect2(p0, (bb.end - p0).ceil())

# ---------------------------------------------------------------- 卡片、格子

static func live_card_base(ci: CanvasItem, r: Rect2, rad: float, amp: float, seed: int) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), rad, 3, 0.0), Color(0, 0, 0, 0.3))
	Art.dilate(ci, Art.rrect(r, rad, seed, amp), 3.0, Art.INK)

static func live_card_fill(ci: CanvasItem, r: Rect2, rad: float, amp: float, seed: int) -> void:
	ci.draw_colored_polygon(Art.rrect(r, rad, seed, amp), Color.WHITE)

static func live_store_hero(ci: CanvasItem) -> void:
	var r := STORE_HERO
	var b := Art.rrect(r, 24, 121, 1.0)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 10), r.size), 24, 121, 0.0), Color(0, 0, 0, 0.35))
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.OCHRE)

static func live_build_card_on(ci: CanvasItem, r: Rect2) -> void:
	var b := Art.rrect(r, 16, 140, 0.7)
	Art.dilate(ci, b, 4.0, Color("ffd23f"))
	Art.dilate(ci, b, 2.0, Art.INK)
	ci.draw_colored_polygon(b, Color("8cc6a0"))

## r 是页签木牌（比按钮宽 18，伸到屏幕外）；里面的浅色名牌相对它偏 (7, 6)
static func live_book_tab(ci: CanvasItem, r: Rect2, on: bool) -> void:
	var tag := Art.rrect(r, 14, 180, 0.7)
	Art.dilate(ci, tag, 3.0, Art.INK)
	ci.draw_colored_polygon(tag, Color("c47a3a") if on else Art.LEATHER_D)
	var plate := Art.rrect(Rect2(r.position + Vector2(7, 6), Vector2(r.size.x - 38, r.size.y - 12)), 12, 190, 0.5)
	ci.draw_colored_polygon(plate, Color("f0d7b0") if on else Color("8a5a32"))

# ---------------------------------------------------------------- 领奖

static func live_rw_plate(ci: CanvasItem, pc: Vector2, r: float) -> void:
	var plate := Art.ell(pc, Vector2(r * 0.72, r * 0.2), 60, 0.03, 22, 0.0, 0.0)
	Art.dilate(ci, plate, 3.0, Art.INK)
	ci.draw_colored_polygon(plate, Art.LEATHER)
	ci.draw_colored_polygon(Art.ell(pc + Vector2(0, -r * 0.03), Vector2(r * 0.6, r * 0.12), 70, 0.03, 20, 0.0, 0.0), Color(Art.OCHRE, 0.9))

## r 是数量胶囊本体（原来控件四周各缩 3）
static func live_rw_badge(ci: CanvasItem, r: Rect2) -> void:
	var b := Art.rrect(r, r.size.y * 0.5, 80, 0.5)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("5a3416"))
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(6, 3), Vector2(r.size.x - 12, (r.size.y + 6.0) * 0.28)), 6, 81, 0.2), Color(1, 1, 1, 0.14))

# ---------------------------------------------------------------- 主角等级

static func live_li_ground(ci: CanvasItem) -> void:
	var art := LI_ART
	var ground := []
	for k in 13:
		ground.append(Vector2(lerpf(art.position.x + 4, art.end.x - 4, float(k) / 12.0), art.position.y + 200 + sin(float(k) * 0.9) * 10.0))
	ground.append(art.end - Vector2(4, 4))
	ground.append(Vector2(art.position.x + 4, art.end.y - 4))
	ci.draw_colored_polygon(Art.poly(ground, 404, 0.5), Color("8bb39a"))

static func live_li_arrow(ci: CanvasItem) -> void:
	var x := 510.0
	var y := 810.0
	var arr := Art.poly([Vector2(x + 100, y + 4), Vector2(x + 122, y - 20), Vector2(x + 144, y + 4), Vector2(x + 130, y + 4), Vector2(x + 130, y + 24), Vector2(x + 114, y + 24), Vector2(x + 114, y + 4)], 402)
	Art.fill(ci, arr, Art.MOSS, 3.0)

# ---------------------------------------------------------------- 丰收祭

static func live_album_ring(ci: CanvasItem, c: Vector2) -> void:
	var circ := Art.ell(c, Vector2(100, 100), 200, 0.02, 32)
	Art.dilate(ci, circ, 4.0, Art.INK)
	ci.draw_colored_polygon(circ, Art.BONE)

static func _ribbon() -> PackedVector2Array:
	var rr := RIBBON
	return Art.poly([rr.position, Vector2(rr.end.x, rr.position.y), Vector2(rr.end.x - 14, rr.get_center().y), rr.end, Vector2(rr.position.x, rr.end.y), Vector2(rr.position.x + 14, rr.get_center().y)], 0)

static func live_event_flags(ci: CanvasItem) -> void:
	var w := 720.0
	var string := []
	for k in 9:
		string.append(Vector2(w * float(k) / 8.0, 200 + sin(float(k) / 8.0 * PI) * 40.0))
	Art.pl(ci, string, 2.5, Art.BONE, 3)
	for k in 8:
		var q: Vector2 = string[k].lerp(string[k + 1], 0.5)
		var cols := [Art.CLAY, Art.OCHRE, Art.TEAL, Art.BONE]
		ci.draw_colored_polygon(Art.poly([q + Vector2(-16, -4), q + Vector2(16, -4), q + Vector2(0, 26)], k), cols[k % 4])
	ci.draw_colored_polygon(Art.ell(Vector2(360, 250), Vector2(200, 40), 1, 0.0, 24), Color(1, 0.6, 0.2, 0.25))

static func live_event_panel(ci: CanvasItem) -> void:
	var tp := Art.rrect(Rect2(296, 350, 168, 44), 22, 220, 0.6)
	Art.dilate(ci, tp, 2.5, Art.INK)
	ci.draw_colored_polygon(tp, Art.BONE)
	var rb := Art.rrect(Rect2(60, 404, 600, 136), 22, 221, 0.8)
	ci.draw_colored_polygon(rb, Color(0.1, 0.1, 0.25, 0.5))
	Art.outline(ci, rb, 2.0, Color(1, 1, 1, 0.2))

# ---------------------------------------------------------------- 引导、输入框、选择面板

static func live_guide_frame(ci: CanvasItem, r: Rect2) -> void:
	var frame := Art.rrect(r, 16, 4, 0.45)
	Art.outline(ci, frame, 6.0, Color("ffe7a8"))
	Art.outline(ci, frame, 2.6, Art.INK)

static func live_field(ci: CanvasItem, r: Rect2) -> void:
	var b := Art.rrect(r, 12, 2, 0.15)
	ci.draw_colored_polygon(b, Color.WHITE)
	Art.outline(ci, b, 2.0, Color("c9a774"))

static func live_sheet(ci: CanvasItem, r: Rect2) -> void:
	var b := Art.rrect(r, 28, 8, 0.2)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.BONE)
	Art.outline(ci, b, 3.0, Art.INK)

static func live_choice(ci: CanvasItem, r: Rect2, on: bool) -> void:
	var box := Art.rrect(r, 16, 5, 0.3)
	Art.dilate(ci, box, 3.0, Art.INK)
	ci.draw_colored_polygon(box, Art.BONE)
	Art.outline(ci, box, 5.0 if on else 2.5, Art.MOSS_D if on else Art.INK)

# ---------------------------------------------------------------- 储物洞

## 粗糙石壁 + 石块纹理 + 洞口（画在洞口渐变之前）
static func live_inv_frame(ci: CanvasItem) -> void:
	var FR := INV_FRAME
	var VIEW := Rect2(50, 432, 620, 600)
	ci.draw_colored_polygon(Art.rrect(Rect2(FR.position + Vector2(0, 12), FR.size), 40, 161, 0.0), Color(0, 0, 0, 0.35))
	var outer := Art.rrect(FR, 40, 161, 2.2, 30.0)
	Art.dilate(ci, outer, 3.5, Art.INK)
	ci.draw_colored_polygon(outer, Color("7d776c"))
	for k in 42:
		var q := FR.position + Vector2(Art.srnd(k * 3) * FR.size.x, Art.srnd(k * 5 + 1) * FR.size.y)
		var rr := 6.0 + Art.srnd(k) * 16.0
		ci.draw_colored_polygon(Art.ell(q, Vector2(rr, rr * 0.7), 170 + k, 0.12, 10), Color("6a645a") if k % 2 == 0 else Color("8c867a"))
	var cave := Art.rrect(Rect2(VIEW.position - Vector2(10, 62), VIEW.size + Vector2(20, 76)), 30, 162, 1.6, 34.0)
	Art.dilate(ci, cave, 3.0, Art.INK)
	ci.draw_colored_polygon(cave, Color("3a2a1f"))

## 洞底阴影 + 底部石台
static func live_inv_ledge(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(50, 1026, 620, 20), 8, 163, 0.0), Color(0, 0, 0, 0.25))
	var ledge := Art.rrect(Rect2(48, 1040, 624, 110), 22, 164, 1.0)
	Art.dilate(ci, ledge, 3.0, Art.INK)
	ci.draw_colored_polygon(ledge, Color("5c4636"))

static func live_inv_sign(ci: CanvasItem) -> void:
	var sign := Art.rrect(Rect2(240, 318, 240, 70), 14, 165, 0.8)
	ci.draw_line(Vector2(270, 300), Vector2(282, 320), Art.ROPE, 5.0, true)
	ci.draw_line(Vector2(450, 300), Vector2(438, 320), Art.ROPE, 5.0, true)
	ci.draw_colored_polygon(Art.rrect(Rect2(240, 326, 240, 70), 14, 165, 0.0), Color(0, 0, 0, 0.3))
	Art.dilate(ci, sign, 3.0, Art.INK)
	ci.draw_colored_polygon(sign, Art.WOOD)
	Art.pl(ci, [Vector2(256, 342), Vector2(360, 338), Vector2(464, 344)], 2.0, Art.WOOD_D, 166)
	Art.pl(ci, [Vector2(256, 370), Vector2(360, 374), Vector2(464, 368)], 2.0, Art.WOOD_D, 167)

static func live_inv_shelf(ci: CanvasItem, sz: Vector2) -> void:
	var y := 108.0 + 4.0
	ci.draw_colored_polygon(Art.rrect(Rect2(4, y + 10, sz.x - 8, 10), 4, 171, 0.0), Color(0, 0, 0, 0.3))
	var plank := Art.rrect(Rect2(2, y, sz.x - 4, 15), 5, 172, 0.5, 60.0)
	Art.dilate(ci, plank, 2.5, Art.INK)
	ci.draw_colored_polygon(plank, Color("a06a36"))
	ci.draw_colored_polygon(Art.rrect(Rect2(8, y + 2, sz.x - 16, 4), 2, 173, 0.0), Color("c98b4a"))
	for x in [14.0, sz.x - 14.0]:
		ci.draw_colored_polygon(Art.poly([Vector2(x - 8, y + 14), Vector2(x + 8, y + 14), Vector2(x + 3, y + 26), Vector2(x - 3, y + 26)], 174), Art.STONE_D)

static func live_inv_niche(ci: CanvasItem, r: Rect2) -> void:
	var niche := Art.rrect(r, 20, 180, 0.6)
	ci.draw_colored_polygon(niche, Color("241912"))
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), 16, 181, 0.4), Color("4a3628"))
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, 14)), 8, 182, 0.0), Color(0, 0, 0, 0.25))
	Art.outline(ci, niche, 2.0, Color("1a110b"))

## 下一格：虚线框 + 加号（价格文字和琥珀图标运行时画）
static func live_inv_next(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_colored_polygon(Art.rrect(r, 20, 183, 0.6), Color(0.36, 0.27, 0.2, 0.75))
	Art.dashed(ci, Art.rrect(r.grow(-3), 18, 184, 0.0), 9, 6, Color("ffd98a"), 2.5)
	var c := Vector2(54, 40)
	ci.draw_circle(c, 18, Art.INK)
	ci.draw_circle(c, 15, Art.MOSS)
	ci.draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color.WHITE, 4.0, true)
	ci.draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color.WHITE, 4.0, true)

static func live_inv_rocks(ci: CanvasItem) -> void:
	var rocks := [[Vector2(36, 70), Vector2(30, 24)], [Vector2(72, 66), Vector2(28, 28)], [Vector2(54, 42), Vector2(26, 20)]]
	for k in rocks.size():
		var e := Art.ell(rocks[k][0], rocks[k][1], 190 + k, 0.12, 12)
		Art.dilate(ci, e, 2.5, Art.INK)
		ci.draw_colored_polygon(e, Color("6f6a63") if k != 1 else Color("847d72"))
		ci.draw_colored_polygon(Art.ell(rocks[k][0] - Vector2(6, 8), rocks[k][1] * 0.35, 195 + k, 0.1, 10), Color(1, 1, 1, 0.12))

# ---------------------------------------------------------------- 自选宝箱

## 卡片底：阴影、木框、内底、聚光圈、数量胶囊（物品、小签、勾运行时画在上面）
static func live_cc_card(ci: CanvasItem, sz: Vector2, on: bool, dim: bool, k: int) -> void:
	var r := Rect2(Vector2(0, 0), sz)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 9), r.size), 22, 800 + k, 0.0), Color(0, 0, 0, 0.28))
	var b := Art.rrect(r, 22, 801 + k, 0.8)
	Art.dilate(ci, b, 6.0 if on else 3.0, Color("ffd23f") if on else Art.INK)
	if on: Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.WOOD if not on else Color("d28c45"))
	var ir := Rect2(10, 10, sz.x - 20, sz.y - 20)
	ci.draw_colored_polygon(Art.rrect(ir, 16, 802 + k, 0.6), Art.BONE if not dim else Color("e4d6bb"))
	var c := Vector2(sz.x * 0.5, 98)
	ci.draw_colored_polygon(Art.ell(c, Vector2(66, 66), 803 + k, 0.03, 24), Color("f6e3b8") if not dim else Color("ddd0b5"))
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, 52), Vector2(46, 8), 804 + k, 0.0, 16), Color(0, 0, 0, 0.12))
	var pill := Art.rrect(Rect2(16, 222, sz.x - 32, 44), 22, 805 + k, 0.5)
	Art.dilate(ci, pill, 2.5, Art.INK)
	ci.draw_colored_polygon(pill, Color("ffe3a0") if not dim else Color("e8d6ac"))

# ---------------------------------------------------------------- 看广告

static func live_ad_track(ci: CanvasItem, r: Rect2) -> void:
	var tr := Art.rrect(r, 13, 901, 0.4)
	Art.dilate(ci, tr, 3.0, Art.INK)
	ci.draw_colored_polygon(tr, Color("5a3d24"))

static func live_ad_reward(ci: CanvasItem, sz: Vector2) -> void:
	var b := Art.rrect(Rect2(Vector2.ZERO, sz), 38, 904, 0.6)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("fff3d6"))

## 石头外框 + 屏幕底色（天空渐变、小景运行时画在上面）
static func live_ad_frame(ci: CanvasItem, sz: Vector2) -> void:
	var outer := Art.rrect(Rect2(Vector2.ZERO, sz), 26, 905, 1.0)
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 9), sz), 26, 905, 0.0), Color(0, 0, 0, 0.3))
	Art.dilate(ci, outer, 3.0, Art.INK)
	ci.draw_colored_polygon(outer, Art.STONE)
	for k in 14:
		var p := Vector2(Art.srnd(k * 3 + 1) * sz.x, Art.srnd(k * 7 + 2) * sz.y)
		ci.draw_circle(p, 3 + Art.srnd(k) * 4, Color(0, 0, 0, 0.08))
	var inner := Art.rrect(Rect2(Vector2(14, 14), sz - Vector2(28, 28)), 16, 906, 0.4)
	Art.dilate(ci, inner, 3.0, Art.STONE_D)
	ci.draw_colored_polygon(inner, Color("9fd6e6"))
