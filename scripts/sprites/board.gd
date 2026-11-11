extends RefCounted
## 棋盘页（Board / BoardScreen / MergeEventBoard）的界面图登记和原始画法。
## 只给「生成物品图.bat」用；游戏里只用 Sprites.draw / Sprites.at 贴这里生成的图。
## 登记格式见 scripts/BakeSprites.gd。

## 藤蔓按格子序号取几种样子（单双数决定镜像）
const VINE_VARIANTS := 8
const VINE_STEM := Color("5b7a32")
const VINE_STEM_HI := Color("a8b878")
const VINE_LEAF := Color("8fae55")
const VINE_LEAF_D := Color("62813a")
const CARD_DASH := Color(0.65, 0.4, 0.2, 0.45)

static func entries() -> Array:
	var out: Array = []
	# ---------------- 棋盘格子
	out.append({"key": "board_cook_pot", "w": 64, "h": 48, "pad": 6,
		"draw": func(ci, r): live_cook_pot(ci, r.get_center(), 0)})
	out.append({"key": "board_cook_flame", "w": 16, "h": 10, "pad": 6,
		"draw": func(ci, r): Art.fill(ci, Art.flame_pts(r.get_center(), 7.0, 10.0, 4), Art.FIRE2, 2.0)})
	out.append({"key": "board_bolt", "w": 16, "h": 18, "pad": 5,
		"draw": func(ci, r): Art.fill(ci, Art.bolt_pts(r.get_center(), 14, 18), Art.FIRE2, 2.0)})
	out.append({"key": "board_bolt_boost", "w": 16, "h": 18, "pad": 5,
		"draw": func(ci, r): Art.fill(ci, Art.bolt_pts(r.get_center(), 14, 18), Art.FIRE_BOOST, 2.0)})
	out.append({"key": "board_prod_glow", "w": 84, "h": 84, "pad": 4,
		"draw": func(ci, r): live_prod_glow(ci, r, 0)})
	# 小牌：墨边一张，白芯一张（运行时染色）
	out.append({"key": "board_epill_ink", "w": 60, "h": 26, "pad": 4, "nine": [14, 13, 14, 13],
		"draw": func(ci, r): Art.dilate(ci, Art.rrect(r, 11, 700, 0.3), 2.0, Art.INK)})
	out.append({"key": "board_epill_fill", "w": 60, "h": 26, "pad": 4, "nine": [14, 13, 14, 13],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 11, 700, 0.3), Color.WHITE)})
	out.append({"key": "board_bpill_ink", "w": 50, "h": 21, "pad": 4, "nine": [12, 10, 12, 10],
		"draw": func(ci, r): Art.dilate(ci, Art.rrect(r, 10, 600, 0.3), 2.0, Art.INK)})
	out.append({"key": "board_bpill_fill", "w": 50, "h": 21, "pad": 4, "nine": [12, 10, 12, 10],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 10, 600, 0.3), Color.WHITE)})
	for v in VINE_VARIANTS:
		out.append({"key": "board_vine_b%d" % v, "w": 96, "h": 96, "pad": 20,
			"draw": func(ci, r): live_vine(ci, r, v, true)})
		out.append({"key": "board_vine_f%d" % v, "w": 96, "h": 96, "pad": 20,
			"draw": func(ci, r): live_vine(ci, r, v, false)})
	out.append({"key": "board_burst_star", "w": 24, "h": 24, "pad": 3,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.star_pts(r.get_center(), 12.0, 5.0, 4, 0), Color.WHITE)})
	# 活动棋盘的提示光框（不抖，白色，运行时染色）
	out.append({"key": "board_glow", "w": 90, "h": 90, "pad": 4, "nine": [22, 22, 22, 22], "static": true,
		"draw": func(ci, r): live_glow(ci, r, Color.WHITE, 1.0)})
	# ---------------- 棋盘页
	out.append({"key": "board_curtain_l", "w": 90, "h": 380, "pad": 6,
		"draw": func(ci, r): _at(ci, r.position, func(): live_curtain(ci, 0, 720.0))})
	out.append({"key": "board_curtain_r", "w": 90, "h": 380, "pad": 6,
		"draw": func(ci, r): _at(ci, r.position - Vector2(630, 0), func(): live_curtain(ci, 1, 720.0))})
	out.append({"key": "board_log", "w": 740, "h": 50, "pad": 6,
		"draw": func(ci, r): _at(ci, r.position - Vector2(-10, 372), func(): live_log(ci, 720.0))})
	out.append({"key": "board_stash_tray", "w": 106, "h": 192, "pad": 6,
		"draw": func(ci, r): _at(ci, r.position - Vector2(6, 26), func(): live_stash_tray(ci, Vector2(118, 226)))})
	out.append({"key": "board_stash_card", "w": 82, "h": 124, "pad": 8,
		"draw": func(ci, r): live_stash_card(ci, r, 44, false)})
	out.append({"key": "board_stash_card_top", "w": 82, "h": 124, "pad": 8,
		"draw": func(ci, r): live_stash_card(ci, r, 43, true)})
	out.append({"key": "board_stash_arrow", "w": 32, "h": 22, "pad": 5,
		"draw": func(ci, r): live_stash_arrow(ci, r)})
	out.append({"key": "board_hero_card", "w": 142, "h": 226, "pad": 6,
		"draw": func(ci, r): _at(ci, r.position, func(): live_hero_card(ci, r.size))})
	out.append({"key": "board_hammer_card", "w": 130, "h": 226, "pad": 6,
		"draw": func(ci, r): _at(ci, r.position, func(): live_hammer_card(ci, r.size))})
	out.append({"key": "board_info_panel", "w": 456, "h": 170, "pad": 6,
		"draw": func(ci, r): _at(ci, r.position, func(): live_info_panel(ci, r.size))})
	out.append({"key": "board_info_tag", "w": 304, "h": 40, "pad": 6,
		"draw": func(ci, r): _at(ci, r.position - Vector2(26, 4), func(): live_info_tag(ci))})
	# 订单卡：阴影墨边 / 白底（染色）/ 虚线，三张叠起来
	out.append({"key": "board_card_base", "w": 200, "h": 192, "pad": 12, "nine": [30, 30, 30, 30],
		"draw": func(ci, r): live_card_base(ci, r, 60)})
	out.append({"key": "board_card_fill", "w": 200, "h": 192, "pad": 12, "nine": [30, 30, 30, 30],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 18, 60, 1.0), Color.WHITE)})
	out.append({"key": "board_card_dash", "w": 200, "h": 192, "pad": 12, "nine": [30, 30, 30, 30],
		"draw": func(ci, r): Art.dashed(ci, Art.rrect(r.grow(-6), 12, 61, 0.0), 8, 6, CARD_DASH, 2.0)})
	out.append({"key": "board_head_story", "w": 76, "h": 76, "pad": 6,
		"draw": func(ci, r): live_head(ci, r.get_center(), 62, true)})
	out.append({"key": "board_head_npc", "w": 76, "h": 76, "pad": 6,
		"draw": func(ci, r): live_head(ci, r.get_center(), 62, false)})
	out.append({"key": "board_spot_shadow", "w": 80, "h": 68, "pad": 4,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.ell(r.get_center(), r.size * 0.5, 63, 0.03, 18), Color(0.8, 0.65, 0.4, 0.35))})
	out.append({"key": "board_chip", "w": 80, "h": 28, "pad": 3, "nine": [16, 14, 16, 14],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 14, 65, 0.4), Color(0.55, 0.35, 0.15, 0.18))})
	# 箭头横着画，运行时转到方向，中段九宫格拉长
	out.append({"key": "board_aim_arrow", "w": 48, "h": 16, "pad": 4, "nine": [4, 0, 14, 0],
		"draw": func(ci, r): live_aim_arrow(ci, Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y))})
	out.append({"key": "board_boost_on", "w": 36, "h": 42, "pad": 5,
		"draw": func(ci, r): live_boost(ci, r.get_center(), true)})
	out.append({"key": "board_boost_off", "w": 36, "h": 42, "pad": 5,
		"draw": func(ci, r): live_boost(ci, r.get_center(), false)})
	# 泡泡购买卡：底层（阴影 + 墨边）、尾巴墨边、面层（底色 + 虚线）、尾巴底色
	out.append({"key": "board_offer_under", "w": 340, "h": 132, "pad": 12,
		"draw": func(ci, r): live_offer_under(ci, r)})
	out.append({"key": "board_offer_top", "w": 340, "h": 132, "pad": 12,
		"draw": func(ci, r): live_offer_top(ci, r)})
	out.append({"key": "board_offer_tail_ink", "w": 30, "h": 20, "pad": 5, "static": true,
		"draw": func(ci, r): Art.dilate(ci, _offer_tail(r), 3.0, Art.INK)})
	out.append({"key": "board_offer_tail_fill", "w": 30, "h": 20, "pad": 5, "static": true,
		"draw": func(ci, r): ci.draw_colored_polygon(_offer_tail(r), Art.BONE)})
	out.append({"key": "board_plate", "w": 76, "h": 76, "pad": 5,
		"draw": func(ci, r): live_hint_plate(ci, r.get_center(), r.size.x, 0, false)})
	out.append({"key": "board_plate_hot", "w": 76, "h": 76, "pad": 5,
		"draw": func(ci, r): live_hint_plate(ci, r.get_center(), r.size.x, 2, true)})
	return out

static func _at(ci: CanvasItem, off: Vector2, fn: Callable) -> void:
	ci.draw_set_transform(off, 0.0, Vector2.ONE)
	fn.call()
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- 棋盘格子

## 制作中的陶锅（锅身 + 锅沿 + 里面的汤）
static func live_cook_pot(ci: CanvasItem, ctr: Vector2, seed: int) -> void:
	var pot := Art.poly([ctr + Vector2(-24, -2), ctr + Vector2(24, -2), ctr + Vector2(16, 18), ctr + Vector2(-16, 18)], seed, 0.7)
	var lip := Art.ell(ctr + Vector2(0, -2), Vector2(24, 8), seed + 1, 0.04, 16)
	Art.sil(ci, [Art.P(pot, Art.CLAY, 1), Art.P(lip, Art.OCHRE, 0)], false, 2.4)
	ci.draw_colored_polygon(Art.ell(ctr + Vector2(0, 0), Vector2(14, 5), seed + 2, 0.03, 12), Color("e07a3a"))

## 生产器底下的暖光
static func live_prod_glow(ci: CanvasItem, r: Rect2, i: int) -> void:
	ci.draw_colored_polygon(Art.rrect(r, 14, i, 0.6), Color(1, 0.86, 0.45, 0.55))
	Art.outline(ci, Art.rrect(r, 14, i, 0.6), 2.0, Color(0.7, 0.45, 0.1, 0.6))

static func live_glow(ci: CanvasItem, r: Rect2, col: Color, a: float) -> void:
	var pts := Art.rrect(r, 14, 77, 0.0)
	ci.draw_colored_polygon(pts, Color(col, a * 0.35))
	Art.outline(ci, pts, 4.0, Color(col, a))

## 藤蔓：两根弯曲的藤茎（墨线 + 深浅两层绿 + 高光）从格子上缘和下部绕过物品，
## 沿茎交替长出带叶脉的双色叶子，末端卷须打圈。
## 走上 / 下三分之一，物品中间留出来，看得清是什么。i 决定镜像和抖动。
static func live_vine(ci: CanvasItem, r: Rect2, i: int, back: bool) -> void:
	var p := r.position
	var s := r.size.x / 96.0
	var flip := i % 2 == 1
	var j := func(k: int, amp: float) -> float: return Art.srnd(i * 13 + k) * amp
	var pt := func(x: float, y: float, k: int) -> Vector2:
		# 带沸腾线：控制点跟着全局 boil 帧轻轻抖
		return p + Vector2((96.0 - x) if flip else x, y) * s + Art.jv(i * 97 + k * 29, 1.2 * s)
	# 两根藤，一上一下：断口那头藏在物品后面，从物品侧边绕出来，
	# 在前面弯一道，末端是尖尖的藤梢 + 卷须
	var up_side: Vector2 = pt.call(12, 36 + j.call(1, 3), 1)
	var lo_side: Vector2 = pt.call(84, 64 + j.call(2, 3), 2)
	if back:
		# 背后那段：从物品中间（看不见）拉到侧边，和前面那段接上
		_vine_stroke(ci, _bez(pt.call(46, 30, 3), pt.call(30, 24, 4), pt.call(16, 28, 5), up_side, 10), 5.5 * s, false, false)
		_vine_stroke(ci, _bez(pt.call(50, 70, 6), pt.call(66, 76, 7), pt.call(80, 72, 8), lo_side, 10), 5.5 * s, false, false)
		return
	# 物品整体压淡一点
	ci.draw_colored_polygon(Art.rrect(r.grow(-5), 14, i, 0.0), Color(0.93, 0.89, 0.8, 0.22))
	var up := _bez(up_side, pt.call(30, 56 + j.call(3, 4), 9), pt.call(58, 24 + j.call(4, 4), 10), pt.call(82, 34 + j.call(5, 3), 11), 22)
	var lo := _bez(lo_side, pt.call(66, 86 + j.call(6, 3), 12), pt.call(38, 58 + j.call(7, 4), 13), pt.call(16, 70 + j.call(8, 3), 14), 22)
	_vine_stroke(ci, up, 6.0 * s, false, true)
	_vine_stroke(ci, lo, 6.0 * s, false, true)
	# 藤梢卷须
	for c in [up, lo]:
		var cv: PackedVector2Array = c
		var d: Vector2 = (cv[cv.size() - 1] - cv[cv.size() - 3]).normalized()
		_curl(ci, cv[cv.size() - 1], d.orthogonal() * (-1.0 if c == up else 1.0) * (-1.0 if flip else 1.0), 6.0 * s, i + (0 if c == up else 1))
	# 叶子：每根两片，左右错开
	var n := 0
	for c in [up, lo]:
		var cv: PackedVector2Array = c
		for k in [7, 15]:
			var tan: Vector2 = (cv[k + 1] - cv[k - 1]).normalized()
			var side := -1.0 if n % 2 == 0 else 1.0
			var ang: float = tan.angle() + side * (1.0 + j.call(20 + n, 0.25)) + Art.jit(i * 7 + n) * 0.06
			_leaf(ci, cv[k], ang, (16.0 + j.call(40 + n, 2.0)) * s)
			n += 1

## 藤条：两头收尖的一条，墨边 + 灰绿芯
static func _vine_stroke(ci: CanvasItem, c: PackedVector2Array, w: float, taper_a := true, taper_b := true) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in c.size():
		var u := float(k) / float(c.size() - 1)
		var dir := (c[mini(k + 1, c.size() - 1)] - c[maxi(k - 1, 0)]).normalized()
		var half := w * 0.5
		if taper_a and u < 0.5: half *= clampf(u * 3.2, 0.25, 1.0)
		if taper_b and u > 0.5: half *= clampf((1.0 - u) * 3.2, 0.12, 1.0)
		left.append(c[k] + dir.orthogonal() * half)
		right.append(c[k] - dir.orthogonal() * half)
	right.reverse()
	var shape := PackedVector2Array(left)
	shape.append_array(right)
	Art.dilate(ci, shape, 2.2, Art.INK)
	ci.draw_colored_polygon(shape, VINE_STEM)
	# 高光：偏上一道浅线
	var hi := PackedVector2Array()
	for k in range(3, c.size() - 3): hi.append(c[k] + Vector2(0, -w * 0.18))
	ci.draw_polyline(hi, Color(VINE_STEM_HI, 0.6), maxf(1.0, w * 0.18), true)

static func _bez(a: Vector2, b: Vector2, c: Vector2, d: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n + 1:
		var t := float(k) / float(n)
		var u := 1.0 - t
		out.append(a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t)
	return out

## 一片叶子：base 处连茎，朝 ang 方向长 len；上半浅绿、下半深绿，中间一道叶脉 + 两根侧脉。
static func _leaf(ci: CanvasItem, base: Vector2, ang: float, len: float) -> void:
	var w := len * 0.42
	var dir := Vector2.from_angle(ang)
	var nrm := dir.orthogonal()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in 9:
		var u := float(k) / 8.0
		var half := w * pow(sin(u * PI), 0.85) * (1.0 - 0.25 * u)
		var along := base + dir * (u * len)
		left.append(along + nrm * half)
		right.append(along - nrm * half)
	var outline := PackedVector2Array(left)
	for k in range(right.size() - 1, -1, -1): outline.append(right[k])
	Art.dilate(ci, outline, 2.2, Art.INK)
	ci.draw_colored_polygon(outline, VINE_LEAF)
	var dark := PackedVector2Array()
	for k in right.size(): dark.append(right[k])
	for k in range(right.size() - 1, -1, -1): dark.append(base + dir * (float(k) / 8.0 * len))
	ci.draw_colored_polygon(dark, VINE_LEAF_D)
	# 叶脉
	ci.draw_line(base + dir * len * 0.08, base + dir * len * 0.86, Color(Art.INK, 0.55), 1.4, true)
	for k in [0.35, 0.6]:
		var m: Vector2 = base + dir * len * k
		ci.draw_line(m, m + (dir + nrm * 0.9).normalized() * w * 0.6, Color(Art.INK, 0.4), 1.1, true)
		ci.draw_line(m, m + (dir - nrm * 0.9).normalized() * w * 0.6, Color(Art.INK, 0.4), 1.1, true)
	# 一点高光
	ci.draw_line(left[2] - nrm * 1.5, left[5] - nrm * 1.5, Color(1, 1, 0.8, 0.45), 1.4, true)

## 卷须：从 at 出发向 dir 方向打一圈半螺旋
static func _curl(ci: CanvasItem, at: Vector2, dir: Vector2, r: float, seed: int) -> void:
	var pts := PackedVector2Array()
	var a0 := dir.angle() + PI
	var spin := 1.0 if seed % 2 == 0 else -1.0
	var c := at + dir * r
	for k in 16:
		var t := float(k) / 15.0
		var a := a0 + spin * t * TAU * 1.25
		pts.append(c + Vector2.from_angle(a) * r * (1.0 - t * 0.75))
	ci.draw_polyline(pts, Art.INK, 5.0, true)
	ci.draw_polyline(pts, VINE_STEM, 2.6, true)

# ---------------------------------------------------------------- 棋盘页

## 顶部场景两侧的布帘。side 0 左，1 右
static func live_curtain(ci: CanvasItem, side: int, width: float) -> void:
	var x0: float = 0.0 if side == 0 else width
	var dir: float = 1.0 if side == 0 else -1.0
	var curtain := PackedVector2Array([Vector2(x0, 0), Vector2(x0 + dir * 90, 0), Vector2(x0 + dir * 60, 180), Vector2(x0 + dir * 30, 380), Vector2(x0, 380)])
	ci.draw_colored_polygon(curtain, Color("c9955a"))
	Art.outline(ci, Art.poly(Array(curtain), side), 3.0)
	Art.dashed(ci, Art.poly([Vector2(x0 + dir * 70, 10), Vector2(x0 + dir * 46, 180), Vector2(x0 + dir * 20, 370)], side + 2, 0.0), 9, 6, Color("f3d7a2"), 2.0)

## 场景底下横着的圆木
static func live_log(ci: CanvasItem, width: float) -> void:
	var log_r := Rect2(-10, 372, width + 20, 50)
	var lg := Art.rrect(log_r, 22, 33, 1.0)
	Art.dilate(ci, lg, 3.0, Art.INK)
	Art.shade(ci, lg, Art.WOOD, 1)
	for i in 8:
		Art.pl(ci, [Vector2(30 + i * 90, 384), Vector2(70 + i * 90, 388), Vector2(100 + i * 90, 384)], 2.0, Color(0.4, 0.2, 0.05, 0.5), i)

static func live_stash_tray(ci: CanvasItem, sz: Vector2) -> void:
	var tray := Rect2(6, 26, sz.x - 12, sz.y - 34)
	var tb := Art.rrect(tray, 16, 41, 1.0)
	Art.dilate(ci, tb, 3.0, Art.INK)
	ci.draw_colored_polygon(tb, Color("8a5a32"))
	Art.dashed(ci, Art.rrect(tray.grow(-6), 12, 42, 0.0), 8, 6, Color(1, 0.85, 0.6, 0.45), 2.0)

## 暂存区一张卡（含阴影），top 是最上面那张（亮色 + 虚线）
static func live_stash_card(ci: CanvasItem, cr: Rect2, seed: int, top: bool) -> void:
	var card := Art.rrect(cr, 14, seed, 0.6)
	ci.draw_colored_polygon(Art.rrect(Rect2(cr.position + Vector2(0, 5), cr.size), 14, seed, 0.0), Color(0, 0, 0, 0.25))
	Art.dilate(ci, card, 2.5, Art.INK)
	ci.draw_colored_polygon(card, Art.BONE if top else Art.BONE2)
	if top:
		Art.dashed(ci, Art.rrect(cr.grow(-6), 10, 44, 0.0), 7, 5, Color(0.65, 0.4, 0.2, 0.4), 2.0)

static func live_stash_arrow(ci: CanvasItem, r: Rect2) -> void:
	var arr := Art.poly([r.position, Vector2(r.end.x, r.position.y), Vector2(r.get_center().x, r.end.y)], 3)
	Art.fill(ci, arr, Art.MOSS, 3.0)

## 主角等级卡的底（卡片 + 头像底圆 + 肩下阴影），人像和进度条运行时叠上去
static func live_hero_card(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(4, 16, sz.x - 8, sz.y - 24)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 18, 45, 0.0), Color(0, 0, 0, 0.3))
	var b := Art.rrect(r, 18, 45, 1.0)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("fbf0d6"))
	Art.dashed(ci, Art.rrect(r.grow(-6), 12, 46, 0.0), 8, 6, Color(0.65, 0.4, 0.2, 0.45), 2.0)
	var head_c := Vector2(sz.x * 0.5, 78)
	var head := Art.ell(head_c, Vector2(44, 44), 47, 0.02, 20)
	Art.dilate(ci, head, 3.0, Art.INK)
	ci.draw_colored_polygon(head, Art.OCHRE.lightened(0.28))
	ci.draw_colored_polygon(Art.ell(Vector2(sz.x * 0.5, 118), Vector2(42, 12), 46, 0.04, 16), Color("c9a56a"))

static func live_hammer_card(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(4, 16, sz.x - 8, sz.y - 24)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 18, 48, 0.0), Color(0, 0, 0, 0.3))
	var b := Art.rrect(r, 18, 48, 1.0)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("ffe9a8"))
	Art.dashed(ci, Art.rrect(r.grow(-6), 12, 49, 0.0), 8, 6, Color(0.65, 0.4, 0.2, 0.45), 2.0)

static func live_info_panel(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(4, 22, sz.x - 8, sz.y - 34)
	var b := Art.rrect(r, 20, 51, 1.0)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 20, 51, 0.0), Color(0, 0, 0, 0.3))
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.HIDE)
	Art.dashed(ci, Art.rrect(r.grow(-8), 14, 52, 0.0), 9, 6, Color(0.65, 0.4, 0.2, 0.5), 2.0)

## 信息栏左上角的名字签条
static func live_info_tag(ci: CanvasItem) -> void:
	var tag := Art.poly([Vector2(26, 4), Vector2(330, 4), Vector2(312, 24), Vector2(330, 44), Vector2(26, 44)], 53)
	Art.dilate(ci, tag, 3.0, Art.INK)
	ci.draw_colored_polygon(tag, Art.OCHRE)

static func live_card_base(ci: CanvasItem, r: Rect2, seed: int) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 18, seed, 0.0), Color(0, 0, 0, 0.3))
	Art.dilate(ci, Art.rrect(r, 18, seed, 1.0), 3.0, Art.INK)

## 订单卡原样（对照用）：阴影、墨边、底色、虚线
static func live_order_card(ci: CanvasItem, r: Rect2, oi: int, bg: Color) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 18, oi, 0.0), Color(0, 0, 0, 0.3))
	var b := Art.rrect(r, 18, 60 + oi, 1.0)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, bg)
	Art.dashed(ci, Art.rrect(r.grow(-6), 12, 61 + oi, 0.0), 8, 6, CARD_DASH, 2.0)

## 订单人头像的底圆
static func live_head(ci: CanvasItem, c: Vector2, seed: int, story: bool) -> void:
	var head := Art.ell(c, Vector2(38, 38), seed, 0.02, 20)
	Art.dilate(ci, head, 3.0, Art.INK)
	ci.draw_colored_polygon(head, Art.OCHRE.lightened(0.3) if story else Art.TEAL.lightened(0.3))

static func live_aim_arrow(ci: CanvasItem, a: Vector2, tip: Vector2) -> void:
	var dir := (tip - a).normalized()
	var n := dir.orthogonal()
	var neck := tip - dir * 8.0
	Art.pl(ci, [a, neck], 6.0, Color.WHITE, 4)
	Art.pl(ci, [a, neck], 3.2, Art.INK, 4)
	var head := Art.poly([tip, neck + n * 5.5, neck - n * 5.5], 6, 0.15)
	Art.fill(ci, head, Art.INK, 2.0)

## 双倍火种开关上的火苗，c 是外焰中心
static func live_boost(ci: CanvasItem, c: Vector2, on: bool) -> void:
	Art.fill(ci, Art.bolt_pts(c, 30, 40), Art.FIRE_BOOST if on else Art.FIRE2, 2.5)

static func live_offer_under(ci: CanvasItem, card: Rect2) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(card.position + Vector2(0, 7), card.size), 22, 204, 0.0), Color(0, 0, 0, 0.25))
	Art.dilate(ci, Art.rrect(card, 22, 204, 0.5), 3.0, Art.INK)

static func live_offer_top(ci: CanvasItem, card: Rect2) -> void:
	ci.draw_colored_polygon(Art.rrect(card, 22, 204, 0.5), Art.BONE)
	Art.dashed(ci, Art.rrect(card.grow(-7), 16, 205, 0.0), 9, 6, Color(0.65, 0.4, 0.2, 0.35), 2.0)

## 尾巴三角：r 是 (tip_x - 15, OFFER_H - 4) 起的 30×20
static func _offer_tail(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x + 17, r.end.y)])

## 泡泡购买卡原样（对照用）
static func live_offer(ci: CanvasItem, card: Rect2, tip_x: float) -> void:
	var h := card.size.y
	var body := Art.rrect(card, 22, 204, 0.5)
	var tail := PackedVector2Array([card.position + Vector2(tip_x - 15, h - 4), card.position + Vector2(tip_x + 15, h - 4), card.position + Vector2(tip_x + 2, h + 16)])
	ci.draw_colored_polygon(Art.rrect(Rect2(card.position + Vector2(0, 7), card.size), 22, 204, 0.0), Color(0, 0, 0, 0.25))
	Art.dilate(ci, body, 3.0, Art.INK)
	Art.dilate(ci, tail, 3.0, Art.INK)
	ci.draw_colored_polygon(body, Art.BONE)
	ci.draw_colored_polygon(tail, Art.BONE)
	Art.dashed(ci, Art.rrect(card.grow(-7), 16, 205, 0.0), 9, 6, Color(0.65, 0.4, 0.2, 0.35), 2.0)

## 图标底下的浅色圆角托盘
static func live_hint_plate(ci: CanvasItem, c: Vector2, s: float, seed: int, hot: bool = false) -> void:
	var r := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
	var plate := Art.rrect(r, s * 0.24, 400 + seed, 0.4)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 3), r.size), s * 0.24, 400 + seed, 0.0), Color(0.42, 0.26, 0.12, 0.18))
	ci.draw_colored_polygon(plate, Color("fff3d6") if hot else Color("f8ead0"))
	Art.outline(ci, plate, 2.0, Color(0.55, 0.34, 0.16, 0.55 if not hot else 0.9))
