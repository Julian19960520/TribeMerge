extends RefCounted
## 部落主页（村庄部件、地块、木牌、通行证卡、小人、转场帘）的界面图登记和原始画法。
## 只给「生成物品图.bat」用；游戏里 TribeArt / HomeScreen / TribeWalkers / ScreenWipe 只贴这里生成的图。
## 登记格式见 scripts/BakeSprites.gd。

const Meme := preload("res://scripts/Meme.gd")

const DIRT := Color("8a5a32")
const HAY := Color("e2b950")
const FLINT := Color("4c5260")
const OBSID := Color("3b3050")
const CLAYW := Color("b65a38")
const SMOKE := Color(0.96, 0.94, 0.9, 0.6)
const PLUM := Color("7d3c8c")
const CARD_YELLOW := Color("e7b45a")
const CARD_YELLOW_L := Color("f2c66e")

## 非透明时整件画成单色剪影
static var flat := Color(0, 0, 0, 0)
## 是否带贴纸白边
static var rim := false
## 分阶段画：只画第 1..stage 阶段的零件（默认画满）；only > 0 时只画第 only 阶段新加的零件（落成动画用）
static var stage := 99
static var only := 0
static var _o := Vector2.ZERO
static var _k := Vector2.ONE

# ---------------------------------------------------------------- 登记

static func entries() -> Array:
	var out: Array = []
	# 村庄部件：每个 id 三种画法
	for kind in TribeArt._HEIGHT:
		for v in TribeArt.VAR_SCALE:
			var bs: float = TribeArt.VAR_SCALE[v]
			var box := TribeArt.part_box(kind, bs)
			out.append({"key": "tribe_" + kind + v, "w": int(box.size.x), "h": int(box.size.y), "pad": 2,
				"draw": func(ci, r): live_part_variant(ci, kind, v, r.position - box.position, bs)})
		# 分几次建的部件：每个中间阶段一张（村庄 + 弹窗图标），每个阶段新加的零件一张（落成动画）
		var n := TribeArt.stages_of(kind)
		if n > 1:
			for s in range(1, n + 1):
				var bs: float = TribeArt.VAR_SCALE[""]
				var box := TribeArt.part_box(kind, bs)
				out.append({"key": TribeArt.delta_key(kind, s), "w": int(box.size.x), "h": int(box.size.y), "pad": 2,
					"draw": func(ci, r): live_part_variant(ci, kind, "", r.position - box.position, bs, 99, s)})
				if s == n:
					continue
				for v in ["", "_icon"]:
					var vbs: float = TribeArt.VAR_SCALE[v]
					var vbox := TribeArt.part_box(kind, vbs)
					out.append({"key": TribeArt.stage_key(kind, s, v), "w": int(vbox.size.x), "h": int(vbox.size.y), "pad": 2,
						"draw": func(ci, r): live_part_variant(ci, kind, v, r.position - vbox.position, vbs, s)})
	# 区域地块（开放 / 未开放）
	var ids: Array = TribeArt.AREAS.keys()
	ids.append("any")
	var pb := TribeArt.PLOT_BOX
	for id in ids:
		for open in [true, false]:
			out.append({"key": TribeArt.plot_key(id, open), "w": int(pb.size.x), "h": int(pb.size.y), "pad": 4, "static": true,
				"draw": func(ci, r): live_plot(ci, r.position - pb.position, id, open)})
	# 下一件的地基
	var fb := TribeArt.FOUND_BOX
	for st in TribeArt.FOUND_N:
		out.append({"key": "tribe_found_%d" % st, "w": int(fb.size.x), "h": int(fb.size.y), "pad": 4,
			"draw": func(ci, r): live_found(ci, r.position - fb.position, st)})
	# 区域木牌
	for id in ids:
		for open in [true, false]:
			out.append({"key": tag_key(id, open), "w": int(TAG_SIZE.x), "h": int(TAG_SIZE.y), "pad": 4,
				"draw": func(ci, r): live_tag_base(ci, r.position, TAG_SIZE, id, open)})
	out.append({"key": "tribe_tag_fill", "w": int(TAG_SIZE.x) - 62, "h": 9, "pad": 2, "nine": [5, 4, 5, 4],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 4.5, 3, 0.2), Color.WHITE)})
	# 通行证卡
	for prem in [false, true]:
		out.append({"key": "tribe_pass_prem" if prem else "tribe_pass", "w": int(PASS_SIZE.x), "h": int(PASS_SIZE.y), "pad": 10,
			"draw": func(ci, r): live_pass_base(ci, r.position, PASS_SIZE, prem)})
	out.append({"key": "tribe_pass_fill", "w": 81, "h": 11, "pad": 2, "nine": [6, 5, 6, 5],
		"draw": func(ci, r): live_pass_fill(ci, r)})
	out.append({"key": "tribe_trophy", "w": int(TROPHY_BOX.size.x), "h": int(TROPHY_BOX.size.y), "pad": 4,
		"draw": func(ci, r): live_trophy(ci, r.position - TROPHY_BOX.position)})
	# 建造动画
	out.append({"key": "tribe_hammer", "w": int(HAMMER_BOX.size.x), "h": int(HAMMER_BOX.size.y), "pad": 2,
		"draw": func(ci, r): live_hammer(ci, r.position - HAMMER_BOX.position)})
	out.append({"key": "tribe_build_ring", "w": 80, "h": 34, "pad": 4, "static": true,
		"draw": func(ci, r): Art.dashed(ci, Art.ell(r.get_center(), Vector2(36, 13), 5, 0.0, 18, 0.0, 0.0), 7, 6, Color(1, 1, 1, 0.9), 2.5)})
	out.append({"key": "tribe_dust", "w": 36, "h": 30, "pad": 3,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.ell(r.get_center(), Vector2(DUST_R, DUST_R * 0.8), 7, 0.1, 12), Color.WHITE)})
	out.append({"key": "tribe_star", "w": 26, "h": 26, "pad": 3,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.star_pts(r.get_center(), STAR_R, STAR_R * 0.42, 4, 3), Color.WHITE)})
	# 村里溜达的小人（每个角色一张，不含脚下影子）
	for role in WALKER_BOUNDS.size():
		var wb := walker_box(role)
		out.append({"key": "tribe_walker_%d" % role, "w": int(wb.size.x), "h": int(wb.size.y), "pad": 2,
			"draw": func(ci, r): live_walker(ci, role, r.position - wb.position)})
	# 小人头顶的对话气泡
	out.append({"key": "tribe_bubble", "w": 240, "h": 80, "pad": 5, "nine": [20, 20, 20, 20],
		"draw": func(ci, r): live_bubble_body(ci, r)})
	out.append({"key": "tribe_bubble_tail", "w": int(TAIL_BOX.size.x), "h": int(TAIL_BOX.size.y), "pad": 4,
		"draw": func(ci, r): live_bubble_tail(ci, r.position - TAIL_BOX.position)})
	# 转场帘的木杆和皮章
	out.append({"key": "tribe_wipe_pole", "w": 760, "h": 30, "pad": 6,
		"draw": func(ci, r): live_wipe_pole(ci, r.position)})
	out.append({"key": "tribe_wipe_badge", "w": int(BADGE_BOX.size.x), "h": int(BADGE_BOX.size.y), "pad": 2,
		"draw": func(ci, r): live_wipe_badge(ci, r.position - BADGE_BOX.position, 0)})
	return out

# ---------------------------------------------------------------- 尺寸（运行时也用）

const TAG_SIZE := Vector2(148, 52)
const PASS_SIZE := Vector2(125, 155)
## 以下内容框都相对各自的中心 / 握把 / 落地点
const TROPHY_BOX := Rect2(-32, -24, 64, 50)
const HAMMER_BOX := Rect2(-75, -29, 92, 58)
const DUST_R := 16.0
const STAR_R := 12.0
const TAIL_BOX := Rect2(-14, -22, 28, 23)
const BADGE_BOX := Rect2(-124, -120, 250, 250)
## 小人贴纸相对落地点的外框（h=84，tools/measure_tribe.gd 量出来的）
const WALKER_BOUNDS := [[-41, -116, 44, 5], [-48, -114, 52, 11], [-38, -84, 41, 3], [-43, -91, 35, 7], [-36, -118, 42, 6],
	[-44, -97, 40, 5], [-39, -87, 45, 6], [-44, -93, 39, 5], [-43, -91, 46, 10], [-45, -105, 40, 6]]
const WALKER_H := 84.0

static func walker_box(role: int) -> Rect2:
	var b: Array = WALKER_BOUNDS[role % WALKER_BOUNDS.size()]
	return Rect2(b[0] - 3, b[1] - 3, b[2] - b[0] + 6, b[3] - b[1] + 6)

static func tag_key(id: String, open: bool) -> String:
	return "tribe_tag_%s_%s" % [id if TribeArt.AREAS.has(id) else "any", "open" if open else "lock"]

# ---------------------------------------------------------------- 原始画法（非部件）

static func live_part_variant(ci: CanvasItem, kind: String, v: String, c: Vector2, bs: float, upto := 99, just := 0) -> void:
	rim = v == "_icon"
	flat = Color.WHITE if v == "_flat" else Color(0, 0, 0, 0)
	stage = upto
	only = just
	live_part(ci, kind, c, bs)
	rim = false
	flat = Color(0, 0, 0, 0)
	stage = 99
	only = 0

static func live_plot(ci: CanvasItem, at: Vector2, id: String, open: bool) -> void:
	var seed := absi(id.hash()) % 50 if id != "any" else 0
	var plot := Art.ell(at + Vector2(0, 10), Vector2(118, 74), seed, 0.05, 30, 0.0, 0.0)
	if open:
		ci.draw_colored_polygon(plot, Color(0.62, 0.45, 0.24, 0.28))
	else:
		ci.draw_colored_polygon(plot, Color(0.25, 0.3, 0.12, 0.12))
		Art.dashed(ci, plot, 12, 9, Color(1, 1, 1, 0.55), 3.0)

static func live_found(ci: CanvasItem, gp: Vector2, st: int) -> void:
	var ring := Art.ell(gp, Vector2(30, 12), st + 3, 0.0, 18, 0.0, 0.0)
	ci.draw_colored_polygon(ring, Color(1, 1, 1, 0.16))
	Art.dashed(ci, ring, 7, 6, Color(1, 1, 1, 0.85), 2.5)
	for sx in [-1.0, 1.0]:
		Art.ln(ci, gp + Vector2(24 * sx, 4), gp + Vector2(22 * sx, -14), 3.0, Art.WOOD_D, st * 7 + int(sx))

## 区域木牌底板（不含图标、文字、进度）：o 是牌子左上角
static func live_tag_base(ci: CanvasItem, o: Vector2, sz: Vector2, id: String, open: bool) -> void:
	var seed := absi(id.hash()) % 90 if id != "any" else 0
	var r := Rect2(o + Vector2(6, 6), sz - Vector2(12, 12))
	var plank := Art.rrect(r, 10, seed, 0.8)
	Art.dilate(ci, plank, 3.0, Art.INK)
	ci.draw_colored_polygon(plank, Art.WOOD if open else Color("8c8476"))
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(5, 3), Vector2(r.size.x - 10, 6)), 3, seed + 1, 0.3), Color(1, 1, 1, 0.22))
	if open:
		var bar := Rect2(o + Vector2(48, 33), Vector2(sz.x - 62, 9))
		ci.draw_colored_polygon(Art.rrect(bar, 4.5, seed + 2, 0.2), Color(0.2, 0.1, 0.03, 0.55))

## 通行证卡底（卡身、飘带、勋章、进度槽、剩余时间小牌）：o 是左上角
static func live_pass_base(ci: CanvasItem, o: Vector2, sz: Vector2, prem: bool) -> void:
	ci.draw_set_transform(o, 0.0, Vector2.ONE)
	var card := Rect2(10, 4, sz.x - 20, 92)
	var body := Art.rrect(card, 18, 91, 0.9)
	ci.draw_colored_polygon(Art.rrect(Rect2(card.position + Vector2(0, 5), card.size), 18, 91, 0.0), Color(0, 0, 0, 0.28))
	if prem:
		Art.dilate(ci, body, 7.0, Art.INK)
		Art.dilate(ci, body, 4.4, Art.CLAY)
		Art.dilate(ci, body, 1.4, Art.INK)
	else:
		Art.dilate(ci, body, 3.2, Art.INK)
	ci.draw_colored_polygon(body, CARD_YELLOW)
	var inner := Art.rrect(card.grow(-6), 13, 92, 0.6)
	ci.draw_colored_polygon(inner, CARD_YELLOW_L)
	ci.draw_colored_polygon(Art.rrect(Rect2(card.position + Vector2(10, 8), Vector2(card.size.x - 20, 14)), 7, 93, 0.3), Color(1, 1, 1, 0.16))
	# 兽皮缝线
	Art.dashed(ci, Art.rrect(card.grow(-11), 9, 94, 0.0), 6, 5, Color(0.55, 0.32, 0.1, 0.45), 1.8)
	# 飘带
	var mc := Vector2(sz.x * 0.5, 38)
	for sx in [-1.0, 1.0]:
		var rib := Art.poly([mc + Vector2(8 * sx, 8), mc + Vector2(30 * sx, 14), mc + Vector2(40 * sx, 30), mc + Vector2(30 * sx, 28), mc + Vector2(28 * sx, 38), mc + Vector2(12 * sx, 22)], 95 + int(sx), 0.5)
		Art.dilate(ci, rib, 2.4, Art.INK)
		ci.draw_colored_polygon(rib, Art.TEAL)
		ci.draw_colored_polygon(Art.poly([mc + Vector2(14 * sx, 11), mc + Vector2(28 * sx, 16), mc + Vector2(34 * sx, 24), mc + Vector2(18 * sx, 18)], 97 + int(sx), 0.3), Color(1, 1, 1, 0.2))
	# 勋章：齿边琥珀 + 骨白内圈
	var outer := Art.star_pts(mc, 31, 26, 12, 98, -PI * 0.5)
	Art.dilate(ci, outer, 2.8, Art.INK)
	ci.draw_colored_polygon(outer, Art.BONE)
	var disc := Art.ell(mc, Vector2(20, 20), 99, 0.02, 18)
	Art.dilate(ci, disc, 2.2, Art.INK)
	ci.draw_colored_polygon(disc, Art.CLAY if prem else Art.AMBER)
	ci.draw_colored_polygon(Art.ell(mc + Vector2(-6, -7), Vector2(7, 4), 100, 0.0, 10, -0.5, 0.3), Color(1, 1, 1, 0.45))
	# 进度槽
	var bar := Rect2(card.position.x + 12, card.end.y - 20, card.size.x - 24, 11)
	var bb := Art.rrect(bar, 5.5, 101, 0.2)
	Art.dilate(ci, bb, 2.0, Art.INK)
	ci.draw_colored_polygon(bb, Color(0.3, 0.17, 0.06, 0.85))
	# 剩余时间小牌
	var pill := Art.rrect(Rect2(14, 123, sz.x - 28, 22), 11, 104, 0.4)
	ci.draw_colored_polygon(pill, Color(0.17, 0.09, 0.03, 0.72))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 通行证进度条的填充（九宫格拉到当前进度）
static func live_pass_fill(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_colored_polygon(Art.rrect(r, 5.5, 102, 0.2), Art.MOSS)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(3, 2), Vector2(r.size.x - 6.0, 3)), 1.5, 103, 0.0), Color(1, 1, 1, 0.35))

## 排行榜按钮上的石杯奖杯
static func live_trophy(ci: CanvasItem, c: Vector2) -> void:
	var cup := Art.poly([c + Vector2(-17, -18), c + Vector2(17, -18), c + Vector2(14, -2), c + Vector2(6, 6), c + Vector2(-6, 6), c + Vector2(-14, -2)], 61, 0.4)
	for sx in [-1.0, 1.0]:
		var ear := Art.ell(c + Vector2(19 * sx, -10), Vector2(7, 7), 62 + int(sx), 0.02, 12)
		Art.dilate(ci, ear, 2.4, Art.INK)
		ci.draw_colored_polygon(ear, Art.AMBER)
	var stem := Art.poly([c + Vector2(-4, 5), c + Vector2(4, 5), c + Vector2(5, 13), c + Vector2(-5, 13)], 63, 0.2)
	var base := Art.rrect(Rect2(c + Vector2(-14, 12), Vector2(28, 9)), 3, 64, 0.3)
	for part in [stem, base]:
		Art.dilate(ci, part, 2.4, Art.INK)
		ci.draw_colored_polygon(part, Art.WOOD)
	Art.dilate(ci, cup, 2.6, Art.INK)
	ci.draw_colored_polygon(cup, Art.FIRE2)
	ci.draw_colored_polygon(Art.poly([c + Vector2(-12, -15), c + Vector2(-5, -15), c + Vector2(-8, -3)], 65, 0.2), Color(1, 1, 1, 0.45))

## 建造锤：p 是握把末端，锤头朝左
static func live_hammer(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_set_transform(p, 0.0, Vector2.ONE)
	Art.sil(ci, [Art.P(Art.capsule(Vector2(0, 0), Vector2(-46, 0), 5.0, 1), Art.WOOD, 1),
		Art.P(Art.rrect(Rect2(-62, -17, 24, 34), 7, 2, 0.4), Art.STONE, 1)])
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 村里的小人（不含影子）：feet 是落地点
static func live_walker(ci: CanvasItem, role: int, feet: Vector2) -> void:
	Meme.walker_portrait(ci, role, feet)

static func live_bubble_body(ci: CanvasItem, r: Rect2) -> void:
	var b := Art.rrect(r, 14, 9, 0.4)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color(1, 0.99, 0.95))

## 气泡尾巴：anchor 是尾尖指向的点。上面补一块纸色，盖住尾巴伸进气泡里的那截墨线。
static func live_bubble_tail(ci: CanvasItem, anchor: Vector2) -> void:
	var paper := Color(1, 0.99, 0.95)
	var tail := Art.poly([anchor + Vector2(-9, -16), anchor + Vector2(9, -16), anchor + Vector2(2, -2)], 3, 0.2)
	Art.dilate(ci, tail, 3.0, Art.INK)
	ci.draw_colored_polygon(tail, paper)
	ci.draw_rect(Rect2(anchor + Vector2(-13, -21), Vector2(26, 5.5)), paper)

## 转场帘顶上的木杆：o 是杆子左上角（宽 W+40）
static func live_wipe_pole(ci: CanvasItem, o: Vector2) -> void:
	var w := 760.0
	Art.fill(ci, Art.rrect(Rect2(o, Vector2(w, 30)), 14, 31, 0.6), Art.WOOD, 4.0)
	ci.draw_line(o + Vector2(0, 9), o + Vector2(w, 9), Color(1, 0.9, 0.7, 0.35), 4.0)
	for x in [90.0, 380.0, 670.0]:
		for k in 3:
			var xx: float = o.x + x - 8.0 + float(k) * 8.0
			ci.draw_line(Vector2(xx - 3, o.y - 2), Vector2(xx + 3, o.y + 32), Art.ROPE, 4.0, true)

## 转场帘中间的皮章（不含图标和字）：c 是中心
static func live_wipe_badge(ci: CanvasItem, c: Vector2, seed: int) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE)
	ci.draw_colored_polygon(Art.ell(Vector2(4, 12), Vector2(116, 110), 7, 0.0, 28), Color(0, 0, 0, 0.28))
	Art.fill(ci, Art.ell(Vector2.ZERO, Vector2(112, 108), seed, 0.05, 28), Art.LEATHER, 4.0)
	var ring := Art.ell(Vector2.ZERO, Vector2(96, 92), seed + 1, 0.02, 40)
	for k in ring.size():
		if k % 2 == 0:
			ci.draw_line(ring[k], ring[(k + 1) % ring.size()], Art.ROPE, 4.0, true)
	Art.fill(ci, Art.ell(Vector2.ZERO, Vector2(80, 78), seed + 2, 0.03, 28), Art.BONE, 3.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 按原来的画法在 c 处画一件部件（只在生成图片时用）
static func live_part(ci: CanvasItem, kind: String, c: Vector2, s: float = 1.0, squash: Vector2 = Vector2.ONE) -> void:
	_o = c
	_k = squash * s
	_tf(ci)
	_draw_kind(ci, kind)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- 底层画笔（统一走这里，方便剪影模式）

static func _tf(ci: CanvasItem) -> void:
	ci.draw_set_transform(_o, 0.0, _k)

static func _c(col: Color) -> Color:
	return flat if flat.a > 0.0 else col

static func _sil(ci: CanvasItem, parts: Array, w: float = 3.0) -> void:
	if flat.a > 0.0:
		for p in parts:
			Art.dilate(ci, p[0], w, flat)
			ci.draw_colored_polygon(p[0], flat)
		return
	Art.sil(ci, parts, rim, w)

static func _fill(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, _c(col))

static func _ln(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color = Art.INK, seed: int = 0) -> void:
	Art.ln(ci, a, b, w, _c(col), seed)

static func _pl(ci: CanvasItem, arr: Array, w: float, col: Color = Art.INK, seed: int = 0) -> void:
	Art.pl(ci, arr, w, _c(col), seed)

static func _dot(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, _c(col))

## 第 s 阶段的零件这次画不画
static func _on(s: int) -> bool:
	return s == only if only > 0 else s <= stage

## 只在前 last 个阶段露着的零件（后面会被换掉，如独木舟挖空前的原木）
static func _until(last: int) -> bool:
	return only <= last if only > 0 else stage <= last

static func _shadow(ci: CanvasItem, w: float, h: float = 0.0) -> void:
	if flat.a > 0.0 or not _on(1):
		return
	if h <= 0.0:
		h = w * 0.24
	ci.draw_colored_polygon(Art.ell(Vector2(0, 2), Vector2(w, h), 1, 0.0, 20, 0.0, 0.0), Color(0.15, 0.08, 0.0, 0.18))

## 物品图标（订单里的那套），落在部件局部坐标 p
static func _it(ci: CanvasItem, id: String, p: Vector2, size: float) -> void:
	if flat.a > 0.0:
		ci.draw_circle(p, size * 0.32, flat)
		return
	Art.item(ci, id, _o + p * _k, size * _k.x, false)
	_tf(ci)

static func _log(a: Vector2, b: Vector2, r: float, seed: int, col: Color = Art.WOOD) -> Array:
	return Art.P(Art.capsule(a, b, r, seed), col, 1)

## 原木截面（年轮）
static func _ring(ci: CanvasItem, c: Vector2, r: float, seed: int) -> void:
	var e := Art.ell(c, Vector2(r, r), seed, 0.05, 14)
	Art.dilate(ci, e, 2.2, _c(Art.INK))
	_fill(ci, e, Color("e8c48a"))
	Art.outline(ci, Art.ell(c, Vector2(r * 0.55, r * 0.55), seed + 1, 0.06, 12), 1.6, _c(Color(0.48, 0.29, 0.12, 0.8)))
	_dot(ci, c, r * 0.16, Color(0.48, 0.29, 0.12, 0.8))

static func _post(x: float, h: float, r: float, seed: int, col: Color = Art.WOOD, lean: float = 0.0) -> Array:
	return _log(Vector2(x, 0), Vector2(x + lean, -h), r, seed, col)

## 陶罐轮廓：w 腹宽，h 高，口沿宽 mouth
static func _jar(c: Vector2, w: float, h: float, mouth: float, seed: int) -> PackedVector2Array:
	var half := [Vector2(mouth * 0.5 + 3, -h), Vector2(mouth * 0.5, -h * 0.9), Vector2(w * 0.42, -h * 0.72),
		Vector2(w * 0.5, -h * 0.46), Vector2(w * 0.44, -h * 0.18), Vector2(w * 0.3, 0)]
	var pts: Array = []
	for p in half:
		pts.append(c + p)
	for i in range(half.size() - 1, -1, -1):
		pts.append(c + Vector2(-half[i].x, half[i].y))
	return Art.poly(pts, seed, 0.6)

static func _stone(c: Vector2, r: Vector2, seed: int, col: Color = Art.STONE) -> Array:
	return Art.P(Art.ell(c, r, seed, 0.12, 12), col)

static func _leaf(ci: CanvasItem, base: Vector2, ang: float, ln: float, seed: int, col: Color = Art.LEAF) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x) * ln * 0.32
	var tip := base + d * ln
	var mid := base + d * ln * 0.5
	var pts := Art.poly([base, mid + n, tip, mid - n], seed, 0.4)
	Art.dilate(ci, pts, 1.8, _c(Art.INK))
	_fill(ci, pts, col)
	_ln(ci, base, tip - d * ln * 0.2, 1.4, Art.LEAF_D, seed)

static func _flame(ci: CanvasItem, c: Vector2, w: float, h: float, seed: int) -> void:
	var outer := Art.flame_pts(c, w, h, seed)
	Art.dilate(ci, outer, 2.6, _c(Art.INK))
	_fill(ci, outer, Art.FIRE)
	_fill(ci, Art.flame_pts(c + Vector2(0, h * 0.14), w * 0.55, h * 0.62, seed + 3), Art.FIRE2)

static func _smoke(ci: CanvasItem, c: Vector2, seed: int) -> void:
	if flat.a > 0.0:
		return
	var t := float(Art.boil % 8) / 8.0
	for k in 3:
		var f := fmod(t + float(k) / 3.0, 1.0)
		var p := c + Vector2(sin(f * 5.0 + float(seed)) * 8.0, -f * 46.0)
		ci.draw_colored_polygon(Art.ell(p, Vector2(7, 6) * (0.7 + f), seed + k, 0.1, 10), Color(SMOKE, SMOKE.a * (1.0 - f)))

static func _rope_line(ci: CanvasItem, a: Vector2, b: Vector2, sag: float, seed: int) -> Array:
	var pts: Array = []
	for k in 9:
		var t := float(k) / 8.0
		pts.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * sag))
	_pl(ci, pts, 2.4, Art.INK, seed)
	_pl(ci, pts, 1.2, Art.ROPE, seed)
	return pts

static func _cloth(ci: CanvasItem, top: Vector2, w: float, h: float, col: Color, seed: int) -> void:
	var pts := Art.poly([top + Vector2(-w * 0.5, 0), top + Vector2(w * 0.5, 0), top + Vector2(w * 0.55, h),
		top + Vector2(w * 0.15, h - 5), top + Vector2(-w * 0.2, h + 2), top + Vector2(-w * 0.55, h - 3)], seed, 0.6)
	_sil(ci, [Art.P(pts, col, 1)], 2.4)

# ---------------------------------------------------------------- 分发

static func _draw_kind(ci: CanvasItem, kind: String) -> void:
	match kind:
		"campfire": _campfire(ci)
		"logpile": _logpile(ci)
		"stumps": _stumps(ci)
		"drum": _drum(ci)
		"totem": _totem(ci)
		"chiefhut": _chiefhut(ci)
		"berrybush": _berrybush(ci)
		"basketrack": _basketrack(ci)
		"dryingmat": _dryingmat(ci)
		"seedjar": _seedjar(ci)
		"sprouts": _sprouts(ci)
		"fruittree": _fruittree(ci)
		"rockpile": _rockpile(ci)
		"anvilstone": _anvilstone(ci)
		"flintpit": _flintpit(ci)
		"toolrack": _toolrack(ci)
		"whetstone": _whetstone(ci)
		"obsidian": _obsidian(ci)
		"grassstack": _grassstack(ci)
		"loomframe": _loomframe(ci)
		"dyepot": _dyepot(ci)
		"clothesline": _clothesline(ci)
		"hidetent": _hidetent(ci)
		"featherpole": _featherpole(ci)
		"spears": _spears(ci)
		"snare": _snare(ci)
		"meatrack": _meatrack(ci)
		"hidedry": _hidedry(ci)
		"hunttent": _hunttent(ci)
		"skullgate": _skullgate(ci)
		"stonestove": _stonestove(ci)
		"spit": _spit(ci)
		"smokehouse": _smokehouse(ci)
		"cookpit": _cookpit(ci)
		"firewood": _firewood(ci)
		"sacredfire": _sacredfire(ci)
		"logs": _logs(ci)
		"chopblock": _chopblock(ci)
		"bench": _bench(ci)
		"sawhorse": _sawhorse(ci)
		"woodshed": _woodshed(ci)
		"carvedpole": _carvedpole(ci)
		"claypit": _claypit(ci)
		"wheel": _wheel(ci)
		"potshelf": _potshelf(ci)
		"firepit": _firepit(ci)
		"kilndome": _kilndome(ci)
		"bigjar": _bigjar(ci)
		"netrack": _netrack(ci)
		"fishrack": _fishrack(ci)
		"fishtrap": _fishtrap(ci)
		"shellpile": _shellpile(ci)
		"canoe": _canoe(ci)
		"stilthut": _stilthut(ci)
		_: _rubble(ci)

static func _rubble(ci: CanvasItem) -> void:
	_shadow(ci, 34)
	_sil(ci, [_stone(Vector2(-14, -10), Vector2(16, 12), 1), _stone(Vector2(14, -8), Vector2(14, 10), 2, Art.STONE_D),
		_stone(Vector2(0, -24), Vector2(12, 10), 3)])

# ================================================================ 篝火广场
# 分几次建的部件按「建造阶段」分层画：_on(s) 为真才画第 s 阶段的零件。
# 阶段数见 TribeArt.STAGES；画满就是完整部件。后面阶段的零件可以盖住前面的（如土窑先砌矮墙、再封圆顶）。

static func _campfire(ci: CanvasItem) -> void:
	_shadow(ci, 54, 14)
	var back: Array = []
	for k in 5:
		var a := PI + PI * float(k + 0.5) / 5.0
		back.append(_stone(Vector2(cos(a) * 44, sin(a) * 11 - 4), Vector2(10, 7), 10 + k))
	_sil(ci, back, 2.2)
	_sil(ci, [_log(Vector2(-32, -4), Vector2(28, -18), 6.5, 1), _log(Vector2(-28, -18), Vector2(32, -4), 6.5, 2, Art.WOOD_D)])
	_flame(ci, Vector2(0, -40), 24, 62, 3)
	var front: Array = []
	for k in 6:
		var a := PI * float(k + 0.5) / 6.0
		front.append(_stone(Vector2(cos(a) * 46, sin(a) * 12 - 2), Vector2(11, 7.5), 20 + k))
	_sil(ci, front, 2.2)

static func _logpile(ci: CanvasItem) -> void:
	_shadow(ci, 50)
	var ends: Array = []
	var logs: Array = []
	for k in 3:
		var y := -8.0
		var x := -30.0 + k * 22.0
		logs.append(_log(Vector2(x - 6, y), Vector2(x + 26, y - 6), 8.5, k, Art.WOOD if k % 2 == 0 else Art.WOOD_D))
		ends.append(Vector2(x - 6, y))
	for k in 2:
		var x := -19.0 + k * 22.0
		logs.append(_log(Vector2(x - 6, -24), Vector2(x + 26, -30), 8.5, 5 + k))
		ends.append(Vector2(x - 6, -24))
	logs.append(_log(Vector2(-14, -40), Vector2(18, -46), 8.5, 9, Art.WOOD_D))
	ends.append(Vector2(-14, -40))
	_sil(ci, logs, 2.6)
	for k in ends.size():
		_ring(ci, ends[k], 7.5, 30 + k)
	_ln(ci, Vector2(30, -10), Vector2(42, -2), 2.4, Art.WOOD_D, 7)

static func _stump(ci: CanvasItem, c: Vector2, r: float, h: float, seed: int) -> void:
	var body := Art.poly([c + Vector2(-r - 3, 0), c + Vector2(-r, -h), c + Vector2(r, -h), c + Vector2(r + 3, 0), c + Vector2(0, 4)], seed, 0.6)
	_sil(ci, [Art.P(body, Art.WOOD_D, 1)], 2.4)
	for k in 3:
		_ln(ci, c + Vector2(-r * 0.6 + k * r * 0.6, -h + 4), c + Vector2(-r * 0.6 + k * r * 0.6, -2), 1.4, Color(0.3, 0.16, 0.05, 0.5), seed + k)
	var top := Art.ell(c + Vector2(0, -h), Vector2(r, r * 0.4), seed + 4, 0.04, 14)
	Art.dilate(ci, top, 2.2, _c(Art.INK))
	_fill(ci, top, Color("e8c48a"))
	Art.outline(ci, Art.ell(c + Vector2(0, -h), Vector2(r * 0.55, r * 0.22), seed + 5, 0.05, 12), 1.4, _c(Color(0.48, 0.29, 0.12, 0.8)))

static func _stumps(ci: CanvasItem) -> void:
	_shadow(ci, 54, 12)
	_stump(ci, Vector2(-30, -6), 14, 20, 1)
	_stump(ci, Vector2(30, -8), 13, 18, 2)
	_stump(ci, Vector2(0, 4), 16, 22, 3)

static func _drum(ci: CanvasItem) -> void:
	_shadow(ci, 34)
	var body := Art.poly([Vector2(-30, -52), Vector2(30, -52), Vector2(22, 0), Vector2(-22, 0)], 1, 0.6)
	_sil(ci, [Art.P(body, Art.LEATHER, 1)])
	for k in 6:
		var x1 := -28.0 + k * 11.2
		var x2 := -20.0 + k * 8.0
		_ln(ci, Vector2(x1, -48), Vector2(x2 + 4, -4), 1.8, Art.ROPE, k)
		_ln(ci, Vector2(x1 + 6, -48), Vector2(x2 - 2, -4), 1.8, Art.ROPE, k + 9)
	_fill(ci, Art.poly([Vector2(-23, -26), Vector2(23, -26), Vector2(22, -20), Vector2(-22, -20)], 3), Art.CLAY)
	var head := Art.ell(Vector2(0, -52), Vector2(31, 9), 4, 0.03, 18)
	Art.dilate(ci, head, 2.6, _c(Art.INK))
	_fill(ci, head, Art.HIDE)
	_sil(ci, [_log(Vector2(20, -58), Vector2(40, -74), 3.0, 6, Art.BONE2)], 2.0)
	_dot(ci, Vector2(41, -75), 5, Art.BONE)

static func _totem_face(ci: CanvasItem, y: float, col: Color, seed: int) -> void:
	_sil(ci, [Art.P(Art.rrect(Rect2(-22, y - 36, 44, 38), 6, seed, 0.6), col, 1)], 2.6)
	for sx in [-1.0, 1.0]:
		_dot(ci, Vector2(9 * sx, y - 22), 5.5, Art.BONE)
		_dot(ci, Vector2(9 * sx, y - 22), 2.6, Art.INK)
	_fill(ci, Art.poly([Vector2(-9, y - 10), Vector2(9, y - 10), Vector2(6, y - 5), Vector2(-6, y - 5)], seed + 1), Art.INK)
	_fill(ci, Art.poly([Vector2(-3, y - 18), Vector2(3, y - 18), Vector2(0, y - 12)], seed + 2), Art.OCHRE)

## 1 木脸墩 → 2 叠上青脸 → 3 红脸、展翅鸟头
static func _totem(ci: CanvasItem) -> void:
	_shadow(ci, 30)
	if _on(1): _totem_face(ci, 0, Art.WOOD, 1)
	if _on(2): _totem_face(ci, -38, Art.TEAL, 2)
	if _on(3):
		_totem_face(ci, -76, Art.CLAY, 3)
		var wing := Art.poly([Vector2(-48, -108), Vector2(-22, -120), Vector2(0, -114), Vector2(22, -120), Vector2(48, -108), Vector2(24, -102), Vector2(0, -108), Vector2(-24, -102)], 4)
		_sil(ci, [Art.P(wing, Art.OCHRE, 1)], 2.6)
		var beak := Art.poly([Vector2(-14, -112), Vector2(14, -112), Vector2(10, -134), Vector2(0, -146), Vector2(-10, -134)], 5)
		_sil(ci, [Art.P(beak, Art.OCHRE.darkened(0.1), 1)], 2.6)
		_dot(ci, Vector2(-4, -130), 3, Art.INK)
		_dot(ci, Vector2(4, -130), 3, Art.INK)

## 1 木墙、门洞、人字木架 → 2 盖茅草顶、挂彩边 → 3 屋脊插骨角、挂兽头骨
static func _chiefhut(ci: CanvasItem) -> void:
	_shadow(ci, 86, 16)
	if _on(1):
		var wall := Art.rrect(Rect2(-66, -46, 132, 46), 8, 2, 0.8)
		_sil(ci, [Art.P(wall, Art.WOOD, 1)])
		_sil(ci, [_log(Vector2(-70, -40), Vector2(0, -106), 3.4, 11, Art.WOOD_D), _log(Vector2(70, -40), Vector2(0, -106), 3.4, 12, Art.WOOD_D),
			_log(Vector2(-40, -70), Vector2(40, -70), 3.0, 13, Art.WOOD_D)], 2.2)
		_ln(ci, Vector2(-6, -100), Vector2(6, -104), 2.4, Art.ROPE, 14)
		for sx in [-1.0, 1.0]:
			_ln(ci, Vector2(38 * sx - 4, -68), Vector2(38 * sx + 4, -72), 2.4, Art.ROPE, 15)
	if _on(2):
		var roof := Art.poly([Vector2(-86, -36), Vector2(-20, -112), Vector2(0, -118), Vector2(20, -112), Vector2(86, -36), Vector2(0, -44)], 3)
		_sil(ci, [Art.P(roof, Color("d9a54a"), 1)])
		for i in 9:
			_ln(ci, Vector2(-10 + i * 2.5, -112), Vector2(-76 + i * 19, -40), 1.8, Color(0.45, 0.28, 0.05, 0.55), i)
		for i in 7:
			var x := -78.0 + i * 26.0
			_fill(ci, Art.poly([Vector2(x, -40), Vector2(x + 14, -40), Vector2(x + 7, -28)], 40 + i), Art.CLAY if i % 2 == 0 else Art.TEAL)
	if _on(1):
		var door := Art.rrect(Rect2(-16, -36, 32, 36), 14, 4, 0.5)
		_sil(ci, [Art.P(door, Art.LEATHER_D, 2)], 2.4)
	if _on(3):
		for sx in [-1.0, 1.0]:
			_sil(ci, [_log(Vector2(10 * sx, -114), Vector2(26 * sx, -132), 3.6, 7, Art.BONE2)], 2.0)
		var skull := Art.ell(Vector2(0, -124), Vector2(12, 10), 9, 0.05)
		_sil(ci, [Art.P(skull, Art.BONE, 2)], 2.4)
		_dot(ci, Vector2(-4, -125), 2.4, Art.INK)
		_dot(ci, Vector2(4, -125), 2.4, Art.INK)

# ================================================================ 采集园

## 1 矮矮两团叶 → 2 长出顶冠、挂第一批果 → 3 果子挂满
static func _berrybush(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	if _on(1):
		_sil(ci, [Art.P(Art.ell(Vector2(-16, -24), Vector2(24, 22), 1, 0.1), Art.LEAF_D),
			Art.P(Art.ell(Vector2(16, -26), Vector2(24, 24), 2, 0.1), Art.LEAF_D)])
	if _on(2):
		_sil(ci, [Art.P(Art.ell(Vector2(0, -40), Vector2(26, 22), 3, 0.1), Art.LEAF)])
	for k in 9:
		if not _on(2 if k < 3 else 3):
			continue
		var p := Vector2(-28 + Art.srnd(k * 3) * 56, -54 + Art.srnd(k * 7) * 40)
		_dot(ci, p, 5.2, Art.INK)
		_dot(ci, p, 4.0, Art.BERRY)
		_dot(ci, p + Vector2(-1.4, -1.4), 1.3, Color(1, 1, 1, 0.8))

static func _basket(ci: CanvasItem, c: Vector2, w: float, h: float, seed: int) -> void:
	var body := Art.poly([c + Vector2(-w * 0.5, -h), c + Vector2(w * 0.5, -h), c + Vector2(w * 0.38, 0), c + Vector2(-w * 0.38, 0)], seed, 0.5)
	_sil(ci, [Art.P(body, Art.WOOD, 1)], 2.4)
	for k in 3:
		var y := -h * 0.25 - k * h * 0.27
		_ln(ci, c + Vector2(-w * 0.42, y), c + Vector2(w * 0.42, y), 1.4, Art.WOOD_D, seed + k)
	_ln(ci, c + Vector2(-w * 0.52, -h), c + Vector2(w * 0.52, -h), 3.0, Art.ROPE, seed + 5)

## 1 木架 → 2 架上两只草篓 → 3 地上大篓装满果
static func _basketrack(ci: CanvasItem) -> void:
	_shadow(ci, 42)
	if _on(1):
		_sil(ci, [_post(-34, 74, 3.5, 1, Art.WOOD_D, 4), _post(34, 74, 3.5, 2, Art.WOOD_D, -4),
			_log(Vector2(-36, -40), Vector2(36, -40), 3.2, 3), _log(Vector2(-34, -72), Vector2(34, -72), 3.2, 4)], 2.4)
	if _on(2):
		_basket(ci, Vector2(-14, -42), 30, 24, 5)
		_basket(ci, Vector2(16, -42), 26, 20, 6)
		_it(ci, "fruit_6", Vector2(-14, -70), 22)
	if _on(3):
		_basket(ci, Vector2(4, 0), 38, 30, 7)
		_it(ci, "fruit_2", Vector2(-2, -32), 20)
		_it(ci, "fruit_1", Vector2(10, -32), 18)

## 1 铺开草席 → 2 摆上两颗果 → 3 晒满一排
static func _dryingmat(ci: CanvasItem) -> void:
	_shadow(ci, 52, 10)
	if _on(1):
		var mat := Art.poly([Vector2(-50, -2), Vector2(-36, -22), Vector2(50, -22), Vector2(38, -2)], 1, 0.5)
		_sil(ci, [Art.P(mat, HAY, 1)], 2.4)
		for k in 7:
			var x := -40.0 + k * 13.0
			_ln(ci, Vector2(x - 2, -3), Vector2(x + 12, -21), 1.2, Color(0.55, 0.38, 0.12, 0.6), k)
		_ln(ci, Vector2(-44, -12), Vector2(44, -12), 1.2, Color(0.55, 0.38, 0.12, 0.6), 9)
	var fr := ["fruit_4", "fruit_2", "fruit_5", "fruit_1", "fruit_4"]
	for k in fr.size():
		if _on(2 if k % 2 == 1 else 3):
			_it(ci, fr[k], Vector2(-30 + k * 15, -14 - (k % 2) * 4), 20)

## 1 大陶罐 → 2 画上彩纹、旁边小罐 → 3 罐口满种子、地上撒一溜
static func _seedjar(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	if _on(1):
		_sil(ci, [Art.P(_jar(Vector2(-12, 0), 40, 56, 18, 1), CLAYW, 0)], 2.6)
	if _on(2):
		_ln(ci, Vector2(-30, -34), Vector2(6, -34), 2.0, Art.OCHRE, 2)
		_ln(ci, Vector2(-30, -28), Vector2(6, -28), 2.0, Art.INK, 3)
		_sil(ci, [Art.P(_jar(Vector2(22, 0), 28, 38, 14, 4), Art.CLAY.lightened(0.1), 0)], 2.4)
	if _on(3):
		_fill(ci, Art.ell(Vector2(22, -38), Vector2(8, 2.6), 5, 0.0, 10), Art.SEED)
		for k in 6:
			var p := Vector2(-2 + k * 6.5, 2 - Art.srnd(k) * 4)
			_fill(ci, Art.ell(p, Vector2(3.2, 2.2), k, 0.0, 8, 0.4), Art.SEED)

## 1 翻好土垄、点上种子 → 2 左边两棵冒芽 → 3 右边两棵冒芽 → 4 两头插上系红布的木桩
static func _sprouts(ci: CanvasItem) -> void:
	_shadow(ci, 50, 10)
	if _on(4):
		for sx in [-1.0, 1.0]:
			_ln(ci, Vector2(46 * sx, -2), Vector2(45 * sx, -30), 6.4, Art.INK, 41)
			_ln(ci, Vector2(46 * sx, -2), Vector2(45 * sx, -30), 3.6, Art.WOOD_D, 41)
	if _on(1):
		var bed := Art.poly([Vector2(-48, 0), Vector2(-40, -14), Vector2(40, -14), Vector2(48, 0)], 1, 0.6)
		_sil(ci, [Art.P(bed, DIRT, 1)], 2.4)
		for k in 5:
			_dot(ci, Vector2(-38 + k * 19, -5), 2.0, Color(0.3, 0.16, 0.05, 0.6))
	for k in 4:
		if not _on(2 if k < 2 else 3):
			continue
		var x := -30.0 + k * 20.0
		_ln(ci, Vector2(x, -12), Vector2(x, -24), 2.2, Art.LEAF_D, k)
		_leaf(ci, Vector2(x, -22), -PI * 0.5 - 0.7, 14, k * 3, Art.LEAF)
		_leaf(ci, Vector2(x, -22), -PI * 0.5 + 0.7, 14, k * 3 + 1, Art.MOSS)
	if _on(4):
		for sx in [-1.0, 1.0]:
			_cloth(ci, Vector2(45 * sx + 3 * sx, -28), 8, 12, Art.CLAY, 34 + int(sx))

## 1 光秃秃的树干 → 2 两侧长出叶团 → 3 树冠合拢 → 4 结满果子，树下落一颗
static func _fruittree(ci: CanvasItem) -> void:
	_shadow(ci, 56, 14)
	if _on(1):
		var trunk := Art.poly([Vector2(-10, 0), Vector2(-6, -60), Vector2(-24, -84), Vector2(-14, -88), Vector2(0, -70),
			Vector2(14, -92), Vector2(22, -86), Vector2(6, -60), Vector2(10, 0)], 1, 0.7)
		_sil(ci, [Art.P(trunk, Art.WOOD_D, 1)], 2.6)
	if _on(2):
		_sil(ci, [Art.P(Art.ell(Vector2(-30, -98), Vector2(32, 28), 2, 0.1), Art.LEAF_D),
			Art.P(Art.ell(Vector2(30, -100), Vector2(32, 28), 3, 0.1), Art.LEAF_D)], 2.8)
	if _on(3):
		_sil(ci, [Art.P(Art.ell(Vector2(0, -122), Vector2(40, 30), 4, 0.1), Art.LEAF)], 2.8)
	if _on(4):
		var fr := [Vector2(-34, -100), Vector2(-8, -128), Vector2(24, -110), Vector2(6, -96), Vector2(40, -96), Vector2(-20, -122)]
		for k in fr.size():
			_dot(ci, fr[k], 7.2, Art.INK)
			_dot(ci, fr[k], 6.0, Art.CLAY if k % 2 == 0 else Art.OCHRE)
			_dot(ci, fr[k] + Vector2(-2, -2), 1.8, Color(1, 1, 1, 0.75))
		_it(ci, "fruit_6", Vector2(-22, -6), 22)

# ================================================================ 石匠坊

## 1 两块大底石 → 2 垒上顶石、塞块小石 → 3 补齐碎石，敲出亮面
static func _rockpile(ci: CanvasItem) -> void:
	_shadow(ci, 44)
	if _on(1):
		_sil(ci, [_stone(Vector2(-22, -12), Vector2(20, 13), 1), _stone(Vector2(18, -11), Vector2(22, 12), 2, Art.STONE_D)], 2.6)
	if _on(2):
		_sil(ci, [_stone(Vector2(-2, -30), Vector2(18, 13), 3), _stone(Vector2(-36, -2), Vector2(9, 6), 5, Art.STONE_D)], 2.6)
	if _on(3):
		_sil(ci, [_stone(Vector2(30, -28), Vector2(10, 8), 4)], 2.6)
		for k in 3:
			_pl(ci, [Vector2(-12 + k * 18, -26 + k * 6), Vector2(-6 + k * 18, -30 + k * 6)], 1.6, Color(1, 1, 1, 0.55), k)

## 1 平石砧 → 2 砧上压锤石 → 3 敲下燧石片，地上崩一圈碎屑
static func _anvilstone(ci: CanvasItem) -> void:
	_shadow(ci, 44)
	if _on(1):
		var slab := Art.poly([Vector2(-40, 0), Vector2(-36, -26), Vector2(-10, -34), Vector2(34, -30), Vector2(42, 0)], 1, 0.7)
		_sil(ci, [Art.P(slab, Art.STONE, 0)], 2.8)
		_pl(ci, [Vector2(-30, -22), Vector2(-4, -28), Vector2(30, -24)], 1.6, Color(1, 1, 1, 0.5), 2)
	if _on(2):
		_sil(ci, [Art.P(Art.ell(Vector2(14, -40), Vector2(13, 9), 3, 0.12, 12, -0.3), Art.STONE_D, 0)], 2.4)
	if _on(3):
		_sil(ci, [Art.P(Art.poly([Vector2(-22, -32), Vector2(-6, -38), Vector2(-14, -28)], 4), FLINT, 1)], 2.0)
		for k in 4:
			_fill(ci, Art.poly([Vector2(-38 + k * 6, 2), Vector2(-34 + k * 6, -2), Vector2(-31 + k * 6, 3)], 10 + k), FLINT)

## 1 挖开土坑 → 2 露出燧石 → 3 坑边立一把石镐
static func _flintpit(ci: CanvasItem) -> void:
	_shadow(ci, 48, 14)
	if _on(1):
		var rim_pts := Art.ell(Vector2(0, -8), Vector2(44, 16), 1, 0.06, 22)
		_sil(ci, [Art.P(rim_pts, DIRT, 1)], 2.6)
		_fill(ci, Art.ell(Vector2(0, -6), Vector2(34, 10), 2, 0.05, 18), Color("3d2716"))
	if _on(2):
		for k in 5:
			var c := Vector2(-22 + k * 11, -8 + Art.srnd(k) * 4)
			var sh := Art.poly([c + Vector2(-5, 2), c + Vector2(0, -10), c + Vector2(6, 1)], k)
			Art.dilate(ci, sh, 1.6, _c(Art.INK))
			_fill(ci, sh, FLINT if k % 2 == 0 else Color("6a7184"))
	if _on(3):
		_sil(ci, [_log(Vector2(30, -6), Vector2(44, -40), 2.6, 7), Art.P(Art.poly([Vector2(36, -44), Vector2(56, -40), Vector2(40, -34)], 8), Art.STONE_D, 1)], 2.2)

## 1 木架 → 2 挂上石斧、石锤 → 3 插上最高的石矛
static func _toolrack(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	if _on(1):
		_sil(ci, [_post(-30, 66, 3.2, 1, Art.WOOD_D), _post(30, 66, 3.2, 2, Art.WOOD_D), _log(Vector2(-34, -58), Vector2(34, -58), 3.2, 3)], 2.4)
	if _on(2):
		_sil(ci, [_log(Vector2(-16, -2), Vector2(-8, -74), 2.8, 4), Art.P(Art.poly([Vector2(-14, -64), Vector2(-28, -74), Vector2(-28, -56)], 5), Art.STONE, 1)], 2.2)
	if _on(3):
		_sil(ci, [_log(Vector2(6, -2), Vector2(10, -82), 2.6, 6), Art.P(Art.poly([Vector2(6, -80), Vector2(10, -98), Vector2(14, -80)], 7), FLINT, 1)], 2.2)
	if _on(2):
		_sil(ci, [_log(Vector2(22, -2), Vector2(24, -52), 2.6, 8), Art.P(Art.rrect(Rect2(16, -62, 18, 12), 4, 9, 0.4), Art.STONE_D, 1)], 2.2)

## 1 两块垫石 → 2 架上磨石板 → 3 板面磨亮、放上燧石刃 → 4 装上骨柄、系青珠
static func _whetstone(ci: CanvasItem) -> void:
	_shadow(ci, 46)
	if _on(1):
		_sil(ci, [_stone(Vector2(-28, -10), Vector2(10, 12), 1, Art.STONE_D), _stone(Vector2(28, -10), Vector2(10, 12), 2, Art.STONE_D)], 2.4)
	if _on(2):
		var top := Art.poly([Vector2(-46, -20), Vector2(-40, -34), Vector2(42, -36), Vector2(48, -20)], 3, 0.6)
		_sil(ci, [Art.P(top, Art.STONE, 0)], 2.6)
	if _on(3):
		_fill(ci, Art.poly([Vector2(-34, -34), Vector2(36, -35), Vector2(30, -31), Vector2(-30, -30)], 4), Color("c9c4ba"))
		_sil(ci, [Art.P(Art.poly([Vector2(-26, -40), Vector2(6, -46), Vector2(10, -40), Vector2(-24, -36)], 5), FLINT, 1)], 2.0)
	if _on(4):
		_sil(ci, [_log(Vector2(10, -42), Vector2(26, -46), 2.6, 6, Art.BONE2)], 2.0)
		_dot(ci, Vector2(30, -40), 3.0, Art.TEAL)

## 1 矿床底石 → 2 两侧冒出小晶 → 3 中排两块 → 4 正中紫色大晶闪光
static func _obsidian(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	if _on(1):
		_sil(ci, [_stone(Vector2(0, -8), Vector2(38, 12), 1, Art.STONE_D)], 2.4)
	var shards := [[Vector2(-18, -10), 12.0, 50.0, -0.25], [Vector2(18, -10), 11.0, 46.0, 0.3], [Vector2(0, -12), 14.0, 76.0, 0.0],
		[Vector2(-30, -6), 8.0, 28.0, -0.5], [Vector2(30, -6), 8.0, 30.0, 0.55]]
	var when := [3, 3, 4, 2, 2]
	for k in shards.size():
		if not _on(when[k]):
			continue
		var sh = shards[k]
		var b: Vector2 = sh[0]
		var w: float = sh[1]
		var h: float = sh[2]
		var a: float = sh[3]
		var pts := Art.poly(Art.rot_pts([Vector2(-w, 0), Vector2(-w * 0.8, -h * 0.7), Vector2(0, -h), Vector2(w * 0.8, -h * 0.7), Vector2(w, 0)], a, b), k + 3, 0.5)
		_sil(ci, [Art.P(pts, OBSID if k != 2 else PLUM, 1)], 2.4)
		_ln(ci, b + Vector2(0, -h * 0.9).rotated(a), b + Vector2(-w * 0.3, -h * 0.2).rotated(a), 1.6, Color(1, 1, 1, 0.45), k)
	if flat.a == 0.0 and _on(4):
		ci.draw_colored_polygon(Art.star_pts(Vector2(10, -70), 6, 2, 4, 9), Color(1, 1, 1, 0.85))

# ================================================================ 编织棚

## 1 堆起一个矮草堆 → 2 堆高成垛、捆上草绳 → 3 顶上扎个草揪
static func _grassstack(ci: CanvasItem) -> void:
	_shadow(ci, 44)
	if _on(1):
		var low := Art.poly([Vector2(-42, 0), Vector2(-36, -18), Vector2(-18, -32), Vector2(0, -36), Vector2(18, -32), Vector2(36, -18), Vector2(42, 0)], 1, 0.8)
		_sil(ci, [Art.P(low, HAY, 0)], 2.8)
		for k in 7:
			var x := -30.0 + k * 10.0
			_ln(ci, Vector2(x * 0.5, -32), Vector2(x, -2), 1.3, Color(0.6, 0.4, 0.1, 0.55), k)
	if _on(2):
		var dome := Art.poly([Vector2(-42, 0), Vector2(-38, -30), Vector2(-20, -56), Vector2(0, -64), Vector2(20, -56), Vector2(38, -30), Vector2(42, 0)], 1, 0.8)
		_sil(ci, [Art.P(dome, HAY, 0)], 2.8)
		for k in 9:
			var x := -34.0 + k * 8.5
			_ln(ci, Vector2(x * 0.4, -58), Vector2(x, -2), 1.3, Color(0.6, 0.4, 0.1, 0.55), k)
		_ln(ci, Vector2(-36, -24), Vector2(36, -24), 3.0, Art.ROPE, 11)
		_ln(ci, Vector2(-36, -24), Vector2(36, -24), 1.2, Art.WOOD_D, 12)
	if _on(3):
		_sil(ci, [_log(Vector2(4, -60), Vector2(8, -74), 2.0, 13, HAY)], 1.6)
		_ln(ci, Vector2(1, -64), Vector2(10, -66), 2.4, Art.ROPE, 14)

## 1 木框 → 2 绷上经线 → 3 织出彩带、插着骨梭
static func _loomframe(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	if _on(1):
		_sil(ci, [_post(-32, 92, 3.4, 1, Art.WOOD_D), _post(32, 92, 3.4, 2, Art.WOOD_D),
			_log(Vector2(-38, -84), Vector2(38, -84), 3.4, 3), _log(Vector2(-36, -16), Vector2(36, -16), 3.4, 4)], 2.4)
	if _on(2):
		for k in 8:
			var x := -26.0 + k * 7.4
			_ln(ci, Vector2(x, -82), Vector2(x, -18), 1.2, Art.ROPE, k)
	if _on(3):
		var band := Art.rrect(Rect2(-28, -50, 56, 30), 3, 5, 0.4)
		_sil(ci, [Art.P(band, Art.TEAL, 2)], 2.0)
		for k in 3:
			_ln(ci, Vector2(-26, -45 + k * 9), Vector2(26, -45 + k * 9), 2.4, Art.OCHRE if k != 1 else Art.CLAY, 10 + k)
		_sil(ci, [_log(Vector2(-14, -58), Vector2(22, -62), 2.0, 6, Art.BONE2)], 1.8)

## 1 大陶缸 → 2 倒满青色染水 → 3 搅棍和一块刚染好的布
static func _dyepot(ci: CanvasItem) -> void:
	_shadow(ci, 38)
	if _on(1):
		var pot := _jar(Vector2(0, 0), 64, 50, 52, 1)
		_sil(ci, [Art.P(pot, CLAYW, 0)], 2.8)
		_fill(ci, Art.ell(Vector2(0, -50), Vector2(26, 6), 2, 0.03, 16), Color("3d2716"))
	if _on(2):
		_fill(ci, Art.ell(Vector2(0, -50), Vector2(26, 6), 2, 0.03, 16), Art.TEAL)
		_fill(ci, Art.ell(Vector2(-6, -51), Vector2(10, 2), 3, 0.0, 12), Color(1, 1, 1, 0.45))
	if _on(3):
		_sil(ci, [_log(Vector2(10, -48), Vector2(28, -84), 2.6, 4)], 2.0)
		_cloth(ci, Vector2(-14, -52), 14, 26, Art.TEAL.lightened(0.15), 5)
	if _on(1):
		_ln(ci, Vector2(-26, -28), Vector2(26, -28), 2.0, Art.INK, 6)
		for k in 4:
			_dot(ci, Vector2(-20 + k * 13, -20), 2.4, Art.BONE)

static func _rope_pts(a: Vector2, b: Vector2, sag: float) -> Array:
	var pts: Array = []
	for k in 9:
		var t := float(k) / 8.0
		pts.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * sag))
	return pts

## 1 两根桩拉上绳 → 2 晾上红布、绿布 → 3 正中挂一张缝好的兽皮
static func _clothesline(ci: CanvasItem) -> void:
	_shadow(ci, 58, 10)
	var pts := _rope_pts(Vector2(-50, -78), Vector2(50, -78), 10)
	if _on(1):
		_sil(ci, [_post(-52, 84, 3.2, 1, Art.WOOD_D, 3), _post(52, 84, 3.2, 2, Art.WOOD_D, -3)], 2.4)
		_rope_line(ci, Vector2(-50, -78), Vector2(50, -78), 10, 3)
	if _on(2):
		_cloth(ci, pts[2] + Vector2(0, -2), 22, 34, Art.CLAY, 4)
	if _on(3):
		_cloth(ci, pts[4] + Vector2(0, -2), 20, 40, Art.HIDE2, 5)
	if _on(2):
		_cloth(ci, pts[6] + Vector2(0, -2), 22, 30, Art.MOSS, 6)
	if _on(3):
		for k in 3:
			_ln(ci, pts[4] + Vector2(-8, 10 + k * 8), pts[4] + Vector2(8, 10 + k * 8), 1.4, Art.LEATHER, 10 + k)

## 1 立起三根帐杆 → 2 蒙上兽皮 → 3 开门帘 → 4 画上红纹、青星
static func _hidetent(ci: CanvasItem) -> void:
	_shadow(ci, 54, 14)
	if _on(1):
		_sil(ci, [_log(Vector2(40, 2), Vector2(-22, -116), 2.6, 1, Art.WOOD_D), _log(Vector2(-40, 2), Vector2(22, -116), 2.6, 2, Art.WOOD_D),
			_log(Vector2(0, 2), Vector2(0, -118), 2.6, 3, Art.WOOD_D)], 2.0)
		_ln(ci, Vector2(-8, -98), Vector2(8, -96), 3.0, Art.ROPE, 8)
	if _on(2):
		var tent := Art.poly([Vector2(-52, 0), Vector2(-6, -98), Vector2(6, -98), Vector2(52, 0), Vector2(0, 6)], 4, 0.8)
		_sil(ci, [Art.P(tent, Art.HIDE2, 0)], 2.8)
	if _on(3):
		var door := Art.poly([Vector2(-14, 2), Vector2(0, -40), Vector2(14, 2)], 5, 0.5)
		_fill(ci, door, Art.LEATHER_D)
		Art.outline(ci, door, 2.0, _c(Art.INK))
	if _on(4):
		for k in 5:
			var y := -18.0 - k * 14.0
			var hw := 46.0 - k * 9.0
			_ln(ci, Vector2(-hw, y), Vector2(-hw + 8, y), 2.4, Art.CLAY, 20 + k)
			_ln(ci, Vector2(hw - 8, y), Vector2(hw, y), 2.4, Art.CLAY, 30 + k)
		_fill(ci, Art.star_pts(Vector2(-22, -40), 6, 2.5, 4, 6), Art.TEAL)
		_fill(ci, Art.star_pts(Vector2(22, -40), 6, 2.5, 4, 7), Art.TEAL)

static func _feather(ci: CanvasItem, base: Vector2, ang: float, ln: float, col: Color, seed: int) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x) * ln * 0.22
	var pts := Art.poly([base, base + d * ln * 0.3 + n, base + d * ln, base + d * ln * 0.3 - n], seed, 0.4)
	Art.dilate(ci, pts, 1.8, _c(Art.INK))
	_fill(ci, pts, col)
	_fill(ci, Art.poly([base + d * ln * 0.62 + n * 0.7, base + d * ln, base + d * ln * 0.62 - n * 0.7], seed + 1, 0.3), Art.INK)
	_ln(ci, base, base + d * ln * 0.9, 1.2, Art.BONE, seed)

## 1 立旗杆、缠绳 → 2 横杆挂两端羽毛 → 3 中间三根补齐 → 4 杆顶插冠羽
static func _featherpole(ci: CanvasItem) -> void:
	_shadow(ci, 26)
	if _on(1):
		_sil(ci, [_post(0, 132, 3.6, 1, Art.WOOD_D)], 2.4)
	if _on(2):
		_sil(ci, [_log(Vector2(-28, -116), Vector2(28, -116), 2.8, 2)], 2.2)
	var cols := [Art.CLAY, Art.OCHRE, Art.TEAL, Art.BONE, Art.CLAY]
	for k in 5:
		if not _on(2 if k == 0 or k == 4 else 3):
			continue
		var x := -24.0 + k * 12.0
		_feather(ci, Vector2(x, -114), PI * 0.5 + (x / 200.0), 34, cols[k], k * 5)
	if _on(4):
		_feather(ci, Vector2(0, -132), -PI * 0.5 - 0.3, 22, Art.CLAY, 40)
		_feather(ci, Vector2(0, -132), -PI * 0.5 + 0.3, 22, Art.OCHRE, 41)
	if _on(1):
		for k in 3:
			_ln(ci, Vector2(-4, -30 - k * 6), Vector2(4, -28 - k * 6), 2.4, Art.ROPE, 50 + k)

# ================================================================ 猎人营

## 1 两根立桩架横杆 → 2 两边各靠一支矛 → 3 正中立起最长的矛
static func _spears(ci: CanvasItem) -> void:
	_shadow(ci, 36)
	if _on(1):
		_sil(ci, [_log(Vector2(-36, -30), Vector2(36, -30), 3.0, 1, Art.WOOD_D)], 2.2)
	for k in 3:
		if not _on(3 if k == 1 else 2):
			continue
		var x := -20.0 + k * 20.0
		var lean := (float(k) - 1.0) * 6.0
		_sil(ci, [_log(Vector2(x, 0), Vector2(x + lean, -88), 2.4, 2 + k),
			Art.P(Art.poly([Vector2(x + lean - 5, -86), Vector2(x + lean, -104), Vector2(x + lean + 5, -86)], 6 + k), FLINT, 1)], 2.0)
		_ln(ci, Vector2(x + lean * 0.95 - 3, -84), Vector2(x + lean * 0.95 + 3, -80), 2.0, Art.ROPE, 10 + k)
	if _on(1):
		_sil(ci, [_log(Vector2(-36, -2), Vector2(-34, -36), 3.0, 14, Art.WOOD_D), _log(Vector2(36, -2), Vector2(34, -36), 3.0, 15, Art.WOOD_D)], 2.2)

## 1 压弯一棵小树 → 2 垂下绳套 → 3 钉好地桩、放上诱饵
static func _snare(ci: CanvasItem) -> void:
	_shadow(ci, 42, 10)
	if _on(1):
		var sap := [Vector2(-30, 0), Vector2(-30, -30), Vector2(-24, -56), Vector2(-8, -70), Vector2(12, -72)]
		_pl(ci, sap, 6.0, Art.INK, 1)
		_pl(ci, sap, 3.4, Art.WOOD, 1)
		_leaf(ci, Vector2(-26, -50), PI + 0.4, 14, 2)
		_leaf(ci, Vector2(-14, -66), -PI * 0.5 - 0.5, 12, 3)
	if _on(2):
		_rope_line(ci, Vector2(12, -72), Vector2(16, -14), 0, 4)
		var loop := Art.ell(Vector2(16, -6), Vector2(22, 7), 5, 0.06, 18)
		Art.outline(ci, loop, 3.6, _c(Art.INK))
		Art.outline(ci, loop, 1.8, _c(Art.ROPE))
	if _on(3):
		_sil(ci, [_log(Vector2(34, 0), Vector2(36, -14), 2.6, 6, Art.WOOD_D)], 2.0)
		_it(ci, "fruit_1", Vector2(16, -8), 16)

## 1 搭起晾架 → 2 两边挂上肉条 → 3 正中挂烤肉，地上放只猎到的鸟
static func _meatrack(ci: CanvasItem) -> void:
	_shadow(ci, 52, 12)
	if _on(1):
		_sil(ci, [_post(-44, 88, 3.4, 1, Art.WOOD_D, 6), _post(44, 88, 3.4, 2, Art.WOOD_D, -6),
			_log(Vector2(-46, -80), Vector2(46, -80), 3.4, 3)], 2.4)
	var meats := [Vector2(-24, -78), Vector2(0, -78), Vector2(24, -78)]
	for k in 3:
		if not _on(3 if k == 1 else 2):
			continue
		var p: Vector2 = meats[k]
		_ln(ci, p, p + Vector2(0, 10), 1.8, Art.ROPE, k)
		var m := Art.poly([p + Vector2(-8, 10), p + Vector2(8, 10), p + Vector2(10, 32), p + Vector2(0, 40), p + Vector2(-10, 32)], k + 4, 0.6)
		_sil(ci, [Art.P(m, Art.MEAT if k != 1 else Art.ROAST, 1)], 2.2)
		_ln(ci, p + Vector2(-5, 20), p + Vector2(5, 26), 2.0, Color(1, 1, 1, 0.6), k + 9)
	if _on(3):
		_it(ci, "bird_1", Vector2(30, -14), 26)

## 1 方木框 → 2 撑上一张生皮 → 3 四边绑绳绷紧
static func _hidedry(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	if _on(1):
		_sil(ci, [_post(-34, 86, 3.2, 1, Art.WOOD_D), _post(34, 86, 3.2, 2, Art.WOOD_D),
			_log(Vector2(-38, -80), Vector2(38, -80), 3.2, 3), _log(Vector2(-38, -14), Vector2(38, -14), 3.2, 4)], 2.4)
	if _on(2):
		var hide := Art.poly([Vector2(-22, -72), Vector2(-8, -66), Vector2(8, -66), Vector2(22, -72), Vector2(24, -52), Vector2(18, -36),
			Vector2(24, -22), Vector2(8, -26), Vector2(-8, -26), Vector2(-24, -22), Vector2(-18, -36), Vector2(-24, -52)], 5, 0.6)
		_sil(ci, [Art.P(hide, Color("c98a4a"), 0)], 2.4)
	if _on(3):
		for p in [Vector2(-22, -72), Vector2(22, -72), Vector2(-24, -22), Vector2(24, -22), Vector2(-24, -52), Vector2(24, -52)]:
			var edge := Vector2(signf(p.x) * 33.0, p.y if absf(p.y + 47) > 20 else p.y)
			_ln(ci, p, edge, 1.4, Art.ROPE, int(p.x + p.y))
		for k in 4:
			_dot(ci, Vector2(-10 + (k % 2) * 18, -56 + int(k / 2) * 16), 3.0, Color("8a5426"))

## 1 斜搭帐杆 → 2 蒙上皮帐、留门 → 3 顶上压一层毛皮 → 4 门边靠一支猎矛
static func _hunttent(ci: CanvasItem) -> void:
	_shadow(ci, 56, 14)
	if _on(1):
		_sil(ci, [_log(Vector2(-50, 0), Vector2(-24, -70), 2.6, 11, Art.WOOD_D), _log(Vector2(50, 0), Vector2(-16, -72), 2.6, 12, Art.WOOD_D),
			_log(Vector2(10, -2), Vector2(-20, -72), 2.4, 13, Art.WOOD_D)], 2.0)
	if _on(2):
		var tent := Art.poly([Vector2(-56, 0), Vector2(-30, -66), Vector2(-20, -74), Vector2(44, -60), Vector2(56, 0)], 1, 0.8)
		_sil(ci, [Art.P(tent, Art.LEATHER, 0)], 2.8)
	if _on(3):
		var fur := Art.poly([Vector2(-32, -64), Vector2(-20, -72), Vector2(44, -58), Vector2(40, -44), Vector2(30, -50), Vector2(18, -42), Vector2(6, -52), Vector2(-8, -44), Vector2(-20, -54)], 2, 0.6)
		_sil(ci, [Art.P(fur, Color("8b6a4a"), 1)], 2.2)
	if _on(2):
		var door := Art.poly([Vector2(-28, 2), Vector2(-14, -40), Vector2(2, 2)], 3, 0.5)
		_fill(ci, door, Art.LEATHER_D.darkened(0.3))
		Art.outline(ci, door, 2.0, _c(Art.INK))
	if _on(1):
		_sil(ci, [_log(Vector2(-22, -72), Vector2(-30, -94), 2.4, 4, Art.WOOD_D), _log(Vector2(-18, -72), Vector2(-6, -92), 2.4, 5, Art.WOOD_D)], 1.8)
	if _on(4):
		_sil(ci, [_log(Vector2(26, -2), Vector2(50, -40), 2.4, 6), Art.P(Art.poly([Vector2(48, -38), Vector2(58, -54), Vector2(54, -34)], 7), FLINT, 1)], 1.8)

## 1 两根粗门柱 → 2 架起一对猛犸牙 → 3 正中挂上大头骨 → 4 柱上缠红、垂羽毛
static func _skullgate(ci: CanvasItem) -> void:
	_shadow(ci, 58, 12)
	if _on(1):
		_sil(ci, [_post(-48, 82, 4.2, 1, Art.WOOD_D), _post(48, 82, 4.2, 2, Art.WOOD_D)], 2.6)
	if _on(2):
		for sx in [-1.0, 1.0]:
			var pts: Array = []
			for k in 8:
				var t := float(k) / 7.0
				pts.append(Vector2(sx * (48.0 - t * 40.0), -70.0 - sin(t * PI * 0.85) * 40.0))
			_pl(ci, pts, 13.0, Art.INK, 3)
			_pl(ci, pts, 8.5, Art.BONE, 3)
	if _on(3):
		var skull := Art.poly([Vector2(-18, -96), Vector2(-14, -116), Vector2(0, -122), Vector2(14, -116), Vector2(18, -96), Vector2(8, -84), Vector2(-8, -84)], 4, 0.6)
		_sil(ci, [Art.P(skull, Art.BONE2, 0)], 2.6)
		_dot(ci, Vector2(-7, -104), 4.4, Art.INK)
		_dot(ci, Vector2(7, -104), 4.4, Art.INK)
		_ln(ci, Vector2(-6, -90), Vector2(6, -90), 1.8, Art.INK, 5)
	if _on(4):
		for sx in [-1.0, 1.0]:
			_ln(ci, Vector2(48 * sx, -50), Vector2(48 * sx, -40), 6.0, Art.CLAY, 6)
			_feather(ci, Vector2(48 * sx, -40), PI * 0.5, 22, Art.OCHRE, 7 + int(sx))

# ================================================================ 火塘灶

## 1 围一圈石头 → 2 生起火 → 3 架上石板烤菜
static func _stonestove(ci: CanvasItem) -> void:
	_shadow(ci, 46, 12)
	if _on(1):
		var back: Array = []
		for k in 4:
			var a := PI + PI * float(k + 0.5) / 4.0
			back.append(_stone(Vector2(cos(a) * 36, sin(a) * 10 - 10), Vector2(10, 9), 1 + k))
		_sil(ci, back, 2.2)
	if _on(2):
		_flame(ci, Vector2(0, -26), 16, 34, 7)
	if _on(3):
		var slab := Art.poly([Vector2(-34, -30), Vector2(30, -34), Vector2(36, -26), Vector2(-30, -22)], 6, 0.5)
		_sil(ci, [Art.P(slab, Art.STONE_D, 1)], 2.4)
		_it(ci, "veg_2", Vector2(-10, -38), 22)
		_it(ci, "veg_1", Vector2(14, -40), 20)
	if _on(1):
		var front: Array = []
		for k in 5:
			var a := PI * float(k + 0.5) / 5.0
			front.append(_stone(Vector2(cos(a) * 40, sin(a) * 10 - 6), Vector2(10, 8), 10 + k))
		_sil(ci, front, 2.2)

## 1 生火 → 2 两边立起叉架 → 3 横杆串上整块肉，冒烟
static func _spit(ci: CanvasItem) -> void:
	_shadow(ci, 52, 12)
	if _on(1):
		_flame(ci, Vector2(0, -18), 18, 30, 3)
	if _on(2):
		for sx in [-1.0, 1.0]:
			_sil(ci, [_log(Vector2(44 * sx, 0), Vector2(42 * sx, -50), 3.0, 1, Art.WOOD_D),
				_log(Vector2(42 * sx, -50), Vector2(50 * sx, -64), 2.6, 2, Art.WOOD_D),
				_log(Vector2(42 * sx, -50), Vector2(34 * sx, -62), 2.6, 3, Art.WOOD_D)], 2.2)
	if _on(3):
		_sil(ci, [_log(Vector2(-50, -54), Vector2(50, -54), 2.4, 4, Art.WOOD)], 2.0)
		var meat := Art.ell(Vector2(0, -54), Vector2(24, 14), 5, 0.1)
		_sil(ci, [Art.P(meat, Art.ROAST, 0)], 2.6)
		for k in 3:
			_ln(ci, Vector2(-12 + k * 12, -64), Vector2(-16 + k * 12, -46), 2.0, Color(0.45, 0.2, 0.05, 0.7), k)
		_smoke(ci, Vector2(0, -72), 9)

## 1 板墙和门洞 → 2 盖上草顶 → 3 屋里生火、门口挂鱼，顶上冒烟
static func _smokehouse(ci: CanvasItem) -> void:
	_shadow(ci, 50, 12)
	if _on(1):
		var wall := Art.rrect(Rect2(-38, -54, 76, 54), 6, 1, 0.7)
		_sil(ci, [Art.P(wall, Art.WOOD_D, 1)])
		for k in 5:
			_ln(ci, Vector2(-30 + k * 15, -50), Vector2(-30 + k * 15, -4), 1.4, Color(0.2, 0.1, 0.03, 0.5), k)
	if _on(2):
		var roof := Art.poly([Vector2(-50, -46), Vector2(0, -92), Vector2(50, -46), Vector2(0, -54)], 2)
		_sil(ci, [Art.P(roof, HAY.darkened(0.08), 1)])
		for k in 6:
			_ln(ci, Vector2(-2 + k, -90), Vector2(-42 + k * 17, -48), 1.4, Color(0.45, 0.28, 0.05, 0.5), 10 + k)
	if _on(1):
		var door := Art.rrect(Rect2(-14, -34, 28, 34), 4, 3, 0.4)
		_fill(ci, door, Color("2a170b"))
		Art.outline(ci, door, 2.0, _c(Art.INK))
	if _on(3):
		_fill(ci, Art.ell(Vector2(0, -6), Vector2(8, 4), 4, 0.1, 10), Art.FIRE)
		for k in 2:
			var p := Vector2(-6 + k * 12, -30)
			_ln(ci, p, p + Vector2(0, 6), 1.4, Art.ROPE, 20 + k)
			_fill(ci, Art.ell(p + Vector2(0, 12), Vector2(3, 7), 21 + k, 0.1, 10), Art.FISH)
		_smoke(ci, Vector2(0, -92), 4)

## 1 挖坑培土 → 2 坑里铺满炭火 → 3 埋上叶包，冒烟
static func _cookpit(ci: CanvasItem) -> void:
	_shadow(ci, 52, 12)
	if _on(1):
		var mound := Art.ell(Vector2(0, -10), Vector2(48, 14), 1, 0.06, 22)
		_sil(ci, [Art.P(mound, DIRT, 1)], 2.4)
		_fill(ci, Art.ell(Vector2(0, -10), Vector2(36, 9), 2, 0.05, 18), Color("3a1c0c"))
	if _on(2):
		for k in 7:
			var p := Vector2(-28 + k * 9.5, -10 + Art.srnd(k) * 4 - 2)
			_dot(ci, p, 3.6, Art.FIRE if k % 2 == 0 else Art.FIRE2)
	if _on(3):
		for k in 3:
			var c := Vector2(-20 + k * 20, -18)
			var pts := Art.ell(c, Vector2(10, 6), 5 + k, 0.08, 12, 0.3 * (k - 1))
			_sil(ci, [Art.P(pts, Art.LEAF_D, 1)], 2.0)
			_ln(ci, c + Vector2(-8, 0), c + Vector2(8, 0), 1.2, Art.MOSS, 9 + k)
		_smoke(ci, Vector2(-14, -24), 11)

## 1 两根柱、钉上背板 → 2 码下两层柴 → 3 码满到顶 → 4 盖上草檐
static func _firewood(ci: CanvasItem) -> void:
	_shadow(ci, 46)
	if _on(1):
		_sil(ci, [_post(-42, 58, 3.0, 1, Art.WOOD_D), _post(42, 58, 3.0, 2, Art.WOOD_D)], 2.2)
		var back := Art.rrect(Rect2(-40, -54, 80, 52), 3, 3, 0.5)
		_fill(ci, back, Color("5a3416"))
		Art.outline(ci, back, 2.4, _c(Art.INK))
	for row in 4:
		if not _on(2 if row < 2 else 3):
			continue
		for col in 5:
			var c := Vector2(-32 + col * 16 + (row % 2) * 5, -10 - row * 13)
			if c.x > 34:
				continue
			_ring(ci, c, 6.8, row * 7 + col)
	if _on(4):
		_sil(ci, [Art.P(Art.poly([Vector2(-48, -50), Vector2(48, -50), Vector2(44, -62), Vector2(-44, -62)], 4), HAY.darkened(0.1), 1)], 2.2)

## 1 石台基 → 2 垒上中段、刻金纹 → 3 架上火盆 → 4 点燃圣火，火星绕着转
static func _sacredfire(ci: CanvasItem) -> void:
	_shadow(ci, 44, 12)
	if _on(1):
		var base := Art.poly([Vector2(-40, 0), Vector2(-34, -22), Vector2(34, -22), Vector2(40, 0)], 1, 0.6)
		_sil(ci, [Art.P(base, Art.STONE, 0)], 2.6)
	if _on(2):
		var mid := Art.poly([Vector2(-28, -22), Vector2(-24, -46), Vector2(24, -46), Vector2(28, -22)], 2, 0.6)
		_sil(ci, [Art.P(mid, Art.STONE_D, 1)], 2.6)
	if _on(3):
		var bowl := Art.poly([Vector2(-36, -50), Vector2(36, -50), Vector2(24, -66), Vector2(-24, -66)], 3, 0.6)
		_sil(ci, [Art.P(bowl, Art.STONE, 0)], 2.6)
	if _on(2):
		for k in 3:
			_fill(ci, Art.star_pts(Vector2(-14 + k * 14, -34), 5, 2, 4, 4 + k), Art.OCHRE)
	if _on(4):
		_flame(ci, Vector2(0, -98), 30, 76, 5)
		if flat.a == 0.0:
			var t := float(Art.boil % 8) / 8.0
			for k in 4:
				var a := TAU * (float(k) / 4.0 + t * 0.25)
				ci.draw_colored_polygon(Art.star_pts(Vector2(cos(a) * 34, -96 + sin(a) * 26), 4, 1.5, 4, 20 + k), Color(1, 0.9, 0.5, 0.9))

# ================================================================ 木工场

## 1 底下一根大原木 → 2 码上第二根 → 3 顶上第三根
static func _logs(ci: CanvasItem) -> void:
	_shadow(ci, 52)
	if _on(1):
		_sil(ci, [_log(Vector2(-44, -12), Vector2(36, -18), 11, 1)], 2.6)
		_ring(ci, Vector2(-44, -12), 10, 10)
	if _on(2):
		_sil(ci, [_log(Vector2(-40, -36), Vector2(40, -40), 11, 2, Art.WOOD_D)], 2.6)
		_ring(ci, Vector2(-40, -36), 10, 11)
	if _on(3):
		_sil(ci, [_log(Vector2(-30, -58), Vector2(30, -60), 10, 3)], 2.6)
		_ring(ci, Vector2(-30, -58), 9, 12)
	if _on(1):
		for k in 3:
			_ln(ci, Vector2(-20 + k * 18, -16), Vector2(-10 + k * 18, -18), 1.4, Color(0.3, 0.16, 0.05, 0.5), 20 + k)

## 1 立个木墩 → 2 劈下木片、旁边滚一截柴 → 3 墩上砍着一把石斧
static func _chopblock(ci: CanvasItem) -> void:
	_shadow(ci, 46)
	if _on(1):
		_stump(ci, Vector2(0, 0), 22, 30, 1)
	if _on(3):
		_sil(ci, [_log(Vector2(-4, -36), Vector2(24, -64), 3.0, 2),
			Art.P(Art.poly([Vector2(-12, -30), Vector2(-4, -44), Vector2(4, -34), Vector2(-6, -26)], 3), Art.STONE, 1)], 2.2)
	if _on(2):
		for k in 3:
			var c := Vector2(-36 + k * 9, -6 - (k % 2) * 6)
			_sil(ci, [Art.P(Art.poly([c + Vector2(-5, 6), c + Vector2(-2, -10), c + Vector2(5, -8), c + Vector2(4, 6)], 4 + k), Color("e0b070"), 1)], 1.8)
		_sil(ci, [_log(Vector2(28, -4), Vector2(44, -8), 5, 8)], 2.0)
		_ring(ci, Vector2(44, -8), 5, 9)

## 1 两个凳脚 → 2 架上长凳面 → 3 凳上摆着手工活
static func _bench(ci: CanvasItem) -> void:
	_shadow(ci, 52, 10)
	if _on(1):
		for x in [-36.0, 36.0]:
			_sil(ci, [Art.P(Art.rrect(Rect2(x - 6, -22, 12, 22), 3, int(x), 0.4), Art.WOOD_D, 1)], 2.2)
	if _on(2):
		var top := Art.poly([Vector2(-50, -20), Vector2(-46, -32), Vector2(48, -32), Vector2(52, -20)], 1, 0.5)
		_sil(ci, [Art.P(top, Art.WOOD, 0)], 2.6)
		_ln(ci, Vector2(-40, -26), Vector2(40, -27), 1.4, Color(0.3, 0.16, 0.05, 0.5), 2)
	if _on(3):
		_it(ci, "craft_5", Vector2(22, -38), 18)
		_it(ci, "craft_2", Vector2(-18, -36), 16)

## 1 两对交叉腿 → 2 架上木板 → 3 刨出卷花，压着石刨
static func _sawhorse(ci: CanvasItem) -> void:
	_shadow(ci, 46, 10)
	if _on(1):
		for sx in [-1.0, 1.0]:
			_sil(ci, [_log(Vector2(30 * sx - 10, 0), Vector2(30 * sx + 6, -40), 3.0, 1 + int(sx), Art.WOOD_D),
				_log(Vector2(30 * sx + 10, 0), Vector2(30 * sx - 6, -40), 3.0, 3 + int(sx), Art.WOOD_D)], 2.0)
	if _on(2):
		var plank := Art.poly([Vector2(-46, -36), Vector2(46, -40), Vector2(46, -48), Vector2(-46, -46)], 5, 0.4)
		_sil(ci, [Art.P(plank, Color("dca866"), 1)], 2.4)
	if _on(3):
		for k in 5:
			var p := Vector2(-20 + k * 7, -50 - (k % 2) * 3)
			_pl(ci, [p, p + Vector2(3, -5), p + Vector2(7, -3)], 1.6, Color("e8c48a"), k)
		_sil(ci, [Art.P(Art.rrect(Rect2(4, -58, 22, 10), 3, 6, 0.4), Art.STONE, 1)], 2.0)

## 1 两根棚柱 → 2 搭上草顶 → 3 棚下放木墩和半成品 → 4 滚来一截原木、柱上挂斧
static func _woodshed(ci: CanvasItem) -> void:
	_shadow(ci, 62, 14)
	if _on(1):
		_sil(ci, [_post(-50, 78, 3.4, 1, Art.WOOD_D), _post(50, 70, 3.4, 2, Art.WOOD_D)], 2.4)
	if _on(3):
		_stump(ci, Vector2(-14, 0), 14, 18, 3)
	if _on(4):
		_sil(ci, [_log(Vector2(10, -6), Vector2(40, -12), 7, 4)], 2.2)
		_ring(ci, Vector2(10, -6), 6.5, 5)
	if _on(3):
		_it(ci, "furn_3", Vector2(-14, -28), 24)
	if _on(2):
		var roof := Art.poly([Vector2(-64, -76), Vector2(-56, -94), Vector2(60, -82), Vector2(64, -64)], 6, 0.7)
		_sil(ci, [Art.P(roof, HAY.darkened(0.05), 1)])
		for k in 8:
			_ln(ci, Vector2(-56 + k * 15, -92 + k * 1.5), Vector2(-60 + k * 16, -76 + k * 1.6), 1.4, Color(0.45, 0.28, 0.05, 0.55), 10 + k)
	if _on(4):
		_sil(ci, [_log(Vector2(-30, -64), Vector2(-20, -40), 2.0, 20), Art.P(Art.poly([Vector2(-34, -66), Vector2(-24, -70), Vector2(-22, -60)], 21), Art.STONE, 1)], 1.6)

## 1 立起光木柱 → 2 下半截刻纹上色 → 3 上半截刻纹上色 → 4 顶上装展翅鸟头
static func _carvedpole(ci: CanvasItem) -> void:
	_shadow(ci, 30)
	if _on(1):
		var pole := Art.rrect(Rect2(-16, -124, 32, 124), 6, 1, 0.6)
		_sil(ci, [Art.P(pole, Art.WOOD, 1)], 2.6)
	var bands := [Art.CLAY, Art.TEAL, Art.OCHRE, Art.CLAY]
	for k in 4:
		if not _on(2 if k < 2 else 3):
			continue
		var y := -18.0 - k * 28.0
		_fill(ci, Art.poly([Vector2(-16, y), Vector2(16, y - 2), Vector2(16, y - 8), Vector2(-16, y - 6)], 10 + k), bands[k])
		for j in 3:
			_fill(ci, Art.poly([Vector2(-12 + j * 9, y - 10), Vector2(-6 + j * 9, y - 10), Vector2(-9 + j * 9, y - 18)], 20 + k * 3 + j), Art.INK)
	if _on(4):
		var wing := Art.poly([Vector2(-44, -122), Vector2(-16, -130), Vector2(16, -130), Vector2(44, -122), Vector2(30, -112), Vector2(16, -118), Vector2(-16, -118), Vector2(-30, -112)], 2)
		_sil(ci, [Art.P(wing, Art.TEAL, 1)], 2.4)
		var head := Art.ell(Vector2(0, -138), Vector2(13, 12), 3, 0.05)
		_sil(ci, [Art.P(head, Art.WOOD, 0)], 2.4)
		_fill(ci, Art.poly([Vector2(-4, -136), Vector2(4, -136), Vector2(0, -126)], 4), Art.OCHRE)
		_dot(ci, Vector2(-5, -141), 2.4, Art.INK)
		_dot(ci, Vector2(5, -141), 2.4, Art.INK)

# ================================================================ 陶窑坊

## 1 挖开土坑 → 2 和出一坑红泥 → 3 堆上泥团、插根搅棍
static func _claypit(ci: CanvasItem) -> void:
	_shadow(ci, 52, 12)
	if _on(1):
		var rim_pts := Art.ell(Vector2(0, -8), Vector2(48, 15), 1, 0.06, 22)
		_sil(ci, [Art.P(rim_pts, DIRT, 1)], 2.4)
		_fill(ci, Art.ell(Vector2(0, -7), Vector2(38, 10), 2, 0.06, 18), Color("3d2716"))
	if _on(2):
		_fill(ci, Art.ell(Vector2(0, -7), Vector2(38, 10), 2, 0.06, 18), Color("9a4528"))
		_fill(ci, Art.ell(Vector2(-10, -10), Vector2(12, 3), 3, 0.0, 12), Color(1, 1, 1, 0.3))
	if _on(3):
		for k in 3:
			var c := Vector2(30 + k * 6, -14 - k * 8)
			_sil(ci, [Art.P(Art.ell(c, Vector2(8, 6), 4 + k, 0.12, 10), CLAYW, 0)], 2.0)
		_sil(ci, [_log(Vector2(-30, -10), Vector2(-46, -30), 2.4, 8, Art.WOOD_D)], 1.8)

## 1 垫座石 → 2 装上转盘，转起来 → 3 盘上拉出一只陶坯
static func _wheel(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	if _on(1):
		_sil(ci, [_stone(Vector2(0, -8), Vector2(18, 10), 1, Art.STONE_D)], 2.2)
	if _on(2):
		var disc := Art.ell(Vector2(0, -22), Vector2(36, 10), 2, 0.03, 20)
		_sil(ci, [Art.P(Art.poly([Vector2(-36, -22), Vector2(36, -22), Vector2(34, -14), Vector2(-34, -14)], 3), Art.STONE, 1)], 2.4)
		Art.dilate(ci, disc, 2.4, _c(Art.INK))
		_fill(ci, disc, Color("c9c4ba"))
	if _on(3):
		_sil(ci, [Art.P(_jar(Vector2(0, -24), 34, 40, 18, 4), Color("cf7a4e"), 0)], 2.4)
		_pl(ci, [Vector2(-12, -46), Vector2(0, -48), Vector2(12, -46)], 1.4, Color(1, 1, 1, 0.5), 5)
	if flat.a == 0.0 and _on(2):
		var t := float(Art.boil % 8) / 8.0 * TAU
		for k in 2:
			var a := t + PI * k
			ci.draw_line(Vector2(cos(a) * 30, -22 + sin(a) * 8), Vector2(cos(a + 0.5) * 30, -22 + sin(a + 0.5) * 8), Color(1, 1, 1, 0.8), 2.0, true)

## 1 两层空架子 → 2 下层摆上三只罐 → 3 上层摆满，架前放着新烧的陶器
static func _potshelf(ci: CanvasItem) -> void:
	_shadow(ci, 50)
	if _on(1):
		_sil(ci, [_post(-44, 88, 3.0, 1, Art.WOOD_D), _post(44, 88, 3.0, 2, Art.WOOD_D)], 2.2)
		for y in [-40.0, -80.0]:
			_sil(ci, [Art.P(Art.poly([Vector2(-50, y), Vector2(50, y), Vector2(50, y + 7), Vector2(-50, y + 7)], int(-y)), Art.WOOD, 1)], 2.2)
	if _on(2):
		_sil(ci, [Art.P(_jar(Vector2(-24, -40), 24, 32, 12, 3), CLAYW, 0), Art.P(_jar(Vector2(8, -40), 30, 26, 22, 4), Color("cf7a4e"), 0),
			Art.P(_jar(Vector2(34, -40), 18, 30, 10, 5), CLAYW.darkened(0.1), 0)], 2.2)
	if _on(3):
		_sil(ci, [Art.P(_jar(Vector2(-14, -80), 28, 30, 14, 6), Color("cf7a4e"), 0), Art.P(_jar(Vector2(20, -80), 22, 22, 18, 7), CLAYW, 0)], 2.2)
	if _on(2):
		_ln(ci, Vector2(-26, -54), Vector2(-4, -56), 1.6, Art.INK, 8)
	if _on(3):
		_ln(ci, Vector2(-8, -96), Vector2(-20, -94), 1.6, Art.BONE, 9)
		_it(ci, "pot_3", Vector2(-24, -6), 26)
		_it(ci, "ware_2", Vector2(22, -8), 22)

## 1 石圈烧坑 → 2 坑里码上两只陶坯 → 3 点火，炭火通红冒烟
static func _firepit(ci: CanvasItem) -> void:
	_shadow(ci, 52, 12)
	if _on(1):
		var rim_pts := Art.ell(Vector2(0, -10), Vector2(48, 14), 1, 0.06, 22)
		_sil(ci, [Art.P(rim_pts, Art.STONE_D, 1)], 2.4)
		_fill(ci, Art.ell(Vector2(0, -9), Vector2(38, 9), 2, 0.05, 18), Color("3a1c0c"))
	if _on(2):
		_sil(ci, [Art.P(_jar(Vector2(-16, -6), 24, 26, 14, 3), CLAYW, 0), Art.P(_jar(Vector2(14, -4), 28, 30, 16, 4), Color("cf7a4e"), 0)], 2.2)
	if _on(3):
		_flame(ci, Vector2(-28, -18), 9, 22, 5)
		_flame(ci, Vector2(30, -18), 9, 24, 6)
		_flame(ci, Vector2(0, -12), 8, 18, 7)
		for k in 6:
			_dot(ci, Vector2(-36 + k * 14, -4), 2.6, Art.FIRE2 if k % 2 == 0 else Art.FIRE)
		_smoke(ci, Vector2(0, -36), 3)

## 1 砌一圈矮泥墙、留窑口 → 2 封成圆顶 → 3 顶上起烟囱 → 4 窑里点火，烟囱冒烟
static func _kilndome(ci: CanvasItem) -> void:
	_shadow(ci, 56, 14)
	if _on(1):
		var low := Art.poly([Vector2(-50, 0), Vector2(-49, -26), Vector2(-30, -34), Vector2(30, -34), Vector2(49, -26), Vector2(50, 0)], 1, 0.9)
		_sil(ci, [Art.P(low, CLAYW, 0)], 2.8)
		for k in 2:
			var y := -10.0 - k * 12.0
			_ln(ci, Vector2(-44, y), Vector2(-34, y - 2), 1.6, Color(0.4, 0.15, 0.05, 0.5), k)
			_ln(ci, Vector2(34, y - 2), Vector2(44, y), 1.6, Color(0.4, 0.15, 0.05, 0.5), k + 9)
	if _on(2):
		var dome := Art.poly([Vector2(-50, 0), Vector2(-48, -30), Vector2(-36, -56), Vector2(-16, -72), Vector2(16, -72), Vector2(36, -56), Vector2(48, -30), Vector2(50, 0)], 1, 0.9)
		_sil(ci, [Art.P(dome, CLAYW, 0)], 2.8)
	if _on(3):
		_sil(ci, [Art.P(Art.rrect(Rect2(-12, -98, 24, 30), 4, 2, 0.5), CLAYW.darkened(0.12), 1)], 2.4)
	if _on(1):
		var mouth := Art.poly([Vector2(-18, 0), Vector2(-16, -24), Vector2(0, -34), Vector2(16, -24), Vector2(18, 0)], 3, 0.5)
		Art.dilate(ci, mouth, 2.4, _c(Art.INK))
		_fill(ci, mouth, Color("3a1c0c"))
	if _on(4):
		_fill(ci, Art.flame_pts(Vector2(0, -12), 10, 22, 4), Art.FIRE)
		_fill(ci, Art.flame_pts(Vector2(0, -9), 5, 13, 5), Art.FIRE2)
	if _on(2):
		for k in 5:
			var y := -10.0 - k * 12.0
			var w := 44.0 - k * 6.0
			_ln(ci, Vector2(-w, y), Vector2(-w + 10, y - 2), 1.6, Color(0.4, 0.15, 0.05, 0.5), k)
			_ln(ci, Vector2(w - 10, y - 2), Vector2(w, y), 1.6, Color(0.4, 0.15, 0.05, 0.5), k + 9)
	if _on(4):
		_smoke(ci, Vector2(0, -100), 7)

## 1 盘出半截瓮身 → 2 收口成形、捏上双耳 → 3 刻颈纹和锯齿纹 → 4 画上鱼纹、点一圈黑点
static func _bigjar(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	if _on(1):
		var half := Art.poly([Vector2(-36, -40), Vector2(-32, -16), Vector2(-22, 0), Vector2(22, 0), Vector2(32, -16), Vector2(36, -40)], 1, 0.6)
		_sil(ci, [Art.P(half, Color("d8854e"), 0)], 3.0)
		_fill(ci, Art.ell(Vector2(0, -40), Vector2(34, 6), 2, 0.03, 18), Color("8a4a26"))
		for k in 3:
			_ln(ci, Vector2(-33 + k, -12 - k * 10), Vector2(33 - k, -12 - k * 10), 1.2, Color(0.5, 0.25, 0.1, 0.4), 20 + k)
	if _on(2):
		var jar := _jar(Vector2.ZERO, 72, 88, 30, 1)
		_sil(ci, [Art.P(jar, Color("d8854e"), 0)], 3.0)
	if _on(3):
		_ln(ci, Vector2(-30, -62), Vector2(30, -62), 3.0, Art.INK, 2)
		for k in 6:
			var x := -28.0 + k * 11.0
			_pl(ci, [Vector2(x, -56), Vector2(x + 5.5, -46), Vector2(x + 11, -56)], 2.6, Art.INK, 3 + k)
		_ln(ci, Vector2(-34, -40), Vector2(34, -40), 2.4, Art.CLAY.darkened(0.2), 10)
	if _on(4):
		_fill(ci, Art.ell(Vector2(-2, -26), Vector2(13, 7), 11, 0.0, 14), Art.INK)
		_fill(ci, Art.poly([Vector2(9, -26), Vector2(20, -33), Vector2(20, -19)], 12, 0.4), Art.INK)
		_dot(ci, Vector2(-8, -27), 1.6, Art.BONE)
		for k in 4:
			_dot(ci, Vector2(-24 + k * 16, -10), 2.6, Art.INK)
	if _on(2):
		for sx in [-1.0, 1.0]:
			var ear := Art.ell(Vector2(34 * sx, -56), Vector2(6, 9), 12, 0.05, 10)
			Art.outline(ci, ear, 3.6, _c(Art.INK))
			Art.outline(ci, ear, 2.0, _c(Color("d8854e")))

# ================================================================ 渔猎场

## 一条挂着的鱼：尾巴朝上系在绳上，c 是系绳点
static func _hang_fish(ci: CanvasItem, c: Vector2, ln: float, col: Color, seed: int) -> void:
	_ln(ci, c, c + Vector2(0, 5), 1.6, Art.ROPE, seed)
	var top := c + Vector2(0, 5)
	var tail := Art.poly([top + Vector2(-5, 0), top + Vector2(5, 0), top + Vector2(1.5, 7), top + Vector2(-1.5, 7)], seed, 0.3)
	var body := Art.ell(top + Vector2(0, 7 + ln * 0.5), Vector2(ln * 0.24, ln * 0.5), seed + 1, 0.04, 14)
	_sil(ci, [Art.P(tail, col.darkened(0.15), 1), Art.P(body, col, 0)], 2.0)
	_dot(ci, top + Vector2(-1.5, 7 + ln * 0.86), 1.6, Art.INK)
	_ln(ci, top + Vector2(-ln * 0.18, 7 + ln * 0.62), top + Vector2(ln * 0.18, 7 + ln * 0.66), 1.2, col.darkened(0.3), seed + 2)

## 扇贝：底点 c，半径 r，朝向 ang（0 = 朝上）
static func _scallop(ci: CanvasItem, c: Vector2, r: float, ang: float, col: Color, seed: int) -> void:
	var pts: Array = [c]
	for k in 9:
		var a := -PI * 0.5 + ang + (float(k) / 8.0 - 0.5) * 1.9
		var rr := r * (1.0 if k % 2 == 0 else 0.93)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	_sil(ci, [Art.P(Art.poly(pts, seed, 0.3), col, 0)], 2.0)
	for k in 4:
		var a := -PI * 0.5 + ang + ((float(k) + 0.5) / 4.0 - 0.5) * 1.6
		_ln(ci, c + Vector2(cos(a), sin(a)) * r * 0.2, c + Vector2(cos(a), sin(a)) * r * 0.85, 1.2, col.darkened(0.25), seed + k)

## 1 两根桩架横杆 → 2 挂上一张渔网 → 3 网边系浮子、网里兜着一条鱼
static func _netrack(ci: CanvasItem) -> void:
	_shadow(ci, 50)
	if _on(1):
		_sil(ci, [_post(-44, 90, 3.2, 1, Art.WOOD_D, 4), _post(44, 90, 3.2, 2, Art.WOOD_D, -4),
			_log(Vector2(-50, -84), Vector2(50, -84), 3.0, 3)], 2.4)
	var tl := Vector2(-38, -82)
	var tr := Vector2(38, -82)
	var bl := Vector2(-32, -30)
	var br := Vector2(34, -26)
	if _on(2):
		var sheet := Art.poly([tl, tr, br + Vector2(0, 2), Vector2(0, -22), bl + Vector2(0, 2)], 4, 0.4)
		_fill(ci, sheet, Color(Art.ROPE, 0.22))
		for k in 9:
			var t := float(k) / 8.0
			var top := tl.lerp(tr, t)
			var t2 := clampf(t + 0.25, 0.0, 1.0)
			var t3 := clampf(t - 0.25, 0.0, 1.0)
			_ln(ci, top, bl.lerp(br, t2) + Vector2(0, sin(t2 * PI) * 6.0), 1.3, Art.ROPE, 10 + k)
			_ln(ci, top, bl.lerp(br, t3) + Vector2(0, sin(t3 * PI) * 6.0), 1.3, Art.ROPE, 30 + k)
		_ln(ci, tl, bl, 1.8, Art.ROPE, 50)
		_ln(ci, tr, br, 1.8, Art.ROPE, 51)
		var hem: Array = []
		for k in 9:
			var t := float(k) / 8.0
			hem.append(bl.lerp(br, t) + Vector2(0, sin(t * PI) * 6.0))
		_pl(ci, hem, 3.4, Art.INK, 60)
		_pl(ci, hem, 2.0, Art.ROPE, 60)
	if _on(3):
		for k in 4:
			var t := (float(k) + 0.5) / 4.0
			var p := bl.lerp(br, t) + Vector2(0, sin(t * PI) * 6.0 + 5)
			_dot(ci, p, 5.0, Art.INK)
			_dot(ci, p, 3.8, Art.OCHRE if k % 2 == 0 else Art.BONE)
		_it(ci, "fish_2", Vector2(4, -50), 40)
		var coil := Art.ell(Vector2(40, -4), Vector2(12, 5), 70, 0.05, 14)
		Art.outline(ci, coil, 3.4, _c(Art.INK))
		Art.outline(ci, coil, 2.0, _c(Art.ROPE))

## 1 两副交叉木架、搭横杆 → 2 挂一排鲜鱼 → 3 下面再加一杆熏鱼，地上一篓鱼
static func _fishrack(ci: CanvasItem) -> void:
	_shadow(ci, 56, 12)
	if _on(1):
		for sx in [-1.0, 1.0]:
			_sil(ci, [_log(Vector2(48 * sx - 10, 0), Vector2(48 * sx + 5, -78), 2.8, 1 + int(sx), Art.WOOD_D),
				_log(Vector2(48 * sx + 10, 0), Vector2(48 * sx - 5, -78), 2.8, 3 + int(sx), Art.WOOD_D)], 2.0)
		_sil(ci, [_log(Vector2(-58, -70), Vector2(58, -70), 2.6, 5)], 2.0)
	if _on(3):
		_sil(ci, [_log(Vector2(-46, -36), Vector2(46, -36), 2.4, 6, Art.WOOD_D)], 2.0)
		for k in 3:
			_hang_fish(ci, Vector2(-24 + k * 24, -36), 16, Color("a8763e"), 20 + k)
	if _on(2):
		for k in 4:
			_hang_fish(ci, Vector2(-33 + k * 22, -70), 22, Art.FISH if k % 2 == 0 else Art.FISH.lightened(0.15), 10 + k)
	if _on(3):
		_basket(ci, Vector2(-40, 2), 24, 16, 30)
		_it(ci, "fish_4", Vector2(-40, -16), 34)

## 1 打下木桩、扎好三道藤圈 → 2 编成锥形鱼笼 → 3 绳子拴在桩上，笼口钻进一条鱼
static func _fishtrap(ci: CanvasItem) -> void:
	_shadow(ci, 46, 11)
	if _on(1):
		_sil(ci, [_post(-42, 46, 3.0, 1, Art.WOOD_D)], 2.2)
	var rings := [[-18.0, 18.0], [6.0, 15.0], [28.0, 10.0]]
	if _on(1):
		for k in rings.size():
			var rg: Array = rings[k]
			var e := Art.ell(Vector2(rg[0], -2 - rg[1]), Vector2(rg[1] * 0.4, rg[1]), 5 + k, 0.03, 16)
			Art.outline(ci, e, 4.0, _c(Art.INK))
			Art.outline(ci, e, 2.2, _c(Art.WOOD))
	if _on(2):
		var body := Art.poly([Vector2(-26, -38), Vector2(30, -22), Vector2(48, -14), Vector2(48, -8), Vector2(30, -2), Vector2(-26, 0)], 8, 0.5)
		_sil(ci, [Art.P(body, HAY.darkened(0.06), 1)], 2.4)
		for k in 6:
			var x := -20.0 + k * 11.0
			var hh := lerpf(18.0, 6.0, float(k) / 5.0)
			_ln(ci, Vector2(x, -19 - hh), Vector2(x + 3, -19 + hh), 1.3, Color(0.55, 0.38, 0.12, 0.7), 12 + k)
		for k in rings.size():
			var rg: Array = rings[k]
			var x: float = rg[0]
			var h: float = rg[1]
			_ln(ci, Vector2(x, -2 - h * 1.85), Vector2(x, -2), 2.4, Art.WOOD_D, 20 + k)
		var mouth := Art.ell(Vector2(-26, -19), Vector2(7, 18), 9, 0.04, 16)
		Art.dilate(ci, mouth, 2.2, _c(Art.INK))
		_fill(ci, mouth, Color("4a3418"))
	if _on(3):
		_rope_line(ci, Vector2(-42, -40), Vector2(-26, -34), 4, 30)
		_it(ci, "fish_3", Vector2(-22, -18), 30)
		_it(ci, "fish_1", Vector2(40, 0), 30)

## 1 一小堆碎贝壳 → 2 堆上几只大扇贝 → 3 顶上一只张开的蚌、旁边石锤和蛤蜊
static func _shellpile(ci: CanvasItem) -> void:
	_shadow(ci, 46, 11)
	if _on(1):
		var mound := Art.poly([Vector2(-44, 0), Vector2(-34, -14), Vector2(-12, -22), Vector2(14, -22), Vector2(36, -14), Vector2(46, 0)], 1, 0.6)
		_sil(ci, [Art.P(mound, Color("e3d4b8"), 0)], 2.4)
		for k in 9:
			var p := Vector2(-34 + k * 8.5, -6 - Art.srnd(k * 5) * 12)
			_fill(ci, Art.ell(p, Vector2(4, 2.4), k, 0.1, 8, Art.srnd(k) * 2.0), Color("c9a98f") if k % 2 == 0 else Color("f2e6d0"))
	if _on(2):
		_scallop(ci, Vector2(-20, -14), 16, -0.35, Color("eab2a0"), 10)
		_scallop(ci, Vector2(18, -12), 15, 0.4, Art.BONE, 11)
		_scallop(ci, Vector2(0, -20), 18, 0.0, Color("f0c9a8"), 12)
	if _on(3):
		var low := Art.ell(Vector2(2, -34), Vector2(14, 6), 20, 0.05, 14)
		_sil(ci, [Art.P(low, Color("6c7d8c"), 1)], 2.2)
		_fill(ci, Art.ell(Vector2(2, -35), Vector2(10, 3.6), 21, 0.04, 12), Color("e9e2d8"))
		_dot(ci, Vector2(4, -36), 3.4, Art.INK)
		_dot(ci, Vector2(4, -36), 2.6, Color("fbf6ee"))
		var lid := Art.poly([Vector2(-12, -36), Vector2(-8, -46), Vector2(6, -48), Vector2(16, -38)], 22, 0.4)
		_sil(ci, [Art.P(lid, Color("7b8c9a"), 1)], 2.2)
		_it(ci, "clam_3", Vector2(36, -8), 30)
		_sil(ci, [Art.P(Art.ell(Vector2(-40, -6), Vector2(8, 6), 23, 0.1, 10), Art.STONE, 1)], 2.0)

## 1 拖来一根大原木 → 2 挖空成船 → 3 削出翘头、画上纹 → 4 船里放桨、兜着鱼
static func _canoe(ci: CanvasItem) -> void:
	_shadow(ci, 68, 12)
	if _on(1):
		for x in [-34.0, 34.0]:
			_sil(ci, [Art.P(Art.rrect(Rect2(x - 9, -8, 18, 9), 3, int(x), 0.4), Art.WOOD_D, 1)], 2.0)
		if _until(1):
			_sil(ci, [_log(Vector2(-58, -16), Vector2(58, -18), 12, 1, Art.WOOD_D)], 2.6)
			_ring(ci, Vector2(-58, -16), 11, 2)
	if _on(3):
		for sx in [-1.0, 1.0]:
			var prow := Art.poly([Vector2(56 * sx, -26), Vector2(72 * sx, -46), Vector2(72 * sx, -36), Vector2(62 * sx, -18)], 5 + int(sx), 0.4)
			_sil(ci, [Art.P(prow, Art.WOOD, 0)], 2.2)
	if _on(2):
		var hull := Art.poly([Vector2(-66, -30), Vector2(-50, -28), Vector2(50, -28), Vector2(66, -30), Vector2(58, -14), Vector2(40, -4), Vector2(-40, -4), Vector2(-58, -14)], 3, 0.5)
		_sil(ci, [Art.P(hull, Art.WOOD, 0)], 2.6)
		var hollow := Art.ell(Vector2(0, -28), Vector2(50, 5), 4, 0.03, 20)
		Art.dilate(ci, hollow, 2.0, _c(Art.INK))
		_fill(ci, hollow, Color("5a3416"))
	if _on(4):
		_sil(ci, [_log(Vector2(-30, -26), Vector2(44, -56), 2.2, 30), Art.P(Art.ell(Vector2(48, -58), Vector2(5, 11), 31, 0.05, 12, -1.2), Art.WOOD, 1)], 1.8)
		_it(ci, "fish_5", Vector2(-14, -34), 36)
	if _on(3):
		_ln(ci, Vector2(-50, -18), Vector2(50, -18), 3.0, Art.CLAY, 6)
		for k in 7:
			var x := -42.0 + k * 14.0
			_fill(ci, Art.poly([Vector2(x, -15), Vector2(x + 7, -15), Vector2(x + 3.5, -9)], 7 + k), Art.TEAL)
		_dot(ci, Vector2(60, -24), 3.2, Art.BONE)
		_dot(ci, Vector2(60, -24), 1.6, Art.INK)

## 1 打下四根高脚桩 → 2 铺上平台、搭梯子 → 3 起木墙、开门窗 → 4 盖草顶，檐下挂鱼
static func _stilthut(ci: CanvasItem) -> void:
	_shadow(ci, 58, 14)
	if _on(1):
		_sil(ci, [_post(-30, 58, 3.2, 1, Art.WOOD_D.darkened(0.15)), _post(34, 58, 3.2, 2, Art.WOOD_D.darkened(0.15))], 2.2)
		_sil(ci, [_post(-46, 54, 3.6, 3, Art.WOOD_D), _post(48, 54, 3.6, 4, Art.WOOD_D)], 2.4)
		_ln(ci, Vector2(-44, -8), Vector2(46, -44), 2.6, Art.WOOD_D, 5)
		_ln(ci, Vector2(-44, -44), Vector2(46, -8), 2.6, Art.WOOD_D, 6)
		for x in [-46.0, 48.0]:
			_ln(ci, Vector2(x - 3, -40), Vector2(x + 3, -36), 2.2, Art.ROPE, int(x))
	if _on(3):
		var wall := Art.rrect(Rect2(-40, -106, 80, 50), 5, 7, 0.6)
		_sil(ci, [Art.P(wall, Art.WOOD, 1)])
		for k in 5:
			_ln(ci, Vector2(-32 + k * 16, -102), Vector2(-32 + k * 16, -60), 1.4, Color(0.3, 0.16, 0.05, 0.5), 8 + k)
		var door := Art.rrect(Rect2(6, -92, 22, 34), 4, 9, 0.4)
		_fill(ci, door, Color("2a170b"))
		Art.outline(ci, door, 2.0, _c(Art.INK))
		var win := Art.rrect(Rect2(-28, -92, 18, 14), 3, 10, 0.4)
		_fill(ci, win, Color("2a170b"))
		Art.outline(ci, win, 2.0, _c(Art.INK))
	if _on(2):
		var deck := Art.poly([Vector2(-58, -58), Vector2(58, -58), Vector2(56, -48), Vector2(-56, -48)], 11, 0.4)
		_sil(ci, [Art.P(deck, Color("c58d52"), 1)], 2.4)
		for k in 6:
			_ln(ci, Vector2(-48 + k * 19, -57), Vector2(-48 + k * 19, -49), 1.2, Color(0.3, 0.16, 0.05, 0.5), 12 + k)
		# 梯子：两根梯帮 + 四根横档
		_ln(ci, Vector2(50, 0), Vector2(42, -48), 5.0, Art.INK, 20)
		_ln(ci, Vector2(66, 0), Vector2(58, -48), 5.0, Art.INK, 21)
		_ln(ci, Vector2(50, 0), Vector2(42, -48), 2.6, Art.WOOD, 20)
		_ln(ci, Vector2(66, 0), Vector2(58, -48), 2.6, Art.WOOD, 21)
		for k in 4:
			var y := -9.0 - k * 11.0
			var dx := y / 6.0
			_ln(ci, Vector2(50 + dx, y), Vector2(66 + dx, y), 3.6, Art.INK, 30 + k)
			_ln(ci, Vector2(50 + dx, y), Vector2(66 + dx, y), 2.0, Art.WOOD, 30 + k)
	if _on(4):
		var roof := Art.poly([Vector2(-60, -96), Vector2(-8, -138), Vector2(8, -138), Vector2(60, -96), Vector2(0, -104)], 40)
		_sil(ci, [Art.P(roof, HAY.darkened(0.06), 1)])
		for k in 7:
			_ln(ci, Vector2(-6 + k * 2, -136), Vector2(-52 + k * 17, -99), 1.4, Color(0.45, 0.28, 0.05, 0.5), 41 + k)
		for k in 3:
			_hang_fish(ci, Vector2(-42 + k * 9, -98), 14, Art.FISH if k != 1 else Color("a8763e"), 50 + k)
