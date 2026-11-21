class_name PACraft
extends PA
## 制作产物（data/crafts.json）的画法。id 是「小类_序号」，比如 fruitplate_3。
## 思路：容器和切开的样子自己画，整个的材料直接用材料本身的图缩小摆进去，一眼能认出是用什么做的。

const WRAP := Color("5f9e34")      # 包东西的大叶子
const PALM := Color("8fbf4a")      # 棕榈叶
const SLAB := Color("b8b1a4")      # 石板
const PLUM_IN := Color("ffe9a8")
const FIG_IN := Color("ef6f86")
const MANGO_IN := Color("ffc23a")
const PAPAYA_IN := Color("ffa45a")
const MELON_IN := Color("f04a5a")
const POME_SEED := Color("e2304e")

## 画一件制作产物。没有画法时画个石头占位，返回 false
static func draw(ci: CanvasItem, id: String, c: Vector2, size: float, rim: bool = true) -> bool:
	var cat := id.get_slice("_", 0)
	var n := int(id.get_slice("_", 1))
	var t := Transform2D(0.0, Vector2.ONE * (size / 100.0), 0.0, c)
	xf = t
	ci.draw_set_transform_matrix(t)
	var s: int = absi(id.hash()) % 97
	var done := true
	match cat:
		"fruitplate": _fruitplate(ci, n, s, rim)
		"ration": _ration(ci, n, s, rim)
		"grill": _grill(ci, n, s, rim)
		"honey": _honey(ci, n, s, rim)
		"stew": _stew(ci, n, s, rim)
		"drink": _drink(ci, n, s, rim)
		"seafood": _seafood(ci, n, s, rim)
		"stonetool": _stonetool(ci, n, s, rim)
		"hunting": _hunting(ci, n, s, rim)
		"light": _light(ci, n, s, rim)
		"fishgear": _fishgear(ci, n, s, rim)
		"weave": _cweave(ci, n, s, rim)
		"furniture": _furniture(ci, n, s, rim)
		"building": _building(ci, n, s, rim)
		"jewelry": _jewelry(ci, n, s, rim)
		"clothes": _clothes(ci, n, s, rim)
		"music": _music(ci, n, s, rim)
		"medicine": _medicine(ci, n, s, rim)
		"ritual": _ritual(ci, n, s, rim)
		_: done = false
	if not done:
		sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)
		ci.draw_string(ThemeDB.fallback_font, Vector2(-8, 10), "?", HORIZONTAL_ALIGNMENT_CENTER, -1, 30, INK)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	xf = Transform2D.IDENTITY
	return done

# ---------------------------------------------------------------- 公共零件

## 把一个材料的图缩小画在 pos（材料图自身坐标 100×100，size 是缩到多大）
static func _m(ci: CanvasItem, id: String, pos: Vector2, size: float, rim: bool = false, rot: float = 0.0) -> void:
	var outer := xf
	var ch := id.get_slice("_", 0)
	var art: Array = ProdArt.CHAIN_ART[ch]
	ProdArt.draw_xf(ci, art[0], art[1], int(id.get_slice("_", 1)), outer * Transform2D(rot, Vector2.ONE * (size / 100.0), 0.0, pos), rim, false)
	xf = outer
	ci.draw_set_transform_matrix(outer)

## 铺在下面的大叶子：一片或几片，带主脉
static func _leafmat(ci: CanvasItem, c: Vector2, w: float, h: float, s: int, rim: bool, col: Color = WRAP) -> void:
	var parts := [ov(c + Vector2(-w * 0.42, 2), w * 0.55, h * 0.75, s + 1, col.darkened(0.12), -0.35, 1),
		ov(c + Vector2(w * 0.42, 2), w * 0.55, h * 0.75, s + 2, col.darkened(0.08), 0.35, 1),
		ov(c, w, h, s, col, 0.0, 1)]
	sil(ci, parts, rim)
	pl(ci, [c + Vector2(-w * 0.9, 0), c + Vector2(w * 0.9, -1)], 1.8, Color(LEAF_D, 0.9), s)
	for k in 4:
		var x := -w * 0.6 + float(k) * w * 0.4
		ln(ci, c + Vector2(x, 0), c + Vector2(x + w * 0.16, -h * 0.55), 1.3, Color(LEAF_D, 0.7), s + k)
		ln(ci, c + Vector2(x, 0), c + Vector2(x + w * 0.16, h * 0.55), 1.3, Color(LEAF_D, 0.7), s + k + 9)

## 棕榈叶垫：一排细长叶片扇开
static func _palmmat(ci: CanvasItem, c: Vector2, w: float, s: int, rim: bool) -> void:
	var parts := []
	for k in 7:
		var a := PI + 0.2 + float(k) * (PI - 0.4) / 6.0
		var d := Vector2(cos(a) * w, sin(a) * w * 0.28 + 10)
		parts.append(ov(c + d * 0.5, w * 0.52, 5.5, s + k, PALM.darkened(0.05 * float(k % 2)), d.angle(), 1))
	sil(ci, parts, rim)
	for k in 7:
		var a := PI + 0.2 + float(k) * (PI - 0.4) / 6.0
		var d := Vector2(cos(a) * w, sin(a) * w * 0.28 + 10)
		ln(ci, c + d * 0.12, c + d * 0.9, 1.2, Color(LEAF_D, 0.8), s + k)

## 木板
static func _board(ci: CanvasItem, c: Vector2, w: float, h: float, s: int, rim: bool) -> void:
	sil(ci, [bx(c.x - w / 2, c.y - h / 2, w, h, 7, s, WOOD)], rim)
	for k in 2:
		pl(ci, [c + Vector2(-w * 0.4, -h * 0.15 + float(k) * h * 0.35), c + Vector2(w * 0.4, -h * 0.2 + float(k) * h * 0.35)], 1.4, WOOD_D, s + 1 + k)

## 平石板
static func _slab(ci: CanvasItem, c: Vector2, w: float, h: float, s: int, rim: bool) -> void:
	sil(ci, [P(poly([c + Vector2(-w * 0.5, -h * 0.2), c + Vector2(-w * 0.3, -h * 0.5), c + Vector2(w * 0.35, -h * 0.45),
		c + Vector2(w * 0.5, 0), c + Vector2(w * 0.3, h * 0.5), c + Vector2(-w * 0.4, h * 0.45)], s, 0.8), SLAB, 1)], rim)

## 陶盘（扁）：外圈 + 内底
static func _clayplate(ci: CanvasItem, c: Vector2, w: float, h: float, s: int, rim: bool) -> void:
	sil(ci, [ov(c + Vector2(0, 3), w, h, s, CLAYPOT.darkened(0.1), 0.0, 1), ov(c, w, h * 0.92, s + 1, CLAYPOT, 0.0, 0)], rim)
	ci.draw_colored_polygon(ell(c + Vector2(0, -1), Vector2(w * 0.76, h * 0.62), s + 2, 0.03, 18), CLAYPOT.lightened(0.18))
	for k in 6:
		var a := float(k) * TAU / 6.0
		ci.draw_circle(c + Vector2(cos(a) * w * 0.88, sin(a) * h * 0.8), 1.4, Color(INK, 0.55))

## 碗的后半（内壁），先画；内容摆完再画 _bowl_front
static func _bowl_back(ci: CanvasItem, c: Vector2, w: float, col: Color, s: int) -> void:
	ci.draw_colored_polygon(ell(c, Vector2(w, w * 0.3), s, 0.02, 20), col.darkened(0.35))

static func _bowl_front(ci: CanvasItem, c: Vector2, w: float, h: float, col: Color, s: int, rim: bool, lip: Color = Color.TRANSPARENT) -> void:
	var body: Array = []
	for k in 17:
		var a := float(k) * PI / 16.0
		body.append(c + Vector2(cos(a) * w * (1.0 - 0.14 * sin(a) * sin(a)), sin(a) * h))
	sil(ci, [P(poly(body, s, 0.5), col, 1)], rim)
	var front: Array = []
	for k in 13:
		var a := float(k) * PI / 12.0
		front.append(c + Vector2(cos(a) * w * 0.97, sin(a) * w * 0.22))
	var lc := lip if lip.a > 0.0 else col.lightened(0.15)
	ci.draw_polyline(PackedVector2Array(front), INK, 7.0, true)
	ci.draw_polyline(PackedVector2Array(front), lc, 3.6, true)
	pl(ci, [c + Vector2(-w * 0.72, h * 0.55), c + Vector2(w * 0.72, h * 0.55)], 1.6, col.darkened(0.3), s + 2)

## 一片楔形切块：外圈是皮，里面是瓤。a 是朝向，span 是张角
static func _wedge(ci: CanvasItem, c: Vector2, r: float, a: float, span: float, skin: Color, flesh: Color, s: int, rim: bool, rind: float = 0.16) -> void:
	var outer := [c]
	var inner := [c]
	for k in 9:
		var t := a - span / 2.0 + span * float(k) / 8.0
		outer.append(c + Vector2(cos(t), sin(t)) * r)
		inner.append(c + Vector2(cos(t), sin(t)) * r * (1.0 - rind))
	sil(ci, [P(poly(outer, s, 0.4), skin, 1), P(poly(inner, s + 1, 0.3), flesh, 0)], rim)

## 对半切开的圆果：皮一圈，瓤，中间籽
static func _half(ci: CanvasItem, c: Vector2, rx: float, ry: float, rot: float, skin: Color, flesh: Color, s: int, rim: bool) -> void:
	sil(ci, [ov(c, rx, ry, s, skin, rot, 1), ov(c, rx * 0.8, ry * 0.8, s + 1, flesh, rot, 0)], rim)

static func _seeds(ci: CanvasItem, c: Vector2, rx: float, ry: float, n: int, r: float, col: Color, s: int) -> void:
	for k in n:
		var a := float(k) * 2.4 + float(s % 7)
		var d := sqrt(float(k + 1) / float(n))
		ci.draw_circle(c + Vector2(cos(a) * rx * d, sin(a) * ry * d), r, col)

## 系绳：几道草绳绕过去
static func _tie(ci: CanvasItem, a: Vector2, b: Vector2, s: int, col: Color = GRASS) -> void:
	sil(ci, [stk(a, b, 2.6, s, col)], false)
	sil(ci, [stk(a + Vector2(0, 4), b + Vector2(0, 4), 2.2, s + 1, col.darkened(0.1))], false)

# ---------------------------------------------------------------- 鲜果拼盘

static func _fruitplate(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 野莓叶包：大叶子卷成兜，草茎扎口，野莓从口里冒出来
			_m(ci, "fruit_1", Vector2(-13, -28), 58, rim, -0.2)
			_m(ci, "fruit_1", Vector2(13, -30), 56, rim, 0.3)
			_m(ci, "fruit_1", Vector2(0, -20), 54, rim)
			var pouch := [Vector2(-30, -4), Vector2(-14, 0), Vector2(0, -2), Vector2(16, 0), Vector2(30, -6),
				Vector2(26, 12), Vector2(14, 28), Vector2(2, 36), Vector2(-12, 30), Vector2(-24, 14)]
			sil(ci, [pg(pouch, s, WRAP), pg([Vector2(-30, -4), Vector2(-14, 0), Vector2(-2, 34), Vector2(-12, 30), Vector2(-24, 14)], s + 1, WRAP.darkened(0.15), 1)], rim)
			pl(ci, [Vector2(-14, 0), Vector2(-2, 32)], 1.6, Color(LEAF_D, 0.9), s)
			sil(ci, [stk(Vector2(-25, 8), Vector2(26, 5), 2.8, s + 2, GRASS), stk(Vector2(18, 6), Vector2(30, 18), 2.0, s + 3, GRASS),
				stk(Vector2(18, 6), Vector2(34, 6), 2.0, s + 4, GRASS_D)], false)
		2:  # 樱桃串：一根草茎上系一串樱桃
			sil(ci, [stk(Vector2(-36, -30), Vector2(36, -26), 2.6, s, GRASS)], rim)
			_m(ci, "fruit_2", Vector2(-22, 4), 54, rim)
			_m(ci, "fruit_2", Vector2(2, 8), 56, rim, 0.15)
			_m(ci, "fruit_2", Vector2(24, 2), 52, rim, -0.2)
			for x in [-22.0, 4.0, 26.0]:
				sil(ci, [stk(Vector2(x, -27), Vector2(x - 2, -18), 1.8, s + int(x), GRASS_D)], false)
		3:  # 双莓拼：叶子上一边野莓一边蓝莓
			_leafmat(ci, Vector2(0, 22), 38, 14, s, rim)
			_m(ci, "fruit_1", Vector2(-16, 0), 56, false)
			_m(ci, "fruit_3", Vector2(16, -2), 58, false)
		4:  # 野李切块：石板上一个整李、半个带核的李子和两瓣，旁边一片尖石片
			_slab(ci, Vector2(0, 22), 88, 30, s, rim)
			_m(ci, "fruit_4", Vector2(-18, -10), 52, false)
			_m(ci, "tool_2", Vector2(30, 4), 44, false, 0.5)
			sil(ci, [ov(Vector2(6, 10), 17, 15, s + 3, PAFood.PLUM, 0.1, 1), ov(Vector2(6, 10), 14, 12, s + 4, PLUM_IN, 0.1, 0)], false)
			ci.draw_colored_polygon(ell(Vector2(6, 10), Vector2(5, 6.5), s + 5, 0.05, 12, 0.1), SEED)
			_wedge(ci, Vector2(-30, 30), 16, -PI / 2.0 + 0.5, 1.0, PAFood.PLUM, PLUM_IN, s + 5, false, 0.18)
			_wedge(ci, Vector2(-10, 34), 16, -PI / 2.0 + 0.2, 1.0, PAFood.PLUM, PLUM_IN, s + 7, false, 0.18)
		5:  # 无花果对半：两半无花果，粉红瓤，满是小籽
			_leafmat(ci, Vector2(0, 24), 38, 12, s, rim)
			_m(ci, "tool_2", Vector2(28, 8), 40, false, -0.4)
			for k in 2:
				var c := Vector2(-16 + float(k) * 24, 6 - float(k) * 4)
				var r := 0.15 if k == 0 else -0.25
				sil(ci, [ov(c, 15, 19, s + k, PAFood.FIG, r, 1), ov(c + Vector2(0, 1), 12, 15.5, s + 3 + k, FIG_IN, r, 0),
					stk(c + Vector2(0, -18), c + Vector2(1, -25), 2.4, s + 6 + k, WOOD_D, 2)], false)
				ci.draw_colored_polygon(ell(c + Vector2(0, 2), Vector2(5, 8), s + 8 + k, 0.08, 12, r), Color("f7d9a0"))
				_seeds(ci, c + Vector2(0, 1), 9, 12, 14, 1.1, Color(INK, 0.7), s + k)
		6:  # 樱桃野李拼
			_leafmat(ci, Vector2(0, 22), 38, 14, s, rim)
			_m(ci, "fruit_4", Vector2(-12, -4), 62, false)
			_m(ci, "fruit_2", Vector2(18, -2), 56, false, 0.2)
		7:  # 苹果梨拼盘：木板上一苹果一梨，再切一块苹果
			_board(ci, Vector2(0, 26), 82, 20, s, rim)
			_m(ci, "fruit_7", Vector2(14, -8), 62, false)
			_m(ci, "fruit_6", Vector2(-14, -2), 62, false)
			_wedge(ci, Vector2(-2, 22), 12, -PI / 2.0, 1.3, PAFood.APPLE, Color("fff1c8"), s + 5, false, 0.12)
		8:  # 棕榈叶果盘
			_palmmat(ci, Vector2(0, 30), 46, s, rim)
			_m(ci, "fruit_6", Vector2(-12, -4), 60, false)
			_m(ci, "fruit_4", Vector2(16, 0), 54, false)
		9:  # 葡萄串：麻秆横挑，下面挂两串葡萄
			sil(ci, [stk(Vector2(-40, -28), Vector2(40, -34), 3.0, s, Color("c9a86a"))], rim)
			for k in 2:
				var x := -14.0 + float(k) * 28.0
				sil(ci, [stk(Vector2(x, -30 - float(k) * 3), Vector2(x, -18), 1.6, s + k, GRASS_D)], false)
				_m(ci, "fruit_9", Vector2(x, 6), 64, rim, 0.1 - 0.2 * float(k))
		10:  # 芒果船：半个芒果切成格子翻开，旁边半月石刀
			_m(ci, "tool_4", Vector2(26, 16), 60, rim, 0.3)
			var c := Vector2(-8, 6)
			sil(ci, [ov(c + Vector2(0, 6), 30, 20, s, Color("8fb83a"), -0.15, 1), ov(c, 27, 17, s + 1, MANGO_IN, -0.15, 0)], rim)
			for i in 4:
				for j in 3:
					var p := c + Vector2(-16 + float(i) * 11, -9 + float(j) * 9).rotated(-0.15)
					sil(ci, [P(rrect(Rect2(p.x - 4.5, p.y - 4.5, 9, 9), 2.5, s + i * 3 + j, 0.4), MANGO_IN.lightened(0.08 * float((i + j) % 2)), 0)], false)
		11:  # 木瓜盅：木瓜对剖掏空，装满蓝莓
			_m(ci, "tool_4", Vector2(28, 20), 40, false, -0.3)
			var c := Vector2(-4, 10)
			sil(ci, [ov(c, 36, 20, s, PAFood.PAPAYA.darkened(0.05), -0.08, 1), ov(c + Vector2(0, -3), 30, 14, s + 1, PAPAYA_IN, -0.08, 0)], rim)
			ci.draw_colored_polygon(ell(c + Vector2(0, -4), Vector2(18, 7), s + 2, 0.06, 16, -0.08), PAPAYA_IN.darkened(0.25))
			_m(ci, "fruit_3", Vector2(-2, -12), 50, false)
		12:  # 椰子壳果碗：半个椰壳当碗，里头放无花果
			var c := Vector2(0, 6)
			_bowl_back(ci, c, 32, PAFood.COCO, s)
			_m(ci, "fruit_5", Vector2(-11, -22), 54, false, -0.2)
			_m(ci, "fruit_5", Vector2(11, -20), 54, false, 0.25)
			_bowl_front(ci, c, 32, 30, PAFood.COCO, s + 1, rim)
			sil(ci, [stk(c + Vector2(-30, 1), c + Vector2(30, 1), 2.6, s + 4, BONE, 0)], false)
			for k in 7:
				ln(ci, c + Vector2(-22 + float(k) * 7, 10 + float(k % 2) * 6), c + Vector2(-19 + float(k) * 7, 16 + float(k % 2) * 6), 1.3, Color(INK, 0.45), s + k)
		13:  # 西瓜大块：石板上两大块西瓜，长石刃搁旁边
			_slab(ci, Vector2(0, 26), 90, 24, s, rim)
			_m(ci, "tool_5", Vector2(28, 16), 52, false, -0.3)
			for k in 2:
				var c := Vector2(-20 + float(k) * 26, -18 + float(k) * 6)
				var ang := PI / 2.0 + (0.15 if k == 0 else -0.1)
				_wedge(ci, c, 38, ang, 1.3, PAFood.MELON, MELON_IN, s + k * 4, false, 0.15)
				var w2 := []
				for j in 9:
					var tt := ang - 0.65 + 1.3 * float(j) / 8.0
					w2.append(c + Vector2(cos(tt), sin(tt)) * 31)
				ci.draw_polyline(PackedVector2Array(w2), Color("f3f0d0"), 2.4, true)
				for j in 4:
					var tt := ang - 0.4 + float(j) * 0.27
					ci.draw_colored_polygon(ell(c + Vector2(cos(tt), sin(tt)) * 20, Vector2(1.6, 2.6), s + j, 0.0, 8, tt), INK)
		14:  # 五果拼盘：大叶子铺底，樱桃、无花果、梨、葡萄
			_leafmat(ci, Vector2(0, 24), 44, 15, s, rim)
			_m(ci, "fruit_9", Vector2(-20, -8), 52, false, -0.15)
			_m(ci, "fruit_7", Vector2(18, -10), 54, false)
			_m(ci, "fruit_5", Vector2(-4, 4), 46, false)
			_m(ci, "fruit_2", Vector2(20, 10), 44, false, 0.2)
		15:  # 石榴籽碗：陶碗里堆满石榴籽，碗边靠着半个石榴
			var c := Vector2(-4, 8)
			_bowl_back(ci, c, 30, CLAYPOT, s)
			var seeds := []
			for k in 16:
				var a := float(k) * 2.4
				var d := sqrt(float(k + 1) / 16.0)
				seeds.append(circ(c + Vector2(cos(a) * 24 * d, -8 + sin(a) * 5 * d - (1.0 - d) * 16), 5.2, s + k, POME_SEED.lightened(0.08 * float(k % 3)), 0))
			sil(ci, seeds, false, 2.0)
			for k in 16:
				var a := float(k) * 2.4
				var d := sqrt(float(k + 1) / 16.0)
				ci.draw_circle(c + Vector2(cos(a) * 24 * d - 1.5, -10 + sin(a) * 5 * d - (1.0 - d) * 16), 1.4, Color(1, 1, 1, 0.75))
			_bowl_front(ci, c, 30, 26, CLAYPOT, s + 1, rim)
			_half(ci, Vector2(28, 22), 13, 14, 0.3, PAFood.POME, Color("fbe0c8"), s + 20, rim)
			_seeds(ci, Vector2(28, 22), 8, 9, 9, 2.2, POME_SEED, s + 21)
		16:  # 鲜果陶盘：陶盘上苹果和石榴
			_clayplate(ci, Vector2(0, 22), 42, 16, s, rim)
			_m(ci, "fruit_8", Vector2(14, -6), 60, false)
			_m(ci, "fruit_6", Vector2(-14, -2), 60, false)
		17:  # 菠萝蜜大拼盘：大木盘，后面一个菠萝蜜，前面芒果和石榴
			_board(ci, Vector2(0, 28), 90, 18, s, rim)
			_m(ci, "fruit_14", Vector2(0, -14), 70, false)
			_m(ci, "fruit_10", Vector2(-24, 4), 50, false, -0.3)
			_m(ci, "fruit_8", Vector2(24, 6), 48, false)
		18:  # 部落果宴：棕榈叶捆铺开，椰子、西瓜块、菠萝蜜堆成小山
			_palmmat(ci, Vector2(0, 32), 52, s, rim)
			_m(ci, "fruit_14", Vector2(0, -18), 62, false)
			_m(ci, "fruit_12", Vector2(-24, -2), 52, false)
			_wedge(ci, Vector2(26, -8), 26, PI / 2.0 - 0.2, 1.3, PAFood.MELON, MELON_IN, s + 5, false, 0.15)
			sparks(ci, [Vector2(-40, -36), Vector2(40, -30)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 熟肉、干粮、蜂蜜的零件

const CRUST := Color("a8521f")     # 烤得焦黄的肉皮
const CRUST_L := Color("d07a34")
const JERKY := Color("8a3a22")
const DOUGH := Color("e0b46a")     # 粉饼
const DOUGH_D := Color("b9843e")
const HONEY := Color("f5a81c")
const HONEY_L := Color("ffd45a")

## 烤鸡腿形：一头肉一头骨
static func _drum(ci: CanvasItem, c: Vector2, l: float, ang: float, sz: float, s: int, rim: bool, col: Color = CRUST) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	var e := c + d * l
	sil(ci, [stk(c + d * l * 0.3, e, maxf(sz * 0.16, 2.2), s, BONE, 0),
		circ(e + d * sz * 0.1 + n * sz * 0.16, sz * 0.17, s + 1, BONE), circ(e + d * sz * 0.1 - n * sz * 0.16, sz * 0.17, s + 2, BONE),
		ov(c + d * l * 0.05, l * 0.48, sz * 0.5, s + 3, col, ang, 1)], rim)
	hl(ci, c - n * sz * 0.2 - d * l * 0.05, l * 0.2, sz * 0.12, ang, 0.45)

## 整只烤禽：圆滚的身子，两只腿翘起
static func _roastbird(ci: CanvasItem, c: Vector2, sz: float, s: int, rim: bool, col: Color = CRUST) -> void:
	_drum(ci, c + Vector2(-sz * 0.45, -sz * 0.1), sz * 0.7, -2.3, sz * 0.5, s, rim, col)
	_drum(ci, c + Vector2(sz * 0.45, -sz * 0.1), sz * 0.7, -0.84, sz * 0.5, s + 5, rim, col)
	sil(ci, [ov(c, sz, sz * 0.66, s + 9, col, 0.0, 1)], rim)
	hl(ci, c + Vector2(-sz * 0.3, -sz * 0.3), sz * 0.35, sz * 0.14, -0.3, 0.45)
	pl(ci, [c + Vector2(-sz * 0.2, sz * 0.15), c + Vector2(0, sz * 0.35), c + Vector2(sz * 0.2, sz * 0.15)], 1.6, Color(INK, 0.4), s)

## 一块烤肉：圆角块，带烤痕
static func _chunk(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool, col: Color = CRUST, rot: float = 0.0) -> void:
	sil(ci, [P(_rrect_rot(c, r * 2.0, r * 1.6, r * 0.45, rot, s), col, 1)], rim)
	for k in 2:
		var o := Vector2(-r * 0.35 + float(k) * r * 0.7, 0).rotated(rot)
		ln(ci, c + o + Vector2(-r * 0.2, -r * 0.45).rotated(rot), c + o + Vector2(r * 0.2, r * 0.45).rotated(rot), 2.0, CHAR, s + k)

static func _rrect_rot(c: Vector2, w: float, h: float, rad: float, rot: float, s: int) -> PackedVector2Array:
	var pts := rrect(Rect2(-w / 2, -h / 2, w, h), rad, s, 0.6)
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p.rotated(rot))
	return out

## 一根签子穿几块肉
static func _skewer(ci: CanvasItem, a: Vector2, b: Vector2, ts: Array, r: float, s: int, rim: bool, col: Color = CRUST) -> void:
	sil(ci, [stk(a, b, 2.4, s, WOOD_D)], rim)
	var rot := (b - a).angle()
	for k in ts.size():
		_chunk(ci, a.lerp(b, float(ts[k])), r, s + 3 * k, rim, col.lightened(0.06 * float(k % 2)), rot)

## 一扇肋排
static func _ribs(ci: CanvasItem, c: Vector2, w: float, h: float, s: int, rim: bool) -> void:
	var parts := []
	for k in 4:
		var x := c.x - w * 0.36 + float(k) * w * 0.24
		parts.append(stk(Vector2(x, c.y - h * 0.2), Vector2(x - 4, c.y - h * 0.85), 3.2, s + k, BONE, 0))
	parts.append(ov(c, w * 0.55, h * 0.45, s + 9, CRUST, -0.05, 1))
	sil(ci, parts, rim)
	for k in 3:
		ln(ci, c + Vector2(-w * 0.3 + float(k) * w * 0.25, -h * 0.2), c + Vector2(-w * 0.2 + float(k) * w * 0.25, h * 0.25), 2.0, CHAR, s + k)
	hl(ci, c + Vector2(-w * 0.2, -h * 0.18), w * 0.16, h * 0.08, -0.1, 0.4)

## 熏肉条
static func _strip(ci: CanvasItem, top: Vector2, l: float, s: int, rim: bool) -> void:
	var pts := []
	for k in 5:
		pts.append(top + Vector2(sin(float(k) * 1.4 + float(s)) * 2.0 - 4.0, float(k) * l / 4.0))
	for k in 5:
		pts.append(top + Vector2(sin(float(4 - k) * 1.4 + float(s)) * 2.0 + 4.0, float(4 - k) * l / 4.0))
	sil(ci, [pg(pts, s, JERKY)], rim)
	ln(ci, top + Vector2(-1, l * 0.2), top + Vector2(-1, l * 0.8), 1.4, Color(FAT, 0.8), s)

const FAT := Color("f3d3a0")

## 小火堆：两根柴加火苗
static func _fire(ci: CanvasItem, c: Vector2, w: float, s: int, rim: bool) -> void:
	sil(ci, [stk(c + Vector2(-w, 4), c + Vector2(w, -2), 4.0, s, WOOD_D), stk(c + Vector2(-w, -2), c + Vector2(w, 4), 4.0, s + 1, WOOD)], rim)
	flame(ci, c + Vector2(0, -w * 0.5), w * 0.8, w * 1.1, s + 2)

## 两根叉棍架一根横杆
static func _spit(ci: CanvasItem, y: float, w: float, h: float, s: int, rim: bool) -> void:
	for k in 2:
		var x := -w if k == 0 else w
		sil(ci, [stk(Vector2(x, y + h), Vector2(x, y), 3.0, s + k, WOOD_D), stk(Vector2(x, y + 4), Vector2(x - 6, y - 6), 2.4, s + k + 2, WOOD_D),
			stk(Vector2(x, y + 4), Vector2(x + 6, y - 6), 2.4, s + k + 4, WOOD_D)], rim)

## 一小块蜂蜜：亮黄、有高光
static func _honey_blob(ci: CanvasItem, c: Vector2, rx: float, ry: float, s: int, rim: bool) -> void:
	sil(ci, [ov(c, rx, ry, s, HONEY, 0.0, 1)], rim)
	hl(ci, c + Vector2(-rx * 0.35, -ry * 0.35), rx * 0.3, ry * 0.18, -0.3, 0.6)

## 浇在东西上面的蜂蜜：一条波浪，往下挂几滴
static func _drizzle(ci: CanvasItem, c: Vector2, w: float, s: int) -> void:
	var top := []
	for k in 9:
		var t := float(k) / 8.0
		top.append(c + Vector2(-w + 2.0 * w * t, sin(t * 9.0 + float(s)) * 2.5))
	var line := PackedVector2Array(top)
	ci.draw_polyline(line, INK, 8.0, true)
	ci.draw_polyline(line, HONEY, 5.0, true)
	for k in 3:
		var p: Vector2 = top[2 + k * 2]
		var dr := ell(p + Vector2(0, 6), Vector2(3.2, 5.0), s + k, 0.0, 12)
		ci.draw_colored_polygon(ell(p + Vector2(0, 6), Vector2(4.6, 6.4), s + k, 0.0, 12), INK)
		ci.draw_colored_polygon(dr, HONEY)
	ci.draw_polyline(line, HONEY_L, 1.6, true)

## 蜂蜜水洼：铺在底下的亮黄一摊
static func _honey_pool(ci: CanvasItem, c: Vector2, rx: float, ry: float, s: int, rim: bool) -> void:
	sil(ci, [ov(c, rx, ry, s, HONEY, 0.0, 0, 0.08)], rim)
	hl(ci, c + Vector2(-rx * 0.4, -ry * 0.25), rx * 0.25, ry * 0.2, -0.1, 0.55)

## 扁圆饼：侧面一圈深色，上面浅色
static func _cake(ci: CanvasItem, c: Vector2, rx: float, ry: float, th: float, s: int, rim: bool, col: Color = DOUGH) -> void:
	sil(ci, [ov(c + Vector2(0, th), rx, ry, s, col.darkened(0.2), 0.0, 1), P(rrect(Rect2(c.x - rx, c.y, rx * 2.0, th), 1.0, s + 1, 0.3), col.darkened(0.2), 1),
		ov(c, rx, ry, s + 2, col, 0.0, 0)], rim)
	for k in 5:
		var a := float(k) * 2.4 + float(s)
		ci.draw_circle(c + Vector2(cos(a) * rx * 0.55, sin(a) * ry * 0.5), 1.4, Color(DOUGH_D, 0.9))

## 皮口袋：圆底，收口扎绳；open 时口敞开
static func _bag(ci: CanvasItem, c: Vector2, w: float, h: float, col: Color, s: int, rim: bool) -> void:
	var pts := [c + Vector2(-w * 0.35, -h * 0.5), c + Vector2(w * 0.35, -h * 0.5), c + Vector2(w * 0.2, -h * 0.3),
		c + Vector2(w * 0.55, -h * 0.05), c + Vector2(w * 0.5, h * 0.35), c + Vector2(0, h * 0.5),
		c + Vector2(-w * 0.5, h * 0.35), c + Vector2(-w * 0.55, -h * 0.05), c + Vector2(-w * 0.2, -h * 0.3)]
	sil(ci, [pg(pts, s, col)], rim)
	sil(ci, [stk(c + Vector2(-w * 0.24, -h * 0.3), c + Vector2(w * 0.24, -h * 0.3), 2.6, s + 1, ROPE)], false)
	sil(ci, [stk(c + Vector2(w * 0.2, -h * 0.3), c + Vector2(w * 0.34, -h * 0.12), 2.0, s + 2, ROPE)], false)
	hl(ci, c + Vector2(-w * 0.25, h * 0.05), w * 0.12, h * 0.16, 0.3, 0.3)

## 敞口的袋子：后沿先画，内容摆进去，再画前面
static func _sack_back(ci: CanvasItem, c: Vector2, w: float, col: Color, s: int) -> void:
	ci.draw_colored_polygon(ell(c, Vector2(w, w * 0.32), s, 0.05, 16), col.darkened(0.4))

static func _sack_front(ci: CanvasItem, c: Vector2, w: float, h: float, col: Color, s: int, rim: bool) -> void:
	var pts := [c + Vector2(w, 0), c + Vector2(w * 1.12, h * 0.55), c + Vector2(w * 0.7, h), c + Vector2(-w * 0.7, h), c + Vector2(-w * 1.12, h * 0.55), c + Vector2(-w, 0)]
	for k in 7:
		var a := PI - float(k + 1) * PI / 8.0
		pts.append(c + Vector2(cos(a) * w, sin(a) * w * 0.32))
	sil(ci, [pg(pts, s, col)], rim)
	pl(ci, [c + Vector2(-w * 0.8, w * 0.32 + 4), c + Vector2(0, w * 0.4 + 6), c + Vector2(w * 0.8, w * 0.32 + 4)], 1.6, Color(INK, 0.4), s)

## 草窝：一圈乱草
static func _nest(ci: CanvasItem, c: Vector2, w: float, s: int, rim: bool) -> void:
	sil(ci, [ov(c, w, w * 0.36, s, GRASS, 0.0, 1)], rim)
	for k in 9:
		var x := -w * 0.85 + float(k) * w * 0.21
		ln(ci, c + Vector2(x, -w * 0.15 + float(k % 2) * 4), c + Vector2(x + 8, w * 0.2 - float(k % 3) * 2), 1.4, GRASS_D, s + k)

# ---------------------------------------------------------------- 干粮点心

static func _ration(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 松子小把：一把草围成窝，里面一堆松子
			_nest(ci, Vector2(0, 20), 36, s, rim)
			_m(ci, "seed_1", Vector2(-14, -6), 66, false, -0.2)
			_m(ci, "seed_1", Vector2(14, -4), 66, false, 0.3)
			_m(ci, "seed_1", Vector2(0, -18), 62, false)
		2:  # 榛子果仁：石片上敲开的榛子，壳一边仁一边
			_slab(ci, Vector2(0, 24), 80, 24, s, rim)
			_m(ci, "seed_2", Vector2(-16, -6), 60, false)
			_m(ci, "tool_1", Vector2(24, 4), 50, false, 0.4)
			for k in 3:
				sil(ci, [ov(Vector2(4 + float(k) * 9, 20 - float(k % 2) * 5), 5.5, 4.2, s + k, Color("f3dcae"), 0.3 * float(k), 1)], false)
			sil(ci, [P(_arc_band(Vector2(-24, 24), 7, 3, PI, TAU, s + 6), SEED, 1)], false)
		3:  # 橡果粉饼：石板上一张粗粉饼，撒着粉，旁边两颗橡果
			_slab(ci, Vector2(0, 24), 86, 26, s, rim)
			_cake(ci, Vector2(-6, 10), 26, 12, 6, s, false)
			_m(ci, "seed_3", Vector2(26, 0), 46, false, 0.3)
			for k in 7:
				ci.draw_circle(Vector2(-30 + float(k) * 9, 30 + float(k % 2) * 3), 1.6, Color(1, 1, 1, 0.7))
		4:  # 杏仁果干：叶子上杏仁和切片晒干的无花果
			_leafmat(ci, Vector2(0, 24), 38, 13, s, rim)
			for k in 3:
				var c := Vector2(10 + float(k) * 9, 10 - float(k) * 6)
				sil(ci, [ov(c, 9, 8, s + k, PAFood.FIG.darkened(0.15), 0.2, 1), ov(c, 6.5, 5.5, s + k + 3, Color("c46a6a"), 0.2, 0)], false)
				_seeds(ci, c, 4, 3.5, 5, 0.9, Color(INK, 0.6), s + k)
			_m(ci, "seed_4", Vector2(-16, 0), 54, false, -0.3)
		5:  # 坚果小饼：石板上三块小饼，镶着坚果
			_slab(ci, Vector2(0, 26), 84, 22, s, rim)
			for k in 3:
				var c := Vector2(-22 + float(k) * 22, 14 - float(k % 2) * 8)
				_cake(ci, c, 13, 6, 5, s + k * 4, false)
				sil(ci, [ov(c + Vector2(-3, -1), 3.5, 2.6, s + k, SEED, 0.4, 1), ov(c + Vector2(4, 1), 3.5, 2.4, s + k + 1, Color("e8c48a"), -0.4, 1)], false)
			_m(ci, "seed_2", Vector2(-26, -12), 40, false)
			_m(ci, "seed_4", Vector2(26, -14), 40, false, 0.4)
		6:  # 开心果袋：碎皮缝的小口袋，敞着口，开心果冒出来
			var c := Vector2(0, 2)
			_sack_back(ci, c, 24, LEATHER, s)
			_m(ci, "seed_5", Vector2(-8, -12), 48, false)
			_m(ci, "seed_5", Vector2(9, -10), 46, false, 0.4)
			_sack_front(ci, c, 24, 34, LEATHER, s + 1, rim)
			for k in 3:
				ln(ci, c + Vector2(-14 + float(k) * 14, 14), c + Vector2(-12 + float(k) * 14, 26), 1.4, Color(HIDE, 0.8), s + k)
		7:  # 腰果果干串：一根麻绳串着腰果和梨干片
			sil(ci, [stk(Vector2(-38, -30), Vector2(36, 28), 2.2, s, Color("c9a86a"))], rim)
			for k in 5:
				var p := Vector2(-38, -30).lerp(Vector2(36, 28), 0.12 + float(k) * 0.19)
				if k % 2 == 0:
					_m(ci, "seed_6", p, 36, false, 0.6)
				else:
					sil(ci, [ov(p, 10, 8, s + k, PAFood.PEAR.darkened(0.2), 0.7, 1), ov(p, 7, 5.5, s + k + 1, Color("f1e6a8"), 0.7, 0)], false)
					ci.draw_circle(p, 1.6, SEED)
		8:  # 板栗干粮：干草捆上堆着板栗
			_m(ci, "cloth_3", Vector2(0, 14), 82, rim)
			_m(ci, "seed_7", Vector2(-12, -14), 50, false)
			_m(ci, "seed_7", Vector2(12, -12), 50, false, 0.3)
		9:  # 核桃仁饼：两块石板一上一下夹烤，上面揭开，一张核桃饼
			_slab(ci, Vector2(0, 26), 88, 22, s, rim)
			_cake(ci, Vector2(-4, 12), 28, 11, 6, s + 1, false, DOUGH.darkened(0.08))
			for k in 4:
				sil(ci, [ov(Vector2(-16 + float(k) * 9, 10 + float(k % 2) * 3), 4, 3, s + k, Color("c99a5a"), 0.0, 1)], false)
			_m(ci, "tool_9", Vector2(24, -14), 46, false, 0.5)
			_m(ci, "seed_8", Vector2(-26, -12), 42, false)
		10:  # 果仁糊：陶碗里一碗糊，上面杏仁和苹果片
			var c := Vector2(0, 6)
			_bowl_back(ci, c, 32, CLAYPOT, s)
			sil(ci, [ov(c + Vector2(0, -2), 28, 8, s + 3, Color("e9cf9a"), 0.0, 0)], false)
			_bowl_front(ci, c, 32, 28, CLAYPOT, s + 1, rim)
			_m(ci, "seed_4", Vector2(-12, -14), 50, false, -0.5)
			_m(ci, "fruit_6", Vector2(12, -14), 44, false)
		11:  # 澳洲坚果酥：几块金黄的酥块，夹着蜂巢，坚果在旁边
			_board(ci, Vector2(0, 28), 80, 16, s, rim)
			for k in 3:
				var c := Vector2(-22 + float(k) * 20, 12 - float(k % 2) * 6)
				sil(ci, [bx(c.x - 10, c.y - 8, 20, 16, 4, s + k, Color("f0c25a"))], false)
				for j in 3:
					ci.draw_circle(c + Vector2(-5 + float(j) * 5, -2 + float(j % 2) * 4), 1.8, Color("fff0c0"))
			_m(ci, "craft_10", Vector2(22, -10), 46, false)
			_m(ci, "seed_9", Vector2(-20, -12), 42, false)
		12:  # 巴西栗干粮包：兽皮包成方包，绳子十字扎，旁边一个果荚
			sil(ci, [P(rrect(Rect2(-30, -10, 54, 42), 12, s, 0.8), Color("c99a62"), 1)], rim)
			sil(ci, [stk(Vector2(-30, 10), Vector2(24, 10), 2.6, s + 1, ROPE), stk(Vector2(-4, -10), Vector2(-4, 32), 2.6, s + 2, ROPE)], false)
			sil(ci, [ov(Vector2(-4, 10), 4.5, 4.5, s + 3, ROPE, 0.0, 1)], false)
			_m(ci, "seed_10", Vector2(26, 8), 50, false, 0.2)
		13:  # 黑胡桃糕：一摞石板当台，上面两层糕，顶上石榴籽
			for k in 3:
				_slab(ci, Vector2(0, 32 - float(k) * 8), 70 - float(k) * 6, 18, s + 20 + k, rim)
			_cake(ci, Vector2(0, -4), 26, 10, 7, s, false, Color("8a5a3a"))
			_cake(ci, Vector2(0, -15), 20, 8, 6, s + 1, false, Color("a06a42"))
			for k in 6:
				var a := float(k) * 1.05
				sil(ci, [circ(Vector2(cos(a) * 10, -15 + sin(a) * 3.5), 2.6, s + k, POME_SEED)], false, 1.6)
		14:  # 海椰子大饼：一张大饼搁在石板摞上，核桃仁镶边，海椰子在后
			_m(ci, "seed_12", Vector2(18, -18), 54, rim)
			for k in 3:
				_slab(ci, Vector2(0, 34 - float(k) * 8), 80 - float(k) * 6, 18, s + 20 + k, rim)
			_cake(ci, Vector2(-4, 4), 34, 13, 7, s, false)
			for k in 7:
				var a := float(k) * TAU / 7.0
				sil(ci, [ov(Vector2(-4 + cos(a) * 22, 4 + sin(a) * 7), 4, 3, s + k, Color("c99a5a"), 0.0, 1)], false, 1.6)
		15:  # 行猎干粮袋：兽皮背袋，带背带，口里露葡萄和板栗
			sil(ci, [P(_arc_band(Vector2(0, -2), 30, 3.5, PI + 0.3, TAU - 0.3, s), LEATHER_D, 1)], rim)
			var c := Vector2(0, 0)
			_sack_back(ci, c, 26, Color("c99a62"), s)
			_m(ci, "fruit_9", Vector2(-8, -14), 44, false, -0.2)
			_m(ci, "seed_7", Vector2(10, -8), 40, false)
			_sack_front(ci, c, 26, 36, Color("c99a62"), s + 1, rim)
			sil(ci, [ov(Vector2(0, 20), 6, 6, s + 4, BONE, 0.0, 1)], false)
		16:  # 坚果果干拼：木板上开心果、腰果和芒果干条
			_board(ci, Vector2(0, 28), 84, 16, s, rim)
			_m(ci, "seed_5", Vector2(-22, 4), 44, false)
			_m(ci, "seed_6", Vector2(0, 6), 42, false, 0.3)
			for k in 3:
				sil(ci, [stk(Vector2(12 + float(k) * 7, 16), Vector2(18 + float(k) * 7, -4), 3.6, s + k, Color("f0a52c"))], false)
		17:  # 远行干粮：两个鼓鼓的兽皮包，捆在一起，挂一个椰子
			_bag(ci, Vector2(-14, 8), 40, 52, Color("b98a5a"), s, rim)
			_bag(ci, Vector2(16, 12), 36, 44, Color("c99a62"), s + 3, rim)
			_m(ci, "fruit_12", Vector2(24, -16), 40, false)
			_m(ci, "seed_9", Vector2(-28, 26), 34, false)
			sparks(ci, [Vector2(-38, -34), Vector2(40, -36)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 烤肉

static func _grill(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 烤麻雀串：一根小树枝串两只小烤雀
			sil(ci, [stk(Vector2(-36, 26), Vector2(34, -26), 2.2, s, WOOD_D)], rim)
			_roastbird(ci, Vector2(-10, 8), 13, s + 1, rim)
			_roastbird(ci, Vector2(14, -10), 13, s + 2, rim)
		2:  # 烤壁虎：分叉树枝上叉着一只烤焦的壁虎
			sil(ci, [stk(Vector2(-6, 38), Vector2(-2, 0), 3.0, s, WOOD_D), stk(Vector2(-2, 2), Vector2(-20, -30), 2.4, s + 1, WOOD_D),
				stk(Vector2(-2, 2), Vector2(18, -30), 2.4, s + 2, WOOD_D)], rim)
			var body := [ov(Vector2(0, -16), 9, 16, s + 3, CRUST, 0.0, 1), ov(Vector2(0, -36), 6, 7, s + 4, CRUST, 0.0, 1),
				stk(Vector2(0, -2), Vector2(10, 20), 3.0, s + 5, CRUST), stk(Vector2(-6, -24), Vector2(-16, -30), 2.4, s + 6, CRUST),
				stk(Vector2(6, -24), Vector2(16, -30), 2.4, s + 7, CRUST), stk(Vector2(-6, -8), Vector2(-16, -2), 2.4, s + 8, CRUST),
				stk(Vector2(6, -8), Vector2(16, -2), 2.4, s + 9, CRUST)]
			sil(ci, body, rim)
			grill(ci, Vector2(0, -16), 10, 2, s, 0.0)
		3:  # 烤野兔：一捆树枝搭的架子上趴着一只烤兔
			_m(ci, "furn_3", Vector2(0, 20), 80, rim)
			sil(ci, [ov(Vector2(-2, -6), 28, 15, s, CRUST, 0.0, 1), ov(Vector2(-28, -12), 11, 9, s + 1, CRUST, 0.0, 1),
				stk(Vector2(18, 0), Vector2(32, 6), 5.0, s + 2, CRUST), stk(Vector2(-18, 2), Vector2(-26, 10), 4.2, s + 3, CRUST)], rim)
			grill(ci, Vector2(-2, -8), 16, 3, s, -0.6)
			hl(ci, Vector2(-8, -14), 10, 4, -0.1, 0.4)
		4:  # 烤野鸡：木杆穿过的整只烤鸡
			sil(ci, [stk(Vector2(-42, 2), Vector2(42, -4), 3.0, s, WOOD)], rim)
			_roastbird(ci, Vector2(0, 6), 24, s + 1, rim)
			_fire(ci, Vector2(0, 32), 14, s + 5, false)
		5:  # 狐狸肉串：木杆上穿四大块
			_skewer(ci, Vector2(-40, 28), Vector2(40, -26), [0.2, 0.4, 0.6, 0.8], 10, s, rim)
		6:  # 烤野鸭：叉棍架上横杆，挂一只烤鸭，下面火
			_spit(ci, -14, 34, 52, s, rim)
			sil(ci, [stk(Vector2(-40, -14), Vector2(40, -14), 2.6, s + 6, WOOD)], false)
			_roastbird(ci, Vector2(0, -2), 20, s + 7, rim, CRUST_L.darkened(0.1))
			_fire(ci, Vector2(0, 32), 12, s + 9, false)
		7:  # 烤狼排：劈柴上一大块带骨排
			_m(ci, "furn_6", Vector2(0, 20), 110, rim)
			_drum(ci, Vector2(-8, 0), 32, 0.2, 34, s, rim)
			grill(ci, Vector2(-10, 0), 18, 3, s, -0.9)
		8:  # 石板烤肉：劈柴上架石板，石板上几片肉
			_fire(ci, Vector2(0, 32), 18, s, rim)
			_slab(ci, Vector2(0, 10), 82, 24, s + 2, rim)
			for k in 3:
				_chunk(ci, Vector2(-20 + float(k) * 20, 4 - float(k % 2) * 4), 9, s + 4 + k, false, CRUST_L.darkened(0.05 * float(k)), 0.2 * float(k - 1))
			steam(ci, Vector2(0, -12), 3, 20)
		9:  # 烤大雁：劈柴上一只大烤雁
			_m(ci, "furn_6", Vector2(0, 24), 110, rim)
			_roastbird(ci, Vector2(0, 0), 30, s, rim)
		10:  # 果木熏兔：吊着的熏兔，下面苹果木冒烟
			sil(ci, [stk(Vector2(-40, -36), Vector2(40, -36), 2.6, s, WOOD_D), stk(Vector2(0, -36), Vector2(0, -24), 1.6, s + 1, ROPE)], rim)
			sil(ci, [ov(Vector2(0, -4), 14, 22, s + 2, Color("8f4a24"), 0.0, 1), stk(Vector2(-6, -24), Vector2(-4, -34), 3.0, s + 3, Color("8f4a24")),
				stk(Vector2(6, -24), Vector2(4, -34), 3.0, s + 4, Color("8f4a24"))], rim)
			_m(ci, "fruit_6", Vector2(-24, 24), 38, false)
			_m(ci, "furn_6", Vector2(10, 30), 56, false)
			smoke(ci, Vector2(18, 10), 0.7)
		11:  # 烤野猪腿：一抱劈柴上横一条大猪腿
			_m(ci, "furn_7", Vector2(0, 20), 106, rim)
			_drum(ci, Vector2(-10, -2), 42, -0.25, 44, s, rim)
			grill(ci, Vector2(-12, -2), 22, 3, s, -1.2)
		12:  # 熏肉条：树皮搭的架子上挂一排肉条，下面柴
			sil(ci, [stk(Vector2(-36, 34), Vector2(-30, -32), 3.0, s, WOOD_D), stk(Vector2(36, 34), Vector2(30, -32), 3.0, s + 1, WOOD_D),
				P(rrect(Rect2(-38, -38, 76, 9), 3, s + 2, 0.6), Color("a98256"), 1)], rim)
			for k in 4:
				_strip(ci, Vector2(-20 + float(k) * 13, -28), 34 + float(k % 2) * 6, s + 3 + k, false)
			_m(ci, "furn_7", Vector2(0, 32), 48, false)
		13:  # 坚果烤鸡：木板上一只烤鸡，周围一圈板栗
			_board(ci, Vector2(0, 28), 88, 16, s, rim)
			_roastbird(ci, Vector2(0, 4), 24, s + 1, rim)
			_m(ci, "seed_7", Vector2(-30, 14), 34, false)
			_m(ci, "seed_7", Vector2(30, 14), 34, false, 0.4)
		14:  # 烤鹿肉：细原木上叠两大块鹿肉
			_m(ci, "furn_8", Vector2(0, 22), 110, rim)
			_chunk(ci, Vector2(-8, 4), 18, s, rim, CRUST, -0.1)
			_chunk(ci, Vector2(8, -8), 15, s + 3, rim, CRUST_L.darkened(0.05), 0.15)
		15:  # 叶包烤猪：棕榈叶层层包着，揭开一角露出肉，冒热气
			sil(ci, [ov(Vector2(0, 14), 40, 22, s, PALM.darkened(0.1), 0.0, 1), ov(Vector2(-12, 12), 30, 16, s + 1, PALM, -0.15, 1)], rim)
			_chunk(ci, Vector2(10, 4), 16, s + 2, false, CRUST_L)
			sil(ci, [pg([Vector2(-36, 10), Vector2(-4, -6), Vector2(4, 22), Vector2(-30, 30)], s + 4, PALM.lightened(0.05))], false)
			for k in 3:
				ln(ci, Vector2(-30 + float(k) * 8, 14), Vector2(-14 + float(k) * 8, 4), 1.4, Color(LEAF_D, 0.8), s + k)
			steam(ci, Vector2(12, -14), 3, 22)
		16:  # 烤野牛肋排：原木上一大扇肋排
			_m(ci, "furn_9", Vector2(0, 24), 112, rim)
			_ribs(ci, Vector2(0, 4), 62, 40, s, rim)
		17:  # 双拼烤肉：木板上鹿排和鸭腿
			_m(ci, "furn_9", Vector2(0, 24), 112, rim)
			_chunk(ci, Vector2(-12, 4), 16, s, rim, CRUST, -0.15)
			_drum(ci, Vector2(14, 0), 24, -0.9, 26, s + 3, rim, CRUST_L.darkened(0.1))
		18:  # 烤鸵鸟腿：两根原木上横一条特大的腿
			_m(ci, "furn_10", Vector2(0, 22), 110, rim)
			_drum(ci, Vector2(-14, 0), 50, -0.15, 50, s, rim)
			grill(ci, Vector2(-16, 0), 26, 3, s, -1.3)
		19:  # 猛犸烤腿：一垛原木上一条巨腿，带火
			_m(ci, "furn_11", Vector2(0, 22), 108, rim)
			_drum(ci, Vector2(-16, -6), 54, -0.25, 58, s, rim, Color("9a4a1c"))
			grill(ci, Vector2(-18, -6), 30, 4, s, -1.3)
			glow(ci, Vector2(0, 0), 46, Color(1, 0.7, 0.3))
		20:  # 篝火烤宴：篝火上架横杆，肋排和大雁，前面半圆木当案板
			glow(ci, Vector2(0, 10), 50, Color(1, 0.6, 0.2))
			_spit(ci, -22, 38, 58, s, rim)
			sil(ci, [stk(Vector2(-44, -22), Vector2(44, -22), 2.6, s + 6, WOOD)], false)
			_roastbird(ci, Vector2(-14, -10), 16, s + 7, rim)
			_ribs(ci, Vector2(18, -8), 30, 22, s + 8, rim)
			_fire(ci, Vector2(0, 22), 16, s + 9, false)
			_m(ci, "furn_12", Vector2(0, 36), 64, false)
			sparks(ci, [Vector2(-38, -42), Vector2(40, -40)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 蜜食甜品

static func _honey(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 蜜渍野莓：一摊蜂蜜里泡着野莓，边上一小块蜂巢
			_honey_pool(ci, Vector2(0, 24), 36, 12, s, rim)
			_m(ci, "fruit_1", Vector2(-10, -2), 54, false)
			_m(ci, "craft_10", Vector2(22, 4), 42, false)
			_drizzle(ci, Vector2(-10, -6), 12, s)
		2:  # 蜂蜜樱桃：樱桃上浇蜜
			_honey_pool(ci, Vector2(0, 26), 34, 10, s, rim)
			_m(ci, "fruit_2", Vector2(-2, 0), 66, false)
			_drizzle(ci, Vector2(-2, 6), 18, s)
		3:  # 蜜糖松子：蜂蜜把松子粘成一坨
			_honey_blob(ci, Vector2(0, 12), 32, 22, s, rim)
			for k in 7:
				var a := float(k) * 2.4
				var d := sqrt(float(k + 1) / 7.0)
				sil(ci, [ov(Vector2(cos(a) * 18 * d, 10 + sin(a) * 11 * d), 6.5, 4.2, s + k, Color("f6e4bc"), a, 0)], false, 1.4)
			hl(ci, Vector2(-14, 0), 8, 4, -0.3, 0.55)
		4:  # 蜂巢甜块：棕榈叶上切好的几块蜂巢
			_palmmat(ci, Vector2(0, 30), 44, s, rim)
			_m(ci, "craft_10", Vector2(-14, 2), 52, false)
			_m(ci, "craft_10", Vector2(14, 0), 50, false, 0.3)
			_drizzle(ci, Vector2(0, 18), 16, s)
		5:  # 蜜渍李子：蜂巢上两个裹满蜜的李子
			_m(ci, "craft_11", Vector2(0, 16), 76, rim)
			_m(ci, "fruit_4", Vector2(-12, -14), 48, false)
			_m(ci, "fruit_4", Vector2(12, -12), 46, false, 0.3)
			_drizzle(ci, Vector2(0, -10), 20, s)
		6:  # 蜂蜜杏仁：蜂巢上一捧蜜裹杏仁
			_m(ci, "craft_11", Vector2(0, 16), 76, rim)
			for k in 3:
				_m(ci, "seed_4", Vector2(-14 + float(k) * 14, -10 - float(k % 2) * 6), 40, false, -0.4 + 0.4 * float(k))
			_drizzle(ci, Vector2(0, -6), 18, s)
		7:  # 蜜无花果：对半的无花果浇上蜜
			_m(ci, "craft_11", Vector2(20, 18), 50, rim)
			for k in 2:
				var c := Vector2(-16 + float(k) * 18, 6 - float(k) * 4)
				sil(ci, [ov(c, 13, 17, s + k, PAFood.FIG, 0.1, 1), ov(c + Vector2(0, 1), 10.5, 13.5, s + 3 + k, FIG_IN, 0.1, 0)], rim)
				_seeds(ci, c, 7, 10, 10, 1.0, Color(INK, 0.7), s + k)
			_drizzle(ci, Vector2(-8, -6), 18, s)
		8:  # 蜂蜜坚果棒：几根金黄的棒子，嵌着腰果核桃
			_board(ci, Vector2(0, 28), 84, 16, s, rim)
			for k in 3:
				var c := Vector2(-20 + float(k) * 18, 10 - float(k) * 6)
				sil(ci, [P(_rrect_rot(c, 40, 12, 5, -0.5, s + k), HONEY.darkened(0.08), 1)], false)
				for j in 3:
					ci.draw_circle(c + Vector2(-10 + float(j) * 10, 0).rotated(-0.5), 2.6, Color("f3dcae") if j % 2 == 0 else Color("a8743a"))
			_m(ci, "seed_8", Vector2(30, -18), 34, false)
		9:  # 蜜烤苹果：两个苹果串在树枝上，裹着蜜，下面一小堆柴
			_m(ci, "furn_3", Vector2(0, 30), 60, rim)
			sil(ci, [stk(Vector2(-16, 22), Vector2(-14, -36), 2.0, s, WOOD_D), stk(Vector2(16, 22), Vector2(14, -36), 2.0, s + 1, WOOD_D)], rim)
			_m(ci, "fruit_6", Vector2(-15, -12), 50, false)
			_m(ci, "fruit_6", Vector2(15, -8), 48, false)
			_drizzle(ci, Vector2(-15, -16), 8, s)
			_drizzle(ci, Vector2(15, -12), 8, s + 3)
		10:  # 蜜浆小罐：陶罐口漫出蜜，旁边蜂巢
			_m(ci, "pot_6", Vector2(-6, 4), 86, rim)
			_m(ci, "craft_11", Vector2(26, 22), 46, false)
			_drizzle(ci, Vector2(-6, -18), 12, s)
		11:  # 蜜石榴碗：陶碗里石榴籽浇蜜，碗后靠大蜂巢
			_m(ci, "craft_12", Vector2(18, -16), 50, rim)
			var c := Vector2(-4, 10)
			_bowl_back(ci, c, 30, CLAYPOT, s)
			var seeds := []
			for k in 14:
				var a := float(k) * 2.4
				var d := sqrt(float(k + 1) / 14.0)
				seeds.append(circ(c + Vector2(cos(a) * 22 * d, -10 + sin(a) * 5 * d - (1.0 - d) * 16), 5.2, s + k, POME_SEED, 0))
			sil(ci, seeds, false, 2.0)
			_drizzle(ci, c + Vector2(0, -14), 16, s)
			_bowl_front(ci, c, 30, 26, CLAYPOT, s + 1, rim)
		12:  # 蜂蜜核桃糕：石板上一块厚糕，顶上浇蜜放核桃
			_slab(ci, Vector2(0, 26), 86, 24, s, rim)
			_cake(ci, Vector2(0, 2), 30, 12, 14, s + 1, false, Color("c98a4a"))
			_drizzle(ci, Vector2(0, 0), 24, s)
			_m(ci, "seed_8", Vector2(0, -10), 40, false)
		13:  # 蜜芒果：芒果切条码好，浇蜜，旁边大蜂巢
			_m(ci, "craft_12", Vector2(24, -10), 52, rim)
			_honey_pool(ci, Vector2(-6, 24), 34, 11, s, rim)
			for k in 4:
				sil(ci, [P(_rrect_rot(Vector2(-22 + float(k) * 11, 14), 10, 26, 5, 0.25, s + k), MANGO_IN, 1)], false)
			_drizzle(ci, Vector2(-6, 6), 20, s)
		14:  # 蜂蜜椰子：半个椰壳里盛满蜜，蜂巢搁一边
			_m(ci, "craft_12", Vector2(26, -10), 46, rim)
			var c := Vector2(-6, 8)
			_bowl_back(ci, c, 30, PAFood.COCO, s)
			sil(ci, [ov(c + Vector2(0, -2), 28, 8, s + 3, HONEY, 0.0, 0)], false, 2.0)
			hl(ci, c + Vector2(-8, -4), 9, 2.5, 0.0, 0.6)
			_drizzle(ci, c + Vector2(18, -2), 6, s)
			_bowl_front(ci, c, 30, 28, PAFood.COCO, s + 1, rim, BONE)
		15:  # 蜜饯拼盘：小碟上蜜渍葡萄、梨片和蜂巢
			_clayplate(ci, Vector2(0, 24), 42, 15, s, rim)
			_m(ci, "fruit_9", Vector2(-18, -4), 44, false, -0.2)
			_m(ci, "craft_12", Vector2(16, -6), 44, false)
			for k in 2:
				var p := Vector2(-2 + float(k) * 14, 18)
				sil(ci, [ov(p, 9, 6, s + k, PAFood.PEAR.darkened(0.1), 0.2, 1), ov(p, 6.5, 4, s + k + 2, Color("f8eea8"), 0.2, 0)], false)
			_drizzle(ci, Vector2(-6, 8), 20, s)
			sparks(ci, [Vector2(-38, -34), Vector2(38, -36)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 陶器装东西

## 陶器的口在材料图里的位置和半宽（材料图坐标，size 100 时）
const MOUTH := {
	"pot_1": [Vector2(0, 8), 5.5], "pot_3": [Vector2(0, 8), 19.0], "pot_6": [Vector2(0, -9), 8.0],
	"pot_7": [Vector2(-1, -12), 6.0], "pot_9": [Vector2(0, -9), 10.0], "pot_10": [Vector2(0, -10), 19.0],
	"pot_11": [Vector2(0, -18), 16.0], "pot_12": [Vector2(0, -21), 21.0], "pot_13": [Vector2(0, -16), 24.0],
	"pot_15": [Vector2(0, -26), 12.0],
}
const BROTH := Color("d9a35a")
const BROTH_D := Color("a8703a")
const MILK := Color("f2e6c8")

## 陶器口在画面里的位置和半宽
static func _pmouth(pot: String, pos: Vector2, size: float) -> Array:
	var m: Array = MOUTH[pot]
	return [pos + (m[0] as Vector2) * size / 100.0, float(m[1]) * size / 100.0]

## 陶器口上的一层汤水
static func _surface(ci: CanvasItem, mo: Array, col: Color, s: int) -> void:
	var c: Vector2 = mo[0]
	var w: float = mo[1]
	ci.draw_colored_polygon(ell(c, Vector2(w * 1.02, maxf(w * 0.3, 2.0)), s, 0.0, 16), INK)
	ci.draw_colored_polygon(ell(c, Vector2(w * 0.88, maxf(w * 0.22, 1.4)), s, 0.0, 16), col)
	ci.draw_colored_polygon(ell(c + Vector2(-w * 0.3, -w * 0.04), Vector2(w * 0.22, maxf(w * 0.06, 0.8)), s, 0.0, 10), Color(1, 1, 1, 0.5))

# ---------------------------------------------------------------- 炖煮汤羹

static func _stew_pot(ci: CanvasItem, pot: String, pos: Vector2, size: float, broth: Color, s: int, rim: bool, stuff: Callable) -> void:
	var mo := _pmouth(pot, pos, size)
	stuff.call((mo[0] as Vector2) + Vector2(0, -8), mo[1])
	_m(ci, pot, pos, size, rim)
	_surface(ci, mo, broth, s)
	steam(ci, (mo[0] as Vector2) + Vector2(-float(mo[1]) - 6.0, -4), 2, 16)

static func _stew(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1, 2, 3:  # 一碗汤：木耳 / 树菇 / 泥鳅
			var c := Vector2(0, 8)
			_bowl_back(ci, c, 34, CLAYPOT, s)
			sil(ci, [ov(c + Vector2(0, -3), 31, 8, s + 3, BROTH_D if n < 3 else BROTH, 0.0, 0)], false, 2.0)
			match n:
				1:
					_m(ci, "craft_7", c + Vector2(-12, -42), 92, false, -0.3)
					_m(ci, "craft_7", c + Vector2(14, -38), 84, false, 0.5)
				2:
					_m(ci, "craft_8", c + Vector2(0, -44), 90, false)
				3:
					_m(ci, "fish_4", c + Vector2(0, -34), 100, false, -0.15)
			_bowl_front(ci, c, 34, 28, CLAYPOT, s + 1, rim)
			steam(ci, c + Vector2(0, -24), 3, 18)
		4:  # 野兔炖罐：罐口冒出肉块和一根骨头
			_stew_pot(ci, "pot_6", Vector2(0, 8), 150, BROTH, s, rim, func(m: Vector2, w: float):
				sil(ci, [stk(m + Vector2(4, 4), m + Vector2(14, -22), 3.2, s, BONE, 0), circ(m + Vector2(15, -24), 4.0, s + 1, BONE)], rim)
				_chunk(ci, m + Vector2(-6, -4), 8, s + 2, rim, CRUST_L, 0.3))
		5, 6, 7:  # 野鸡汤 / 板栗炖鸡 / 野鸭坚果汤：罐口竖一只鸡腿
			_stew_pot(ci, "pot_6", Vector2(-4, 8), 150, BROTH, s, rim, func(m: Vector2, w: float):
				_drum(ci, m + Vector2(2, -2), 20, -1.3, 18, s, rim, CRUST_L if n != 7 else CRUST))
			if n == 6:
				_m(ci, "seed_7", Vector2(26, 26), 40, false)
			elif n == 7:
				_m(ci, "seed_5", Vector2(26, 26), 40, false)
		8:  # 野猪肉羹：罐里满满的肉块
			_stew_pot(ci, "pot_6", Vector2(0, 8), 150, BROTH_D, s, rim, func(m: Vector2, w: float):
				_chunk(ci, m + Vector2(-6, -6), 8, s, rim, CRUST, -0.3)
				_chunk(ci, m + Vector2(7, -8), 8, s + 3, rim, CRUST_L, 0.4))
		9:  # 鳜鱼汤：鱼尾巴从罐口翘出来
			_stew_pot(ci, "pot_6", Vector2(0, 8), 150, BROTH, s, rim, func(m: Vector2, w: float):
				_m(ci, "fish_6", m + Vector2(4, -10), 54, rim, -1.2))
		10:  # 河蚌汤
			_stew_pot(ci, "pot_6", Vector2(0, 8), 150, MILK, s, rim, func(m: Vector2, w: float):
				_m(ci, "clam_3", m + Vector2(0, -8), 44, rim, 0.3))
		11:  # 鹿肉炖菇：双耳罐，肉块和菇
			_stew_pot(ci, "pot_9", Vector2(0, 8), 124, BROTH_D, s, rim, func(m: Vector2, w: float):
				_chunk(ci, m + Vector2(-6, -4), 9, s, rim, CRUST, 0.3)
				_m(ci, "craft_8", m + Vector2(8, -10), 40, rim))
		12:  # 灵芝补汤：双耳罐插一朵大灵芝，旁边雁腿
			_stew_pot(ci, "pot_9", Vector2(-4, 8), 124, BROTH_D, s, rim, func(m: Vector2, w: float):
				_m(ci, "craft_9", m + Vector2(0, -14), 46, rim))
			_drum(ci, Vector2(24, 26), 14, -0.6, 14, s + 7, rim, CRUST_L)
		13:  # 三足鼎炖肉：鼎里肋骨和肉块
			_stew_pot(ci, "pot_10", Vector2(0, 10), 110, BROTH_D, s, rim, func(m: Vector2, w: float):
				for k in 3:
					sil(ci, [stk(m + Vector2(-8 + float(k) * 8, 0), m + Vector2(-12 + float(k) * 9, -18), 2.6, s + k, BONE, 0)], rim)
				_chunk(ci, m + Vector2(-10, -2), 8, s + 4, rim, CRUST, -0.2)
				_chunk(ci, m + Vector2(10, -3), 8, s + 5, rim, CRUST_L, 0.3))
		14, 15:  # 陶甑蒸栗 / 蒸鱼：甑上面放吃的，冒大蒸汽
			var mo := _pmouth("pot_11", Vector2(0, 8), 120)
			_m(ci, "pot_11", Vector2(0, 8), 120, rim)
			if n == 14:
				_m(ci, "seed_7", (mo[0] as Vector2) + Vector2(-8, -6), 40, false)
				_m(ci, "seed_7", (mo[0] as Vector2) + Vector2(9, -5), 40, false, 0.4)
			else:
				_m(ci, "fish_7", (mo[0] as Vector2) + Vector2(0, -4), 60, false)
			steam(ci, (mo[0] as Vector2) + Vector2(0, -16), 3, 20)
		16:  # 大缸炖牛：大缸里牛肉和灵芝
			_stew_pot(ci, "pot_13", Vector2(0, 10), 100, BROTH_D, s, rim, func(m: Vector2, w: float):
				_chunk(ci, m + Vector2(-10, -4), 10, s, rim, CRUST, -0.3)
				_m(ci, "craft_9", m + Vector2(12, -10), 40, rim))
		17:  # 猛犸骨汤：大缸里斜插一根巨骨
			_stew_pot(ci, "pot_13", Vector2(0, 10), 100, MILK, s, rim, func(m: Vector2, w: float):
				sil(ci, [stk(m + Vector2(-4, 6), m + Vector2(20, -30), 5.0, s, BONE, 0), circ(m + Vector2(17, -34), 6, s + 1, BONE), circ(m + Vector2(25, -30), 6, s + 2, BONE)], rim))
		18:  # 海鲜大炖锅：鼎里章鱼腕、蟹、扇贝
			_stew_pot(ci, "pot_10", Vector2(0, 10), 110, Color("e07a4a"), s, rim, func(m: Vector2, w: float):
				_m(ci, "clam_6", m + Vector2(-12, -8), 40, rim, -0.3)
				_m(ci, "clam_5", m + Vector2(12, -8), 40, rim, 0.3)
				_tentacle(ci, m + Vector2(0, 0), 20, -1.4, s, rim))
		19:  # 部落大锅饭：大缸满满一锅，雁腿、鹿肉、坚果
			glow(ci, Vector2(0, -10), 46, Color(1, 0.8, 0.4))
			_stew_pot(ci, "pot_13", Vector2(0, 10), 100, BROTH, s, rim, func(m: Vector2, w: float):
				_drum(ci, m + Vector2(-12, -2), 18, -2.0, 16, s, rim, CRUST_L)
				_chunk(ci, m + Vector2(12, -6), 9, s + 3, rim, CRUST, 0.3)
				_m(ci, "seed_9", m + Vector2(0, -8), 32, rim))
			sparks(ci, [Vector2(-40, -36), Vector2(40, -32)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

## 一条弯起的章鱼腕，带吸盘
static func _tentacle(ci: CanvasItem, base: Vector2, l: float, ang: float, s: int, rim: bool, col: Color = Color("d8655a")) -> void:
	var spine := []
	for k in 7:
		var t := float(k) / 6.0
		spine.append(base + Vector2(cos(ang + t * 1.6), sin(ang + t * 1.6)) * l * t)
	var parts := []
	for k in 6:
		parts.append(stk(spine[k], spine[k + 1], 6.5 - float(k) * 0.7, s + k, col, 0))
	sil(ci, parts, rim)
	for k in 5:
		ci.draw_circle((spine[k] as Vector2).lerp(spine[k + 1], 0.5) + Vector2(1.5, 1.5), 1.5, Color("f8c8b8"))

# ---------------------------------------------------------------- 饮品酒浆

## 陶器装着饮料：先画陶器，口上一层颜色
static func _drink_pot(ci: CanvasItem, pot: String, pos: Vector2, size: float, col: Color, s: int, rim: bool) -> Array:
	_m(ci, pot, pos, size, rim)
	var mo := _pmouth(pot, pos, size)
	_surface(ci, mo, col, s)
	return mo

static func _drink(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 野莓汁
			_drink_pot(ci, "pot_1", Vector2(-8, -10), 230, Color("c8324a"), s, rim)
			_m(ci, "fruit_1", Vector2(24, 18), 44, false)
		2:  # 樱桃汁：杯沿挂一对樱桃
			var mo := _drink_pot(ci, "pot_1", Vector2(-6, -10), 230, Color("a0182e"), s, rim)
			_m(ci, "fruit_2", (mo[0] as Vector2) + Vector2(14, 4), 46, false, 0.3)
		3:  # 蜜水
			_drink_pot(ci, "pot_1", Vector2(-8, -10), 230, HONEY_L, s, rim)
			_m(ci, "craft_10", Vector2(24, 20), 40, false)
		4:  # 蓝莓浆：一碗紫浆
			var c := Vector2(0, 8)
			_bowl_back(ci, c, 32, CLAYPOT, s)
			sil(ci, [ov(c + Vector2(0, -4), 29, 8, s + 3, Color("5a4aa0"), 0.0, 0)], false, 2.0)
			hl(ci, c + Vector2(-10, -6), 8, 2.4, 0.0, 0.5)
			_bowl_front(ci, c, 32, 26, CLAYPOT, s + 1, rim)
			_m(ci, "fruit_3", Vector2(26, -14), 46, false)
		5, 6, 7:  # 苹果浆 / 坚果浆 / 西瓜汁：陶罐
			var col: Color = [Color("f2dc8a"), MILK, Color("ef5a6a")][n - 5]
			_drink_pot(ci, "pot_6", Vector2(-8, 0), 170, col, s, rim)
			match n:
				5: _m(ci, "fruit_6", Vector2(24, 20), 44, false)
				6:
					_m(ci, "seed_4", Vector2(22, 22), 36, false, 0.3)
					_m(ci, "seed_9", Vector2(32, 26), 30, false)
				7: _wedge(ci, Vector2(24, 2), 22, PI / 2.0 - 0.1, 1.2, PAFood.MELON, MELON_IN, s + 5, rim, 0.15)
		8, 9, 10, 11, 12:  # 陶壶：梨水 / 石榴汁 / 芒果浆 / 树皮茶 / 灵芝茶
			var col: Color = [Color("e8eca0"), Color("c8283c"), MANGO_IN, Color("a86a3a"), Color("7a4a2a")][n - 8]
			var mo := _drink_pot(ci, "pot_7", Vector2(-8, 0), 150, col, s, rim)
			match n:
				8: _m(ci, "fruit_7", Vector2(26, 20), 42, false)
				9: _m(ci, "fruit_8", Vector2(26, 20), 42, false)
				10: _m(ci, "fruit_10", Vector2(26, 20), 42, false, 0.3)
				11:
					_m(ci, "craft_2", Vector2(24, 24), 46, false)
					steam(ci, (mo[0] as Vector2) + Vector2(0, -8), 2, 16)
				12:
					_m(ci, "craft_9", Vector2(24, 20), 44, false)
					steam(ci, (mo[0] as Vector2) + Vector2(0, -8), 2, 16)
		13:  # 椰子水：凿开一个口的椰子，插一根芦苇管，旁边石凿
			_m(ci, "tool_6", Vector2(24, 22), 46, false, 0.4)
			_m(ci, "fruit_12", Vector2(-6, 2), 100, rim)
			sil(ci, [ov(Vector2(-6, -14), 6, 3, s, BONE, 0.0, 0)], false, 2.0)
			sil(ci, [stk(Vector2(-6, -14), Vector2(8, -40), 2.4, s + 1, GRASS)], false)
		14:  # 葡萄酒：双耳罐，葡萄和蜂巢
			_drink_pot(ci, "pot_9", Vector2(-6, 0), 140, Color("6a1a3a"), s, rim)
			_m(ci, "fruit_9", Vector2(24, 18), 46, false)
			_m(ci, "craft_11", Vector2(-30, 26), 34, false)
		15:  # 黑陶敬酒：黑陶高柄杯盛满酒，葡萄蜂巢在一旁
			_drink_pot(ci, "pot_12", Vector2(-4, 4), 90, Color("6a1a3a"), s, rim)
			_m(ci, "fruit_9", Vector2(28, 22), 40, false)
			_m(ci, "craft_12", Vector2(-30, 24), 36, false)
			sparks(ci, [Vector2(-34, -34), Vector2(30, -38)], 5.0)
		16:  # 蜂蜜酒：大缸，缸边挂蜂巢
			_drink_pot(ci, "pot_13", Vector2(-4, 4), 104, Color("e8a83a"), s, rim)
			_m(ci, "craft_12", Vector2(26, -14), 44, false)
			for k in 3:
				ci.draw_arc(Vector2(-12 + float(k) * 10, -22 - float(k % 2) * 6), 2.4, 0, TAU, 10, Color(1, 1, 1, 0.7), 1.4)
		17:  # 果酒大瓮：彩陶大瓮，口上葡萄，旁边菠萝蜜
			glow(ci, Vector2(0, 0), 46, Color(1, 0.8, 0.5))
			_m(ci, "fruit_14", Vector2(26, 14), 46, false)
			var mo := _drink_pot(ci, "pot_15", Vector2(-6, 4), 96, Color("6a1a3a"), s, rim)
			_m(ci, "fruit_9", (mo[0] as Vector2) + Vector2(-2, -6), 40, false)
			sparks(ci, [Vector2(-40, -34), Vector2(40, -38)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 鱼鲜

const FILLET := Color("f2b49a")
const FILLET_D := Color("d98a6e")

## 在鱼身上补几道烤痕
static func _scorch(ci: CanvasItem, c: Vector2, w: float, ang: float, s: int) -> void:
	grill(ci, c, w, 3, s, ang - 1.1)

static func _seafood(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 青蛙腿串：小树枝串三对蛙腿
			sil(ci, [stk(Vector2(-36, 28), Vector2(34, -26), 2.2, s, WOOD_D)], rim)
			for k in 3:
				var p := Vector2(-36, 28).lerp(Vector2(34, -26), 0.25 + float(k) * 0.25)
				_drum(ci, p, 14, 0.6, 12, s + k * 3, rim, Color("d9a070"))
		2:  # 烤麦穗鱼：分叉树枝叉着两条小鱼，带烤痕
			sil(ci, [stk(Vector2(0, 38), Vector2(0, 6), 2.6, s, WOOD_D), stk(Vector2(0, 8), Vector2(-16, -36), 2.2, s + 1, WOOD_D),
				stk(Vector2(0, 8), Vector2(16, -36), 2.2, s + 2, WOOD_D)], rim)
			_m(ci, "fish_3", Vector2(-14, -10), 70, rim, -1.2)
			_m(ci, "fish_3", Vector2(14, -10), 70, rim, -1.9)
			_scorch(ci, Vector2(-14, -12), 10, -1.2, s)
			_scorch(ci, Vector2(14, -12), 10, 1.2, s + 3)
		3:  # 烤田螺：分叉树枝上串满田螺
			sil(ci, [stk(Vector2(0, 38), Vector2(0, 8), 2.6, s, WOOD_D), stk(Vector2(0, 10), Vector2(-24, -34), 2.2, s + 1, WOOD_D),
				stk(Vector2(0, 10), Vector2(24, -34), 2.2, s + 2, WOOD_D)], rim)
			for k in 2:
				_m(ci, "clam_1", Vector2(-8 - float(k) * 10, -4 - float(k) * 18), 56, rim)
				_m(ci, "clam_1", Vector2(8 + float(k) * 10, -4 - float(k) * 18), 56, rim)
		4:  # 河虾串：木杆横串三只虾
			sil(ci, [stk(Vector2(-40, 10), Vector2(40, -6), 2.6, s, WOOD)], rim)
			for k in 3:
				_m(ci, "clam_2", Vector2(-24 + float(k) * 24, 4 - float(k) * 5), 54, rim)
		5:  # 泥鳅干：干草捆上横晾几条泥鳅
			_m(ci, "cloth_3", Vector2(0, 16), 90, rim)
			_m(ci, "fish_4", Vector2(-4, -10), 70, rim, 0.1)
			_m(ci, "fish_4", Vector2(6, -22), 66, rim, -0.15)
		6:  # 鱼干串：麻秆上用绳挂一串小鱼和泥鳅
			sil(ci, [stk(Vector2(-42, -32), Vector2(42, -36), 2.8, s, Color("c9a86a"))], rim)
			for k in 3:
				var x := -24.0 + float(k) * 24.0
				sil(ci, [stk(Vector2(x, -33), Vector2(x, -22), 1.4, s + k, GRASS_D)], false)
				_m(ci, "fish_4" if k == 1 else "fish_3", Vector2(x, 4), 64, rim, PI / 2.0)
		7:  # 小龙虾拼盘：陶碟上两只红小龙虾
			_clayplate(ci, Vector2(0, 24), 42, 15, s, rim)
			_m(ci, "clam_4", Vector2(-12, 2), 64, false, -0.3)
			_m(ci, "clam_4", Vector2(14, 4), 60, false, 0.4)
		8:  # 蒸河蟹：陶甑顶上一只蟹，冒大气
			var mo := _pmouth("pot_11", Vector2(0, 10), 120)
			_m(ci, "pot_11", Vector2(0, 10), 120, rim)
			_m(ci, "clam_5", (mo[0] as Vector2) + Vector2(0, -6), 56, false)
			steam(ci, (mo[0] as Vector2) + Vector2(0, -18), 3, 18)
		9:  # 烤扇贝：一束木杆架成烤架，几个扇贝，下面火
			_fire(ci, Vector2(0, 30), 16, s, rim)
			for k in 4:
				sil(ci, [stk(Vector2(-38, 12 - float(k) * 3), Vector2(38, 8 - float(k) * 3), 2.2, s + k, WOOD_D)], rim)
			_m(ci, "clam_6", Vector2(-18, -4), 46, false)
			_m(ci, "clam_6", Vector2(16, -8), 46, false, 0.2)
		10:  # 鳜鱼烤片：劈柴上石板，几片鱼肉
			_m(ci, "furn_6", Vector2(0, 30), 86, rim)
			_slab(ci, Vector2(0, 12), 84, 24, s, rim)
			for k in 3:
				var c := Vector2(-20 + float(k) * 20, 6 - float(k % 2) * 4)
				sil(ci, [P(_rrect_rot(c, 18, 12, 5, 0.2, s + k), FILLET, 1)], false)
				pl(ci, [c + Vector2(-5, -3), c + Vector2(0, 0), c + Vector2(-5, 3)], 1.2, FILLET_D, s + k)
				pl(ci, [c + Vector2(1, -3), c + Vector2(6, 0), c + Vector2(1, 3)], 1.2, FILLET_D, s + k + 4)
			_m(ci, "fish_6", Vector2(22, -18), 40, false, 0.2)
		11:  # 海螺烤盅：海螺口朝上搁在劈柴上，冒热气
			_m(ci, "furn_6", Vector2(0, 28), 92, rim)
			_m(ci, "clam_7", Vector2(0, -2), 74, rim)
			steam(ci, Vector2(-6, -24), 2, 16)
		12:  # 比目鱼干：麻线吊起一条扁鱼
			sil(ci, [stk(Vector2(-30, -40), Vector2(30, -40), 2.2, s, Color("c9a86a")), stk(Vector2(0, -40), Vector2(0, -24), 1.4, s + 1, Color("c9a86a"))], rim)
			_m(ci, "fish_7", Vector2(0, 6), 86, rim, PI / 2.0)
			_m(ci, "cloth_6", Vector2(-28, 26), 40, false)
		13:  # 乌贼串：木杆竖穿乌贼
			sil(ci, [stk(Vector2(0, 40), Vector2(0, -40), 2.6, s, WOOD)], rim)
			_m(ci, "fish_9", Vector2(0, 0), 90, rim)
			_scorch(ci, Vector2(0, -10), 12, 0.0, s)
		14:  # 章鱼烤腕：劈柴上几条卷起的章鱼腕
			_m(ci, "furn_6", Vector2(0, 26), 92, rim)
			_tentacle(ci, Vector2(-18, 8), 32, -1.0, s, rim)
			_tentacle(ci, Vector2(4, 10), 34, -1.6, s + 4, rim, Color("c8504a"))
			_tentacle(ci, Vector2(20, 12), 26, -2.2, s + 8, rim)
		15:  # 熏鳗鱼：树皮架子上挂一条鳗鱼，下面柴冒烟
			sil(ci, [stk(Vector2(-34, 36), Vector2(-28, -32), 3.0, s, WOOD_D), stk(Vector2(34, 36), Vector2(28, -32), 3.0, s + 1, WOOD_D),
				P(rrect(Rect2(-36, -38, 72, 9), 3, s + 2, 0.6), Color("a98256"), 1)], rim)
			_m(ci, "fish_11", Vector2(0, -6), 80, false, 0.0)
			_m(ci, "furn_7", Vector2(0, 32), 50, false)
			smoke(ci, Vector2(10, 14), 0.6)
		16:  # 鳐鱼干：棕榈叶上摊着一条晒干的鳐鱼
			_palmmat(ci, Vector2(0, 30), 48, s, rim)
			_m(ci, "fish_12", Vector2(0, -2), 92, false)
		17:  # 甲鱼汤：三足鼎里探出甲鱼
			var mo := _pmouth("pot_10", Vector2(0, 6), 120)
			_m(ci, "clam_8", (mo[0] as Vector2) + Vector2(0, -6), 60, rim, -0.2)
			_m(ci, "pot_10", Vector2(0, 6), 120, rim)
			_surface(ci, mo, BROTH, s)
			steam(ci, (mo[0] as Vector2) + Vector2(0, -16), 3, 18)
		18:  # 鱼贝拼盘：陶碟上鳜鱼、河蚌、扇贝
			_clayplate(ci, Vector2(0, 26), 44, 15, s, rim)
			_m(ci, "fish_6", Vector2(0, -6), 70, false)
			_m(ci, "clam_3", Vector2(-24, 14), 40, false)
			_m(ci, "clam_6", Vector2(22, 16), 40, false)
		19:  # 鲨鱼排：原木上一大块鱼排，长石刃
			_m(ci, "furn_9", Vector2(0, 26), 110, rim)
			_m(ci, "tool_5", Vector2(28, -10), 56, false, -0.6)
			var c := Vector2(-8, 0)
			sil(ci, [ov(c, 26, 18, s, Color("7d8c98"), -0.1, 1), ov(c, 22, 14.5, s + 1, FILLET, -0.1, 0)], rim)
			sil(ci, [ov(c, 4, 4, s + 2, BONE, 0.0, 1)], false)
			for k in 4:
				var a := float(k) * PI / 2.0 + 0.4
				ln(ci, c + Vector2(cos(a), sin(a)) * 5, c + Vector2(cos(a) * 18, sin(a) * 11), 1.4, FILLET_D, s + k)
			_scorch(ci, c, 18, -0.1, s)
		20:  # 鳇鱼大宴：一垛原木上横着鳇鱼王，后面大陶缸
			glow(ci, Vector2(0, -6), 50, Color(1, 0.85, 0.4))
			_m(ci, "pot_13", Vector2(-22, -6), 70, rim)
			_m(ci, "furn_11", Vector2(0, 26), 100, rim)
			_m(ci, "fish_16", Vector2(4, -2), 90, false)
			sparks(ci, [Vector2(-42, -36), Vector2(40, -38)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 器具的零件

const FLINT := Color("8d8796")
const FLINT_L := Color("b9b3c2")
const CORD := Color("c9a86a")
const BIRCH := Color("f1ece0")
const RESIN := Color("e8902a")
const WATER := Color("7cc4e8")

## 绑绳：在 p 处横着缠几圈
static func _lash(ci: CanvasItem, p: Vector2, ang: float, half: float, n: int, s: int, col: Color = CORD) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var nn := Vector2(-d.y, d.x)
	for i in n:
		var m := p + d * (float(i) - float(n - 1) * 0.5) * 4.2
		ln(ci, m - nn * half, m + nn * half + d * 1.5, 4.6, INK, s + i)
		ln(ci, m - nn * half, m + nn * half + d * 1.5, 2.6, col, s + i)

## 打制石片：尖头柳叶形，边缘有崩口，中间棱线
static func _flake(ci: CanvasItem, c: Vector2, l: float, w: float, ang: float, s: int, rim: bool, col: Color = FLINT) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var nn := Vector2(-d.y, d.x)
	var pts := [c + d * l * 0.5]
	for k in 5:
		var t := 0.3 - float(k) * 0.2
		pts.append(c + d * l * t + nn * w * (0.75 + 0.25 * float(k % 2)) * sin((t + 0.5) * PI * 0.9 + 0.3))
	pts.append(c - d * l * 0.5)
	for k in 5:
		var t := -0.5 + 0.2 + float(k) * 0.2
		pts.append(c + d * l * t - nn * w * (0.75 + 0.25 * float((k + 1) % 2)) * sin((t + 0.5) * PI * 0.9 + 0.3))
	sil(ci, [pg(pts, s, col)], rim)
	pl(ci, [c - d * l * 0.4, c + d * l * 0.35], 1.4, Color(1, 1, 1, 0.55), s)
	for k in 3:
		var p := c + d * l * (-0.25 + float(k) * 0.2)
		ln(ci, p + nn * w * 0.6, p + nn * w * 0.1 + d * 3, 1.2, Color(INK, 0.35), s + k)

## 木柄
static func _shaft(ci: CanvasItem, a: Vector2, b: Vector2, r: float, s: int, rim: bool, col: Color = WOOD) -> void:
	sil(ci, [stk(a, b, r, s, col)], rim)
	var d := (b - a).normalized()
	ln(ci, a + d * 6 + Vector2(-d.y, d.x) * r * 0.3, b - d * 6 + Vector2(-d.y, d.x) * r * 0.3, 1.2, Color(1, 1, 1, 0.35), s)

## 斧/锛的石头头：梯形，刃口一边亮
static func _axehead(ci: CanvasItem, c: Vector2, w: float, h: float, ang: float, s: int, rim: bool, col: Color = FLINT) -> void:
	var pts := [Vector2(-w * 0.35, -h * 0.5), Vector2(w * 0.5, -h * 0.62), Vector2(w * 0.55, h * 0.62), Vector2(-w * 0.35, h * 0.5), Vector2(-w * 0.5, 0)]
	var out := []
	for p in pts:
		out.append(c + (p as Vector2).rotated(ang))
	sil(ci, [pg(out, s, col)], rim)
	ln(ci, c + Vector2(w * 0.42, -h * 0.5).rotated(ang), c + Vector2(w * 0.46, h * 0.5).rotated(ang), 2.2, FLINT_L, s)

## 弓：一道木弧加弦
static func _bow(ci: CanvasItem, c: Vector2, h: float, bend: float, ang: float, s: int, rim: bool, col: Color = WOOD) -> void:
	var arc := []
	for k in 9:
		var t := float(k) / 8.0 * 2.0 - 1.0
		arc.append(c + Vector2(-bend * (1.0 - t * t), t * h * 0.5).rotated(ang))
	var parts := []
	for k in 8:
		parts.append(stk(arc[k], arc[k + 1], 3.2 - absf(float(k) - 3.5) * 0.3, s + k, col, 1))
	ci.draw_line(arc[0], arc[8], INK, 2.6, true)
	ci.draw_line(arc[0], arc[8], CORD.lightened(0.3), 1.2, true)
	sil(ci, parts, rim)

## 箭：杆、石尖、尾羽
static func _arrow(ci: CanvasItem, a: Vector2, b: Vector2, s: int, rim: bool, fcol: Color = Color("a87a4a")) -> void:
	var d := (b - a).normalized()
	var nn := Vector2(-d.y, d.x)
	sil(ci, [stk(a, b, 1.8, s, WOOD.lightened(0.1)),
		pg([a + d * 2, a + d * 14 + nn * 7, a + d * 18 + nn * 2], s + 1, fcol, 1), pg([a + d * 2, a + d * 14 - nn * 7, a + d * 18 - nn * 2], s + 2, fcol.darkened(0.15), 1)], rim)
	_flake(ci, b + d * 4, 12, 4.5, d.angle(), s + 3, rim)

## 网：在四边形里画网格
static func _net(ci: CanvasItem, q: Array, nx: int, ny: int, s: int, col: Color = CORD) -> void:
	var a: Vector2 = q[0]
	var b: Vector2 = q[1]
	var c: Vector2 = q[2]
	var d: Vector2 = q[3]
	for w in [4.0, 2.0]:
		var cc: Color = INK if w > 3.0 else col
		for i in nx + 1:
			var t := float(i) / float(nx)
			ci.draw_line(a.lerp(b, t), d.lerp(c, t), cc, w, true)
		for j in ny + 1:
			var t := float(j) / float(ny)
			var p0 := a.lerp(d, t)
			var p1 := b.lerp(c, t)
			var mid := p0.lerp(p1, 0.5) + Vector2(0, 3.0 * sin(float(j) + float(s)))
			ci.draw_polyline(PackedVector2Array([p0, mid, p1]), cc, w, true)

## 火把：杆、头、火苗
static func _torch(ci: CanvasItem, base: Vector2, top: Vector2, head: Color, s: int, rim: bool, fsz: float = 14.0) -> void:
	_shaft(ci, base, top, 3.4, s, rim, WOOD_D)
	var d := (top - base).normalized()
	sil(ci, [ov(top - d * 4, 8, 11, s + 1, head, d.angle() + PI / 2.0, 1)], rim)
	_lash(ci, top - d * 12, d.angle(), 4.5, 2, s + 2)
	glow(ci, top + d * 8, fsz * 1.6, Color(1, 0.7, 0.3))
	flame(ci, top + d * 6 + Vector2(0, -fsz * 0.4), fsz, fsz * 1.6, s + 3)

## 一圈石头
static func _stonering(ci: CanvasItem, c: Vector2, rx: float, ry: float, n: int, r: float, s: int, rim: bool, back: bool) -> void:
	var parts := []
	for k in n:
		var a := float(k) * TAU / float(n)
		if (sin(a) < 0.0) != back:
			continue
		parts.append(P(PA.raw_rock(c + Vector2(cos(a) * rx, sin(a) * ry), r, s + k, STONE.darkened(0.05 * float(k % 3)))[0], STONE.darkened(0.05 * float(k % 3)), 1))
	sil(ci, parts, rim)

## 编织筐体：轮廓加编织纹
static func _wicker(ci: CanvasItem, pts: Array, r: Rect2, s: int, rim: bool, col: Color = Color("c9a060")) -> void:
	sil(ci, [pg(pts, s, col)], rim)
	weave(ci, r, s)

# ---------------------------------------------------------------- 石器工具

static func _stonetool(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 刮刀：小树枝柄，一头绑石片
			_shaft(ci, Vector2(-34, 30), Vector2(8, -4), 3.4, s, rim)
			_flake(ci, Vector2(18, -14), 30, 12, -0.7, s + 1, rim)
			_lash(ci, Vector2(6, -2), -0.7, 5, 3, s + 2)
		2:  # 缝皮锥：分叉树枝柄，前面一根尖锥，带一截皮线
			_shaft(ci, Vector2(-30, 30), Vector2(-4, 4), 4.0, s, rim)
			sil(ci, [stk(Vector2(-14, 20), Vector2(-24, 6), 2.4, s + 1, WOOD)], rim)
			sil(ci, [pg([Vector2(-6, 0), Vector2(30, -30), Vector2(2, 8)], s + 2, FLINT)], rim)
			_lash(ci, Vector2(-4, 6), -0.75, 5, 3, s + 3)
			pl(ci, [Vector2(30, -30), Vector2(36, -14), Vector2(26, 0), Vector2(34, 14)], 2.0, LEATHER, s)
		3:  # 石钻：竖杆底下石尖，一张小弓的弦绕在杆上
			_shaft(ci, Vector2(0, 22), Vector2(0, -36), 3.4, s, rim)
			_flake(ci, Vector2(0, 30), 16, 6, PI / 2.0, s + 1, rim)
			_lash(ci, Vector2(0, 20), PI / 2.0, 5, 2, s + 2)
			_bow(ci, Vector2(0, -4), 64, 10, PI / 2.0, s + 3, rim)
			sil(ci, [ov(Vector2(0, -38), 9, 4, s + 4, WOOD_D, 0.0, 1)], rim)
		4:  # 手斧：一把短柄，夹着半月形石刃
			_shaft(ci, Vector2(-28, 34), Vector2(8, -26), 4.4, s, rim)
			_axehead(ci, Vector2(16, -18), 30, 30, -0.4, s + 1, rim)
			_lash(ci, Vector2(6, -22), -1.0, 6, 3, s + 2)
		5:  # 石锤：木杆加一块方石头，麻绳十字绑
			_shaft(ci, Vector2(-30, 36), Vector2(10, -16), 4.0, s, rim)
			sil(ci, [P(_rrect_rot(Vector2(14, -20), 36, 22, 6, -0.9, s + 1), STONE, 1)], rim)
			_lash(ci, Vector2(14, -20), -0.9 + PI / 2.0, 12, 3, s + 2)
		6:  # 石刀鞘：兽皮刀鞘，露出刀柄
			_shaft(ci, Vector2(14, -22), Vector2(24, -38), 4.0, s, rim, WOOD_D)
			sil(ci, [pg([Vector2(4, -20), Vector2(22, -14), Vector2(-14, 34), Vector2(-26, 30)], s + 1, LEATHER)], rim)
			for k in 4:
				var p := Vector2(10, -16).lerp(Vector2(-20, 30), 0.15 + float(k) * 0.22)
				ln(ci, p + Vector2(-5, -3), p + Vector2(5, 3), 1.6, HIDE, s + k)
			_lash(ci, Vector2(12, -18), -1.1, 7, 2, s + 6)
		7:  # 石凿套：一卷碎皮摊开，插着几把凿子
			sil(ci, [P(_rrect_rot(Vector2(0, 14), 76, 34, 8, -0.1, s), LEATHER, 1)], rim)
			for k in 3:
				var x := -22.0 + float(k) * 20.0
				_shaft(ci, Vector2(x, 26), Vector2(x + 2, -10), 3.0, s + k, false, WOOD_D)
				sil(ci, [pg([Vector2(x - 3, -10), Vector2(x + 6, -10), Vector2(x + 3, -24)], s + k + 4, FLINT)], false)
			sil(ci, [P(_rrect_rot(Vector2(0, 22), 76, 14, 5, -0.1, s + 9), LEATHER.darkened(0.12), 1)], false)
		8:  # 石锛：曲尺形木柄，横绑石锛头
			_shaft(ci, Vector2(-26, 38), Vector2(-6, -24), 4.0, s, rim)
			_shaft(ci, Vector2(-8, -20), Vector2(14, -28), 4.0, s + 1, rim)
			_axehead(ci, Vector2(22, -14), 22, 18, PI / 2.0 + 0.3, s + 2, rim)
			_lash(ci, Vector2(12, -26), 0.0, 5, 3, s + 3)
		9:  # 石斧：长柄，斧头用麻线绑紧
			_shaft(ci, Vector2(-30, 38), Vector2(10, -32), 4.2, s, rim)
			_axehead(ci, Vector2(20, -18), 34, 28, 0.15, s + 1, rim)
			_lash(ci, Vector2(6, -24), -1.05, 6, 4, s + 2)
		10:  # 石杵：长圆石头，上头一截木把
			sil(ci, [ov(Vector2(4, 8), 13, 30, s, STONE, 0.3, 1)], rim)
			_shaft(ci, Vector2(-6, -18), Vector2(-14, -38), 5.0, s + 1, rim)
			_lash(ci, Vector2(-6, -18), -2.0, 6, 3, s + 2)
			hl(ci, Vector2(-2, 4), 4, 14, 0.3, 0.4)
		11:  # 磨石：平石板上压一块圆石，磨出的亮痕
			_slab(ci, Vector2(0, 22), 86, 30, s, rim)
			for k in 3:
				ln(ci, Vector2(-30 + float(k) * 6, 22 + float(k) * 3), Vector2(10 + float(k) * 6, 18 + float(k) * 3), 1.6, Color(1, 1, 1, 0.6), s + k)
			sil(ci, [P(PA.raw_rock(Vector2(16, 4), 16, s + 4, STONE.darkened(0.1))[0], STONE.darkened(0.1), 1)], rim)
		12:  # 石臼：方石头凿出一个坑，旁边石凿
			sil(ci, [bx(-30, -8, 56, 44, 8, s, STONE), ov(Vector2(-2, -8), 28, 9, s + 1, STONE.lightened(0.1), 0.0, 1)], rim)
			ci.draw_colored_polygon(ell(Vector2(-2, -8), Vector2(18, 5.5), s + 2, 0.03, 14), STONE_D)
			_m(ci, "tool_6", Vector2(30, 14), 50, false, 0.5)
		13:  # 石磨盘：一块长圆的磨盘，上面横一根磨棒
			sil(ci, [ov(Vector2(0, 24), 42, 14, s, STONE_D, 0.0, 1), ov(Vector2(0, 18), 40, 13, s + 1, STONE, 0.0, 0)], rim)
			ci.draw_colored_polygon(ell(Vector2(0, 18), Vector2(28, 7), s + 2, 0.03, 14), STONE.lightened(0.12))
			sil(ci, [stk(Vector2(-30, 8), Vector2(30, 2), 8.0, s + 3, STONE.darkened(0.08))], rim)
			hl(ci, Vector2(-8, 2), 12, 2.4, -0.1, 0.5)
		14:  # 石砧：几块方石垒起，顶面平，石凿搁在上面
			for k in 2:
				sil(ci, [bx(-34 + float(k) * 34, 16, 32, 22, 4, s + k, STONE.darkened(0.06 * float(k)))], rim)
			sil(ci, [bx(-26, -6, 52, 24, 4, s + 3, STONE)], rim)
			ln(ci, Vector2(-22, -2), Vector2(22, -2), 1.6, Color(1, 1, 1, 0.5), s)
			_m(ci, "tool_6", Vector2(4, -16), 54, false, 1.2)
		15:  # 木柄石镐：长柄，两头尖的镐头
			_shaft(ci, Vector2(-26, 38), Vector2(8, -26), 4.4, s, rim)
			sil(ci, [pg([Vector2(-26, -14), Vector2(8, -34), Vector2(42, -20), Vector2(10, -22)], s + 1, FLINT)], rim)
			_lash(ci, Vector2(8, -26), -1.1, 6, 4, s + 2)
		16:  # 工具袋：兽皮袋，里面插着刀和凿
			var c := Vector2(0, 6)
			_sack_back(ci, c, 26, Color("b98a5a"), s)
			_shaft(ci, c + Vector2(-8, 4), c + Vector2(-16, -30), 3.0, s + 1, false, WOOD_D)
			_m(ci, "tool_6", c + Vector2(4, -26), 44, false, 0.3)
			_m(ci, "tool_4", c + Vector2(14, -14), 40, false, -0.4)
			_sack_front(ci, c, 26, 32, Color("b98a5a"), s + 2, rim)
			sil(ci, [P(_arc_band(c + Vector2(0, 4), 34, 3, PI + 0.2, TAU - 0.2, s + 4), LEATHER_D, 1)], false)
		17:  # 石匠工具组：毛皮上一字摆开凿、锛头、斧头坯
			sil(ci, [P(_rrect_rot(Vector2(0, 20), 90, 34, 14, -0.05, s), FUR, 1)], rim)
			for k in 6:
				ln(ci, Vector2(-38 + float(k) * 15, 8), Vector2(-34 + float(k) * 15, 14), 1.6, FUR_D, s + k)
			_m(ci, "tool_6", Vector2(-26, 0), 52, false, 0.2)
			_m(ci, "tool_7", Vector2(0, -2), 52, false)
			_m(ci, "tool_8", Vector2(26, 0), 52, false, -0.2)
			sparks(ci, [Vector2(-40, -30), Vector2(38, -34)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 狩猎武器

static func _spear(ci: CanvasItem, a: Vector2, b: Vector2, r: float, head: float, s: int, rim: bool) -> void:
	_shaft(ci, a, b, r, s, rim)
	var d := (b - a).normalized()
	_flake(ci, b + d * head * 0.4, head, head * 0.32, d.angle(), s + 1, rim)
	_lash(ci, b - d * 2, d.angle(), r + 2.0, 3, s + 2)

static func _hunting(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 投石索：两根麻绳，中间皮兜包一块石头
			pl(ci, [Vector2(-36, -30), Vector2(-24, 0), Vector2(-10, 16)], 4.2, INK, s)
			pl(ci, [Vector2(-36, -30), Vector2(-24, 0), Vector2(-10, 16)], 2.4, CORD, s)
			pl(ci, [Vector2(36, -26), Vector2(24, 2), Vector2(12, 16)], 4.2, INK, s + 1)
			pl(ci, [Vector2(36, -26), Vector2(24, 2), Vector2(12, 16)], 2.4, CORD, s + 1)
			sil(ci, [ov(Vector2(0, 20), 16, 10, s + 2, LEATHER, 0.0, 1)], rim)
			sil(ci, [P(PA.raw_rock(Vector2(0, 12), 10, s + 3, STONE)[0], STONE, 1)], rim)
			sil(ci, [circ(Vector2(-36, -32), 4, s + 4, CORD), circ(Vector2(36, -28), 4, s + 5, CORD)], rim)
		2:  # 木矛
			_spear(ci, Vector2(-36, 38), Vector2(26, -26), 3.2, 24, s, rim)
		3:  # 石矛：粗杆，矛头大，绑得多
			_spear(ci, Vector2(-38, 38), Vector2(22, -22), 4.4, 32, s, rim)
			_lash(ci, Vector2(-10, 10), -0.78, 6, 4, s + 6, Color("e6d6a8"))
		4:  # 投掷石刀：半月石刀，系一截麻绳
			pl(ci, [Vector2(-10, 4), Vector2(-26, 20), Vector2(-14, 32), Vector2(-34, 36)], 4.2, INK, s)
			pl(ci, [Vector2(-10, 4), Vector2(-26, 20), Vector2(-14, 32), Vector2(-34, 36)], 2.4, CORD, s)
			_m(ci, "tool_4", Vector2(8, 6), 104, rim, -0.3)
		5:  # 箭
			_arrow(ci, Vector2(-34, 32), Vector2(28, -26), s, rim)
		6:  # 羽箭束：三支箭用绳扎成一束
			for k in 3:
				_arrow(ci, Vector2(-30 + float(k) * 8, 36 - float(k) * 2), Vector2(22 + float(k) * 8, -28 - float(k) * 2), s + k * 5, rim, Color("c8763a") if k == 1 else Color("8a6a4a"))
			_lash(ci, Vector2(0, 4), -0.9, 12, 3, s + 20)
		7:  # 短弓
			_bow(ci, Vector2(6, 2), 70, 20, -0.5, s, rim)
		8:  # 长弓：更长，中间缠皮
			_bow(ci, Vector2(10, 2), 92, 22, -0.6, s, rim, WOOD_D.lightened(0.1))
			_lash(ci, Vector2(-11, 2) + Vector2(0, 0), -0.6 + PI / 2.0, 5, 3, s + 9, LEATHER)
		9:  # 箭袋：兽皮筒，露出一把箭尾
			for k in 3:
				_arrow(ci, Vector2(-6 + float(k) * 8, -30 - float(k % 2) * 4), Vector2(-12 + float(k) * 8, 10), s + k * 4, false)
			sil(ci, [P(_rrect_rot(Vector2(0, 10), 30, 56, 10, 0.12, s + 20), LEATHER, 1)], rim)
			for k in 3:
				ln(ci, Vector2(-12, -6 + float(k) * 14), Vector2(14, -2 + float(k) * 14), 1.8, HIDE, s + k)
			sil(ci, [P(_arc_band(Vector2(0, 2), 26, 2.6, -PI / 2.0 - 1.2, -PI / 2.0 + 1.2, s + 22), LEATHER_D, 1)], false)
		10:  # 绊索陷阱：弯下的树枝，一根绊绳拉到地桩
			sil(ci, [stk(Vector2(-30, 38), Vector2(-30, 10), 3.0, s, WOOD_D), stk(Vector2(-30, 12), Vector2(10, -34), 2.4, s + 1, WOOD)], rim)
			sil(ci, [stk(Vector2(28, 38), Vector2(28, 16), 3.0, s + 2, WOOD_D)], rim)
			pl(ci, [Vector2(10, -34), Vector2(14, -6), Vector2(10, 16)], 3.6, INK, s)
			pl(ci, [Vector2(10, -34), Vector2(14, -6), Vector2(10, 16)], 1.8, CORD, s)
			pl(ci, [Vector2(-30, 30), Vector2(0, 30), Vector2(28, 30)], 3.6, INK, s + 1)
			pl(ci, [Vector2(-30, 30), Vector2(0, 30), Vector2(28, 30)], 1.8, CORD, s + 1)
			ci.draw_arc(Vector2(10, 20), 7, 0, TAU, 14, INK, 3.4, true)
			ci.draw_arc(Vector2(10, 20), 7, 0, TAU, 14, CORD, 1.6, true)
		11:  # 套索：一圈盘好的绳子，打一个活结
			for k in 3:
				ci.draw_arc(Vector2(-6, 8), 26 - float(k) * 4, 0, TAU, 28, INK, 6.0, true)
				ci.draw_arc(Vector2(-6, 8), 26 - float(k) * 4, 0, TAU, 28, Color("8fa060") if k == 1 else CORD, 3.6, true)
			ci.draw_arc(Vector2(22, -18), 12, 0, TAU, 20, INK, 5.0, true)
			ci.draw_arc(Vector2(22, -18), 12, 0, TAU, 20, CORD, 2.8, true)
			_lash(ci, Vector2(14, -8), -0.8, 4, 3, s)
		12:  # 陷坑尖桩：一排削尖的木桩
			for k in 5:
				var x := -32.0 + float(k) * 16.0
				var h := 52.0 - float(k % 2) * 10.0
				sil(ci, [pg([Vector2(x - 5, 36), Vector2(x + 5, 36), Vector2(x + 4, 36 - h + 10), Vector2(x, 36 - h), Vector2(x - 4, 36 - h + 10)], s + k, WOOD)], rim)
				sil(ci, [pg([Vector2(x + 4, 36 - h + 10), Vector2(x, 36 - h), Vector2(x - 4, 36 - h + 10)], s + k + 9, Color("e8c48a"), 0)], false)
			pl(ci, [Vector2(-36, 22), Vector2(36, 20)], 3.0, CORD, s)
		13:  # 猎刀：长石刃，碎皮缠柄
			_flake(ci, Vector2(10, -10), 52, 9, -0.75, s, rim)
			sil(ci, [stk(Vector2(-14, 12), Vector2(-30, 28), 5.0, s + 1, LEATHER)], rim)
			for k in 3:
				var p := Vector2(-16, 14).lerp(Vector2(-28, 26), float(k) / 2.0)
				ln(ci, p + Vector2(-4, 3), p + Vector2(3, -4), 1.6, LEATHER_D, s + k)
		14:  # 投矛器：一根带钩的木板，矛搁在上面
			_spear(ci, Vector2(-40, 26), Vector2(30, -30), 2.6, 20, s, rim)
			sil(ci, [P(_rrect_rot(Vector2(-14, 18), 50, 8, 4, -0.68, s + 6), WOOD_D, 1)], rim)
			sil(ci, [circ(Vector2(-34, 34), 4, s + 7, WOOD_D)], rim)
		15:  # 猎网：一张网，四角坠毛石
			_net(ci, [Vector2(-34, -30), Vector2(30, -34), Vector2(36, 24), Vector2(-30, 28)], 5, 4, s)
			for p in [Vector2(-34, -30), Vector2(30, -34), Vector2(36, 24), Vector2(-30, 28)]:
				sil(ci, [P(PA.raw_rock(p, 7, s, STONE)[0], STONE, 1)], rim)
		16:  # 大石斧：粗原木柄，大斧头
			_shaft(ci, Vector2(-30, 38), Vector2(6, -32), 6.0, s, rim)
			_axehead(ci, Vector2(20, -16), 44, 40, 0.1, s + 1, rim)
			_lash(ci, Vector2(2, -24), -1.1, 8, 4, s + 2)
		17:  # 猛犸长矛：两根木杆接成长杆，长石刃，挂毛皮穗
			glow(ci, Vector2(22, -26), 24, Color(1, 0.9, 0.6))
			_spear(ci, Vector2(-42, 40), Vector2(24, -24), 5.0, 40, s, rim)
			_lash(ci, Vector2(-10, 9), -0.78, 7, 4, s + 6)
			sil(ci, [ov(Vector2(14, -2), 7, 14, s + 7, FUR, 0.4, 1), ov(Vector2(20, 0), 5, 11, s + 8, FUR_D, 0.2, 1)], rim)
			sparks(ci, [Vector2(-34, -30), Vector2(40, -40)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 照明取暖

## 陶灯的灯芯在材料图里的位置（size 100）
const LAMP_WICK := Vector2(28, -2)

static func _light(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 松枝火把：一捆树枝扎成，顶上松脂
			_torch(ci, Vector2(-12, 38), Vector2(8, -14), Color("6a8a3a"), s, rim)
			_m(ci, "craft_4", Vector2(24, 26), 40, false)
		2:  # 桦皮火把：木杆顶上裹白桦皮
			_torch(ci, Vector2(-12, 38), Vector2(8, -14), BIRCH, s, rim)
			for k in 3:
				ln(ci, Vector2(1 + float(k) * 3, -22 + float(k) * 4), Vector2(9 + float(k) * 3, -20 + float(k) * 4), 1.4, INK, s + k)
		3:  # 松脂火把：顶上一大块松脂
			_torch(ci, Vector2(-12, 38), Vector2(8, -14), RESIN, s, rim, 16)
		4:  # 火种罐：陶罐里闷着红炭，插一根小树枝
			var mo := _pmouth("pot_6", Vector2(0, 8), 150)
			sil(ci, [stk((mo[0] as Vector2) + Vector2(2, 2), (mo[0] as Vector2) + Vector2(14, -22), 2.0, s, WOOD_D)], rim)
			_m(ci, "pot_6", Vector2(0, 8), 150, rim)
			_surface(ci, mo, Color("ff5a22"), s)
			glow(ci, mo[0], 20, Color(1, 0.5, 0.2))
			smoke(ci, (mo[0] as Vector2) + Vector2(-4, -12), 0.5)
		5:  # 篝火堆：毛石围一圈，中间劈柴，大火
			_stonering(ci, Vector2(0, 24), 36, 10, 9, 8, s, rim, true)
			_m(ci, "furn_7", Vector2(0, 22), 80, false)
			glow(ci, Vector2(0, 0), 34, Color(1, 0.6, 0.2))
			flame(ci, Vector2(0, -2), 24, 40, s + 3, rim)
			_stonering(ci, Vector2(0, 24), 36, 10, 9, 8, s, rim, false)
		6:  # 石火盆：两块石板围成盆，里面柴火
			glow(ci, Vector2(0, -4), 34, Color(1, 0.6, 0.2))
			flame(ci, Vector2(0, -4), 22, 36, s, rim)
			sil(ci, [pg([Vector2(-40, 4), Vector2(-6, 10), Vector2(-8, 36), Vector2(-34, 32)], s + 1, STONE), pg([Vector2(40, 4), Vector2(6, 10), Vector2(8, 36), Vector2(34, 32)], s + 2, STONE.darkened(0.08))], rim)
			sil(ci, [stk(Vector2(-14, 12), Vector2(14, 8), 4.0, s + 3, WOOD_D)], false)
		7, 8, 10:  # 松脂灯 / 陶油灯 / 长明灯
			if n == 10:
				glow(ci, Vector2(0, -6), 44, Color(1, 0.9, 0.6))
			_m(ci, "pot_5", Vector2(-8, -6), 150, rim)
			var wick := Vector2(-8, -6) + LAMP_WICK * 1.5
			glow(ci, wick + Vector2(0, -10), 18 if n == 7 else 26, Color(1, 0.7, 0.3))
			match n:
				7: _m(ci, "craft_5", Vector2(-28, 28), 40, false)
				8: _m(ci, "craft_6", Vector2(-28, 28), 40, false)
				10:
					_m(ci, "gem_2", Vector2(-28, 24), 50, false)
					sparks(ci, [Vector2(-36, -30), Vector2(36, -36)], 5.0)
		9:  # 灯笼：棕榈叶编的笼子，里面透着陶灯的光
			sil(ci, [stk(Vector2(0, -44), Vector2(0, -28), 1.8, s, CORD)], rim)
			glow(ci, Vector2(0, 4), 36, Color(1, 0.75, 0.35))
			var cage := [Vector2(-8, -30), Vector2(8, -30), Vector2(26, -8), Vector2(24, 22), Vector2(10, 32), Vector2(-10, 32), Vector2(-24, 22), Vector2(-26, -8)]
			sil(ci, [pg(cage, s + 1, Color("ffd88a"))], rim)
			for k in 5:
				var x := -18.0 + float(k) * 9.0
				pl(ci, [Vector2(x * 0.3, -30), Vector2(x * 1.3, 0), Vector2(x * 0.5, 32)], 3.0, PALM.darkened(0.2), s + k)
			flame(ci, Vector2(0, 8), 8, 14, s + 7)
			sil(ci, [ov(Vector2(0, -30), 10, 3, s + 8, PALM.darkened(0.25), 0.0, 1), ov(Vector2(0, 32), 12, 3, s + 9, PALM.darkened(0.25), 0.0, 1)], false)
		11:  # 暖炉：大陶缸开几个孔，里面红光
			glow(ci, Vector2(0, 0), 46, Color(1, 0.55, 0.2))
			var mo := _pmouth("pot_13", Vector2(0, 8), 110)
			flame(ci, (mo[0] as Vector2) + Vector2(0, -8), 16, 24, s, rim)
			_m(ci, "pot_13", Vector2(0, 8), 110, rim)
			_surface(ci, mo, Color("ff6a2a"), s)
			for k in 3:
				sil(ci, [circ(Vector2(-14 + float(k) * 14, 12), 4.5, s + k, Color("ffb040"))], false, 2.0)
			_m(ci, "furn_6", Vector2(30, 32), 40, false)
		12:  # 火塘石圈：方石和毛石围一大圈，两根原木架火
			glow(ci, Vector2(0, 0), 52, Color(1, 0.6, 0.2))
			_stonering(ci, Vector2(0, 22), 42, 13, 11, 9, s, rim, true)
			sil(ci, [stk(Vector2(-30, 26), Vector2(26, 4), 6.0, s + 1, WOOD_D), stk(Vector2(-26, 4), Vector2(30, 26), 6.0, s + 2, WOOD)], rim)
			flame(ci, Vector2(0, -4), 26, 44, s + 3, rim)
			_stonering(ci, Vector2(0, 22), 42, 13, 11, 9, s + 5, rim, false)
			sparks(ci, [Vector2(-40, -36), Vector2(40, -34)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 渔具

static func _hook(ci: CanvasItem, top: Vector2, sz: float, s: int, rim: bool, col: Color = BONE) -> void:
	var r := sz * 0.3
	var bot := top + Vector2(0, sz - r)
	var pts := [top]
	for k in 5:
		pts.append(top.lerp(bot, float(k + 1) / 5.0))
	for k in 9:
		var a := PI - float(k + 1) * PI * 1.05 / 9.0
		pts.append(bot + Vector2(r + r * cos(a), r * sin(a)))
	var tip: Vector2 = pts[pts.size() - 1]
	var w := maxf(sz * 0.11, 2.6)
	var line := PackedVector2Array(pts)
	if rim:
		ci.draw_polyline(line, RIM_COL, w + 9.0, true)
	ci.draw_polyline(line, INK, w + 3.4, true)
	ci.draw_polyline(line, col, w, true)
	var barb := PackedVector2Array([tip + Vector2(-w * 0.6, w * 0.6), tip + Vector2(-w * 1.6, w * 2.6), tip + Vector2(w * 0.6, -w * 0.4)])
	ci.draw_colored_polygon(barb, col)
	ci.draw_polyline(PackedVector2Array([barb[0], barb[1], barb[2]]), INK, 1.6, true)
	ci.draw_circle(top, w * 0.7, INK)

static func _fishgear(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 鱼钩：一只骨钩，系着麻线
			pl(ci, [Vector2(-30, -38), Vector2(-14, -30), Vector2(4, -28)], 3.8, INK, s)
			pl(ci, [Vector2(-30, -38), Vector2(-14, -30), Vector2(4, -28)], 2.0, CORD, s)
			_hook(ci, Vector2(4, -30), 52, s, rim)
		2:  # 钓线：一团线绕在小木片上，垂下一只钩
			sil(ci, [P(_rrect_rot(Vector2(-12, -4), 36, 30, 6, -0.2, s), WOOD, 1)], rim)
			for k in 5:
				ln(ci, Vector2(-26, -14 + float(k) * 5).rotated(0.0), Vector2(2, -18 + float(k) * 5), 2.4, CORD, s + k)
			pl(ci, [Vector2(4, 0), Vector2(16, 8), Vector2(20, 2)], 3.6, INK, s)
			pl(ci, [Vector2(4, 0), Vector2(16, 8), Vector2(20, 2)], 1.8, CORD, s)
			_hook(ci, Vector2(20, 2), 28, s + 4, rim)
		3:  # 钓竿：弯竿，线垂下挂钩
			var rod := [Vector2(-38, 38), Vector2(-14, 4), Vector2(10, -22), Vector2(34, -36)]
			for k in 3:
				sil(ci, [stk(rod[k], rod[k + 1], 3.8 - float(k) * 0.9, s + k, WOOD)], rim)
			pl(ci, [Vector2(34, -36), Vector2(36, -10), Vector2(34, 10)], 1.6, INK, s)
			_hook(ci, Vector2(34, 10), 18, s + 4, rim, FLINT_L)
		4:  # 网坠：几个小陶坠穿在麻线上
			pl(ci, [Vector2(-40, -10), Vector2(-14, 4), Vector2(14, 4), Vector2(40, -10)], 3.6, INK, s)
			pl(ci, [Vector2(-40, -10), Vector2(-14, 4), Vector2(14, 4), Vector2(40, -10)], 2.0, CORD, s)
			for k in 4:
				var p := Vector2(-30 + float(k) * 20, 4 + float(k % 3 == 0) * -4)
				sil(ci, [ov(p + Vector2(0, 12), 8, 10, s + k, CLAYPOT, 0.0, 1)], rim)
				ci.draw_circle(p + Vector2(0, 8), 2.0, INK)
		5:  # 小渔网：一张折起的小网，麻束收口
			_net(ci, [Vector2(-30, -28), Vector2(22, -32), Vector2(34, 20), Vector2(-24, 28)], 4, 4, s)
			_lash(ci, Vector2(-28, -26), -0.8, 8, 3, s + 5)
			for p in [Vector2(22, -32), Vector2(34, 20), Vector2(-24, 28)]:
				sil(ci, [circ(p, 4, s, Color("e8d08a"))], rim)
		6:  # 石鱼叉：杆子头上三根石齿
			_shaft(ci, Vector2(-34, 38), Vector2(14, -14), 3.6, s, rim)
			var d := Vector2(cos(-0.78), sin(-0.78))
			var nn := Vector2(-d.y, d.x)
			var parts := [stk(Vector2(14, -14) + nn * 12, Vector2(14, -14) - nn * 12, 3.0, s + 9, WOOD_D)]
			for k in 3:
				var b := Vector2(14, -14) + nn * (float(k) - 1.0) * 10.0
				parts.append(stk(b, b + d * (22 if k == 1 else 16), 2.6, s + k, FLINT))
				parts.append(pg([b + d * (22 if k == 1 else 16) + nn * 4, b + d * (32 if k == 1 else 26), b + d * (22 if k == 1 else 16) - nn * 4], s + k + 3, FLINT))
			sil(ci, parts, rim)
			_lash(ci, Vector2(10, -10), -0.78, 5, 3, s + 5)
		7:  # 鱼篓：藤编的细口篓，口上一圈藤环
			_wicker(ci, [Vector2(-12, -22), Vector2(12, -22), Vector2(26, 4), Vector2(22, 32), Vector2(-22, 32), Vector2(-26, 4)], Rect2(-24, -18, 48, 48), s, rim)
			sil(ci, [ov(Vector2(0, -22), 15, 5, s + 2, Color("9a7a3a"), 0.0, 1)], rim)
			ci.draw_colored_polygon(ell(Vector2(0, -22), Vector2(9, 2.6), s, 0.0, 12), INK)
			_m(ci, "fish_3", Vector2(10, -24), 40, false, -1.0)
		8:  # 虾笼：横放的长笼子，一头是漏斗口
			_wicker(ci, [Vector2(-34, -10), Vector2(30, -16), Vector2(36, 4), Vector2(30, 26), Vector2(-34, 30), Vector2(-40, 10)], Rect2(-36, -12, 70, 40), s, rim, Color("b89050"))
			sil(ci, [ov(Vector2(-36, 10), 8, 20, s + 2, Color("9a7a3a"), 0.0, 1)], false)
			ci.draw_colored_polygon(ell(Vector2(-36, 10), Vector2(4, 9), s, 0.0, 12), INK)
			for k in 3:
				_lash(ci, Vector2(-16 + float(k) * 20, 8), 0.0, 20, 1, s + k)
		9:  # 鱼梁：水里一排木桩，桩脚压毛石
			sil(ci, [ov(Vector2(0, 26), 44, 12, s, WATER, 0.0, 1)], rim)
			for k in 5:
				var x := -32.0 + float(k) * 16.0
				sil(ci, [stk(Vector2(x, 28 - float(k % 2) * 4), Vector2(x + 2, -22 + float(k % 2) * 6), 3.2, s + k, WOOD)], rim)
			pl(ci, [Vector2(-34, 0), Vector2(34, -4)], 2.4, CORD, s)
			for k in 4:
				sil(ci, [P(PA.raw_rock(Vector2(-24 + float(k) * 16, 30), 6, s + k, STONE)[0], STONE, 1)], false)
			for k in 3:
				ln(ci, Vector2(-30 + float(k) * 22, 36), Vector2(-20 + float(k) * 22, 36), 1.8, Color(1, 1, 1, 0.7), s + k)
		10:  # 晒鱼架：两根桩架一根横木，麻线挂鱼
			sil(ci, [stk(Vector2(-34, 38), Vector2(-30, -28), 3.4, s, WOOD_D), stk(Vector2(34, 38), Vector2(30, -28), 3.4, s + 1, WOOD_D),
				stk(Vector2(-40, -26), Vector2(40, -30), 3.4, s + 2, WOOD)], rim)
			for k in 3:
				var x := -16.0 + float(k) * 16.0
				pl(ci, [Vector2(x, -28), Vector2(x, -16)], 1.4, CORD, s + k)
				_m(ci, "fish_3", Vector2(x, 4), 54, false, PI / 2.0)
		11:  # 渔具箱：木板箱，装着线团和鱼钩
			sil(ci, [bx(-34, -4, 68, 40, 4, s, WOOD)], rim)
			sil(ci, [P(_rrect_rot(Vector2(-8, -16), 66, 10, 3, -0.3, s + 1), WOOD.lightened(0.08), 1)], rim)
			for k in 2:
				ln(ci, Vector2(-32, 8 + float(k) * 12), Vector2(32, 8 + float(k) * 12), 1.6, WOOD_D, s + k)
			_m(ci, "cloth_6", Vector2(16, -12), 40, false)
			_hook(ci, Vector2(-14, -20), 18, s + 4, false)
		12:  # 独木舟桨
			_shaft(ci, Vector2(-30, -38), Vector2(10, 4), 3.6, s, rim)
			sil(ci, [ov(Vector2(20, 18), 12, 24, s + 1, WOOD, -0.78, 1)], rim)
			ln(ci, Vector2(12, 10), Vector2(28, 26), 1.6, WOOD_D, s)
			sil(ci, [stk(Vector2(-34, -38), Vector2(-24, -40), 4.0, s + 2, WOOD_D)], rim)
		13:  # 大渔网：一张大网，下缘挂小陶坠，上缘浮子
			_net(ci, [Vector2(-40, -30), Vector2(40, -30), Vector2(36, 28), Vector2(-36, 28)], 6, 5, s)
			for k in 5:
				sil(ci, [ov(Vector2(-32 + float(k) * 16, -30), 5, 4, s + k, Color("e8d08a"), 0.0, 1)], rim)
				sil(ci, [ov(Vector2(-30 + float(k) * 15, 30), 4, 5, s + k + 5, CLAYPOT, 0.0, 1)], rim)
		14:  # 渔筏：几根原木绑成筏，放在水上
			sil(ci, [ov(Vector2(0, 26), 48, 16, s, WATER, 0.0, 1)], rim)
			for k in 3:
				ln(ci, Vector2(-40 + float(k) * 30, 36), Vector2(-28 + float(k) * 30, 36), 1.8, Color(1, 1, 1, 0.7), s + k)
			var logs := []
			for k in 4:
				var y := -6.0 + float(k) * 8.0
				logs.append(stk(Vector2(-38 + float(k) * 2, y), Vector2(38 - float(k) * 2, y + 4), 5.0, s + k, WOOD.darkened(0.08 * float(k % 2))))
			sil(ci, logs, rim)
			for x in [-24.0, 22.0]:
				_lash(ci, Vector2(x, 12), PI / 2.0 + 0.1, 16, 1, s, Color("8fa060"))
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 家园的零件

const RATTAN := Color("b98d48")
const RATTAN_D := Color("8a6630")
const HEMP := Color("e2cf9a")
const LINEN := Color("efe4c8")
const HIDE_C := Color("d9b07a")

## 一块木板（可旋转）
static func _plank(ci: CanvasItem, c: Vector2, w: float, h: float, rot: float, s: int, rim: bool, col: Color = WOOD) -> void:
	sil(ci, [P(_rrect_rot(c, w, h, minf(h * 0.3, 4.0), rot, s), col, 1)], rim)
	if w > 24.0:
		ln(ci, c + Vector2(-w * 0.35, -h * 0.1).rotated(rot), c + Vector2(w * 0.3, -h * 0.15).rotated(rot), 1.2, Color(WOOD_D, 0.8), s)

## 一张摊开的兽皮：四角拉开的不规则形状
static func _hide(c: Vector2, w: float, h: float, s: int, col: Color = HIDE_C) -> Array:
	return pg([c + Vector2(-w * 0.5, -h * 0.5), c + Vector2(-w * 0.2, -h * 0.38), c + Vector2(w * 0.2, -h * 0.42), c + Vector2(w * 0.5, -h * 0.5),
		c + Vector2(w * 0.4, 0), c + Vector2(w * 0.5, h * 0.5), c + Vector2(w * 0.15, h * 0.4), c + Vector2(-w * 0.2, h * 0.44),
		c + Vector2(-w * 0.5, h * 0.5), c + Vector2(-w * 0.42, 0)], s, col)

## 一块方石
static func _block(ci: CanvasItem, r: Rect2, s: int, rim: bool, col: Color = STONE) -> void:
	sil(ci, [bx(r.position.x, r.position.y, r.size.x, r.size.y, 3, s, col)], rim)
	ln(ci, r.position + Vector2(3, 3), r.position + Vector2(r.size.x - 4, 3), 1.4, Color(1, 1, 1, 0.45), s)

## 一盘绳子
static func _coil(ci: CanvasItem, c: Vector2, r: float, n: int, col: Color, s: int) -> void:
	for k in n:
		var rr := r - float(k) * 5.0
		ci.draw_colored_polygon(ell(c, Vector2(rr + 3, (rr + 3) * 0.55), s + k, 0.0, 24), INK)
		ci.draw_colored_polygon(ell(c, Vector2(rr, rr * 0.55), s + k, 0.0, 24), col.darkened(0.06 * float(k % 2)))
		ci.draw_colored_polygon(ell(c, Vector2(rr - 3.2, (rr - 3.2) * 0.55), s + k, 0.0, 24), INK)
	ci.draw_colored_polygon(ell(c, Vector2(r - float(n) * 5.0 + 1.0, (r - float(n) * 5.0 + 1.0) * 0.55), s, 0.0, 16), col.darkened(0.35))
	for k in 10:
		var a := float(k) * TAU / 10.0
		ln(ci, c + Vector2(cos(a) * (r - 2), sin(a) * (r - 2) * 0.55), c + Vector2(cos(a + 0.2) * (r - 5), sin(a + 0.2) * (r - 5) * 0.55), 1.2, Color(INK, 0.4), s + k)

# ---------------------------------------------------------------- 草编藤编

static func _cweave(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 草绳：一盘草绳，绳头翘出来
			sil(ci, [ov(Vector2(0, 14), 36, 21, s, GRASS, 0.0, 1)], rim)
			_coil(ci, Vector2(0, 12), 34, 4, GRASS, s)
			sil(ci, [stk(Vector2(30, 10), Vector2(40, -14), 2.6, s + 5, GRASS)], rim)
		2:  # 草垫：一张圆草垫，一圈圈盘起
			sil(ci, [ov(Vector2(0, 20), 42, 18, s, GRASS_D, 0.0, 1), ov(Vector2(0, 16), 42, 18, s + 1, GRASS, 0.0, 0)], rim)
			for k in 4:
				ci.draw_polyline(ell(Vector2(0, 16), Vector2(36 - float(k) * 9, (36 - float(k) * 9) * 0.43), s + k, 0.0, 28), Color(GRASS_D, 0.9), 1.6, true)
		3:  # 草帽：尖顶宽檐
			sil(ci, [ov(Vector2(0, 18), 42, 14, s, GRASS, 0.0, 1), pg([Vector2(-24, 14), Vector2(0, -30), Vector2(24, 14)], s + 1, GRASS.lightened(0.05))], rim)
			for k in 4:
				pl(ci, [Vector2(-20 + float(k) * 5, 10 - float(k) * 9), Vector2(20 - float(k) * 5, 10 - float(k) * 9)], 1.4, GRASS_D, s + k)
			sil(ci, [stk(Vector2(-22, 12), Vector2(22, 12), 2.6, s + 6, Color("c9a86a"))], false)
		4:  # 草鞋：一双草鞋，脚跟塞了兽毛
			for k in 2:
				var c := Vector2(-16 + float(k) * 30, 14 - float(k) * 10)
				sil(ci, [ov(c, 13, 26, s + k, GRASS, 0.25, 1)], rim)
				for j in 4:
					ln(ci, c + Vector2(-9, -16 + float(j) * 9).rotated(0.25), c + Vector2(9, -16 + float(j) * 9).rotated(0.25), 1.4, GRASS_D, s + j)
				pl(ci, [c + Vector2(-11, -2).rotated(0.25), c + Vector2(0, -12).rotated(0.25), c + Vector2(11, -2).rotated(0.25)], 3.0, Color("9c7a3a"), s)
				sil(ci, [ov(c + Vector2(0, 18).rotated(0.25), 7, 5, s + 5 + k, FUR, 0.0, 1)], false)
		5:  # 麻绳：一盘麻绳，打了个结
			_coil(ci, Vector2(0, 12), 36, 4, HEMP, s)
			sil(ci, [stk(Vector2(-30, 8), Vector2(-40, -16), 3.0, s + 5, HEMP)], rim)
			sil(ci, [circ(Vector2(-40, -18), 4.5, s + 6, HEMP)], rim)
		6:  # 草席：卷起一半的长席
			sil(ci, [P(_rrect_rot(Vector2(8, 18), 66, 30, 3, -0.15, s), GRASS, 1)], rim)
			for k in 6:
				ln(ci, Vector2(-20 + float(k) * 11, 6 + float(k) * -1.6), Vector2(-16 + float(k) * 11, 30 - float(k) * 1.6), 1.4, GRASS_D, s + k)
			sil(ci, [P(_rrect_rot(Vector2(-28, 10), 20, 40, 9, -0.15, s + 7), GRASS.darkened(0.06), 1)], rim)
			ci.draw_arc(Vector2(-31, -9), 5, 0, TAU, 12, GRASS_D, 1.6, true)
			_lash(ci, Vector2(-28, 10), -0.15, 9, 1, s + 9, Color("c9a86a"))
		7:  # 麻布：木杆上搭着一匹麻布
			sil(ci, [stk(Vector2(-42, -28), Vector2(42, -32), 3.2, s, WOOD)], rim)
			var cloth := [Vector2(-28, -30), Vector2(26, -32), Vector2(30, 0), Vector2(24, 32), Vector2(8, 26), Vector2(-6, 34), Vector2(-22, 26), Vector2(-30, 2)]
			sil(ci, [pg(cloth, s + 1, LINEN)], rim)
			for k in 3:
				pl(ci, [Vector2(-14 + float(k) * 13, -26), Vector2(-16 + float(k) * 13, 4), Vector2(-12 + float(k) * 13, 26)], 1.4, Color(INK, 0.3), s + k)
			sil(ci, [stk(Vector2(-42, -28), Vector2(42, -32), 3.2, s, WOOD)], false)
		8:  # 麻线网兜：网兜装着几个果子，口上收绳
			_m(ci, "fruit_6", Vector2(-8, 0), 52, false)
			_m(ci, "fruit_4", Vector2(10, 4), 48, false)
			var bag := [Vector2(-8, -24), Vector2(8, -24), Vector2(28, 0), Vector2(22, 26), Vector2(0, 34), Vector2(-22, 26), Vector2(-28, 0)]
			for w in [3.6, 1.8]:
				var col: Color = INK if w > 2.0 else HEMP
				ci.draw_polyline(PackedVector2Array(bag + [bag[0]]), col, w, true)
				for k in 5:
					var x := -20.0 + float(k) * 10.0
					ci.draw_polyline(PackedVector2Array([Vector2(x * 0.35, -24), Vector2(x * 1.2, 4), Vector2(x * 0.6, 30)]), col, w, true)
				for k in 3:
					var y := -12.0 + float(k) * 14.0
					ci.draw_polyline(PackedVector2Array([Vector2(-26, y), Vector2(0, y + 4), Vector2(26, y)]), col, w, true)
			sil(ci, [stk(Vector2(-8, -24), Vector2(0, -40), 2.0, s, HEMP), stk(Vector2(8, -24), Vector2(0, -40), 2.0, s + 1, HEMP)], rim)
		9:  # 棕榈扇：一片棕榈叶扇面，小树枝柄
			_shaft(ci, Vector2(-4, 40), Vector2(0, 0), 3.0, s, rim)
			var parts := []
			for k in 7:
				var a := -PI / 2.0 - 1.1 + float(k) * 2.2 / 6.0
				parts.append(ov(Vector2(0, 0) + Vector2(cos(a), sin(a)) * 20, 22, 6, s + k, PALM.darkened(0.06 * float(k % 2)), a, 1))
			sil(ci, parts, rim)
			for k in 7:
				var a := -PI / 2.0 - 1.1 + float(k) * 2.2 / 6.0
				ln(ci, Vector2.ZERO + Vector2(cos(a), sin(a)) * 4, Vector2(cos(a), sin(a)) * 38, 1.2, Color(LEAF_D, 0.8), s + k)
			_lash(ci, Vector2(0, 2), PI / 2.0, 4, 2, s + 9)
		10:  # 棕榈雨披：几层棕榈叶叠成的斗篷，麻线系领口
			var parts := []
			for row in 3:
				for k in 5:
					var x := -26.0 + float(k) * 13.0 - float(row) * 0.0
					var y := -16.0 + float(row) * 16.0
					parts.append(ov(Vector2(x * (0.7 + 0.15 * float(row)), y + 8), 7, 16, s + row * 5 + k, PALM.darkened(0.05 * float((k + row) % 2)), 0.1 * float(k - 2), 1))
			sil(ci, parts, rim)
			sil(ci, [stk(Vector2(-12, -24), Vector2(12, -24), 3.0, s + 20, HEMP)], false)
			sil(ci, [circ(Vector2(0, -24), 4, s + 21, HEMP)], false)
		11:  # 草编门帘：横杆下垂一排草帘
			var parts := []
			for k in 9:
				var x := -32.0 + float(k) * 8.0
				parts.append(stk(Vector2(x, -26), Vector2(x + sin(float(k)) * 2.0, 32 - float(k % 3) * 4), 3.2, s + k, PALM.darkened(0.08 * float(k % 2))))
			sil(ci, parts, rim)
			sil(ci, [stk(Vector2(-40, -28), Vector2(40, -28), 3.4, s + 10, WOOD)], rim)
			for k in 2:
				pl(ci, [Vector2(-36, -6 + float(k) * 18), Vector2(36, -6 + float(k) * 18)], 1.6, HEMP, s + k)
		12:  # 棕榈屋顶片：木杆上一层层压的棕榈叶
			var parts := []
			for row in 3:
				for k in 6:
					var x := -32.0 + float(k) * 13.0
					parts.append(ov(Vector2(x, -12 + float(row) * 14), 9, 14, s + row * 6 + k, PALM.darkened(0.06 * float(row)), 0.15, 1))
			sil(ci, parts, rim)
			sil(ci, [stk(Vector2(-42, -26), Vector2(42, -26), 3.4, s + 20, WOOD), stk(Vector2(-42, 6), Vector2(42, 6), 3.0, s + 21, WOOD)], false)
		13:  # 背篓：高筒藤篓，两条麻束背带
			_wicker(ci, [Vector2(-22, -30), Vector2(22, -30), Vector2(18, 30), Vector2(-18, 30)], Rect2(-20, -26, 40, 54), s, rim, RATTAN)
			sil(ci, [ov(Vector2(0, -30), 22, 5, s + 1, RATTAN_D, 0.0, 1)], rim)
			ci.draw_colored_polygon(ell(Vector2(0, -30), Vector2(16, 2.6), s, 0.0, 12), INK)
			for x in [-12.0, 12.0]:
				pl(ci, [Vector2(x, -26), Vector2(x * 1.9, -6), Vector2(x * 1.2, 20)], 4.4, INK, s)
				pl(ci, [Vector2(x, -26), Vector2(x * 1.9, -6), Vector2(x * 1.2, 20)], 2.6, HEMP, s)
		14:  # 藤篮：圆篮带提手
			sil(ci, [P(_arc_band(Vector2(0, 2), 28, 4.0, PI, TAU, s), RATTAN_D, 1)], rim)
			_wicker(ci, [Vector2(-34, 0), Vector2(34, 0), Vector2(26, 32), Vector2(-26, 32)], Rect2(-32, 2, 64, 30), s + 1, rim, RATTAN)
			sil(ci, [stk(Vector2(-34, 0), Vector2(34, 0), 3.4, s + 2, RATTAN_D)], false)
		15:  # 藤盾：藤环编的圆盾，中间蒙兽皮
			sil(ci, [ov(Vector2(0, 2), 36, 38, s, RATTAN, 0.0, 1)], rim)
			for k in 3:
				ci.draw_polyline(ell(Vector2(0, 2), Vector2(32 - float(k) * 5, 34 - float(k) * 5), s + k, 0.0, 28), RATTAN_D, 1.6, true)
			sil(ci, [ov(Vector2(0, 2), 18, 20, s + 4, HIDE_C, 0.0, 1)], false)
			sil(ci, [circ(Vector2(0, 2), 6, s + 5, LEATHER_D, 1)], false)
			for k in 4:
				var a := float(k) * PI / 2.0 + 0.4
				ci.draw_circle(Vector2(0, 2) + Vector2(cos(a) * 13, sin(a) * 15), 1.8, INK)
		16:  # 藤编箱：方箱，木板盖
			_wicker(ci, [Vector2(-36, -8), Vector2(36, -8), Vector2(34, 34), Vector2(-34, 34)], Rect2(-34, -6, 68, 40), s, rim, RATTAN)
			_plank(ci, Vector2(0, -12), 80, 12, 0.0, s + 1, rim)
			sil(ci, [bx(-5, -8, 10, 10, 2, s + 2, RATTAN_D)], false)
		17:  # 藤编吊床：两根木桩，中间垂一张藤网
			sil(ci, [stk(Vector2(-40, 38), Vector2(-38, -30), 3.6, s, WOOD_D), stk(Vector2(40, 38), Vector2(38, -30), 3.6, s + 1, WOOD_D)], rim)
			var top := []
			var bot := []
			for k in 9:
				var t := float(k) / 8.0
				top.append(Vector2(-36 + t * 72, -18 + sin(t * PI) * 26))
				bot.append(Vector2(-36 + t * 72, -18 + sin(t * PI) * 38))
			sil(ci, [pg(_band_pts(top, bot), s + 2, RATTAN)], rim)
			for k in 7:
				var t := float(k + 1) / 8.0
				ln(ci, top[k + 1], bot[k + 1], 1.4, RATTAN_D, s + k)
			pl(ci, [Vector2(-38, -26), Vector2(-36, -18)], 2.0, HEMP, s)
			pl(ci, [Vector2(38, -26), Vector2(36, -18)], 2.0, HEMP, s + 1)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

## 两条线围成的带子
static func _band_pts(top: Array, bot: Array) -> Array:
	var out := top.duplicate()
	var rb := bot.duplicate()
	rb.reverse()
	out.append_array(rb)
	return out

# ---------------------------------------------------------------- 家具家什

static func _furniture(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 挂衣杆：立杆，分出几个短杈，挂一件皮衣
			sil(ci, [stk(Vector2(0, 38), Vector2(0, -38), 3.6, s, WOOD), stk(Vector2(0, -20), Vector2(-16, -32), 2.4, s + 1, WOOD), stk(Vector2(0, -8), Vector2(16, -20), 2.4, s + 2, WOOD),
				stk(Vector2(-18, 38), Vector2(18, 38), 3.0, s + 3, WOOD_D)], rim)
			sil(ci, [_hide(Vector2(-14, -10), 20, 28, s + 4)], rim)
		2:  # 木枕：一块半圆劈柴，上面铺兽毛
			sil(ci, [P(_rrect_rot(Vector2(0, 18), 66, 26, 10, 0.0, s), WOOD, 1)], rim)
			ci.draw_polyline(ell(Vector2(-30, 18), Vector2(4, 11), s, 0.0, 12), WOOD_D, 1.4, true)
			sil(ci, [ov(Vector2(0, 4), 30, 10, s + 1, FUR, 0.0, 1)], rim)
			for k in 6:
				ln(ci, Vector2(-22 + float(k) * 9, 0), Vector2(-20 + float(k) * 9, 8), 1.4, FUR_D, s + k)
		3:  # 木碗架：几根木杆搭的小架子，搁两只陶碗
			sil(ci, [stk(Vector2(-30, 38), Vector2(-30, -20), 2.6, s, WOOD), stk(Vector2(30, 38), Vector2(30, -20), 2.6, s + 1, WOOD),
				stk(Vector2(-34, 6), Vector2(34, 6), 2.6, s + 2, WOOD_D), stk(Vector2(-34, -16), Vector2(34, -16), 2.6, s + 3, WOOD_D)], rim)
			_m(ci, "pot_3", Vector2(-12, -16), 70, false)
			_m(ci, "pot_3", Vector2(14, 6), 70, false)
		4:  # 树墩凳：一截原木，年轮朝上
			sil(ci, [P(rrect(Rect2(-28, -4, 56, 40), 8, s, 0.6), WOOD, 1), ov(Vector2(0, -4), 28, 10, s + 1, Color("e2b77a"), 0.0, 1)], rim)
			rings(ci, Vector2(0, -4), Vector2(22, 7.5), s, 3)
			for k in 3:
				ln(ci, Vector2(-18 + float(k) * 16, 6), Vector2(-20 + float(k) * 16, 30), 1.4, WOOD_D, s + k)
		5:  # 藤椅：藤环做靠背，木杆腿
			sil(ci, [stk(Vector2(-22, 38), Vector2(-20, 10), 3.0, s, WOOD_D), stk(Vector2(22, 38), Vector2(20, 10), 3.0, s + 1, WOOD_D)], rim)
			sil(ci, [ov(Vector2(0, -12), 26, 28, s + 2, RATTAN, 0.0, 1)], rim)
			for k in 3:
				ci.draw_polyline(ell(Vector2(0, -12), Vector2(22 - float(k) * 6, 24 - float(k) * 6), s + k, 0.0, 24), RATTAN_D, 1.6, true)
			sil(ci, [P(_rrect_rot(Vector2(0, 12), 56, 12, 5, 0.0, s + 4), RATTAN.lightened(0.06), 1)], rim)
		6:  # 摇篮：弧形藤篮，铺碎皮，底下两道摇脚
			sil(ci, [P(_arc_band(Vector2(0, -2), 40, 4, 0.35, PI - 0.35, s), WOOD_D, 1)], rim)
			_wicker(ci, [Vector2(-34, -10), Vector2(34, -10), Vector2(26, 22), Vector2(-26, 22)], Rect2(-32, -8, 64, 30), s + 1, rim, RATTAN)
			sil(ci, [ov(Vector2(0, -10), 30, 6, s + 2, HIDE_C, 0.0, 1)], false)
		7:  # 屏风：木杆框架，绷两张兽皮
			for k in 2:
				var x := -18.0 + float(k) * 36.0
				sil(ci, [_hide(Vector2(x, 0), 32, 54, s + k, HIDE_C.darkened(0.06 * float(k)))], rim)
			sil(ci, [stk(Vector2(-36, 38), Vector2(-36, -32), 2.6, s + 3, WOOD), stk(Vector2(0, 38), Vector2(0, -32), 2.6, s + 4, WOOD), stk(Vector2(36, 38), Vector2(36, -32), 2.6, s + 5, WOOD),
				stk(Vector2(-38, -28), Vector2(38, -28), 2.6, s + 6, WOOD_D)], rim)
		8:  # 毛皮坐垫：干草垫上压一块毛皮
			sil(ci, [ov(Vector2(0, 24), 40, 13, s, GRASS, 0.0, 1)], rim)
			sil(ci, [ov(Vector2(0, 10), 34, 16, s + 1, FUR, 0.0, 1)], rim)
			for k in 8:
				var a := float(k) * TAU / 8.0
				ln(ci, Vector2(cos(a) * 22, 10 + sin(a) * 9), Vector2(cos(a) * 28, 10 + sin(a) * 12), 1.6, FUR_D, s + k)
			hl(ci, Vector2(-10, 4), 10, 4, -0.1, 0.35)
		9:  # 木梯：两根细原木，几道横档用麻束绑
			sil(ci, [stk(Vector2(-22, 40), Vector2(-12, -40), 3.6, s, WOOD), stk(Vector2(22, 40), Vector2(12, -40), 3.6, s + 1, WOOD)], rim)
			for k in 5:
				var t := 0.12 + float(k) * 0.19
				var a := Vector2(-22, 40).lerp(Vector2(-12, -40), t)
				var b := Vector2(22, 40).lerp(Vector2(12, -40), t)
				sil(ci, [stk(a, b, 2.4, s + k + 2, WOOD_D)], false)
				_lash(ci, a, 0.0, 3, 1, s + k)
		10:  # 草垫床：两根原木搭边，中间堆一层厚干草
			sil(ci, [stk(Vector2(-38, 2), Vector2(38, 2), 4.4, s, WOOD_D)], rim)
			sil(ci, [ov(Vector2(0, 12), 40, 18, s + 1, GRASS, 0.0, 1)], rim)
			for k in 9:
				ln(ci, Vector2(-30 + float(k) * 7, 2 + float(k % 2) * 4), Vector2(-26 + float(k) * 7, 18 - float(k % 3) * 2), 1.4, GRASS_D, s + k)
			sil(ci, [stk(Vector2(-42, 30), Vector2(42, 30), 5.0, s + 2, WOOD)], rim)
			ci.draw_polyline(ell(Vector2(-42, 30), Vector2(3, 5), s, 0.0, 10), WOOD_D, 1.2, true)
		11:  # 皮褥床：原木床架，两张兽皮叠着
			sil(ci, [P(rrect(Rect2(-42, 10, 84, 22), 6, s, 0.6), WOOD, 1)], rim)
			ci.draw_polyline(ell(Vector2(-42, 21), Vector2(4, 10), s, 0.0, 12), WOOD_D, 1.2, true)
			sil(ci, [_hide(Vector2(-4, 6), 76, 24, s + 1, HIDE_C), _hide(Vector2(8, 0), 60, 20, s + 2, FUR)], rim)
			sil(ci, [ov(Vector2(-30, 0), 12, 7, s + 3, LINEN, 0.0, 1)], false)
		12:  # 木桌：木板桌面，四根木杆腿
			for x in [-32.0, 30.0]:
				sil(ci, [stk(Vector2(x, 38), Vector2(x + 2, 0), 3.2, s, WOOD_D)], rim)
			_plank(ci, Vector2(0, -2), 86, 14, 0.0, s + 1, rim)
			for x in [-22.0, 22.0]:
				sil(ci, [stk(Vector2(x, 30), Vector2(x, 6), 3.0, s + 2, WOOD_D)], false)
		13:  # 木箱：木板钉的箱子，盖子半开
			sil(ci, [bx(-36, -6, 72, 42, 4, s, WOOD)], rim)
			for k in 2:
				ln(ci, Vector2(-34, 8 + float(k) * 13), Vector2(34, 8 + float(k) * 13), 1.6, WOOD_D, s + k)
			sil(ci, [P(_rrect_rot(Vector2(-4, -14), 76, 12, 4, -0.18, s + 3), WOOD.lightened(0.08), 1)], rim)
			for x in [-26.0, 26.0]:
				sil(ci, [bx(x - 4, -6, 8, 42, 2, s + 4, WOOD_D)], false)
		14:  # 石桌：方石墩上架一块平石板
			_block(ci, Rect2(-14, 2, 28, 36), s, rim)
			_slab(ci, Vector2(0, -6), 88, 22, s + 1, rim)
		15:  # 储物架：木杆框，三层木板
			sil(ci, [stk(Vector2(-32, 40), Vector2(-32, -38), 3.0, s, WOOD_D), stk(Vector2(32, 40), Vector2(32, -38), 3.0, s + 1, WOOD_D)], rim)
			for k in 3:
				_plank(ci, Vector2(0, -30 + float(k) * 26), 76, 8, 0.0, s + 2 + k, rim)
			_m(ci, "seed_7", Vector2(-14, -34), 30, false)
			_m(ci, "craft_2", Vector2(10, -10), 36, false)
			_m(ci, "furn_13", Vector2(-12, 14), 40, false)
		16:  # 陶罐架：两层木板架，放双耳罐
			sil(ci, [stk(Vector2(-36, 40), Vector2(-36, -38), 3.0, s, WOOD_D), stk(Vector2(36, 40), Vector2(36, -38), 3.0, s + 1, WOOD_D)], rim)
			for k in 2:
				_plank(ci, Vector2(0, -4 + float(k) * 36), 82, 8, 0.0, s + 2 + k, rim)
			_m(ci, "pot_9", Vector2(-14, -26), 62, false)
			_m(ci, "pot_6", Vector2(16, -24), 60, false)
			_m(ci, "pot_3", Vector2(0, 12), 70, false)
		17:  # 大木柜：大木梁做框，两扇门
			sil(ci, [bx(-34, -38, 68, 76, 5, s, WOOD)], rim)
			sil(ci, [bx(-30, -32, 28, 62, 3, s + 1, WOOD.lightened(0.06), 0), bx(2, -32, 28, 62, 3, s + 2, WOOD.lightened(0.06), 0)], false)
			for x in [-6.0, 6.0]:
				sil(ci, [circ(Vector2(x, 0), 3, s + 3, WOOD_D)], false)
			_plank(ci, Vector2(0, -40), 80, 8, 0.0, s + 4, false, WOOD_D)
		18:  # 首领宝座：大木梁靠背，铺毛皮卷，镶绿松石
			glow(ci, Vector2(0, -8), 50, Color(1, 0.85, 0.45))
			sil(ci, [P(rrect(Rect2(-28, -40, 56, 56), 10, s, 0.6), WOOD_D, 1), bx(-38, 2, 76, 18, 5, s + 1, WOOD), bx(-36, 18, 10, 20, 3, s + 2, WOOD_D), bx(26, 18, 10, 20, 3, s + 3, WOOD_D)], rim)
			sil(ci, [_hide(Vector2(0, -6), 44, 52, s + 4, FUR)], false)
			for k in 3:
				var p := Vector2(-14 + float(k) * 14, -36)
				sil(ci, [circ(p, 4.5, s + k, Color("4fc4b8"))], false, 2.0)
			_m(ci, "gem_5", Vector2(0, -44), 34, false)
			sparks(ci, [Vector2(-42, -36), Vector2(42, -32)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 搭建材料

static func _building(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 木栅栏：几根木杆竖着，两道横杆麻束绑
			var parts := []
			for k in 5:
				var x := -32.0 + float(k) * 16.0
				parts.append(pg([Vector2(x - 4, 36), Vector2(x + 4, 36), Vector2(x + 4, -22), Vector2(x, -30), Vector2(x - 4, -22)], s + k, WOOD.darkened(0.05 * float(k % 2))))
			sil(ci, parts, rim)
			sil(ci, [stk(Vector2(-40, -8), Vector2(40, -10), 2.6, s + 6, WOOD_D), stk(Vector2(-40, 18), Vector2(40, 16), 2.6, s + 7, WOOD_D)], false)
			for k in 5:
				_lash(ci, Vector2(-32 + float(k) * 16, -9), PI / 2.0, 4, 1, s + k)
		2:  # 茅草顶：三角形屋顶，层层茅草
			sil(ci, [pg([Vector2(-44, 26), Vector2(0, -34), Vector2(44, 26)], s, PALM.darkened(0.12))], rim)
			for row in 4:
				var y := -18.0 + float(row) * 13.0
				var half := (y + 34.0) * 44.0 / 60.0
				pl(ci, [Vector2(-half, y + 6), Vector2(half, y + 6)], 2.0, LEAF_D, s + row)
				for k in int(half / 6.0):
					var x := -half + float(k) * 12.0 + 6.0
					ln(ci, Vector2(x, y - 4), Vector2(x - 1, y + 6), 1.2, Color(LEAF_D, 0.7), s + k)
			sil(ci, [stk(Vector2(-6, -40), Vector2(6, -28), 2.4, s + 9, WOOD_D), stk(Vector2(6, -40), Vector2(-6, -28), 2.4, s + 10, WOOD_D)], false)
		3:  # 篱笆门：细原木门框，中间藤条编的门板
			sil(ci, [stk(Vector2(-32, 38), Vector2(-32, -36), 4.0, s, WOOD), stk(Vector2(32, 38), Vector2(32, -36), 4.0, s + 1, WOOD), stk(Vector2(-38, -32), Vector2(38, -32), 4.0, s + 2, WOOD_D)], rim)
			_wicker(ci, [Vector2(-26, -24), Vector2(26, -24), Vector2(26, 34), Vector2(-26, 34)], Rect2(-24, -22, 48, 54), s + 3, rim, RATTAN)
			sil(ci, [stk(Vector2(-26, -24), Vector2(26, 34), 2.4, s + 4, RATTAN_D)], false)
		4:  # 皮帐篷：几根木杆撑起，兽皮围成锥
			for k in 3:
				sil(ci, [stk(Vector2(-8 + float(k) * 8, -28), Vector2(-14 + float(k) * 14, -44), 2.0, s + k, WOOD_D)], rim)
			sil(ci, [pg([Vector2(0, -32), Vector2(40, 34), Vector2(-40, 34)], s + 4, HIDE_C)], rim)
			sil(ci, [pg([Vector2(0, -10), Vector2(12, 34), Vector2(-12, 34)], s + 5, LEATHER_D, 0)], false)
			for k in 3:
				pl(ci, [Vector2(-28 + float(k) * 4, 14 - float(k) * 14), Vector2(28 - float(k) * 4, 14 - float(k) * 14)], 1.4, Color(LEATHER_D, 0.6), s + k)
		5:  # 石阶：三级方石台阶
			for k in 3:
				_block(ci, Rect2(-36 + float(k) * 12, 22 - float(k) * 18, 72 - float(k) * 12, 18), s + k, rim, STONE.darkened(0.05 * float(2 - k)))
		6:  # 石灶台：方石垒的灶，前面火口，顶上石板
			_block(ci, Rect2(-34, -4, 68, 42), s, rim)
			ci.draw_colored_polygon(ell(Vector2(0, 22), Vector2(14, 14), s, 0.0, 16), INK)
			glow(ci, Vector2(0, 24), 16, Color(1, 0.55, 0.2))
			flame(ci, Vector2(0, 26), 10, 14, s + 1)
			_slab(ci, Vector2(0, -8), 84, 18, s + 2, rim)
		7:  # 石墙段：方石和毛石错缝砌
			var parts := []
			for row in 3:
				for k in 3:
					var x := -38.0 + float(k) * 26.0 + float(row % 2) * 12.0
					parts.append(bx(x, 18 - float(row) * 20, 24, 18, 3, s + row * 3 + k, STONE.darkened(0.06 * float((row + k) % 3))))
			sil(ci, parts, rim)
		8:  # 木地板：一排木板，两根细原木垫底
			sil(ci, [stk(Vector2(-40, 30), Vector2(30, 34), 4.0, s, WOOD_D), stk(Vector2(-30, -6), Vector2(40, -2), 4.0, s + 1, WOOD_D)], rim)
			var parts := []
			for k in 5:
				parts.append(P(_rrect_rot(Vector2(-22 + float(k) * 12, 14), 12, 56, 2, 0.35, s + 2 + k), WOOD.darkened(0.05 * float(k % 2)), 1))
			sil(ci, parts, rim)
		9:  # 木屋梁：两根大木梁搭成人字，横梁一根，麻线绑
			sil(ci, [stk(Vector2(-40, 34), Vector2(0, -34), 5.0, s, WOOD), stk(Vector2(40, 34), Vector2(0, -34), 5.0, s + 1, WOOD), stk(Vector2(-30, 14), Vector2(30, 14), 4.4, s + 2, WOOD_D)], rim)
			_lash(ci, Vector2(0, -30), 0.0, 6, 3, s + 3)
			_lash(ci, Vector2(-24, 14), PI / 2.0, 6, 2, s + 4)
			_lash(ci, Vector2(24, 14), PI / 2.0, 6, 2, s + 5)
		10:  # 吊桥：两道藤绳之间一排木板
			var top := []
			var bot := []
			for k in 9:
				var t := float(k) / 8.0
				top.append(Vector2(-42 + t * 84, -20 + sin(t * PI) * 22))
				bot.append(Vector2(-42 + t * 84, -2 + sin(t * PI) * 22))
			var planks := []
			for k in 7:
				var p := ((top[k + 1] as Vector2) + (bot[k + 1] as Vector2)) * 0.5
				planks.append(P(_rrect_rot(p, 8, 22, 2, 0.0, s + k), WOOD.darkened(0.06 * float(k % 2)), 1))
			sil(ci, planks, rim)
			for line in [top, bot]:
				ci.draw_polyline(PackedVector2Array(line), INK, 4.6, true)
				ci.draw_polyline(PackedVector2Array(line), Color("8fa060"), 2.6, true)
			sil(ci, [stk(Vector2(-42, 38), Vector2(-42, -26), 3.2, s + 9, WOOD_D), stk(Vector2(42, 38), Vector2(42, -26), 3.2, s + 10, WOOD_D)], rim)
		11:  # 石柱门：两根石柱上压一块巨石
			sil(ci, [bx(-34, -14, 18, 52, 4, s, STONE), bx(16, -14, 18, 52, 4, s + 1, STONE.darkened(0.06))], rim)
			sil(ci, [bx(-42, -34, 84, 22, 6, s + 2, STONE.lightened(0.05))], rim)
			ln(ci, Vector2(-36, -30), Vector2(36, -30), 1.6, Color(1, 1, 1, 0.45), s)
		12:  # 瞭望台：四根木梁撑起平台，顶上棚子
			sil(ci, [stk(Vector2(-30, 40), Vector2(-20, -10), 3.6, s, WOOD_D), stk(Vector2(30, 40), Vector2(20, -10), 3.6, s + 1, WOOD_D),
				stk(Vector2(-26, 22), Vector2(24, 2), 2.4, s + 2, WOOD), stk(Vector2(26, 22), Vector2(-24, 2), 2.4, s + 3, WOOD)], rim)
			_plank(ci, Vector2(0, -12), 62, 10, 0.0, s + 4, rim)
			sil(ci, [stk(Vector2(-24, -14), Vector2(-24, -34), 2.4, s + 5, WOOD_D), stk(Vector2(24, -14), Vector2(24, -34), 2.4, s + 6, WOOD_D)], rim)
			sil(ci, [pg([Vector2(-34, -30), Vector2(0, -46), Vector2(34, -30)], s + 7, PALM.darkened(0.12))], rim)
			sil(ci, [P(_arc_band(Vector2(0, -12), 22, 2.0, 0.2, PI - 0.2, s + 8), Color("8fa060"), 1)], false)
		13:  # 长屋骨架：香柏巨木做脊，大木梁一排人字架，石柱作基
			glow(ci, Vector2(0, -4), 52, Color(1, 0.85, 0.5))
			for k in 3:
				var x := -24.0 + float(k) * 24.0
				sil(ci, [stk(Vector2(x - 22, 34), Vector2(x + 4, -26), 3.0, s + k, WOOD), stk(Vector2(x + 26, 34), Vector2(x + 4, -26), 3.0, s + k + 3, WOOD)], rim)
			sil(ci, [stk(Vector2(-26, -26), Vector2(36, -26), 4.4, s + 7, Color("c0603a"))], rim)
			for k in 4:
				_block(ci, Rect2(-46 + float(k) * 28, 28, 14, 12), s + k + 9, rim)
			sparks(ci, [Vector2(-42, -40), Vector2(42, -38)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 穿戴、巫祭的零件

const TURQ := Color("4fc4b8")
const AMETH := Color("9a6ad0")
const QUARTZ := Color("e2eef2")
const DIAMOND := Color("d8f4ff")
const WOLF := Color("8f8f96")
const FOX := Color("e07a2e")
const BEAD_COLS := [Color("d2512d"), Color("4fc4b8"), Color("f2d07a"), Color("fff7e6")]

## 一条绳子沿弧线（项链、手串）
static func _string(ci: CanvasItem, pts: Array, col: Color = CORD) -> void:
	var line := PackedVector2Array(pts)
	ci.draw_polyline(line, INK, 3.8, true)
	ci.draw_polyline(line, col, 2.0, true)

## 椭圆上取点
static func _ring_pts(c: Vector2, rx: float, ry: float, a0: float, a1: float, n: int) -> Array:
	var out := []
	for k in n + 1:
		var a := lerpf(a0, a1, float(k) / float(n))
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out

## 一根羽毛
static func _feather(ci: CanvasItem, base: Vector2, l: float, ang: float, col: Color, s: int, rim: bool) -> void:
	var d := Vector2(cos(ang), sin(ang))
	sil(ci, [ov(base + d * l * 0.55, l * 0.45, l * 0.16, s, col, ang, 1), stk(base, base + d * l * 0.3, 1.4, s + 1, BONE, 0)], rim)
	ln(ci, base + d * l * 0.15, base + d * l * 0.95, 1.2, Color(INK, 0.6), s)
	for k in 3:
		var p := base + d * l * (0.4 + float(k) * 0.16)
		ln(ci, p, p + d.rotated(-0.9) * l * 0.12, 1.0, Color(INK, 0.35), s + k)

## 小宝石：切面
static func _gem(ci: CanvasItem, c: Vector2, r: float, col: Color, s: int, rim: bool) -> void:
	cut_gem(ci, c, r, col, s, rim)

## 衣服的基本剪影（上衣）：肩、袖、下摆
static func _tunic(ci: CanvasItem, c: Vector2, w: float, h: float, col: Color, s: int, rim: bool, sleeves: bool = true) -> void:
	var pts := [c + Vector2(-w * 0.18, -h * 0.5), c + Vector2(-w * 0.5, -h * 0.38)]
	if sleeves:
		pts.append_array([c + Vector2(-w * 0.72, -h * 0.05), c + Vector2(-w * 0.55, h * 0.05), c + Vector2(-w * 0.4, -h * 0.12)])
	pts.append_array([c + Vector2(-w * 0.42, h * 0.5), c + Vector2(w * 0.42, h * 0.5)])
	if sleeves:
		pts.append_array([c + Vector2(w * 0.4, -h * 0.12), c + Vector2(w * 0.55, h * 0.05), c + Vector2(w * 0.72, -h * 0.05)])
	pts.append_array([c + Vector2(w * 0.5, -h * 0.38), c + Vector2(w * 0.18, -h * 0.5), c + Vector2(0, -h * 0.36)])
	sil(ci, [pg(pts, s, col)], rim)

## 披风：上窄下宽的弧形
static func _cape(ci: CanvasItem, c: Vector2, w: float, h: float, col: Color, s: int, rim: bool) -> void:
	var pts := [c + Vector2(-w * 0.2, -h * 0.5), c + Vector2(w * 0.2, -h * 0.5), c + Vector2(w * 0.5, h * 0.3), c + Vector2(w * 0.35, h * 0.5),
		c + Vector2(0, h * 0.42), c + Vector2(-w * 0.35, h * 0.5), c + Vector2(-w * 0.5, h * 0.3)]
	sil(ci, [pg(pts, s, col)], rim)

## 毛边：沿一条线画一排短毛
static func _fuzz(ci: CanvasItem, a: Vector2, b: Vector2, n: int, col: Color, s: int) -> void:
	var parts := []
	for k in n:
		parts.append(circ(a.lerp(b, (float(k) + 0.5) / float(n)), (b - a).length() / float(n) * 0.75, s + k, col.lightened(0.05 * float(k % 2)), 0))
	sil(ci, parts, false, 2.0)

# ---------------------------------------------------------------- 首饰

static func _jewelry(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1, 11, 12:  # 手串：种子 / 坚果 / 螺壳
			var ring := _ring_pts(Vector2(0, 8), 30, 20, 0, TAU, 24)
			_string(ci, ring)
			var cnt := 10 if n == 1 else 8
			for k in cnt:
				var a := float(k) * TAU / float(cnt)
				var p := Vector2(0, 8) + Vector2(cos(a) * 30, sin(a) * 20)
				match n:
					1: sil(ci, [ov(p, 6, 4.5, s + k, SEED.darkened(0.1 * float(k % 2)), a, 1)], false, 2.0)
					11: _m(ci, "seed_8" if k % 2 == 0 else "seed_5", p + Vector2(0, -6), 28, rim)
					12: _m(ci, "clam_1" if k % 3 else "clam_7", p + Vector2(0, -6), 30, rim)
		2:  # 羽毛发簪：小树枝簪子，尾端插麻雀羽毛
			sil(ci, [stk(Vector2(-34, 34), Vector2(26, -22), 2.6, s, WOOD)], rim)
			sil(ci, [pg([Vector2(26, -22), Vector2(36, -34), Vector2(30, -18)], s + 1, WOOD_D)], rim)
			_feather(ci, Vector2(-26, 26), 36, -2.2, Color("a87a4a"), s + 2, rim)
			_feather(ci, Vector2(-26, 26), 30, -1.7, Color("6a5a4a"), s + 3, rim)
		3, 8, 10, 13:  # 项链：石英 / 绿松石 / 彩珠 / 贝壳
			var arc := _ring_pts(Vector2(0, -16), 34, 44, 0.1, PI - 0.1, 20)
			_string(ci, arc)
			for k in 9:
				var p: Vector2 = arc[1 + k * 2]
				var col: Color = [QUARTZ, TURQ, BEAD_COLS[k % 4], HEMP][[3, 8, 10, 13].find(n)]
				if n == 3 and k % 2 == 0:
					sil(ci, [PA.crystal(p + Vector2(0, 4), 2.6, 4, 0.0, s + k, QUARTZ)], false, 2.0)
				elif n == 13:
					if k % 2 == 0:
						_m(ci, "clam_6", p + Vector2(0, -2), 30, rim)
				else:
					sil(ci, [circ(p, 4.4, s + k, col)], false, 2.0)
			var pend: Vector2 = arc[10] + Vector2(0, 6)
			match n:
				3: sil(ci, [PA.crystal(pend + Vector2(0, 14), 6, 12, 0.0, s + 20, QUARTZ)], rim)
				8: _gem(ci, pend + Vector2(0, 6), 9, TURQ, s + 20, rim)
				10: sil(ci, [ov(pend + Vector2(0, 6), 7, 9, s + 20, CLAYPOT, 0.0, 1)], rim)
				13: _m(ci, "clam_6", pend + Vector2(0, -6), 50, rim)
		4:  # 兽毛手环：麻束扎成环，包着兽毛
			sil(ci, [ov(Vector2(0, 8), 32, 22, s, FUR, 0.0, 1)], rim)
			ci.draw_colored_polygon(ell(Vector2(0, 8), Vector2(18, 10), s + 1, 0.04, 18), Color("f3e6c8"))
			ci.draw_polyline(ell(Vector2(0, 8), Vector2(18, 10), s + 1, 0.04, 18), INK, 2.4, true)
			for k in 10:
				var a := float(k) * TAU / 10.0
				ln(ci, Vector2(cos(a) * 22, 8 + sin(a) * 14), Vector2(cos(a) * 31, 8 + sin(a) * 21), 1.6, FUR_D, s + k)
			_lash(ci, Vector2(26, 8), PI / 2.0, 6, 3, s + 12, HEMP)
		5:  # 石英手镯：麻束编环，镶三颗石英
			ci.draw_polyline(ell(Vector2(0, 10), Vector2(30, 20), s, 0.0, 28), INK, 8.0, true)
			ci.draw_polyline(ell(Vector2(0, 10), Vector2(30, 20), s, 0.0, 28), HEMP, 5.0, true)
			for k in 3:
				sil(ci, [PA.crystal(Vector2(-14 + float(k) * 14, 32 - float(k % 2) * 3), 4, 6, 0.0, s + k, QUARTZ)], rim)
		6:  # 晶簇发冠：一圈头带，正中石英晶簇，两侧秃鹫羽
			_feather(ci, Vector2(-14, -6), 34, -2.0, Color("4a3a3a"), s, rim)
			_feather(ci, Vector2(14, -6), 34, -1.14, Color("4a3a3a"), s + 1, rim)
			ci.draw_polyline(ell(Vector2(0, 14), Vector2(36, 14), s, 0.0, 28), INK, 9.0, true)
			ci.draw_polyline(ell(Vector2(0, 14), Vector2(36, 14), s, 0.0, 28), LEATHER, 6.0, true)
			_m(ci, "gem_3", Vector2(0, -6), 70, rim)
		7:  # 绿松石耳坠：一对，钩子加绿松石坠
			for k in 2:
				var x := -14.0 + float(k) * 28.0
				ci.draw_arc(Vector2(x, -24), 7, PI, TAU + 0.6, 12, INK, 4.0, true)
				ci.draw_arc(Vector2(x, -24), 7, PI, TAU + 0.6, 12, CORD, 2.0, true)
				_string(ci, [Vector2(x - 7, -24), Vector2(x - 6, -6)])
				_gem(ci, Vector2(x - 6, 8), 10, TURQ, s + k, rim)
		9:  # 绿松石腰带：皮带一圈，镶一排绿松石
			ci.draw_polyline(ell(Vector2(0, 6), Vector2(38, 20), s, 0.0, 28), INK, 13.0, true)
			ci.draw_polyline(ell(Vector2(0, 6), Vector2(38, 20), s, 0.0, 28), LEATHER, 9.0, true)
			for k in 5:
				var a := 0.4 + float(k) * (PI - 0.8) / 4.0
				sil(ci, [circ(Vector2(cos(a) * 38, 6 + sin(a) * 20), 4.6, s + k, TURQ)], false, 2.0)
			_gem(ci, Vector2(0, 28), 9, TURQ, s + 9, rim)
		14:  # 紫晶戒指：骨环上镶紫晶
			ci.draw_polyline(ell(Vector2(0, 14), Vector2(22, 16), s, 0.0, 24), INK, 10.0, true)
			ci.draw_polyline(ell(Vector2(0, 14), Vector2(22, 16), s, 0.0, 24), BONE, 6.4, true)
			_gem(ci, Vector2(0, -6), 15, AMETH, s + 1, rim)
		15:  # 紫晶头饰：头带正中紫晶簇，后面雁羽
			_feather(ci, Vector2(-6, -10), 40, -1.9, Color("a8a08a"), s, rim)
			_feather(ci, Vector2(6, -10), 40, -1.24, Color("8a8270"), s + 1, rim)
			ci.draw_polyline(ell(Vector2(0, 16), Vector2(36, 14), s, 0.0, 28), INK, 9.0, true)
			ci.draw_polyline(ell(Vector2(0, 16), Vector2(36, 14), s, 0.0, 28), HEMP, 6.0, true)
			_m(ci, "gem_8", Vector2(0, 0), 64, rim)
		16:  # 羽冠：一排雁羽鹰羽扇开
			for k in 7:
				var a := -PI / 2.0 + (float(k) - 3.0) * 0.28
				_feather(ci, Vector2(0, 18), 46 - absf(float(k) - 3.0) * 4.0, a, Color("8a6a4a") if k % 2 == 0 else Color("f1ece0"), s + k, rim)
			sil(ci, [P(_arc_band(Vector2(0, -6), 34, 4.0, 0.6, PI - 0.6, s + 9), LEATHER, 1)], rim)
		17:  # 鹰羽披肩：毛皮披肩，下摆一圈鹰羽
			for k in 6:
				_feather(ci, Vector2(-26 + float(k) * 10.4, 10), 28, PI / 2.0 + (float(k) - 2.5) * 0.12, Color("6a4a2a") if k % 2 == 0 else Color("e8dcc8"), s + k, rim)
			sil(ci, [pg([Vector2(-14, -26), Vector2(14, -26), Vector2(36, 12), Vector2(-36, 12)], s + 8, FUR)], rim)
			_fuzz(ci, Vector2(-14, -26), Vector2(14, -26), 5, FUR.lightened(0.15), s + 9)
		18:  # 鹦鹉螺吊坠
			_string(ci, _ring_pts(Vector2(0, -40), 26, 34, 0.25, PI - 0.25, 14))
			_m(ci, "clam_11", Vector2(0, 4), 74, rim)
		19:  # 菊石胸针：大菊石，边上镶绿松石
			_m(ci, "clam_12", Vector2(0, 0), 82, rim)
			for k in 3:
				var a := -2.6 + float(k) * 0.6
				sil(ci, [circ(Vector2(cos(a) * 30, -2 + sin(a) * 26), 5, s + k, TURQ)], rim)
		20:  # 首领项圈：毛皮领圈，紫晶洞居中，两边绿松石
			glow(ci, Vector2(0, 8), 44, Color(0.85, 0.6, 1.0))
			ci.draw_polyline(PackedVector2Array(_ring_pts(Vector2(0, -16), 36, 38, 0.05, PI - 0.05, 20)), INK, 18.0, true)
			ci.draw_polyline(PackedVector2Array(_ring_pts(Vector2(0, -16), 36, 38, 0.05, PI - 0.05, 20)), FUR, 14.0, true)
			for k in 4:
				var a := 0.45 + float(k) * 0.75
				if k == 1 or k == 2:
					continue
				_gem(ci, Vector2(0, -16) + Vector2(cos(a) * 36, sin(a) * 38), 7, TURQ, s + k, rim)
			_m(ci, "gem_9", Vector2(0, 14), 60, rim)
			sparks(ci, [Vector2(-38, -34), Vector2(38, -30)], 5.0)
		21:  # 钻石额饰：毛皮额带，正中一颗大钻石
			glow(ci, Vector2(0, -4), 40, Color(0.8, 0.95, 1.0))
			ci.draw_polyline(ell(Vector2(0, 10), Vector2(38, 16), s, 0.0, 28), INK, 14.0, true)
			ci.draw_polyline(ell(Vector2(0, 10), Vector2(38, 16), s, 0.0, 28), FUR, 10.0, true)
			_gem(ci, Vector2(0, -8), 18, DIAMOND, s + 1, rim)
			sparks(ci, [Vector2(-20, -30), Vector2(22, -34), Vector2(38, -12)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 皮毛衣物

static func _clothes(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 草裙：麻秆腰带，下垂一圈草
			var parts := []
			for k in 11:
				var x := -30.0 + float(k) * 6.0
				parts.append(stk(Vector2(x, -10), Vector2(x * 1.25, 34 - float(k % 2) * 4), 2.6, s + k, GRASS.darkened(0.08 * float(k % 2))))
			sil(ci, parts, rim)
			sil(ci, [stk(Vector2(-34, -12), Vector2(34, -12), 3.6, s + 12, Color("c9a86a"))], rim)
		2:  # 兽毛围脖：一圈蓬松兽毛，麻束扎口
			sil(ci, [ov(Vector2(0, 8), 36, 22, s, FUR, 0.0, 1)], rim)
			ci.draw_colored_polygon(ell(Vector2(0, 4), Vector2(18, 8), s, 0.04, 16), FUR_D.darkened(0.3))
			for k in 12:
				var a := float(k) * TAU / 12.0
				ln(ci, Vector2(cos(a) * 24, 8 + sin(a) * 14), Vector2(cos(a) * 34, 8 + sin(a) * 20), 1.6, FUR_D, s + k)
			_lash(ci, Vector2(28, 14), 0.8, 6, 2, s + 12, HEMP)
		3:  # 皮腰带：卷起的皮带，骨扣
			sil(ci, [P(_rrect_rot(Vector2(6, 22), 62, 12, 5, -0.1, s), LEATHER, 1)], rim)
			sil(ci, [ov(Vector2(-18, 4), 22, 20, s + 1, LEATHER, 0.0, 1)], rim)
			ci.draw_polyline(ell(Vector2(-18, 4), Vector2(14, 12), s, 0.0, 18), LEATHER_D, 2.0, true)
			sil(ci, [P(_arc_band(Vector2(32, 20), 8, 3, -PI / 2.0, PI / 2.0, s + 2), BONE, 1)], rim)
		4:  # 皮护腕：一截皮筒，麻线交叉系带
			sil(ci, [P(rrect(Rect2(-22, -26, 44, 58), 10, s, 0.6), LEATHER, 1), ov(Vector2(0, -26), 22, 7, s + 1, LEATHER_D, 0.0, 1)], rim)
			for k in 4:
				var y := -16.0 + float(k) * 12.0
				ln(ci, Vector2(-6, y), Vector2(6, y + 10), 2.0, HEMP, s + k)
				ln(ci, Vector2(6, y), Vector2(-6, y + 10), 2.0, HEMP, s + k + 4)
		5:  # 皮手套：一对连指皮手套
			for k in 2:
				var c := Vector2(-16 + float(k) * 30, 6 - float(k) * 6)
				var rot := -0.2 + float(k) * 0.35
				sil(ci, [P(_rrect_rot(c, 26, 40, 12, rot, s + k), LEATHER.darkened(0.06 * float(k)), 1),
					P(_rrect_rot(c + Vector2(-14, 2).rotated(rot), 10, 18, 5, rot - 0.5, s + k + 2), LEATHER.darkened(0.06 * float(k)), 1)], rim)
				ln(ci, c + Vector2(-13, 14).rotated(rot), c + Vector2(13, 14).rotated(rot), 2.0, HIDE, s + k)
		6:  # 皮背心：无袖短上衣，正面系带
			_tunic(ci, Vector2(0, 4), 70, 68, HIDE_C, s, rim, false)
			for k in 3:
				ln(ci, Vector2(-5, -10 + float(k) * 12), Vector2(5, -6 + float(k) * 12), 2.0, LEATHER_D, s + k)
			ln(ci, Vector2(0, -20), Vector2(0, 36), 1.4, Color(INK, 0.5), s)
		7:  # 皮裙：兽皮裙，下摆流苏，腰上草绳
			sil(ci, [pg([Vector2(-26, -16), Vector2(26, -16), Vector2(36, 24), Vector2(-36, 24)], s, HIDE_C)], rim)
			for k in 9:
				var x := -32.0 + float(k) * 8.0
				sil(ci, [stk(Vector2(x, 22), Vector2(x * 1.05, 34), 2.0, s + k, HIDE_C.darkened(0.08))], false)
			sil(ci, [stk(Vector2(-28, -16), Vector2(28, -16), 3.4, s + 12, GRASS)], rim)
		8:  # 婴儿背带：一大片兽皮兜，藤环收口，麻束带子
			pl(ci, [Vector2(20, 0), Vector2(30, -26), Vector2(-24, -34), Vector2(-20, -8)], 5.0, INK, s)
			pl(ci, [Vector2(20, 0), Vector2(30, -26), Vector2(-24, -34), Vector2(-20, -8)], 3.0, HEMP, s)
			sil(ci, [pg([Vector2(-32, -6), Vector2(30, -10), Vector2(24, 22), Vector2(0, 34), Vector2(-26, 24)], s + 1, HIDE_C)], rim)
			ci.draw_polyline(ell(Vector2(24, -8), Vector2(8, 8), s, 0.0, 14), INK, 6.0, true)
			ci.draw_polyline(ell(Vector2(24, -8), Vector2(8, 8), s, 0.0, 14), RATTAN, 3.4, true)
		9:  # 兽皮靴：一双高筒皮靴，系麻线
			for k in 2:
				var x := -16.0 + float(k) * 30.0
				sil(ci, [pg([Vector2(x - 10, -28), Vector2(x + 8, -28), Vector2(x + 8, 18), Vector2(x + 20, 26), Vector2(x + 18, 36), Vector2(x - 12, 36), Vector2(x - 12, 10)], s + k, LEATHER.darkened(0.08 * float(k)))], rim)
				_fuzz(ci, Vector2(x - 11, -28), Vector2(x + 9, -28), 4, FUR, s + k)
				_lash(ci, Vector2(x - 1, 0), PI / 2.0, 10, 2, s + k + 4, HEMP)
		10:  # 皮袄：长袖皮衣，毛领
			_tunic(ci, Vector2(0, 6), 74, 66, HIDE_C.darkened(0.05), s, rim)
			_fuzz(ci, Vector2(-14, -26), Vector2(14, -26), 5, FUR, s + 1)
			_fuzz(ci, Vector2(-30, 38), Vector2(30, 38), 7, FUR, s + 2)
		11:  # 毛皮帽：圆顶毛皮帽，两个护耳
			sil(ci, [ov(Vector2(-26, 14), 9, 16, s, FUR_D, 0.2, 1), ov(Vector2(26, 14), 9, 16, s + 1, FUR_D, -0.2, 1)], rim)
			sil(ci, [ov(Vector2(0, 4), 30, 26, s + 2, FUR, 0.0, 1)], rim)
			_fuzz(ci, Vector2(-30, 14), Vector2(30, 14), 7, FUR.lightened(0.15), s + 3)
			sil(ci, [circ(Vector2(0, -24), 6, s + 4, FUR.lightened(0.2))], rim)
		12:  # 狐尾围巾：一条蓬松的狐狸尾巴，白尖
			var pts := []
			for k in 8:
				var t := float(k) / 7.0
				pts.append(Vector2(-36 + t * 72, -6 + sin(t * PI) * 24 - t * 10))
			var parts := []
			for k in 7:
				parts.append(stk(pts[k], pts[k + 1], 9.0 + sin(float(k) / 6.0 * PI) * 5.0, s + k, FOX if k < 5 else BONE, 0))
			sil(ci, parts, rim)
			for k in 5:
				ln(ci, pts[k], (pts[k] as Vector2) + Vector2(4, 6), 1.4, Color("a8501a"), s + k)
		13:  # 毛皮斗篷：两张毛皮拼的斗篷，麻线系领
			_cape(ci, Vector2(0, 4), 82, 76, FUR, s, rim)
			ln(ci, Vector2(0, -30), Vector2(0, 38), 1.6, FUR_D, s)
			_fuzz(ci, Vector2(-16, -32), Vector2(16, -32), 5, FUR.lightened(0.15), s + 1)
			_lash(ci, Vector2(0, -28), 0.0, 6, 2, s + 2, HEMP)
		14:  # 狼皮披风：灰狼皮，石英扣
			_cape(ci, Vector2(0, 4), 82, 76, WOLF, s, rim)
			for k in 6:
				ln(ci, Vector2(-24 + float(k) * 10, 10), Vector2(-22 + float(k) * 10, 26), 1.4, WOLF.darkened(0.3), s + k)
			_fuzz(ci, Vector2(-16, -32), Vector2(16, -32), 5, WOLF.lightened(0.2), s + 1)
			sil(ci, [PA.crystal(Vector2(0, -20), 4, 6, 0.0, s + 9, QUARTZ)], rim)
		15:  # 皮甲：厚皮衣上缝一排排硬皮片
			_tunic(ci, Vector2(0, 4), 70, 70, LEATHER, s, rim, false)
			for row in 3:
				for k in 4:
					sil(ci, [bx(-22 + float(k) * 11, -14 + float(row) * 15, 10, 12, 2, s + row * 4 + k, LEATHER_D.lightened(0.15), 0)], false, 2.0)
			_m(ci, "tool_5", Vector2(30, 24), 40, false, -0.6)
		16:  # 毛皮大氅：长毛大衣，宽毛领，麻线系
			_tunic(ci, Vector2(0, 6), 82, 74, FUR, s, rim)
			_fuzz(ci, Vector2(-24, -30), Vector2(24, -30), 7, FUR.lightened(0.2), s + 1)
			ln(ci, Vector2(0, -26), Vector2(0, 42), 1.6, FUR_D, s)
			_fuzz(ci, Vector2(-34, 42), Vector2(34, 42), 8, FUR.lightened(0.12), s + 2)
		17:  # 首领毛皮袍：长袍，毛领，胸前紫晶簇
			glow(ci, Vector2(0, -4), 48, Color(0.85, 0.6, 1.0))
			_tunic(ci, Vector2(0, 6), 84, 78, Color("a84a3a"), s, rim)
			_fuzz(ci, Vector2(-26, -32), Vector2(26, -32), 8, FUR.lightened(0.2), s + 1)
			_fuzz(ci, Vector2(-34, 44), Vector2(34, 44), 9, FUR.lightened(0.12), s + 2)
			_m(ci, "gem_8", Vector2(0, -2), 50, rim)
			sparks(ci, [Vector2(-40, -36), Vector2(40, -34)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 乐器

## 鼓：鼓身 + 绷紧的皮面 + 斜拉的绳
static func _drum_inst(ci: CanvasItem, c: Vector2, w: float, h: float, body: Color, s: int, rim: bool) -> void:
	sil(ci, [P(rrect(Rect2(c.x - w, c.y, w * 2.0, h), w * 0.25, s, 0.6), body, 1), ov(c, w, w * 0.3, s + 1, HIDE_C.lightened(0.1), 0.0, 1)], rim)
	for k in 6:
		var x := -w * 0.85 + float(k) * w * 0.34
		ln(ci, c + Vector2(x, w * 0.25), c + Vector2(x + w * 0.17, h - 3), 1.6, HEMP, s + k)

static func _music(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 草笛：一节麻秆，开几个孔，系一根草茎
			sil(ci, [stk(Vector2(-36, 20), Vector2(32, -20), 5.0, s, Color("c9b45a"))], rim)
			for k in 4:
				ci.draw_circle(Vector2(-12, 6).lerp(Vector2(20, -13), float(k) / 3.0), 2.0, INK)
			pl(ci, [Vector2(-30, 16), Vector2(-26, 30), Vector2(-34, 38)], 2.0, GRASS_D, s)
		2:  # 树皮号：树皮卷成长号角，叉枝作把
			sil(ci, [pg([Vector2(-36, 8), Vector2(-34, 0), Vector2(24, -30), Vector2(36, -16), Vector2(32, -6)], s, Color("c89a62"))], rim)
			sil(ci, [ov(Vector2(30, -20), 8, 16, s + 1, Color("8a5a2a"), -0.5, 1)], rim)
			for k in 3:
				ln(ci, Vector2(-20 + float(k) * 16, -2 - float(k) * 8), Vector2(-16 + float(k) * 16, 6 - float(k) * 8), 1.4, Color(INK, 0.4), s + k)
			sil(ci, [stk(Vector2(-6, 0), Vector2(-14, 30), 2.4, s + 3, WOOD_D), stk(Vector2(-10, 18), Vector2(-2, 26), 2.0, s + 4, WOOD_D)], rim)
		3:  # 木梆子：两根木杆交叉
			sil(ci, [stk(Vector2(-34, 30), Vector2(24, -26), 4.6, s, WOOD), stk(Vector2(34, 30), Vector2(-24, -26), 4.6, s + 1, WOOD.darkened(0.08))], rim)
			sparks(ci, [Vector2(0, -24)], 6.0)
		4:  # 木排箫：一排长短木管，松脂粘，绳扎
			var parts := []
			for k in 6:
				var x := -25.0 + float(k) * 10.0
				parts.append(bx(x - 4.5, -30, 9, 60 - float(k) * 7, 3, s + k, WOOD.lightened(0.05 * float(k % 2))))
			sil(ci, parts, rim)
			for k in 6:
				ci.draw_colored_polygon(ell(Vector2(-25 + float(k) * 10, -28), Vector2(3, 1.6), s + k, 0.0, 8), INK)
			sil(ci, [stk(Vector2(-32, -10), Vector2(32, -10), 2.4, s + 9, RESIN)], false)
		5:  # 石磬：木架上吊一块弯石板
			sil(ci, [stk(Vector2(-34, 38), Vector2(-30, -34), 3.0, s, WOOD_D), stk(Vector2(34, 38), Vector2(30, -34), 3.0, s + 1, WOOD_D), stk(Vector2(-38, -32), Vector2(38, -32), 3.0, s + 2, WOOD)], rim)
			pl(ci, [Vector2(-12, -32), Vector2(-14, -10)], 1.6, CORD, s)
			pl(ci, [Vector2(12, -32), Vector2(14, -10)], 1.6, CORD, s + 1)
			sil(ci, [pg([Vector2(-26, -8), Vector2(0, -16), Vector2(26, -8), Vector2(22, 8), Vector2(0, 0), Vector2(-22, 8)], s + 3, STONE)], rim)
			sil(ci, [stk(Vector2(16, 30), Vector2(30, 16), 2.4, s + 4, WOOD), circ(Vector2(14, 32), 4, s + 5, WOOD_D)], rim)
		6:  # 兽皮鼓：原木挖空，蒙兽皮
			_drum_inst(ci, Vector2(0, -10), 30, 46, WOOD, s, rim)
			sil(ci, [stk(Vector2(26, -30), Vector2(40, -40), 2.4, s + 8, WOOD_D), circ(Vector2(24, -28), 4, s + 9, HIDE_C)], rim)
		7:  # 陶埙：蛋形陶哨，几个音孔
			sil(ci, [ov(Vector2(0, 6), 22, 28, s, CLAYPOT, 0.0, 1)], rim)
			ci.draw_colored_polygon(ell(Vector2(0, -18), Vector2(4, 2.4), s, 0.0, 10), INK)
			for p in [Vector2(-8, 2), Vector2(8, 2), Vector2(-6, 16), Vector2(6, 16)]:
				ci.draw_circle(p, 2.6, INK)
			hl(ci, Vector2(-8, -6), 4, 8, 0.3, 0.4)
			_m(ci, "tool_2", Vector2(28, 26), 36, false, 0.4)
		8:  # 陶鼓：陶罐口蒙兽皮，绳子勒紧
			var mo := _pmouth("pot_6", Vector2(0, 8), 150)
			_m(ci, "pot_6", Vector2(0, 8), 150, rim)
			sil(ci, [ov(mo[0], float(mo[1]) + 6, 5, s, HIDE_C, 0.0, 1)], rim)
			for k in 4:
				var x := -12.0 + float(k) * 8.0
				ln(ci, (mo[0] as Vector2) + Vector2(x, 2), (mo[0] as Vector2) + Vector2(x * 1.6, 16), 1.6, HEMP, s + k)
		9:  # 坚果沙锤：小陶罐插木把，里面板栗核桃
			_shaft(ci, Vector2(0, -6), Vector2(-4, -42), 3.4, s, rim)
			_m(ci, "pot_6", Vector2(0, 8), 120, rim)
			_m(ci, "seed_7", Vector2(-26, 28), 30, false)
			_m(ci, "seed_8", Vector2(26, 28), 30, false)
			for p in [Vector2(-24, -8), Vector2(24, -12)]:
				pl(ci, [p, p + Vector2(4, -4)], 2.0, INK, s)
		10:  # 响铃串：一串田螺和河蚌壳
			sil(ci, [stk(Vector2(-36, -34), Vector2(36, -34), 2.6, s, WOOD)], rim)
			for k in 4:
				var x := -24.0 + float(k) * 16.0
				_string(ci, [Vector2(x, -34), Vector2(x, -10 + float(k % 2) * 8)])
				_m(ci, "clam_1" if k % 2 == 0 else "clam_3", Vector2(x, -4 + float(k % 2) * 8), 40, rim)
		11:  # 海螺号：大海螺，尖端磨出吹口
			_m(ci, "clam_7", Vector2(0, 0), 96, rim, -0.4)
			sil(ci, [ov(Vector2(-28, -18), 5, 4, s, BONE, 0.0, 1)], false)
			_m(ci, "tool_2", Vector2(28, 28), 34, false)
		12:  # 大鼓：半圆木鼓身，兽皮面，藤架
			sil(ci, [stk(Vector2(-36, 38), Vector2(-28, 0), 3.4, s, RATTAN_D), stk(Vector2(36, 38), Vector2(28, 0), 3.4, s + 1, RATTAN_D)], rim)
			_drum_inst(ci, Vector2(0, -18), 36, 50, WOOD_D.lightened(0.1), s + 2, rim)
		13:  # 祭典鼓组：大缸鼓居中，两边原木鼓
			glow(ci, Vector2(0, -4), 50, Color(1, 0.8, 0.5))
			var mo := _pmouth("pot_13", Vector2(0, 0), 90)
			_m(ci, "pot_13", Vector2(0, 0), 90, rim)
			sil(ci, [ov(mo[0], float(mo[1]) + 4, 7, s + 6, FUR, 0.0, 1)], rim)
			_drum_inst(ci, Vector2(-28, 14), 14, 24, WOOD, s, rim)
			_drum_inst(ci, Vector2(28, 16), 13, 22, WOOD.darkened(0.08), s + 3, rim)
			sparks(ci, [Vector2(-40, -38), Vector2(40, -36)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 药草疗伤

static func _medicine(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1, 3:  # 树皮绷带 / 麻布绷带：一卷，拉出一截
			var col := Color("c89a62") if n == 1 else LINEN
			sil(ci, [P(_rrect_rot(Vector2(10, 22), 56, 12, 3, -0.1, s), col, 1)], rim)
			sil(ci, [ov(Vector2(-16, 6), 22, 22, s + 1, col, 0.0, 1)], rim)
			ci.draw_polyline(ell(Vector2(-16, 6), Vector2(14, 14), s, 0.0, 18), Color(INK, 0.5), 1.6, true)
			ci.draw_polyline(ell(Vector2(-16, 6), Vector2(7, 7), s, 0.0, 14), Color(INK, 0.5), 1.6, true)
			if n == 1:
				_lash(ci, Vector2(-16, -14), 0.0, 6, 2, s + 3, HEMP)
			else:
				_m(ci, "craft_5", Vector2(26, -6), 42, false)
		2:  # 止血草包：一把草叶裹成小包，用松脂封口
			sil(ci, [ov(Vector2(0, 10), 28, 24, s, LEAF, 0.2, 1), pg([Vector2(-26, 4), Vector2(0, -20), Vector2(22, 4)], s + 1, LEAF_D, 1)], rim)
			for k in 4:
				ln(ci, Vector2(-20 + float(k) * 12, 0), Vector2(-16 + float(k) * 12, 28), 1.4, Color(LEAF_D, 0.8), s + k)
			sil(ci, [circ(Vector2(0, -6), 7, s + 5, RESIN)], rim)
			hl(ci, Vector2(-2, -8), 3, 2, 0.0, 0.6)
		4:  # 驱虫香：一捆干草插着，点着冒烟，松脂团在旁
			_m(ci, "cloth_3", Vector2(-4, 10), 90, rim)
			for k in 3:
				ci.draw_circle(Vector2(-12 + float(k) * 8, -24 + float(k % 2) * 3), 3.0, Color("ff7b22"))
			smoke(ci, Vector2(-4, -36), 0.6)
			_m(ci, "craft_6", Vector2(28, 26), 36, false)
		5:  # 松脂药膏：小陶碟盛一团琥珀色药膏
			_clayplate(ci, Vector2(0, 22), 36, 13, s, rim)
			_honey_blob(ci, Vector2(0, 12), 22, 12, s + 1, false)
			sil(ci, [stk(Vector2(10, 4), Vector2(34, -20), 2.4, s + 2, WOOD)], rim)
		6:  # 木耳汤剂：陶罐里黑褐药汤，罐口搭木耳
			var mo := _drink_pot(ci, "pot_6", Vector2(0, 8), 150, Color("4a2a1a"), s, rim)
			_m(ci, "craft_7", (mo[0] as Vector2) + Vector2(16, -2), 50, false)
			steam(ci, (mo[0] as Vector2) + Vector2(-4, -8), 2, 16)
		7:  # 树菇药粉：石板上研出一堆粉，旁边树菇
			_slab(ci, Vector2(0, 24), 86, 26, s, rim)
			sil(ci, [pg([Vector2(-26, 22), Vector2(-8, 4), Vector2(10, 22)], s + 1, Color("e8d8b8"), 0)], false, 2.0)
			_m(ci, "craft_8", Vector2(22, -2), 50, false)
			sil(ci, [P(PA.raw_rock(Vector2(-24, 2), 8, s + 2, STONE_D)[0], STONE_D, 1)], false)
		8:  # 蜂蜜药丸：叶子上几颗蜜丸，旁边榛子
			_leafmat(ci, Vector2(0, 24), 38, 12, s, rim)
			for k in 5:
				var p := Vector2(-18 + float(k) * 9, 10 - float(k % 2) * 6)
				_honey_blob(ci, p, 6, 6, s + k, false)
			_m(ci, "seed_2", Vector2(24, -8), 40, false)
		9:  # 安神茶：陶壶，旁边一朵灵芝
			var mo := _drink_pot(ci, "pot_7", Vector2(-6, 2), 150, Color("8a4a2a"), s, rim)
			_m(ci, "craft_9", Vector2(26, 22), 44, false)
			steam(ci, (mo[0] as Vector2) + Vector2(0, -8), 2, 16)
		10:  # 灵芝丹：蜂巢托着一颗发光的丹丸
			_m(ci, "craft_11", Vector2(0, 20), 70, rim)
			glow(ci, Vector2(0, -16), 26, Color(1, 0.7, 0.3))
			sil(ci, [circ(Vector2(0, -16), 11, s, Color("c0402a"))], rim)
			hl(ci, Vector2(-4, -20), 4, 2.6, -0.3, 0.7)
			sparks(ci, [Vector2(-22, -30), Vector2(22, -34)], 5.0)
		11:  # 药箱：木板箱，开盖，露出灵芝和线团
			sil(ci, [bx(-34, -2, 68, 38, 4, s, WOOD)], rim)
			sil(ci, [P(_rrect_rot(Vector2(-6, -18), 70, 10, 3, -0.35, s + 1), WOOD.lightened(0.08), 1)], rim)
			_m(ci, "craft_9", Vector2(-10, -10), 44, false)
			_m(ci, "cloth_6", Vector2(16, -6), 34, false)
			sil(ci, [bx(-34, 8, 68, 28, 4, s + 2, WOOD, 0)], false)
			sil(ci, [P(_rrect_rot(Vector2(0, 20), 14, 4, 1, 0.0, s + 3), CLAY, 0), P(_rrect_rot(Vector2(0, 20), 4, 14, 1, 0.0, s + 4), CLAY, 0)], false, 1.6)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)

# ---------------------------------------------------------------- 祭祀礼器

## 面具：椭圆脸，眼洞，嘴
static func _mask(ci: CanvasItem, c: Vector2, w: float, h: float, col: Color, s: int, rim: bool) -> void:
	sil(ci, [ov(c, w, h, s, col, 0.0, 1)], rim)
	for x in [-w * 0.4, w * 0.4]:
		ci.draw_colored_polygon(ell(c + Vector2(x, -h * 0.15), Vector2(w * 0.24, h * 0.13), s, 0.04, 12), INK)
	pl(ci, [c + Vector2(-w * 0.3, h * 0.45), c + Vector2(0, h * 0.55), c + Vector2(w * 0.3, h * 0.45)], 2.6, INK, s)
	pl(ci, [c + Vector2(0, -h * 0.1), c + Vector2(-w * 0.08, h * 0.25), c + Vector2(w * 0.08, h * 0.25)], 1.6, Color(INK, 0.6), s)

static func _ritual(ci: CanvasItem, n: int, s: int, rim: bool) -> void:
	match n:
		1:  # 石英护符：麻线吊一块石英
			_string(ci, _ring_pts(Vector2(0, -40), 24, 34, 0.25, PI - 0.25, 14))
			_m(ci, "gem_2", Vector2(0, 0), 80, rim)
		2:  # 三叶虫护符：三叶虫化石吊坠
			_string(ci, _ring_pts(Vector2(0, -40), 24, 32, 0.25, PI - 0.25, 14))
			_m(ci, "clam_10", Vector2(0, 2), 80, rim, PI / 2.0)
		3:  # 羽毛面具：木面具，头顶插野鸡羽
			for k in 5:
				_feather(ci, Vector2(0, -20), 36, -PI / 2.0 + (float(k) - 2.0) * 0.3, Color("c8763a") if k % 2 == 0 else Color("3a6a4a"), s + k, rim)
			_mask(ci, Vector2(0, 8), 26, 30, WOOD, s + 6, rim)
			pl(ci, [Vector2(-20, 14), Vector2(-8, 16)], 3.0, CLAY, s)
			pl(ci, [Vector2(20, 14), Vector2(8, 16)], 3.0, CLAY, s + 1)
		4:  # 木雕面具：半圆木刻的面具，眼睛嵌绿松石
			_mask(ci, Vector2(0, 2), 30, 38, WOOD.darkened(0.05), s, rim)
			for x in [-12.0, 12.0]:
				sil(ci, [circ(Vector2(x, -4), 4.5, s + 2, TURQ)], false, 2.0)
			for k in 3:
				ln(ci, Vector2(-24, -26 + float(k) * 6), Vector2(24, -26 + float(k) * 6), 1.4, WOOD_D, s + k)
		5:  # 鹰羽权杖：细原木杖，顶上紫晶簇，挂鹰羽
			glow(ci, Vector2(10, -28), 22, Color(0.85, 0.6, 1.0))
			_shaft(ci, Vector2(-20, 40), Vector2(8, -18), 4.0, s, rim)
			_m(ci, "gem_8", Vector2(12, -26), 54, rim)
			_feather(ci, Vector2(4, -12), 28, 2.2, Color("6a4a2a"), s + 2, rim)
			_feather(ci, Vector2(4, -12), 26, 2.6, Color("e8dcc8"), s + 3, rim)
		6:  # 绿松石神像：方石刻的小人，胸口镶绿松石
			sil(ci, [bx(-20, -12, 40, 50, 6, s, STONE), ov(Vector2(0, -24), 16, 15, s + 1, STONE, 0.0, 1)], rim)
			for x in [-6.0, 6.0]:
				ci.draw_circle(Vector2(x, -26), 2.6, INK)
			pl(ci, [Vector2(-6, -18), Vector2(6, -18)], 2.0, INK, s)
			_gem(ci, Vector2(0, 4), 9, TURQ, s + 3, false)
			for k in 3:
				sil(ci, [circ(Vector2(-14 + float(k) * 14, 26), 3.4, s + k, TURQ)], false, 1.6)
		7:  # 紫晶祭坛：石柱当台，上面紫晶洞
			glow(ci, Vector2(0, -18), 40, Color(0.85, 0.6, 1.0))
			sil(ci, [bx(-18, -4, 36, 42, 4, s, STONE), bx(-26, -10, 52, 10, 3, s + 1, STONE.lightened(0.06))], rim)
			_m(ci, "gem_9", Vector2(0, -24), 70, rim)
			sparks(ci, [Vector2(-34, -36), Vector2(34, -38)], 5.0)
		8:  # 祭火石台：巨石台上一堆柴，燃着松脂火
			glow(ci, Vector2(0, -16), 40, Color(1, 0.6, 0.2))
			sil(ci, [pg([Vector2(-40, 8), Vector2(-30, -6), Vector2(30, -8), Vector2(40, 6), Vector2(34, 38), Vector2(-34, 38)], s, STONE)], rim)
			_m(ci, "furn_11", Vector2(0, -6), 60, false)
			flame(ci, Vector2(0, -24), 20, 32, s + 2, rim)
		9:  # 菊石圣物：藤编托座上放大菊石，周围绿松石
			_wicker(ci, [Vector2(-30, 12), Vector2(30, 12), Vector2(22, 36), Vector2(-22, 36)], Rect2(-28, 14, 56, 22), s, rim, RATTAN)
			_m(ci, "clam_12", Vector2(0, -8), 72, rim)
			for k in 3:
				sil(ci, [circ(Vector2(-20 + float(k) * 20, 12), 4.6, s + k, TURQ)], rim)
		10:  # 彩绘陶祭器：人面鱼纹盆，前面一块绿松石
			_m(ci, "pot_14", Vector2(0, 2), 96, rim)
			_m(ci, "gem_5", Vector2(26, 26), 40, false)
		11:  # 祈雨陶瓮：彩陶大瓮，口插棕榈叶，旁边锦鲤
			for k in 3:
				sil(ci, [ov(Vector2(-8 + float(k) * 8, -34), 4, 16, s + k, PALM, -0.4 + float(k) * 0.4, 1)], rim)
			_m(ci, "pot_15", Vector2(-4, 6), 90, rim)
			_m(ci, "fish_13", Vector2(26, 26), 44, false)
			for k in 3:
				sil(ci, [ov(Vector2(-34 + float(k) * 6, -12 + float(k) * 10), 2.4, 4, s + k, WATER, 0.0, 0)], false, 1.6)
		12:  # 大地母神像：陶土捏的丰满坐像，围毛皮，身上嵌钻石
			glow(ci, Vector2(0, -4), 50, Color(1, 0.9, 0.6))
			sil(ci, [ov(Vector2(0, 18), 30, 22, s, CLAYPOT, 0.0, 1), ov(Vector2(0, -6), 20, 20, s + 1, CLAYPOT, 0.0, 1), ov(Vector2(0, -30), 11, 12, s + 2, CLAYPOT, 0.0, 1)], rim)
			sil(ci, [_hide(Vector2(0, 30), 70, 16, s + 3, FUR)], rim)
			_gem(ci, Vector2(0, -6), 7, DIAMOND, s, false)
			for x in [-4.0, 4.0]:
				ci.draw_circle(Vector2(x, -31), 1.8, INK)
			sparks(ci, [Vector2(-40, -36), Vector2(40, -34)], 5.0)
		13:  # 图腾柱：香柏巨木刻几层脸，顶上鹰展翅，嵌绿松石
			sil(ci, [ov(Vector2(-24, -32), 22, 8, s, Color("6a4a2a"), -0.3, 1), ov(Vector2(24, -32), 22, 8, s + 1, Color("6a4a2a"), 0.3, 1)], rim)
			sil(ci, [bx(-14, -38, 28, 78, 4, s + 2, Color("c0603a"))], rim)
			for k in 2:
				var y := -16.0 + float(k) * 28.0
				for x in [-6.0, 6.0]:
					ci.draw_colored_polygon(ell(Vector2(x, y - 4), Vector2(3.4, 2.6), s, 0.0, 10), INK)
				pl(ci, [Vector2(-7, y + 6), Vector2(7, y + 6)], 2.4, INK, s + k)
				ln(ci, Vector2(-14, y + 12), Vector2(14, y + 12), 1.6, Color(INK, 0.5), s + k)
			sil(ci, [circ(Vector2(0, -32), 5, s + 3, TURQ)], false, 2.0)
		14:  # 首领冠冕：毛皮冠圈，鸵鸟羽，正中钻石
			glow(ci, Vector2(0, -10), 46, Color(0.8, 0.95, 1.0))
			for k in 5:
				_feather(ci, Vector2(0, 4), 44, -PI / 2.0 + (float(k) - 2.0) * 0.32, Color("f1ece0") if k % 2 == 0 else Color("3a3a3a"), s + k, rim)
			ci.draw_polyline(ell(Vector2(0, 16), Vector2(36, 14), s, 0.0, 28), INK, 16.0, true)
			ci.draw_polyline(ell(Vector2(0, 16), Vector2(36, 14), s, 0.0, 28), FUR, 12.0, true)
			_gem(ci, Vector2(0, 26), 12, DIAMOND, s + 8, rim)
			sparks(ci, [Vector2(-40, -36), Vector2(40, -36)], 5.0)
		15:  # 祭鼎：鹰形陶鼎，鼎口放紫晶洞，泛光
			glow(ci, Vector2(0, -10), 52, Color(0.85, 0.6, 1.0))
			_m(ci, "pot_16", Vector2(-6, 4), 90, rim)
			_m(ci, "gem_9", Vector2(26, 26), 44, rim)
			sparks(ci, [Vector2(-42, -36), Vector2(42, -32)], 5.0)
		_:
			sil(ci, [circ(Vector2.ZERO, 26, s, STONE)], rim)
