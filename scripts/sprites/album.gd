extends RefCounted
## 典藏卡册的卡片框（按星级换皮色）、未收集的岩石底、星级小横幅、大图框。
## 只给「生成物品图.bat」用；游戏里只贴生成的图。登记格式见 scripts/BakeSprites.gd。
## 卡片框是九宫格：四边 30 像素、底边 74 像素（名牌）不拉伸。运行时画面窗口 = (12, 12) 到 (宽-12, 高-70)。

## 1★ 素皮 → 2★ 绿 → 3★ 蓝 → 4★ 紫 → 5★ 金，和典藏卡包同一套颜色
const TIER := [Color("a7622c"), Color("5f9e43"), Color("3f7fc0"), Color("8a5cc9"), Color("e0a526")]
const W := 180.0
const H := 252.0
const WIN_PAD := 12.0
const WIN_BOTTOM := 70.0

static func tier_col(stars: int) -> Color:
	return TIER[clampi(stars, 1, 5) - 1]

static func entries() -> Array:
	var out: Array = []
	for t in 5:
		out.append({"key": "alb_card_%d" % (t + 1), "w": int(W), "h": int(H), "pad": 8, "nine": [30, 30, 30, 74],
			"draw": func(ci, r): _card(ci, r, t + 1)})
		out.append({"key": "alb_pic_%d" % (t + 1), "w": 300, "h": 300, "pad": 10, "nine": [46, 46, 46, 46],
			"draw": func(ci, r): _pic_frame(ci, r, t + 1)})
	out.append({"key": "alb_window", "w": 156, "h": 170, "pad": 4, "nine": [16, 16, 16, 16], "static": true,
		"draw": func(ci, r): _window(ci, r)})
	out.append({"key": "alb_locked", "w": 156, "h": 170, "pad": 2, "draw": func(ci, r): _locked(ci, r)})
	out.append({"key": "alb_ribbon", "w": 120, "h": 30, "pad": 8, "nine": [18, 8, 18, 8], "draw": func(ci, r): _ribbon(ci, r)})
	return out

static func _card(ci: CanvasItem, r: Rect2, tier: int) -> void:
	var col := tier_col(tier)
	var body := Art.rrect(r.grow(-2), 18, 700 + tier, 0.6)
	Art.dilate(ci, body, 3.0, Art.INK)
	ci.draw_colored_polygon(body, col)
	# 皮面上亮下暗
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(5, 5), Vector2(r.size.x - 10, r.size.y * 0.45)), 15, 710 + tier, 0.3), col.lightened(0.12))
	Art.dashed(ci, Art.rrect(r.grow(-7), 13, 720, 0.0), 6, 4, col.lightened(0.45), 1.8)
	# 画面窗口底色
	var win := Rect2(r.position + Vector2(WIN_PAD, WIN_PAD), Vector2(r.size.x - WIN_PAD * 2, r.size.y - WIN_PAD - WIN_BOTTOM))
	ci.draw_colored_polygon(Art.rrect(win, 10, 730, 0.0), Color("3c2a1c"))
	# 名牌
	var plate := Art.rrect(Rect2(r.position.x + 14, r.end.y - 62, r.size.x - 28, 50), 10, 740 + tier, 0.5)
	Art.dilate(ci, plate, 2.4, Art.INK)
	ci.draw_colored_polygon(plate, Art.HIDE)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position.x + 18, r.end.y - 30, r.size.x - 36, 14), 6, 741, 0.2), Art.HIDE2)
	# 4★ 起四角嵌宝石，5★ 宝石换成红色
	if tier >= 4:
		for c in [r.position + Vector2(10, 10), Vector2(r.end.x - 10, r.position.y + 10)]:
			var gem := Art.poly([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)], 750 + int(c.x), 0.2)
			Art.dilate(ci, gem, 1.6, Art.INK)
			ci.draw_colored_polygon(gem, Art.BERRY if tier == 5 else Art.TEAL)

## 画面窗口的描边（盖在插画上面）
static func _window(ci: CanvasItem, r: Rect2) -> void:
	var win := Art.rrect(r, 10, 760, 0.0)
	var c := win.duplicate()
	c.append(win[0])
	ci.draw_polyline(c, Art.INK, 3.0, true)
	var inner := Art.rrect(r.grow(-3), 8, 761, 0.0)
	var c2 := inner.duplicate()
	c2.append(inner[0])
	ci.draw_polyline(c2, Color(1, 1, 1, 0.35), 1.6, true)

## 还没收集到：洞壁石头，赭石画的问号和手印
static func _locked(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, Color("7d6a58"))
	for i in 9:
		var c := r.position + Vector2(Art.srnd(i * 3 + 1) * r.size.x, Art.srnd(i * 5 + 2) * r.size.y)
		ci.draw_colored_polygon(Art.ell(c, Vector2(18 + Art.srnd(i) * 22, 10 + Art.srnd(i + 9) * 12), 770 + i, 0.2, 10), Color("8c7864") if i % 2 == 0 else Color("6f5d4c"))
	for i in 4:
		var a := r.position + Vector2(Art.srnd(i + 20) * r.size.x, Art.srnd(i + 30) * r.size.y)
		Art.pl(ci, [a, a + Vector2(10, 8), a + Vector2(14, 20), a + Vector2(24, 24)], 1.6, Color("4e4034"), 780 + i)
	# 手印
	var hand := r.position + Vector2(r.size.x * 0.24, r.size.y * 0.78)
	ci.draw_colored_polygon(Art.ell(hand, Vector2(9, 11), 790, 0.1, 12), Color(0.75, 0.33, 0.15, 0.45))
	for k in 4:
		ci.draw_colored_polygon(Art.ell(hand + Vector2(-8 + k * 5.5, -15 - (k % 2) * 2), Vector2(2.4, 6), 791 + k, 0.1, 8), Color(0.75, 0.33, 0.15, 0.45))
	# 问号
	var q := r.get_center() + Vector2(0, -6)
	var path := [q + Vector2(-16, -14), q + Vector2(-12, -28), q + Vector2(4, -32), q + Vector2(17, -22), q + Vector2(14, -8), q + Vector2(2, 0), q + Vector2(0, 14)]
	Art.pl(ci, path, 13.0, Color(0.25, 0.16, 0.1, 0.6), 800)
	Art.pl(ci, path, 9.0, Color("e0913a"), 800)
	ci.draw_circle(q + Vector2(0, 30), 7.5, Color(0.25, 0.16, 0.1, 0.6))
	ci.draw_circle(q + Vector2(0, 30), 5.5, Color("e0913a"))

## 星级横幅：皮条两头剪成燕尾
static func _ribbon(ci: CanvasItem, r: Rect2) -> void:
	var o := r.position
	var w := r.size.x
	var h := r.size.y
	var band := Art.poly([o, o + Vector2(w, 0), o + Vector2(w - 10, h * 0.5), o + Vector2(w, h), o + Vector2(0, h), o + Vector2(10, h * 0.5)], 810, 0.4)
	Art.dilate(ci, band, 2.4, Art.INK)
	ci.draw_colored_polygon(band, Color("5a3a22"))
	ci.draw_colored_polygon(Art.poly([o + Vector2(4, 3), o + Vector2(w - 4, 3), o + Vector2(w - 8, h * 0.4), o + Vector2(8, h * 0.4)], 811, 0.2), Color("6e4a2c"))

## 大图框：粗皮边 + 缝线 + 四角钉（只画边，中间留空给插画）
static func _pic_frame(ci: CanvasItem, r: Rect2, tier: int) -> void:
	var col := tier_col(tier)
	var mid := Art.rrect(r.grow(-12), 26, 820, 0.0, 30)
	var ring := mid.duplicate()
	ring.append(mid[0])
	ci.draw_polyline(ring, Art.INK, 26.0, true)
	ci.draw_polyline(ring, col, 20.0, true)
	ci.draw_polyline(ring, col.lightened(0.45), 1.6, true)
	for c in [r.position + Vector2(14, 14), Vector2(r.end.x - 14, r.position.y + 14), Vector2(r.position.x + 14, r.end.y - 14), r.end - Vector2(14, 14)]:
		ci.draw_circle(c, 8, Art.INK)
		ci.draw_circle(c, 6, Art.FIRE2 if tier >= 4 else Art.BONE2)
