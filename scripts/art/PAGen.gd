class_name PAGen
extends PA
## 7 条产线的生产器，统一 10 级（设计见 docs/生成器重设计_10级.md）。
## 规则：1~3 级是零件或小工具，4 级起开始产出、画面里看得见产物，7~10 级是场所。
## 每条线一个专属主色，1 级就带上。原来的旧画法（PAFood.gen 等）原样留在各自文件里，这里能用的直接借来摆。

const PINE_B := Color("2f7d5e")       # 木头线：偏蓝的墨绿针叶
const AMETHYST := Color("9a5fd0")     # 工具线：紫晶
const OCHRE_RED := Color("b8442c")    # 狩猎线：赭红
const FLAX := Color("e9b843")         # 衣服线：金黄麻线
const FLAX_D := Color("b8862a")
const CORD := Color("2fb3b0")         # 渔猎线：蓝绿钓线
const WATER := Color("6fc3e8")
const WATER_D := Color("3d93c4")
const TERRA := Color("d06a3a")        # 陶艺线：陶土橙红
const EARTH := Color("9a6b45")
const SOIL := Color("7a4f2a")

## 由 tools/gen_sizes.py 生成
const FIT := {
	"food": [[2.207, -0.5, 17.1], [1.674, 0.5, 17.6], [1.328, -0.5, 11.6], [1.287, -0.5, 15.7], [1.335, 0.5, 6.9], [1.187, 0.5, -2.8], [1.169, -3.7, -7.9], [1.138, -5.6, -10.2], [1.151, 0.0, -10.6], [1.086, 0.0, -15.3]],
	"wood": [[1.488, 0.0, 26.9], [1.359, 0.0, 18.1], [1.216, -0.5, 6.9], [1.079, 1.4, -2.8], [1.042, 0.5, -3.7], [1.024, 0.0, -4.6], [0.974, 0.0, -4.6], [1.051, -0.5, -7.9], [0.981, -0.5, -10.2], [0.969, -0.9, -12.5]],
	"tool": [[1.738, 0.0, 24.1], [1.291, -0.5, 16.2], [1.375, -0.5, 13.0], [1.325, 3.2, 16.7], [1.256, 2.8, 17.6], [1.079, -1.4, 19.0], [1.22, 0.5, 11.1], [1.265, -0.5, 0.9], [1.198, 0.0, 5.6], [1.209, 0.5, 0.9]],
	"hunt": [[1.574, 2.3, 31.9], [1.246, 0.5, 21.8], [1.049, -1.9, -0.9], [1.049, 0.0, -3.7], [1.088, 3.2, 15.7], [1.213, 6.0, 15.7], [1.292, 0.0, -1.9], [1.156, 1.9, 0.0], [1.229, -3.7, -0.5], [1.365, 1.4, 1.9]],
	"cloth": [[1.599, 0.5, 23.6], [1.474, 0.0, 16.7], [1.061, -5.6, 10.6], [1.291, 0.0, 9.7], [1.281, 0.0, 8.8], [1.266, 0.5, 2.3], [1.303, 2.8, 0.9], [1.255, 0.0, 3.7], [1.172, -0.5, -1.9], [1.172, -1.4, -4.6]],
	"fish": [[1.44, -0.5, 19.0], [1.389, 0.0, 21.3], [1.115, -4.6, 4.6], [1.037, 2.3, 0.9], [1.044, 4.6, 8.8], [1.146, 0.0, 5.6], [1.09, -0.9, 6.9], [1.113, 0.0, 12.0], [1.107, 0.0, 8.3], [1.052, 3.2, -6.9]],
	"pot": [[1.617, -0.9, 24.5], [1.781, 0.5, 19.0], [1.241, -6.0, 15.3], [1.009, 0.9, 5.1], [1.059, 0.9, 24.1], [1.001, 1.4, 13.9], [1.062, -0.5, -2.8], [0.965, 9.3, -7.4], [1.314, 0.0, -6.9], [1.054, -16.7, -6.0]],
}

const LINES := ["food", "wood", "tool", "hunt", "cloth", "fish", "pot"]

## 为真时不套 FIT（量原始大小用，见 tools/gen_sheet.gd --measure）
static var raw := false

static func draw(ci: CanvasItem, line: String, lv: int, s: int, rim: bool) -> bool:
	if not LINES.has(line):
		return false
	lv = clampi(lv, 1, 10)
	var keep := xf
	var fitted := not raw and FIT.has(line)
	var sk := Art.stroke_k
	if fitted:
		## 每级 [缩放, 原图中心 x, 原图中心 y]：按逐级递增的目标大小缩放，再挪到正中；描边粗细不跟着变
		var f: Array = FIT[line][lv - 1]
		var k: float = f[0]
		xf = keep * Transform2D(0.0, Vector2(k, k), 0.0, -Vector2(f[1], f[2]) * k)
		ci.draw_set_transform_matrix(xf)
		Art.stroke_k = sk * k
	_draw_scene(ci, line, lv, s, rim)
	Art.stroke_k = sk
	xf = keep
	ci.draw_set_transform_matrix(xf)
	return true

static func _draw_scene(ci: CanvasItem, line: String, lv: int, s: int, rim: bool) -> void:
	## 先整幅只描奶白外边，再不带外边画本体：前后叠着的树、棚子共用一圈外边
	if rim:
		Art.rim_only = true
		_scene(ci, line, lv, s, true)
		Art.rim_only = false
	_scene(ci, line, lv, s, false)

## 后四条线的旧图大多是木头、兽皮的棕色，画的时候把几种棕色换成这条线的主色（深浅面按比例跟着换，见 Art.rc）
const REMAP := {
	"tool": {"c9b45a": "b9b3a8", "9c8a3a": "6f6a63"},
	"hunt": {"c99a68": "c4553a", "a8845a": "b9573c", "6a4a30": "7e3324", "7a4f2a": "8e3b26", "6a4428": "6e2c1e", "b07444": "c86a3e"},
	"cloth": {"a7622c": "dfa23a", "a9b25e": "e9b843", "d9c272": "efc451", "7a4f2a": "c9963a", "8a735c": "c8973e", "ffcf3f": "9a6a1e", "c98f62": "e3b04e",
		"b97a3f": "d6a843", "7a4a22": "a87c2c", "8a5a34": "b8862a", "d9b47a": "efcf74", "a7a197": "cdbb8a", "e3d9a8": "f2dc8c", "c99a52": "d9aa44", "7fb04a": "e2b63e",
		"e8b24a": "f0c24e", "5a3418": "8e6420", "b8442c": "b8862a", "3a2416": "6e4a14"},
	"fish": {"e6c98a": "2fb3b0", "cfae7a": "8fd0ec", "7a5a2a": "3d7fa8"},
	"pot": {"d9a066": "e2773f", "b07444": "b9502c", "c98a5a": "d4683a", "e09a5a": "e57a46", "e8aa6a": "ef8f55", "c99a6a": "dc8a56", "c48a4a": "c96a3a"},
}

static func _scene(ci: CanvasItem, line: String, lv: int, s: int, rim: bool) -> void:
	Art.remap = REMAP.get(line, {})
	_scene_body(ci, line, lv, s, rim)
	Art.remap = {}

static func _scene_body(ci: CanvasItem, line: String, lv: int, s: int, rim: bool) -> void:
	match line:
		"food": _food(ci, lv, s, rim)
		"wood": _wood(ci, lv, s, rim)
		"tool": _tool(ci, lv, s, rim)
		"hunt": _hunt(ci, lv, s, rim)
		"cloth": _cloth(ci, lv, s, rim)
		"fish": _fish(ci, lv, s, rim)
		"pot": _pot(ci, lv, s, rim)

# ---------------------------------------------------------------- 摆放

## 以脚下地面 (0, 38) 为支点缩放 k，再平移 off
static func _push(ci: CanvasItem, k: float, off: Vector2 = Vector2.ZERO) -> Transform2D:
	var keep := xf
	xf = keep * Transform2D(0.0, Vector2(k, k), 0.0, Vector2(0, 38) * (1.0 - k) + off)
	ci.draw_set_transform_matrix(xf)
	return keep

static func _pop(ci: CanvasItem, keep: Transform2D) -> void:
	xf = keep
	ci.draw_set_transform_matrix(xf)

## 旧画法里某一级用的种子，借图时保持原样
static func _os(line: String, lv: int) -> int:
	return abs((line + "G").hash()) % 97 + lv * 7

## 借旧画法的某一级，缩放 k、平移 off
static func _old(ci: CanvasItem, cls, line: String, lv: int, k: float, off: Vector2, rim: bool) -> void:
	var keep := _push(ci, k, off)
	cls.gen(ci, lv, _os(line, lv), rim)
	_pop(ci, keep)

## 一圈小卵石（只画前半圈，后半圈被东西挡住）
static func _pebble_ring(ci: CanvasItem, c: Vector2, rx: float, ry: float, n: int, s: int, rim: bool, front_only: bool = false) -> void:
	var parts := []
	for k in n:
		var a := TAU * float(k) / float(n) + 0.2
		if front_only and sin(a) < -0.15:
			continue
		var p := c + Vector2(cos(a) * rx, sin(a) * ry)
		var r := 3.6 + srnd(s + k) * 1.8
		parts.append(ov(p, r * 1.2, r * 0.85, s + k, STONE.lightened(0.08 * float(k % 3)), 0.0, 1))
	sil(ci, parts, rim, 2.2)

static func _sparkles(ci: CanvasItem, pts: Array, r: float = 5.0) -> void:
	for p in pts:
		spark(ci, p, r)

## 丰收的大树叶子泛黄（9、10 级用）
const AUTUMN_1 := {"72b23c": "9cbf3a", "4b8227": "6a8c24"}
const AUTUMN_2 := {"72b23c": "c4c43c", "4b8227": "8f8d22"}

# ================================================================ 食物：果树（嫩叶黄绿 + 莓果红）

static func _food(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 发芽果核：一颗裂开的棕色果核，裂口冒出两片嫩芽
			var core := Vector2(0, 22)
			sil(ci, [stk(Vector2(1, 18), Vector2(2, 10), 1.5, s + 1, LEAF_D, 2),
				leaf(Vector2(2, 10), 7, 3.0, -2.5, s + 2), leaf(Vector2(2, 10), 7, 3.0, -0.6, s + 3),
				ov(core, 10, 7.5, s + 4, SEED, -0.15, 1)], rim)
			pl(ci, [core + Vector2(-7, -3), core + Vector2(-2, -1), core + Vector2(1, -4), core + Vector2(6, -2)], 1.8, INK, s)
			ln(ci, core + Vector2(-4, 3), core + Vector2(4, 2), 1.2, Color(INK, 0.3), s + 1)
			hl(ci, core + Vector2(-4, -3), 3, 1.5)
		2:
			## 嫩芽：土堆里冒出两片子叶
			_old(ci, PAFood, "food", 1, 1.0, Vector2.ZERO, rim)
		3:
			## 三叶苗，外面围一圈小卵石
			_old(ci, PAFood, "food", 2, 0.92, Vector2.ZERO, rim)
			_pebble_ring(ci, Vector2(0, 31), 27, 7, 9, s + 20, rim, true)
		4:
			## 小灌木，石圈 —— 第一次挂上红野莓（开始产出）
			_old(ci, PAFood, "food", 3, 0.95, Vector2.ZERO, rim)
			_pebble_ring(ci, Vector2(0, 32), 33, 7, 11, s + 20, rim, true)
			PAFood._berries(ci, [Vector2(-16, 12), Vector2(-4, 0), Vector2(14, 10)], 4.6, BERRY, s + 40)
		5:
			## 野莓丛挂满果，地上滚落两颗
			_old(ci, PAFood, "food", 4, 1.0, Vector2.ZERO, rim)
			PAFood._berries(ci, [Vector2(-30, 36), Vector2(30, 38)], 4.6, BERRY, s + 41)
		6:
			## 小果树，树下一圈石头
			_old(ci, PAFood, "food", 6, 1.0, Vector2.ZERO, rim)
			_pebble_ring(ci, Vector2(0, 35), 26, 5, 9, s + 20, rim, true)
		7:
			## 果树挂满果，树下一个叶片包着的果兜
			_old(ci, PAFood, "food", 7, 1.0, Vector2(-4, 0), rim)
			_leaf_bundle(ci, Vector2(26, 32), 1.0, s + 30, rim)
		8:
			## 大果树，树下一只装满果子的藤篮
			_old(ci, PAFood, "food", 8, 1.0, Vector2(-6, 0), rim)
			_fruit_basket(ci, Vector2(30, 30), 0.9, s + 30, rim)
		9:
			## 祈福果树：树枝上系着赭色布条和骨片风铃，树下两篮果，叶子开始泛黄
			Art.remap = AUTUMN_1
			_old(ci, PAFood, "food", 9, 0.98, Vector2.ZERO, rim)
			Art.remap = {}
			_charms(ci, [Vector2(-26, -14), Vector2(24, -16)], s + 50)
			_fruit_basket(ci, Vector2(-34, 30), 0.78, s + 30, rim)
			_fruit_basket(ci, Vector2(34, 32), 0.85, s + 31, rim)
		_:
			## 丰收古树：古树更大，叶子金黄，挂着布条风铃，树下果篮、坚果堆，金光
			Art.remap = AUTUMN_2
			_old(ci, PAFood, "food", 9, 1.08, Vector2.ZERO, rim)
			Art.remap = {}
			_charms(ci, [Vector2(-30, -18), Vector2(28, -20), Vector2(-6, -8)], s + 50)
			_nut_heap(ci, Vector2(-34, 34), s + 60, rim)
			_fruit_basket(ci, Vector2(34, 31), 0.95, s + 30, rim)
			_fruit_basket(ci, Vector2(-4, 40), 0.7, s + 32, rim)
			_sparkles(ci, [Vector2(-50, -40), Vector2(50, -46), Vector2(48, 6)], 6.0)

## 大叶片包起来的一兜果子
static func _leaf_bundle(ci: CanvasItem, c: Vector2, k: float, s: int, rim: bool) -> void:
	var leafp := []
	for j in 15:
		var a := PI * 0.05 + PI * 0.9 * float(j) / 14.0
		leafp.append(c + Vector2(cos(a) * 14.0, sin(a) * 9.0 - 2.0) * k)
	leafp.append(c + Vector2(-16, -8) * k)
	leafp.append(c + Vector2(-6, -3) * k)
	leafp.append(c + Vector2(6, -3) * k)
	leafp.append(c + Vector2(17, -9) * k)
	sil(ci, [circ(c + Vector2(-5, -6) * k, 5.5 * k, s, BERRY, 0), circ(c + Vector2(5, -7) * k, 5.5 * k, s + 1, PAFood.PLUM, 0),
		circ(c + Vector2(0, -11) * k, 5.0 * k, s + 2, BERRY, 0), pg(leafp, s + 3, LEAF, 1)], rim, 2.4)
	ln(ci, c + Vector2(-10, 1) * k, c + Vector2(10, 1) * k, 1.4, LEAF_D, s)

## 藤篮装满果子
static func _fruit_basket(ci: CanvasItem, c: Vector2, k: float, s: int, rim: bool) -> void:
	var body := [c + Vector2(-16, -6) * k, c + Vector2(16, -6) * k, c + Vector2(12, 9) * k, c + Vector2(-12, 9) * k]
	var parts := [circ(c + Vector2(-8, -9) * k, 6.0 * k, s, BERRY, 0), circ(c + Vector2(4, -11) * k, 6.5 * k, s + 1, PAFood.PLUM, 0),
		circ(c + Vector2(11, -7) * k, 5.0 * k, s + 2, PAFood.APPLE, 0), circ(c + Vector2(-1, -6) * k, 5.0 * k, s + 3, PAFood.BLUE, 0),
		pg(body, s + 4, WOOD, 1)]
	sil(ci, parts, rim, 2.4)
	for j in 3:
		var y := c.y + (-2.0 + float(j) * 4.0) * k
		ln(ci, Vector2(c.x - (15.0 - float(j)) * k, y), Vector2(c.x + (15.0 - float(j)) * k, y), 1.3, Color(WOOD_D, 0.9), s + j)
	for j in 4:
		var x := c.x + (-10.0 + float(j) * 7.0) * k
		ln(ci, Vector2(x, c.y - 5.0 * k), Vector2(x * 0.98 + c.x * 0.02, c.y + 8.0 * k), 1.2, Color(WOOD_D, 0.7), s + j + 5)

## 一堆坚果
static func _nut_heap(ci: CanvasItem, c: Vector2, s: int, rim: bool) -> void:
	var parts := []
	var pos := [Vector2(-9, 0), Vector2(0, 1), Vector2(9, 0), Vector2(-4, -6), Vector2(5, -6), Vector2(0, -11)]
	for j in pos.size():
		parts.append(ov(c + pos[j], 5.2, 4.4, s + j, Color("a5652e").lightened(0.06 * float(j % 3)), 0.3 * float(j % 2), 0))
	sil(ci, parts, rim, 2.2)

## 系在树枝上的赭色布条 + 骨片风铃
static func _charms(ci: CanvasItem, tops: Array, s: int) -> void:
	for j in tops.size():
		var t: Vector2 = tops[j]
		if j % 2 == 0:
			var strip := poly([t + Vector2(-2, 0), t + Vector2(3, 0), t + Vector2(5, 16), t + Vector2(1, 13), t + Vector2(-1, 17)], s + j, 0.4)
			ci.draw_colored_polygon(strip, OCHRE_RED)
			outline(ci, strip, 1.6)
		else:
			ln(ci, t, t + Vector2(0, 7), 1.2, INK, s + j)
			for b in 3:
				var bp := t + Vector2(-5.0 + float(b) * 5.0, 9.0 + float(b % 2) * 2.0)
				ln(ci, t + Vector2(0, 7), bp, 1.0, INK, s + b)
				var bone := ell(bp + Vector2(0, 3), Vector2(1.6, 3.4), s + b, 0.0, 8)
				ci.draw_colored_polygon(bone, BONE)
				outline(ci, bone, 1.2)

# ================================================================ 木头：松林伐木点（墨绿针叶）

static func _pine(ci: CanvasItem, base: Vector2, h: float, w: float, n: int, s: int, rim: bool, col: Color = PINE_B) -> void:
	PAWood._sapling(ci, base, h, w, n, s, col, 0.2, maxf(w * 0.12, 2.2), [], rim)

static func _stump(ci: CanvasItem, top: Vector2, w: float, h: float, s: int, rim: bool, extra: Array = []) -> void:
	var parts := extra.duplicate()
	parts.append_array(PAWood._log_up(top, w, h, s, PAWood.BARK))
	sil(ci, parts, rim)
	rings(ci, top, Vector2(w, w * 0.32), s, 2)
	PAWood._bark(ci, top, w, h, s)

## 石斧：木柄 a→b，b 端绑一块灰石刃
static func _axe(ci: CanvasItem, a: Vector2, b: Vector2, s: int, rim: bool, sc: float = 1.0) -> void:
	var d := (b - a).normalized()
	var n := d.orthogonal()
	var head := [b - d * 2.0 * sc + n * 3.0 * sc, b + n * 12.0 * sc + d * 3.0 * sc, b + n * 12.0 * sc - d * 9.0 * sc, b - d * 8.0 * sc + n * 3.0 * sc]
	sil(ci, [stk(a, b + d * 2.0 * sc, 2.8 * sc, s, WOOD), pg(head, s + 1, Color("8f8c88"), 1)], rim, 2.4)
	ln(ci, b - d * 5.0 * sc - n * 2.5 * sc, b - d * 5.0 * sc + n * 2.5 * sc, 3.6 * sc, INK, s)
	ln(ci, b - d * 5.0 * sc - n * 2.0 * sc, b - d * 5.0 * sc + n * 2.0 * sc, 2.0 * sc, OCHRE_RED, s)
	ln(ci, b + n * 11.0 * sc + d * 1.5 * sc, b + n * 11.0 * sc - d * 7.5 * sc, 1.6, Color(1, 1, 1, 0.55), s)

static func _chips(ci: CanvasItem, pts: Array, s: int) -> void:
	for p in pts:
		var ch := poly([p + Vector2(-3, -1), p + Vector2(2, -2.5), p + Vector2(3, 1), p + Vector2(-2, 2)], s + int(p.x))
		ci.draw_colored_polygon(ch, PAWood.FACE)
		outline(ci, ch, 1.2)

## 砍进树干里的石斧：石刃埋在 p 处的斧口里，木柄朝 dir 伸出来
static func _axe_in(ci: CanvasItem, p: Vector2, dir: Vector2, s: int, rim: bool, sc: float = 1.0) -> void:
	var d := dir.normalized()
	var nt := poly([p + Vector2(5, -7) * sc, p + Vector2(-2, 0) * sc, p + Vector2(5, 6) * sc], s, 0.3)
	if not Art.rim_only:
		ci.draw_colored_polygon(nt, PAWood.FACE)
		outline(ci, nt, 1.5)
	var blade := [p + Vector2(-8, -7) * sc, p + Vector2(2, -6) * sc, p + Vector2(2, 6) * sc, p + Vector2(-8, 7) * sc]
	sil(ci, [pg(blade, s + 1, Color("8f8c88"), 1), stk(p + d * 6.0 * sc, p + d * 30.0 * sc, 2.8 * sc, s, WOOD)], rim, 2.4)
	var m := p + d * 9.0 * sc
	ln(ci, m + Vector2(0, -3) * sc, m + Vector2(0, 3) * sc, 4.0 * sc, INK, s)
	ln(ci, m + Vector2(0, -2.5) * sc, m + Vector2(0, 2.5) * sc, 2.2 * sc, OCHRE_RED, s)

## 树干上的白色斧口
static func _notch(ci: CanvasItem, c: Vector2, s: int) -> void:
	var nt := poly([c + Vector2(4, -6), c + Vector2(-3, 0), c + Vector2(4, 5)], s, 0.3)
	ci.draw_colored_polygon(nt, PAWood.FACE)
	outline(ci, nt, 1.5)

static func _mushrooms(ci: CanvasItem, c: Vector2, k: float, s: int, rim: bool) -> void:
	var parts := []
	var caps := [[Vector2(-6, -2), 7.0], [Vector2(5, -5), 8.5], [Vector2(12, 1), 5.5]]
	for j in caps.size():
		var q: Array = caps[j]
		var p: Vector2 = c + (q[0] as Vector2) * k
		var r: float = q[1] * k
		parts.append(stk(p, p + Vector2(0, r * 1.1), r * 0.32, s + j, BONE2, 2))
	for j in caps.size():
		var q: Array = caps[j]
		var p: Vector2 = c + (q[0] as Vector2) * k
		var r: float = q[1] * k
		var cap := []
		for i in 11:
			var a := PI + PI * float(i) / 10.0
			cap.append(p + Vector2(cos(a) * r, sin(a) * r * 0.75))
		parts.append(pg(cap, s + 10 + j, PAWood.SHELF.darkened(0.1 * float(j)), 1))
	sil(ci, parts, rim, 2.2)
	for j in caps.size():
		var q: Array = caps[j]
		ci.draw_circle(c + (q[0] as Vector2) * k + Vector2(-q[1] * 0.3 * k, -q[1] * 0.35 * k), 1.4 * k, Color(1, 1, 1, 0.7))

static func _hive(ci: CanvasItem, top: Vector2, k: float, s: int, rim: bool) -> void:
	var body := []
	for j in 17:
		var a := -PI * 0.5 + TAU * float(j) / 16.0
		var w := 9.0 * k * (0.75 + 0.35 * sin(a))
		body.append(top + Vector2(0, 13.0 * k) + Vector2(cos(a) * w, sin(a) * 13.0 * k))
	var bp := poly(body, s, 0.5)
	sil(ci, [stk(top + Vector2(0, -4), top + Vector2(0, 2), 1.6, s + 1, WOOD_D, 2), P(bp, PAWood.COMB, 1),
		pg([top + Vector2(-2, 25 * k), top + Vector2(2, 25 * k), top + Vector2(0, 31 * k)], s + 2, PAWood.HONEY, 2)], rim, 2.2)
	PAWood._comb_cells(ci, bp, 2.6 * k, s, 0.4)
	PAWood._bee(ci, top + Vector2(14, 6) * k, 3.2 * k, s)

## 斜顶窝棚：两根叉木撑一根横杆，一排树枝斜搭上去，上面铺着针叶
static func _lean_to(ci: CanvasItem, c: Vector2, k: float, s: int, rim: bool) -> void:
	var parts := []
	var l := c + Vector2(-22, 0) * k
	var r := c + Vector2(22, 0) * k
	parts.append(stk(l, l + Vector2(0, -26) * k, 2.4 * k, s, WOOD_D, 2))
	parts.append(stk(r, r + Vector2(0, -26) * k, 2.4 * k, s + 1, WOOD_D, 2))
	for j in 6:
		var x := lerpf(-22.0, 22.0, float(j) / 5.0)
		parts.append(stk(c + Vector2(x - 2.0, -28) * k, c + Vector2(x + 6.0, 2) * k + Vector2(0, -2), 2.0 * k, s + 2 + j, WOOD if j % 2 == 0 else WOOD.darkened(0.1), 2))
	parts.append(stk(l + Vector2(-4, -26) * k, r + Vector2(4, -26) * k, 2.4 * k, s + 9, WOOD_D, 2))
	for j in 3:
		var x := lerpf(-14.0, 18.0, float(j) / 2.0)
		parts.append(ov(c + Vector2(x + 3.0, -20.0 + float(j % 2) * 5.0) * k, 8.0 * k, 4.0 * k, s + 12 + j, PINE_B.lightened(0.18), -0.5, 1))
	sil(ci, parts, rim, 2.4)

## 兽皮顶木屋：圆木墙、兽皮屋顶、门口黑洞
static func _hut(ci: CanvasItem, c: Vector2, k: float, s: int, rim: bool, roof: Color = HIDE2) -> void:
	var w := 28.0 * k
	var wall_top := c.y - 26.0 * k
	var parts := [bx(c.x - w, wall_top, w * 2.0, 26.0 * k, 3, s, WOOD)]
	parts.append(pg([Vector2(c.x - w - 8.0 * k, wall_top + 2.0), Vector2(c.x - 4.0 * k, wall_top - 24.0 * k), Vector2(c.x + 4.0 * k, wall_top - 24.0 * k),
		Vector2(c.x + w + 8.0 * k, wall_top + 2.0), Vector2(c.x + w + 4.0 * k, wall_top + 6.0 * k), Vector2(c.x - w - 4.0 * k, wall_top + 6.0 * k)], s + 1, roof, 1))
	parts.append(stk(Vector2(c.x - 9.0 * k, wall_top - 18.0 * k), Vector2(c.x - 13.0 * k, wall_top - 31.0 * k), 1.8 * k, s + 2, WOOD_D, 2))
	parts.append(stk(Vector2(c.x + 9.0 * k, wall_top - 18.0 * k), Vector2(c.x + 13.0 * k, wall_top - 31.0 * k), 1.8 * k, s + 3, WOOD_D, 2))
	sil(ci, parts, rim)
	for j in 4:
		var x := c.x - w + w * 0.5 * float(j + 1) - 2.0
		ln(ci, Vector2(x, wall_top + 7.0 * k), Vector2(x, c.y - 1.0), 1.4, Color(WOOD_D, 0.8), s + j)
	var door := rrect(Rect2(c.x - 6.0 * k, c.y - 16.0 * k, 12.0 * k, 16.0 * k), 5.0 * k, s, 0.3)
	ci.draw_colored_polygon(door, Color("3b2314"))
	for j in 3:
		ln(ci, Vector2(c.x - w * 0.6 + float(j) * w * 0.55, wall_top - 5.0 * k), Vector2(c.x - w * 0.5 + float(j) * w * 0.55, wall_top - 15.0 * k), 1.3, Color(INK, 0.3), s + j)

## 一片松林：每项 [x, 脚下 y, 高, 半宽, 层数]，先画后排（y 小、颜色深）
static func _grove(ci: CanvasItem, list: Array, s: int, rim: bool) -> void:
	list.sort_custom(func(a, b): return a[1] < b[1])
	for i in list.size():
		var q: Array = list[i]
		var back := clampf((40.0 - float(q[1])) / 14.0, 0.0, 1.0)
		_pine(ci, Vector2(q[0], q[1]), q[2], q[3], q[4], s + i * 3, rim, PINE_B.darkened(0.16 * back).lightened(0.04 * float(i % 2)))

## 树木数量整体往上走：1 簇针叶 → 1 → 2 → 2 → 3 → 3 → 4 → 4 → 5 → 6 棵
static func _wood(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var g := Vector2(0, 36)
	match lv:
		1:
			## 冒针叶的树桩：矮树桩，切口年轮，侧边冒一小簇墨绿松针
			_stump(ci, Vector2(-3, 18), 17, 16, s, rim, [ov(g, 24, 5, s + 8, EARTH, 0.0, 2)])
			_pine(ci, Vector2(16, 33), 17, 7, 2, s + 1, rim)
		2:
			## 树桩旁长出一棵小松苗
			_stump(ci, Vector2(-14, 22), 14, 12, s, rim, [ov(g, 28, 5, s + 8, EARTH, 0.0, 2)])
			_pine(ci, Vector2(8, 36), 42, 15, 2, s + 1, rim)
		3:
			## 两棵小松，一高一矮
			sil(ci, [ov(g, 32, 6, s, EARTH, 0.0, 2)], rim)
			_grove(ci, [[-10, 36, 66, 18, 3], [14, 37, 46, 15, 2]], s + 1, rim)
			PAWood._tuft(ci, Vector2(26, 37), s)
		4:
			## 一棵大松树砍着石斧，旁边一棵小松（开始产出）
			sil(ci, [ov(g, 38, 6, s, EARTH, 0.0, 2)], rim)
			_grove(ci, [[26, 35, 52, 16, 3], [-6, 37, 86, 29, 4]], s + 1, rim)
			_axe_in(ci, Vector2(-4, 27), Vector2(1, -0.35), s + 5, rim)
			_chips(ci, [Vector2(-26, 38), Vector2(-18, 40), Vector2(12, 40)], s)
		5:
			## 三棵松树，前面一个劈柴用的树墩，石斧插在墩上
			sil(ci, [ov(g, 44, 6, s, EARTH, 0.0, 2)], rim)
			_grove(ci, [[-22, 30, 78, 24, 4], [22, 29, 82, 25, 4], [0, 26, 74, 22, 3]], s + 1, rim)
			_stump(ci, Vector2(2, 32), 13, 9, s + 20, rim)
			_axe(ci, Vector2(18, 16), Vector2(6, 30), s + 22, rim, 0.85)
			_chips(ci, [Vector2(-16, 40), Vector2(-8, 42), Vector2(22, 41)], s)
		6:
			## 三棵松树，松林边用枝条搭了个小窝棚
			sil(ci, [ov(g, 48, 6, s, EARTH, 0.0, 2)], rim)
			_grove(ci, [[0, 26, 74, 22, 3], [-30, 33, 82, 25, 4], [30, 32, 86, 25, 4]], s + 1, rim)
			_lean_to(ci, Vector2(-2, 42), 1.3, s + 4, rim)
			_axe(ci, Vector2(30, 42), Vector2(22, 20), s + 6, rim, 0.85)
		7:
			## 四棵松树，窝棚变大了，顶上盖着兽皮，前景树桩长蘑菇
			sil(ci, [ov(g, 50, 6, s, EARTH, 0.0, 2)], rim)
			_grove(ci, [[-14, 24, 78, 22, 4], [16, 23, 82, 22, 4], [-38, 34, 84, 24, 4], [38, 33, 88, 24, 4]], s + 1, rim)
			var kk := _push(ci, 1.3, Vector2(4, 0))
			_lean_to(ci, Vector2(0, 42), 1.25, s + 4, rim)
			sil(ci, [pg([Vector2(-30, 8), Vector2(-10, 2), Vector2(28, 4), Vector2(36, 22), Vector2(0, 24), Vector2(-28, 22)], s + 8, HIDE2, 1)], false)
			if not Art.rim_only:
				for j in 4:
					ci.draw_circle(Vector2(-22.0 + float(j) * 16.0, 6.0 + float(j % 2) * 2.0), 1.6, Color(INK, 0.6))
			_pop(ci, kk)
			_stump(ci, Vector2(-32, 36), 10, 7, s + 20, rim)
			_mushrooms(ci, Vector2(-30, 31), 0.85, s + 30, rim)
		8:
			## 四棵高松围着一间小木屋：圆木墙、树皮屋顶，树上挂着蜂巢
			sil(ci, [ov(g, 52, 6, s, EARTH, 0.0, 2)], rim)
			_grove(ci, [[-32, 28, 88, 25, 5], [32, 27, 92, 25, 5], [-12, 20, 84, 22, 4], [14, 19, 86, 22, 4]], s + 1, rim)
			_hut(ci, Vector2(2, 46), 1.05, s + 10, rim, Color("8a6a44"))
			_hive(ci, Vector2(-38, 4), 0.75, s + 11, rim)
			_stump(ci, Vector2(40, 40), 10, 7, s + 21, rim)
			_axe(ci, Vector2(48, 24), Vector2(40, 37), s + 22, rim, 0.75)
		9:
			## 伐木营地：五棵高松，木屋更大、兽皮屋顶、烟囱冒烟，门口码着柴、挂着石斧
			sil(ci, [ov(g, 54, 6, s, EARTH, 0.0, 2)], rim)
			_grove(ci, [[0, 18, 84, 22, 4], [-26, 22, 88, 23, 5], [26, 21, 90, 23, 5], [-46, 36, 84, 23, 4], [46, 36, 86, 23, 4]], s + 1, rim)
			if not Art.rim_only:
				smoke(ci, Vector2(18, -32), 1.0)
			sil(ci, [stk(Vector2(18, -8), Vector2(18, -26), 4.0, s + 40, STONE_D)], rim)
			_hut(ci, Vector2(0, 48), 1.35, s + 10, rim)
			_axe(ci, Vector2(-24, 28), Vector2(-16, 16), s + 20, false, 0.7)
			_axe(ci, Vector2(24, 28), Vector2(16, 16), s + 21, false, 0.7)
			_woodpile(ci, Vector2(-40, 44), s + 50, rim)
			_hive(ci, Vector2(34, 2), 0.65, s + 30, rim)
		_:
			## 伐木长屋：六棵参天杉树围着一大一小两间木屋，烟囱冒烟，门前一圈木栅栏，金光
			glow(ci, Vector2(0, -16), 62, GOLD)
			sil(ci, [ov(g, 58, 6, s, EARTH, 0.0, 2)], rim)
			_grove(ci, [[-12, 14, 86, 21, 5], [14, 13, 90, 21, 5], [-34, 20, 90, 23, 5], [34, 19, 92, 23, 5], [-52, 38, 84, 21, 4], [52, 38, 86, 21, 4]], s + 1, rim)
			if not Art.rim_only:
				smoke(ci, Vector2(4, -40), 1.1)
			sil(ci, [stk(Vector2(4, -12), Vector2(4, -34), 4.4, s + 40, STONE_D)], rim)
			_hut(ci, Vector2(36, 48), 0.8, s + 12, rim, Color("8a6a44"))
			_hut(ci, Vector2(-8, 48), 1.6, s + 10, rim, Color("c98b52"))
			var fence := []
			for j in 7:
				var x := -52.0 + float(j) * 6.0
				fence.append(stk(Vector2(x, 50), Vector2(x, 36), 1.8, s + 60 + j, WOOD, 2))
			fence.append(stk(Vector2(-54, 42), Vector2(-14, 42), 1.6, s + 70, WOOD_D, 2))
			sil(ci, fence, rim, 2.2)
			_hive(ci, Vector2(-36, 4), 0.7, s + 30, rim)
			_woodpile(ci, Vector2(48, 48), s + 50, rim)
			_sparkles(ci, [Vector2(-56, -52), Vector2(56, -58), Vector2(60, 4)], 6.0)

## 门边码着的一小垛柴（截面朝外）
static func _woodpile(ci: CanvasItem, c: Vector2, s: int, rim: bool) -> void:
	var ends := [Vector2(-7, 0), Vector2(0, 0), Vector2(7, 0), Vector2(-3.5, -6), Vector2(3.5, -6), Vector2(0, -12)]
	var parts := []
	for j in ends.size():
		parts.append(ov(c + ends[j], 4.0, 3.6, s + j, PAWood.FACE, 0.0, 1))
	sil(ci, parts, rim, 2.2)
	if not Art.rim_only:
		for e in ends:
			ci.draw_arc(c + (e as Vector2), 1.6, 0, TAU, 8, Color(WOOD_D, 0.8), 1.0, true)

# ================================================================ 工具：打石场（石灰 + 紫晶）

const AM_DET := Color("e6ccfa")

## 一小簇紫晶：list 每项 [根部, 半宽, 高, 角度]
static func _ame(ci: CanvasItem, list: Array, s: int, rim: bool, extra: Array = []) -> void:
	PATool._st_crys(ci, list, s, AMETHYST, AM_DET, rim, extra)

## 圆河卵石锤石：表面有敲击白痕和一道细紫晶纹
static func _hammerstone(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool) -> void:
	sil(ci, [ov(c, r * 1.2, r, s, PATool.PEB, -0.2, 0, 0.05)], rim)
	pl(ci, [c + Vector2(-r * 0.9, r * 0.1), c + Vector2(-r * 0.3, -r * 0.15), c + Vector2(r * 0.2, r * 0.05), c + Vector2(r * 0.9, -r * 0.3)], 2.6, AMETHYST, s)
	pl(ci, [c + Vector2(-r * 0.3, -r * 0.15), c + Vector2(r * 0.2, r * 0.05)], 1.0, AM_DET, s + 1)
	for k in 4:
		var p := c + Vector2(r * 0.55 + float(k % 2) * 3.0, -r * 0.55 + float(k) * 2.5)
		ln(ci, p, p + Vector2(2.5, -1.5), 1.4, Color(1, 1, 1, 0.85), s + k)

static func _core(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool) -> void:
	sil(ci, [pg(PATool._st_nod_pts(c, r, s), s, PATool.CORTEX, 1)], rim)
	PATool._st_nod_det(ci, c, r, s)

## 平顶大石砧
static func _anvil(ci: CanvasItem, c: Vector2, w: float, th: float, s: int, rim: bool) -> void:
	sil(ci, PATool._st_slab_parts(c, w, w * 0.34, th, s, PATool.ROCK), rim)
	PATool._st_slab_det(ci, c, w, w * 0.34, th, s)

## 打好的石刃（细长叶形），斜靠着
static func _blade(c: Vector2, l: float, ang: float, s: int) -> Array:
	var pts := []
	for k in 14:
		var a := TAU * float(k) / 14.0
		pts.append(Vector2(cos(a) * l, sin(a) * l * 0.26 * (1.0 - 0.5 * maxf(cos(a), 0.0))))
	return pg(rot_pts(pts, ang, c), s, PATool.FLINT.lightened(0.1), 1)

## 石锤：木柄 a→b，b 端绑一块带紫纹的圆锤石，赭红皮绳扎紧
static func _stone_hammer(ci: CanvasItem, a: Vector2, b: Vector2, s: int, rim: bool, k: float = 1.0) -> void:
	var d := (b - a).normalized()
	var head := b + d * 3.0 * k
	sil(ci, [stk(a, b + d * 2.0 * k, 3.2 * k, s, WOOD), ov(head, 13.0 * k, 9.0 * k, s + 1, PATool.PEB, d.angle() + PI * 0.5, 0, 0.05)], rim, 2.6)
	if Art.rim_only:
		return
	var n := d.orthogonal()
	pl(ci, [head - n * 10.0 * k + d * 1.0, head - n * 2.0 * k - d * 1.5, head + n * 9.0 * k + d * 1.5], 2.4, AMETHYST, s)
	for j in 2:
		var m := b - d * (5.0 + float(j) * 4.0) * k
		ln(ci, m - n * 4.0 * k, m + n * 4.0 * k, 3.6 * k, INK, s + j)
		ln(ci, m - n * 3.2 * k, m + n * 3.2 * k, 2.0 * k, OCHRE_RED, s + j)

## 石镐：木柄 a→b，b 端横绑一块两头尖的燧石
static func _stone_pick(ci: CanvasItem, a: Vector2, b: Vector2, s: int, rim: bool, k: float = 1.0) -> void:
	var d := (b - a).normalized()
	var n := d.orthogonal()
	var head := [b + n * 16.0 * k + d * 2.0 * k, b + d * 5.0 * k, b - n * 16.0 * k + d * 2.0 * k, b - d * 4.0 * k]
	sil(ci, [stk(a, b + d * 2.0 * k, 3.0 * k, s, WOOD_D), pg(head, s + 1, PATool.FLINT.lightened(0.15), 1)], rim, 2.6)
	if Art.rim_only:
		return
	ln(ci, b + n * 12.0 * k + d * 1.5, b - n * 12.0 * k + d * 1.5, 1.4, Color(1, 1, 1, 0.4), s)
	var m := b - d * 6.0 * k
	ln(ci, m - n * 4.0 * k, m + n * 4.0 * k, 3.6 * k, INK, s)
	ln(ci, m - n * 3.2 * k, m + n * 3.2 * k, 2.0 * k, OCHRE_RED, s)

static func _tool(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 锤石：一块圆润的河卵石，带敲击白痕和一道紫晶纹
			sil(ci, [ov(Vector2(0, 33), 20, 4, s + 9, PATool.BEACH, 0.0, 2)], rim)
			_hammerstone(ci, Vector2(0, 24), 12, s, rim)
		2:
			## 石锤：锤石绑上木柄，用赭红皮绳扎紧
			sil(ci, [ov(Vector2(0, 35), 30, 5, s + 9, PATool.BEACH, 0.0, 2)], rim)
			_stone_hammer(ci, Vector2(-22, 34), Vector2(10, 4), s, rim)
		3:
			## 石锤和石镐交叉立在一块小石盘上，石盘边长着紫晶
			_anvil(ci, Vector2(0, 28), 22, 9, s + 6, rim)
			_stone_pick(ci, Vector2(22, 30), Vector2(-10, -10), s + 3, rim, 0.85)
			_stone_hammer(ci, Vector2(-22, 30), Vector2(10, -8), s, rim, 0.85)
			_ame(ci, [[Vector2(-4, 34), 3.0, 9.0, -0.4], [Vector2(2, 34), 3.5, 12.0, 0.0], [Vector2(8, 34), 2.8, 8.0, 0.45]], s + 5, rim)
		4:
			## 打石砧：中等的平顶石盘，上面一大块正在打的石核，碎屑飞溅（开始产出）
			_anvil(ci, Vector2(0, 22), 30, 14, s, rim)
			_core(ci, Vector2(-2, 8), 14, s + 1, rim)
			PATool._flakes(ci, [Vector2(-24, -8), Vector2(20, -10), Vector2(28, 2), Vector2(-30, 2)], s + 3)
			for k in 3:
				var a := -2.4 + float(k) * 0.7
				var d := Vector2(cos(a), sin(a))
				ln(ci, Vector2(-2, 2) + d * 18.0, Vector2(-2, 2) + d * 24.0, 1.8, Color(INK, 0.5), s + k)
			_ame(ci, [[Vector2(20, 40), 3.5, 10.0, -0.3], [Vector2(26, 40), 4.0, 14.0, 0.05], [Vector2(32, 40), 3.2, 9.0, 0.45]], s + 5, rim)
			_ame(ci, [[Vector2(-28, 40), 3.0, 8.0, -0.2]], s + 6, rim)
		5:
			## 石砧工作台：更大的石盘，上面一大块石核和一块紫晶，前面一排打好的石刃
			_anvil(ci, Vector2(0, 20), 38, 16, s, rim)
			_core(ci, Vector2(-10, 6), 15, s + 1, rim)
			_ame(ci, [[Vector2(14, 8), 3.5, 11.0, -0.3], [Vector2(20, 8), 4.0, 15.0, 0.1]], s + 7, rim)
			sil(ci, [_blade(Vector2(-28, 42), 11, -0.15, s + 2), _blade(Vector2(-12, 44), 11, -0.05, s + 3), _blade(Vector2(4, 44), 11, 0.08, s + 4)], rim, 2.4)
			_ame(ci, [[Vector2(22, 44), 4.0, 13.0, -0.4], [Vector2(29, 44), 5.0, 18.0, -0.05], [Vector2(37, 44), 4.0, 12.0, 0.4]], s + 5, rim)
		6:
			## 石板工作台：最大的石盘，上面再叠一块石板，台上石核、石锤，前面一排石刃，两边长着紫晶
			_anvil(ci, Vector2(0, 24), 46, 16, s, rim)
			_anvil(ci, Vector2(-4, 8), 32, 11, s + 10, rim)
			_core(ci, Vector2(-14, -4), 15, s + 1, rim)
			_stone_hammer(ci, Vector2(4, 2), Vector2(30, -4), s + 12, rim, 0.8)
			sil(ci, [_blade(Vector2(-30, 44), 11, -0.15, s + 2), _blade(Vector2(-14, 46), 11, -0.05, s + 3), _blade(Vector2(2, 46), 11, 0.08, s + 4)], rim, 2.4)
			_ame(ci, [[Vector2(24, 46), 4.5, 15.0, -0.4], [Vector2(31, 46), 5.5, 21.0, -0.05], [Vector2(39, 46), 4.5, 15.0, 0.3], [Vector2(45, 46), 3.0, 9.0, 0.6]], s + 5, rim)
			_ame(ci, [[Vector2(-48, 34), 3.5, 11.0, -0.4], [Vector2(-42, 34), 3.5, 14.0, 0.0]], s + 7, rim)
			_ame(ci, [[Vector2(14, -2), 3.0, 9.0, 0.1], [Vector2(20, -2), 3.0, 12.0, 0.35]], s + 8, rim)
		7:
			## 采石坑：岩壁凿出方茬，石板、石锤摆在前面，岩层里嵌着紫晶
			_old(ci, PATool, "tool", 5, 1.0, Vector2.ZERO, rim)
			var keep := _push(ci, PATool.GEN_SCALE[4])
			_ame(ci, [[Vector2(-36, 8), 4.0, 13.0, -0.5], [Vector2(-29, 8), 4.5, 18.0, -0.1], [Vector2(-22, 8), 3.5, 11.0, 0.3]], s + 25, false)
			_ame(ci, [[Vector2(32, 2), 3.5, 11.0, -0.2], [Vector2(38, 2), 3.5, 14.0, 0.2], [Vector2(43, 2), 2.8, 8.0, 0.6]], s + 27, false)
			_ame(ci, [[Vector2(-2, -16), 3.0, 9.0, -0.2], [Vector2(4, -16), 3.0, 12.0, 0.2]], s + 29, false)
			_ame(ci, [[Vector2(36, 40), 3.5, 10.0, -0.3], [Vector2(42, 40), 3.0, 7.0, 0.4]], s + 31, rim)
			_pop(ci, keep)
		8:
			## 紫晶矿坑：石坡上挖出竖井，架着木梯，坑壁和坡上长满紫晶
			_old(ci, PATool, "tool", 7, 1.0, Vector2.ZERO, rim)
			var keep := _push(ci, PATool.GEN_SCALE[6])
			_ame(ci, [[Vector2(-38, 8), 4.0, 13.0, -0.5], [Vector2(-31, 8), 4.5, 18.0, -0.1], [Vector2(-24, 8), 3.5, 11.0, 0.3]], s + 25, false)
			_ame(ci, [[Vector2(26, 2), 4.0, 14.0, -0.2], [Vector2(33, 2), 4.5, 18.0, 0.15], [Vector2(40, 2), 3.0, 9.0, 0.6]], s + 27, false)
			_ame(ci, [[Vector2(-18, -14), 3.0, 10.0, -0.2], [Vector2(16, -16), 3.0, 11.0, 0.2]], s + 29, false)
			_ame(ci, [[Vector2(-10, 16), 3.0, 9.0, -0.3], [Vector2(14, 16), 3.0, 9.0, 0.3]], s + 33, false)
			_ame(ci, [[Vector2(-46, 40), 4.0, 13.0, -0.4], [Vector2(-39, 40), 3.5, 10.0, 0.1], [Vector2(40, 40), 4.0, 14.0, 0.0], [Vector2(47, 40), 3.0, 8.0, 0.5]], s + 31, rim)
			_pop(ci, keep)
		9:
			## 晶洞矿口：岩洞口插着火把，洞里紫晶发光
			_old(ci, PATool, "tool", 8, 1.0, Vector2.ZERO, rim)
			var keep := _push(ci, PATool.GEN_SCALE[7])
			_ame(ci, [[Vector2(-50, 40), 4.0, 13.0, -0.5], [Vector2(-43, 40), 4.5, 19.0, -0.1]], s + 5, rim)
			_ame(ci, [[Vector2(44, 40), 4.5, 17.0, 0.05], [Vector2(51, 40), 3.5, 11.0, 0.45]], s + 7, rim)
			_ame(ci, [[Vector2(-30, -6), 3.0, 10.0, -0.3], [Vector2(30, -8), 3.0, 9.0, 0.3]], s + 9, false)
			_pop(ci, keep)
		_:
			## 大采石场：大晶洞前立着木吊杆、码着方石，洞口内外长满紫晶，金光
			glow(ci, Vector2(0, -4), 64, Color("c99ae8"))
			_old(ci, PATool, "tool", 8, 1.15, Vector2(0, 0), rim)
			sil(ci, [stk(Vector2(-42, 42), Vector2(-40, -36), 3.0, s + 1, WOOD_D), stk(Vector2(-44, -32), Vector2(-16, -44), 2.6, s + 2, WOOD_D)], rim)
			pl(ci, [Vector2(-18, -42), Vector2(-19, -22)], 3.4, INK, s)
			pl(ci, [Vector2(-18, -42), Vector2(-19, -22)], 1.8, ROPE, s)
			if not Art.rim_only:
				PATool._st_block(ci, Vector2(-20, -14), 8, 6, Vector2(4, -3), s + 3, PATool.SAND)
				PATool._st_block(ci, Vector2(-34, 36), 12, 7, Vector2(5, -4), s + 4, PATool.SAND)
				PATool._st_block(ci, Vector2(-34, 22), 9, 7, Vector2(5, -4), s + 5, PATool.SAND.lightened(0.05))
			else:
				sil(ci, [PATool._st_block_part(Vector2(-20, -14), 8, 6, Vector2(4, -3), PATool.SAND), PATool._st_block_part(Vector2(-34, 36), 12, 7, Vector2(5, -4), PATool.SAND),
					PATool._st_block_part(Vector2(-34, 22), 9, 7, Vector2(5, -4), PATool.SAND)], rim)
			_ame(ci, [[Vector2(22, 46), 4.5, 15.0, -0.4], [Vector2(30, 46), 5.5, 24.0, -0.05], [Vector2(38, 46), 5.0, 19.0, 0.3], [Vector2(45, 46), 3.5, 11.0, 0.6]], s + 7, rim)
			_ame(ci, [[Vector2(-12, 48), 3.5, 11.0, -0.4], [Vector2(-6, 48), 4.0, 16.0, 0.0], [Vector2(1, 48), 3.2, 10.0, 0.4]], s + 29, rim)
			_ame(ci, [[Vector2(-44, -6), 3.0, 9.0, -0.2], [Vector2(46, -10), 3.0, 12.0, 0.3]], s + 31, false)
			_ame(ci, [[Vector2(24, -26), 3.0, 10.0, 0.3], [Vector2(-8, -30), 3.0, 9.0, -0.2]], s + 33, false)
			_sparkles(ci, [Vector2(-56, -40), Vector2(54, -52), Vector2(60, 12)], 6.0)

# ================================================================ 狩猎：猎场（赭红 + 骨白）

## 借旧狩猎画法 trap_old 的某一级
static func _trap(ci: CanvasItem, n: int, k: float, off: Vector2, rim: bool) -> void:
	var keep := _push(ci, k, off)
	PAHunt.trap_old(ci, n, _os("hunt", n), rim)
	_pop(ci, keep)

## 赭红手印（画上去的，不描边）
static func _hand(ci: CanvasItem, c: Vector2, k: float, s: int, ang: float = 0.0) -> void:
	if Art.rim_only:
		return
	var col := Color(OCHRE_RED, 0.92)
	ci.draw_colored_polygon(ell(c, Vector2(4.2, 4.6) * k, s, 0.06, 12, ang), col)
	for j in 5:
		var a := ang - PI * 0.5 + (float(j) - 2.0) * 0.42 + (0.5 if j == 0 else 0.0)
		var d := Vector2(cos(a), sin(a))
		var l := (6.5 if j in [1, 2, 3] else 4.8) * k
		ci.draw_line(c + d * 3.0 * k, c + d * (3.0 * k + l), col, 2.4 * k, true)

## 一圈赭红皮绳：c 中心，r 半径（俯视压扁），带个活结和一截绳尾
static func _cord_loop(ci: CanvasItem, c: Vector2, r: float, s: int, flat: float = 0.45) -> void:
	if Art.rim_only:
		return
	var pts := arcp(c, Vector2(r, r * flat), 0.0, TAU, 24)
	ci.draw_polyline(PackedVector2Array(pts), INK, 5.0, true)
	ci.draw_polyline(PackedVector2Array(pts), OCHRE_RED, 3.0, true)
	var kn := c + Vector2(r, 0)
	var tail := [kn, kn + Vector2(8, 3), kn + Vector2(14, 1), kn + Vector2(20, 4)]
	pl(ci, tail, 5.0, INK, s)
	pl(ci, tail, 3.0, OCHRE_RED, s)
	ci.draw_circle(kn, 4.0, INK)
	ci.draw_circle(kn, 2.8, OCHRE_RED.lightened(0.15))

## 红羽毛标记：插在地上
static func _feather(ci: CanvasItem, base: Vector2, s: int, rim: bool, sc: float = 1.0) -> void:
	var tip := base + Vector2(4, -26) * sc
	sil(ci, [stk(base, tip, 1.2 * sc, s, BONE2, 2), ov(base.lerp(tip, 0.62), 4.6 * sc, 10.0 * sc, s + 1, OCHRE_RED, 0.15, 1)], rim, 2.2)
	for j in 3:
		var p := base.lerp(tip, 0.45 + 0.13 * float(j))
		ln(ci, p + Vector2(-3, 1) * sc, p + Vector2(3, -1) * sc, 1.2, Color(BONE, 0.8), s + j)

## 篝火：一圈石头、交叉的柴、火苗
static func _campfire(ci: CanvasItem, c: Vector2, k: float, s: int, rim: bool) -> void:
	var parts := []
	for j in 7:
		var a := PI * 0.05 + PI * 0.9 * float(j) / 6.0
		parts.append(ov(c + Vector2(cos(a) * 14.0, sin(a) * 5.0) * k, 4.2 * k, 3.2 * k, s + j, STONE.lightened(0.06 * float(j % 2)), 0.0, 1))
	parts.append(stk(c + Vector2(-12, 2) * k, c + Vector2(10, -6) * k, 2.6 * k, s + 10, WOOD_D))
	parts.append(stk(c + Vector2(12, 2) * k, c + Vector2(-10, -6) * k, 2.6 * k, s + 11, WOOD))
	sil(ci, parts, rim, 2.2)
	if not Art.rim_only:
		flame(ci, c + Vector2(0, -12) * k, 10.0 * k, 22.0 * k, s)

## 圆坑：坑口圆一些，看得到坑里的后壁和一排尖木刺，前沿的土挡住木刺的根
static func _pit(ci: CanvasItem, s: int, rim: bool, k: float = 1.0) -> void:
	var c := Vector2(0, 16)
	sil(ci, [ov(c, 42 * k, 32 * k, s, Color("7a4f2a"), 0.0, 1)], rim)
	if Art.rim_only:
		return
	var hole := ell(c + Vector2(0, -2), Vector2(32, 25) * k, s + 1, 0.04, 22)
	ci.draw_colored_polygon(hole, Color("2a170c"))
	ci.draw_colored_polygon(ell(c + Vector2(0, -12) * k, Vector2(28, 12) * k, s + 2, 0.04, 18), Color("4e2a1a"))
	outline(ci, hole, 2.2)
	var stakes := []
	var tips := []
	for j in 7:
		var x := lerpf(-22.0, 22.0, float(j) / 6.0) * k
		var tip_y := c.y + (-14.0 + float(j % 2) * 6.0 + absf(x) * 0.25) * k
		var base := c.y + 20.0 * k - absf(x) * 0.3
		stakes.append(pg([Vector2(x - 3.4, base), Vector2(x, tip_y), Vector2(x + 3.4, base)], s + 3 + j, WOOD.lightened(0.08), 1))
		tips.append(Vector2(x, tip_y))
	sil(ci, stakes, false, 2.2)
	for tp in tips:
		ci.draw_colored_polygon(poly([tp + Vector2(-1.4, 6), tp + Vector2(0, 1), tp + Vector2(1.4, 6)], s), BONE2)
	## 前沿的土：盖住木刺的根
	var lip := []
	for j in 13:
		var a := PI * float(j) / 12.0
		lip.append(c + Vector2(cos(a) * 32.0, sin(a) * 25.0 - 2.0) * k)
	for j in 13:
		var a := PI - PI * float(j) / 12.0
		lip.append(c + Vector2(cos(a) * 41.0, sin(a) * 31.0) * k)
	ci.draw_colored_polygon(poly(lip, s + 20, 0.3), Art.rc(Color("7a4f2a")))
	pl(ci, arcp(c + Vector2(0, -2) * k, Vector2(32, 25) * k, 0.05, PI - 0.05, 12), 2.2, INK, s)

static func _hunt(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var dirt := Color("7a4f2a")
	match lv:
		1:
			## 赭红套索：一个赭红皮绳打的活结绳圈
			sil(ci, [ov(Vector2(2, 32), 26, 6, s, dirt, 0.0, 1)], rim)
			_cord_loop(ci, Vector2(-2, 28), 14, s)
		2:
			## 做套索的一套东西：一卷赭红皮绳、一根扳机木桩、一块按着赭红手印的石头
			sil(ci, [ov(Vector2(0, 33), 36, 6, s, dirt, 0.0, 1), raw_rock(Vector2(-18, 24), 12, s + 1, STONE.lightened(0.1), 7, 0.15),
				stk(Vector2(14, 34), Vector2(24, 6), 2.6, s + 2, WOOD, 2), stk(Vector2(18, 14), Vector2(28, 16), 2.0, s + 3, WOOD, 2)], rim)
			_hand(ci, Vector2(-18, 22), 0.9, s)
			_cord_loop(ci, Vector2(6, 31), 9, s + 4, 0.5)
			_cord_loop(ci, Vector2(4, 29), 8, s + 5, 0.5)
		3, 4:
			## 3 搭好的弹套：压弯的小树苗吊着赭红绳圈，绳圈里挂一颗红莓当诱饵
			## 4 套到了一只野兔（开始产出）
			var k := 0.95 if lv == 3 else 1.02
			_trap(ci, 2, k, Vector2.ZERO, rim)
			var keep := _push(ci, k)
			if not Art.rim_only:
				ci.draw_arc(Vector2(10, 24), 15, 0, TAU, 28, INK, 4.6, true)
				ci.draw_arc(Vector2(10, 24), 15, 0, TAU, 28, OCHRE_RED, 2.6, true)
				ln(ci, Vector2(20, -28), Vector2(14, 8), 2.6, INK, s)
				ln(ci, Vector2(20, -28), Vector2(14, 8), 1.4, OCHRE_RED, s)
			if lv == 3:
				PAFood._berries(ci, [Vector2(10, 22)], 4.6, BERRY, s + 3) if not Art.rim_only else null
				sil(ci, [raw_rock(Vector2(-38, 30), 9, s + 1, STONE.lightened(0.1), 7, 0.15)], rim)
				_hand(ci, Vector2(-38, 28), 0.7, s)
			_pop(ci, keep)
			if lv == 4:
				var kk := _push(ci, 0.56, Vector2(-6, -6))
				PAHunt._main_art(ci, 2, s + 30, rim)
				_pop(ci, kk)
		6:
			## 伪装陷阱坑：圆圆的坑口，坑里竖着尖木刺；左半边用树枝树叶盖着，旁边插一根赭红羽毛做记号
			_pit(ci, s, rim)
			var cover := []
			for j in 3:
				var x := -32.0 + float(j) * 14.0
				cover.append(stk(Vector2(x - 6.0, 40), Vector2(x + 8.0, 2), 2.4, s + 2 + j, WOOD, 2))
			cover.append(stk(Vector2(-44, 16), Vector2(0, 30), 2.4, s + 7, WOOD_D, 2))
			var lc := [Vector2(-30, 14), Vector2(-16, 10), Vector2(-24, 26), Vector2(-8, 22), Vector2(-34, 32), Vector2(-14, 34)]
			for j in lc.size():
				cover.append(leaf(lc[j], 18, 7.5, -2.6 + float(j) * 1.1, s + 10 + j, LEAF if j % 2 == 0 else LEAF_D.lightened(0.12)))
			sil(ci, cover, false)
			for j in lc.size():
				vein(ci, lc[j], 18, -2.6 + float(j) * 1.1, s + j)
			_feather(ci, Vector2(44, 34), s + 30, rim, 1.3)
		5:
			## 陷阱坑：坑口全掀开了，一圈尖木刺看得清清楚楚，一只野猪掉在刺上
			_pit(ci, s, rim, 1.08)
			if not Art.rim_only:
				var boar := Color("a87650")
				var b := Vector2(14, 22)
				var parts := [ov(b, 13, 8, s, boar, 0.0, 1), ov(b + Vector2(-12, 1), 7, 6, s + 1, boar.darkened(0.05), 0.0, 1),
					pg([b + Vector2(-12, -4), b + Vector2(-9, -11), b + Vector2(-6, -3)], s + 2, boar.darkened(0.15), 1),
					ov(b + Vector2(-16, 3), 3, 2.6, s + 3, Color("c9a080"), 0.0, 1)]
				sil(ci, parts, false)
				zig(ci, b.x - 6.0, b.x + 8.0, b.y - 7.0, 1.4, 5, Color("3b2314"), 1.8, s)
				xeye(ci, b + Vector2(-11, 0), 1.4, 1.4)
			_feather(ci, Vector2(-46, 34), s + 30, rim, 1.2)
			_feather(ci, Vector2(46, 32), s + 31, rim, 1.2)
		7:
			## 木笼陷阱：门板吊在上面，门板上按着赭红手印
			_trap(ci, 5, 1.0, Vector2.ZERO, rim)
			_hand(ci, Vector2(0, -35), 0.8, s)
		8:
			## 猎人帐篷：兽皮帐篷画着赭红手印，旁边晾着兽皮
			_trap(ci, 7, 1.0, Vector2.ZERO, rim)
			_hand(ci, Vector2(-23, -6), 0.75, s)
			_hand(ci, Vector2(-33, 26), 0.6, s + 1, -0.3)
		9:
			## 猎人营地：帐篷、武器架、篝火
			sil(ci, [stk(Vector2(-50, 38), Vector2(-56, -34), 2.0, s + 60, WOOD, 2), stk(Vector2(-44, 38), Vector2(-46, -38), 2.0, s + 61, WOOD, 2)], rim, 2.2)
			sil(ci, [pg([Vector2(-59, -30), Vector2(-58, -46), Vector2(-53, -31)], s + 62, STONE, 2), pg([Vector2(-49, -34), Vector2(-46, -50), Vector2(-43, -34)], s + 63, STONE, 2)], rim, 2.2)
			_trap(ci, 7, 0.95, Vector2(4, 0), rim)
			_hand(ci, Vector2(-17, -5), 0.7, s)
			_hand(ci, Vector2(-27, 26), 0.55, s + 1, -0.3)
			_campfire(ci, Vector2(10, 40), 0.9, s + 40, rim)
		_:
			## 猛犸狩猎屋：猛犸骨头搭的圆顶屋，墙上赭红手印，门口立着骨头图腾
			_trap(ci, 8, 1.0, Vector2(-4, 0), rim)
			_hand(ci, Vector2(-26, 6), 0.8, s, -0.3)
			_hand(ci, Vector2(18, 4), 0.8, s + 1, 0.3)
			var tx := 44.0
			var parts := [stk(Vector2(tx, 40), Vector2(tx, -16), 3.0, s + 50, BONE2)]
			for j in 3:
				parts.append(ov(Vector2(tx, -4.0 + float(j) * 13.0), 6.5, 4.0, s + 51 + j, BONE, 0.0, 1))
			parts.append(ov(Vector2(tx, -20), 8, 6.5, s + 55, BONE, 0.0, 1))
			sil(ci, parts, rim, 2.4)
			if not Art.rim_only:
				ci.draw_circle(Vector2(tx - 3, -21), 1.8, INK)
				ci.draw_circle(Vector2(tx + 3, -21), 1.8, INK)
				for j in 3:
					ln(ci, Vector2(tx - 5, -4.0 + float(j) * 13.0), Vector2(tx + 5, -4.0 + float(j) * 13.0), 1.8, OCHRE_RED, s + j)

# ================================================================ 衣服：织皮作坊（金黄麻线）

## 骨针：针眼在上，穿着金黄麻线
static func _needle(ci: CanvasItem, a: Vector2, b: Vector2, s: int, rim: bool, thread: Array = []) -> void:
	var d := (b - a).normalized()
	sil(ci, [pg([a - d.orthogonal() * 2.6, a + d.orthogonal() * 2.6, b], s, BONE2, 1), circ(a, 3.2, s + 1, BONE2, 1)], rim, 2.2)
	if not Art.rim_only:
		ci.draw_circle(a, 1.3, INK)
		if thread.size() > 1:
			pl(ci, [a] + thread, 3.6, INK, s)
			pl(ci, [a] + thread, 2.0, FLAX, s)

## 下坠纺锤：木杆 + 石盘，杆上缠一团金黄线
static func _spindle(ci: CanvasItem, top: Vector2, h: float, s: int, rim: bool) -> void:
	var bot := top + Vector2(0, h)
	var ball := top + Vector2(0, h * 0.38)
	sil(ci, [stk(top, bot, 1.8, s, WOOD, 2), ov(top + Vector2(0, h * 0.72), h * 0.3, h * 0.1, s + 1, STONE, 0.0, 1),
		ov(ball, h * 0.2, h * 0.22, s + 2, FLAX, 0.0, 1)], rim, 2.2)
	if not Art.rim_only:
		PACloth._cl_ball_det(ci, ball, h * 0.2, s, [Color(FLAX_D, 0.9)])
		ln(ci, top + Vector2(-h * 0.3, h * 0.7), top + Vector2(h * 0.3, h * 0.7), 1.2, Color(INK, 0.3), s)

## 竖织机：两根柱子一根顶梁，经线垂下来，上半截织成金黄和赭色的条纹布，下面坠着石头
static func _loom(ci: CanvasItem, c: Vector2, w: float, h: float, s: int, rim: bool) -> void:
	var top := c.y - h
	var parts := [stk(Vector2(c.x - w, c.y), Vector2(c.x - w + 4.0, top - 6.0), 3.0, s, WOOD_D), stk(Vector2(c.x + w, c.y), Vector2(c.x + w - 4.0, top - 6.0), 3.0, s + 1, WOOD_D),
		stk(Vector2(c.x - w - 4.0, top), Vector2(c.x + w + 4.0, top), 3.0, s + 2, WOOD)]
	var cloth := [Vector2(c.x - w + 6.0, top + 2.0), Vector2(c.x + w - 6.0, top + 2.0), Vector2(c.x + w - 7.0, top + h * 0.55), Vector2(c.x - w + 7.0, top + h * 0.55)]
	parts.append(pg(cloth, s + 3, FLAX, 2))
	sil(ci, parts, rim)
	if Art.rim_only:
		return
	var n := 4
	for j in n:
		var y0 := lerpf(top + 2.0, top + h * 0.55, float(j) / float(n))
		var y1 := lerpf(top + 2.0, top + h * 0.55, (float(j) + 0.5) / float(n))
		ci.draw_colored_polygon(poly([Vector2(c.x - w + 6.5, y0), Vector2(c.x + w - 6.5, y0), Vector2(c.x + w - 6.5, y1), Vector2(c.x - w + 6.5, y1)], s + j, 0.2), Art.rc(OCHRE_RED))
	outline(ci, poly(cloth, s + 3), 1.8)
	var k := 6
	for j in k:
		var x := lerpf(c.x - w + 9.0, c.x + w - 9.0, float(j) / float(k - 1))
		ln(ci, Vector2(x, top + h * 0.55), Vector2(x, c.y - 10.0), 1.2, Color(FLAX_D, 0.95), s + j)
		ci.draw_circle(Vector2(x, c.y - 8.0), 2.6, INK)
		ci.draw_circle(Vector2(x, c.y - 8.0), 1.8, STONE)

## 一团金黄线球
static func _yarn(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool, col: Color = FLAX) -> void:
	sil(ci, [circ(c, r, s, col, 1)], rim, 2.2)
	if not Art.rim_only:
		PACloth._cl_ball_det(ci, c, r, s, [Color(Art.rc(col).darkened(0.3), 0.9)])

static func _cloth(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 骨针：一根骨针穿着一截金黄麻线
			sil(ci, [ov(Vector2(0, 34), 22, 4, s + 9, Color("7a4f2a"), 0.0, 1)], rim)
			_needle(ci, Vector2(-14, 14), Vector2(18, 30), s, rim, [Vector2(-20, 6), Vector2(-22, 18), Vector2(-14, 26), Vector2(-4, 32), Vector2(4, 36)])
		2:
			## 石盘纺锤，缠着一团金黄麻线，线头垂下来
			sil(ci, [ov(Vector2(0, 36), 24, 4, s + 9, Color("7a4f2a"), 0.0, 1)], rim)
			_spindle(ci, Vector2(-4, -6), 40, s, rim)
			if not Art.rim_only:
				pl(ci, [Vector2(-4, -6), Vector2(4, -12), Vector2(14, -6), Vector2(18, 8), Vector2(16, 26), Vector2(22, 34)], 3.6, INK, s)
				pl(ci, [Vector2(-4, -6), Vector2(4, -12), Vector2(14, -6), Vector2(18, 8), Vector2(16, 26), Vector2(22, 34)], 2.0, FLAX, s)
		3:
			## 搭了一半的晾架：一根叉杆立着，横杆一头搭在叉上一头落地；前面摆着纺锤、骨针和线团
			_old(ci, PACloth, "cloth", 3, 1.0, Vector2(-4, 0), rim)
			var keep := _push(ci, 0.62, Vector2(24, 6))
			_spindle(ci, Vector2(-8, -6), 40, s + 1, rim)
			_needle(ci, Vector2(6, 24), Vector2(30, 32), s + 2, rim, [Vector2(2, 18), Vector2(6, 12)])
			_yarn(ci, Vector2(16, 30), 7, s + 4, rim)
			_pop(ci, keep)
		4:
			## 晾麻架：横杆上挂着一排麻束和草（开始产出）
			_old(ci, PACloth, "cloth", 4, 0.95, Vector2.ZERO, rim)
		5:
			## 晾架 + 捶麻石台
			_old(ci, PACloth, "cloth", 5, 0.95, Vector2.ZERO, rim)
		6:
			## 竖织机：已经织出一截金黄与赭色相间的条纹布
			sil(ci, [ov(Vector2(0, 38), 40, 4, s + 9, Color("7a4f2a"), 0.0, 1)], rim)
			_loom(ci, Vector2(0, 38), 30, 66, s, rim)
			_yarn(ci, Vector2(-34, 32), 7, s + 4, rim)
			_yarn(ci, Vector2(36, 33), 6, s + 5, rim, OCHRE_RED)
		7:
			## 绷皮架：木框绷着一张毛皮，框边挂着麻束
			_old(ci, PACloth, "cloth", 6, 1.0, Vector2.ZERO, rim)
			var keep := _push(ci, PACloth.GEN_SCALE[5])
			sil(ci, [PACloth._cl_hang(-36, -26, 5.0, 22.0, s + 10, FLAX), PACloth._cl_hang(36, -26, 5.0, 24.0, s + 11, FLAX)], rim)
			if not Art.rim_only:
				PACloth._cl_hang_det(ci, -36, -26, 5.0, 22.0, s, FLAX)
				PACloth._cl_hang_det(ci, 36, -26, 5.0, 24.0, s + 5, FLAX)
			_pop(ci, keep)
		8:
			## 鞣皮坑：横杆上搭着三张皮，前面泡皮的坑
			_old(ci, PACloth, "cloth", 7, 1.0, Vector2.ZERO, rim)
		9:
			## 皮匠棚：兽皮大棚，旁边晾架挂满麻束
			PA.glow_off = true
			_old(ci, PACloth, "cloth", 8, 0.9, Vector2(-14, 0), rim)
			_old(ci, PACloth, "cloth", 4, 0.62, Vector2(36, 2), rim)
			PA.glow_off = false
			_yarn(ci, Vector2(18, 36), 6, s + 4, rim)
		_:
			## 部落织皮大棚：大棚两边是织机和晾架，门口堆着线团，金光
			glow(ci, Vector2(0, -6), 60, GOLD)
			PA.glow_off = true
			_old(ci, PACloth, "cloth", 8, 0.98, Vector2(0, 0), rim)
			_loom(ci, Vector2(-38, 40), 16, 44, s + 20, rim)
			_old(ci, PACloth, "cloth", 4, 0.56, Vector2(40, 4), rim)
			PA.glow_off = false
			_yarn(ci, Vector2(-14, 38), 6, s + 4, rim)
			_yarn(ci, Vector2(-4, 40), 5, s + 5, rim, OCHRE_RED)
			_yarn(ci, Vector2(14, 39), 6, s + 6, rim)

# ================================================================ 渔猎：渔具到码头（蓝绿钓线 + 水蓝）

## 借渔猎第一稿（池塘、鱼梁、渔棚、码头）的某一级
static func _fish_v1(ci: CanvasItem, n: int, k: float, off: Vector2, rim: bool, ds: int = 0) -> void:
	var keep := _push(ci, k, off)
	PAFish._gen_art_v1(ci, n, _os("fish", n) + ds, rim)
	_pop(ci, keep)

## 骨鱼钩：J 形，带倒刺，顶上一个绑线的疙瘩
static func _hook(ci: CanvasItem, top: Vector2, h: float, s: int, rim: bool) -> void:
	var r := h * 0.3
	var bc := top + Vector2(-r, h - r)
	var parts := [stk(top, top + Vector2(0, h - r), h * 0.07, s, BONE2, 2), band(bc, r, h * 0.07, 0.0, PI * 0.95, s + 1, BONE2),
		pg([bc + Vector2(-r - h * 0.08, 0), bc + Vector2(-r + h * 0.05, -h * 0.18), bc + Vector2(-r + h * 0.08, 0)], s + 2, BONE2, 2),
		circ(top, h * 0.09, s + 3, CORD, 1)]
	sil(ci, parts, rim, 2.2)

## 木线轴：两头粗的木棒，中间缠满蓝绿钓线
static func _spool(ci: CanvasItem, c: Vector2, w: float, s: int, rim: bool) -> void:
	sil(ci, [ov(c + Vector2(-w, 0), w * 0.22, w * 0.6, s, WOOD, 0.0, 1), bx(c.x - w, c.y - w * 0.42, w * 2.0, w * 0.84, 3, s + 1, CORD),
		ov(c + Vector2(w, 0), w * 0.22, w * 0.6, s + 2, WOOD, 0.0, 1)], rim, 2.4)
	if not Art.rim_only:
		for j in 6:
			var x := c.x - w * 0.75 + float(j) * w * 0.3
			ln(ci, Vector2(x, c.y - w * 0.38), Vector2(x + w * 0.12, c.y + w * 0.38), 1.2, Color(CORD.darkened(0.35), 0.8), s + j)
		hl(ci, c + Vector2(-w * 0.3, -w * 0.2), w * 0.4, w * 0.08, 0.0, 0.45)

## 一汪水：渔猎线每一级脚下都有水，蓝色就是这条线的主色
static func _pool(ci: CanvasItem, c: Vector2, rx: float, ry: float, s: int, rim: bool) -> void:
	sil(ci, [ov(c, rx, ry, s, WATER_D, 0.0, 2)], rim)
	if Art.rim_only:
		return
	ci.draw_colored_polygon(ell(c + Vector2(0, -ry * 0.2), Vector2(rx * 0.86, ry * 0.7), s + 1, 0.03, 20), WATER)
	for j in 2:
		pl(ci, arcp(c + Vector2(-rx * 0.35 + float(j) * rx * 0.6, -ry * 0.1), Vector2(rx * 0.14, ry * 0.25), 0.2, PI - 0.2, 6), 1.4, Color(1, 1, 1, 0.7), s + j)

static func _fish(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 骨鱼钩：一枚骨鱼钩，拴着一段蓝绿麻线
			sil(ci, [ov(Vector2(0, 34), 22, 4, s + 9, PAFish.BANK, 0.0, 1)], rim)
			_hook(ci, Vector2(6, 2), 30, s, rim)
			if not Art.rim_only:
				var cord := [Vector2(6, 2), Vector2(-2, -4), Vector2(-12, 2), Vector2(-16, 16), Vector2(-10, 28), Vector2(-20, 34)]
				pl(ci, cord, 3.8, INK, s)
				pl(ci, cord, 2.2, CORD, s)
		2:
			## 骨鱼钩 + 缠满蓝绿钓线的木线轴
			sil(ci, [ov(Vector2(0, 35), 34, 5, s + 9, PAFish.BANK, 0.0, 1)], rim)
			_spool(ci, Vector2(-10, 26), 14, s, rim)
			_hook(ci, Vector2(22, 4), 28, s + 5, rim)
			if not Art.rim_only:
				var cord := [Vector2(4, 22), Vector2(12, 14), Vector2(16, 4), Vector2(22, 4)]
				pl(ci, cord, 3.8, INK, s)
				pl(ci, cord, 2.2, CORD, s)
		3:
			## 倒刺鱼叉，斜插在水边
			_pool(ci, Vector2(-4, 34), 36, 7, s + 40, rim)
			_old(ci, PAFish, "fish", 4, 0.92, Vector2.ZERO, rim)
		4:
			## 钓竿钓到一条小鱼（开始产出）
			_pool(ci, Vector2(10, 37), 38, 7, s + 40, rim)
			_old(ci, PAFish, "fish", 5, 1.0, Vector2.ZERO, rim)
		5:
			## 藤鱼笼，笼口探出两条鱼
			_pool(ci, Vector2(0, 36), 44, 8, s + 40, rim)
			_old(ci, PAFish, "fish", 6, 1.0, Vector2.ZERO, rim)
			PAFish._fish(ci, Vector2(14, 34), 24, 7, 0.1, s + 20, PAFish.SILVER, rim)
		6:
			## 渔网架：晾着一张网
			_pool(ci, Vector2(0, 37), 46, 8, s + 40, rim)
			_old(ci, PAFish, "fish", 7, 1.0, Vector2.ZERO, rim)
		7:
			## 石堰鱼栅：一排石头拦住河水，石头后面插着一道木栅栏，中间缺口卡着一只大鱼笼，水里围着好几条鱼
			var kk := _push(ci, 1.0, Vector2(0, 0))
			_pool(ci, Vector2(0, 24), 56, 22, s + 40, rim)
			var fence := []
			for k in 9:
				var u := float(k) / 8.0
				if k == 4:
					continue
				var x := lerpf(-44.0, 44.0, u)
				var y := 24.0 - sin(PI * u) * 16.0
				fence.append(stk(Vector2(x, y), Vector2(x + 1.0, y - 30.0), 2.4, s + 50 + k, WOOD, 2))
			fence.append(stk(Vector2(-46, 8), Vector2(-4, -10), 1.8, s + 60, WOOD_D, 2))
			fence.append(stk(Vector2(4, -10), Vector2(46, 8), 1.8, s + 61, WOOD_D, 2))
			sil(ci, fence, rim, 2.2)
			if not Art.rim_only:
				PAFish._fish(ci, Vector2(-22, 6), 18, 5.5, -0.3, s + 20, PAFish.SILVER, false)
				PAFish._fish(ci, Vector2(20, 4), 20, 6, 0.25, s + 21, PAFish.CRUCIAN, false)
			var stones := []
			for k in 9:
				var u := float(k) / 8.0
				if k == 4:
					continue
				stones.append(ov(Vector2(lerpf(-48.0, 48.0, u), 30.0 - sin(PI * u) * 16.0), 8.0, 6.5, s + k, PAFish.ROCK.lightened((srnd(s + k) - 0.5) * 0.16), 0.0, 0, 0.08))
			sil(ci, stones, rim, 2.4)
			if not Art.rim_only:
				for k in 8:
					var u := (float(k) + 0.5) / 8.0
					var q := Vector2(lerpf(-48.0, 48.0, u), 30.0 - sin(PI * u) * 16.0)
					pl(ci, [q + Vector2(0, 3), q + Vector2(1, 7), q + Vector2(0, 11)], 1.8, Color(1, 1, 1, 0.85), s + k)
				PAFish._fish(ci, Vector2(2, -22), 20, 6.5, -0.6, s + 22, PAFish.CARP, false)
				for k in 3:
					ci.draw_circle(Vector2(-10.0 + float(k) * 6.0, -8.0 - float(k % 2) * 4.0), 1.8, Color(1, 1, 1, 0.85))
			_pop(ci, kk)
		8:
			## 独木舟：船里放着桨和鱼笼
			_pool(ci, Vector2(0, 32), 54, 10, s + 40, rim)
			_old(ci, PAFish, "fish", 8, 0.8, Vector2.ZERO, rim)
		9:
			## 独木舟码头：木栈桥从岸边伸进水里，桥上立着晒鱼架、放着一篓鱼，桥边停着独木舟
			_pool(ci, Vector2(6, 28), 58, 18, s + 40, rim)
			sil(ci, [ov(Vector2(-42, 30), 22, 12, s + 41, Color("d8b47a"), 0.0, 1)], rim)
			var posts := []
			for x in [-26.0, -4.0, 18.0]:
				posts.append(stk(Vector2(x, 14.0 - x * 0.08), Vector2(x, 34.0 - x * 0.08), 2.6, s + 50 + int(x), WOOD_D, 2))
			sil(ci, posts, rim, 2.2)
			var deck := [Vector2(-54, 18), Vector2(-50, 8), Vector2(34, 2), Vector2(36, 10)]
			sil(ci, [pg(deck, s + 42, WOOD, 1)], rim)
			if not Art.rim_only:
				for j in 9:
					var u := float(j + 1) / 10.0
					ln(ci, Vector2(-52, 13).lerp(Vector2(35, 6), u) + Vector2(1, -4), Vector2(-52, 13).lerp(Vector2(35, 6), u) + Vector2(-1, 4), 1.3, Color(WOOD_D, 0.85), s + j)
			## 晒鱼架
			sil(ci, [stk(Vector2(-40, 12), Vector2(-40, -26), 2.2, s + 60, WOOD_D, 2), stk(Vector2(-12, 9), Vector2(-12, -28), 2.2, s + 61, WOOD_D, 2),
				stk(Vector2(-44, -24), Vector2(-8, -26), 2.2, s + 62, WOOD, 2)], rim, 2.2)
			if not Art.rim_only:
				for j in 3:
					var x := -34.0 + float(j) * 10.0
					ln(ci, Vector2(x, -25), Vector2(x, -20), 1.4, CORD, s + j)
					PAFish._fish(ci, Vector2(x, -10), 16, 4.8, PI * 0.5, s + 83 + j, [PAFish.SILVER, PAFish.CRUCIAN, PAFish.SALMON][j], false)
			## 一篓鱼
			sil(ci, [pg([Vector2(14, -6), Vector2(30, -8), Vector2(28, 6), Vector2(16, 7)], s + 70, Color("c99a52"), 1)], rim, 2.2)
			if not Art.rim_only:
				PAFish._fish(ci, Vector2(22, -10), 14, 4, -0.5, s + 71, PAFish.CARP, false)
			_old(ci, PAFish, "fish", 8, 0.6, Vector2(16, 10), rim)
		_:
			## 水上渔寮：高脚木棚立在水里，屋檐下挂满晾鱼，旁边停着独木舟，金光
			glow(ci, Vector2(0, -8), 62, GOLD)
			_fish_v1(ci, 7, 1.2, Vector2(-8, 0), rim, 1)
			_old(ci, PAFish, "fish", 8, 0.55, Vector2(30, 6), rim)
			_sparkles(ci, [Vector2(-52, -40), Vector2(50, -48), Vector2(56, 10)], 6.0)

# ================================================================ 陶艺：陶坊到陶窑（陶土橙红 + 窑火）

static func _pot_v1(ci: CanvasItem, n: int, k: float, off: Vector2, rim: bool) -> void:
	var keep := _push(ci, k, off)
	PAPot._gen_v1(ci, n, _os("pot", n), rim)
	_pop(ci, keep)

## 摆在地上的一只小陶器：c 是底部中心
static func _pot_at(ci: CanvasItem, c: Vector2, k: float, kind: int, s: int, rim: bool) -> void:
	var keep := xf
	xf = keep * Transform2D(0.0, Vector2(k, k), 0.0, c)
	ci.draw_set_transform_matrix(xf)
	match kind:
		0:
			var prof := [Vector2(12, -10), Vector2(11, -5), Vector2(7, 0)]
			PAPot.vessel(ci, prof, PAPot.FIRED, s, rim)
		1:
			var prof := [Vector2(7, -26), Vector2(8, -22), Vector2(13, -14), Vector2(12, -5), Vector2(7, 0)]
			PAPot.vessel(ci, prof, PAPot.FIRED, s, rim)
			if not Art.rim_only:
				PAPot.zig_at(ci, prof, -14.0, 2.5, 6, PAPot.BLACK_P, 2.0)
		_:
			var prof := [Vector2(9, -30), Vector2(10, -26), Vector2(17, -16), Vector2(15, -5), Vector2(9, 0)]
			PAPot.vessel(ci, prof, PAPot.PAINT, s, rim)
			if not Art.rim_only:
				PAPot.band_at(ci, prof, -22.0, PAPot.RED_P, 2.6)
				PAPot.zig_at(ci, prof, -14.0, 2.5, 7, PAPot.BLACK_P, 2.0)
	xf = keep
	ci.draw_set_transform_matrix(xf)

static func _pot(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	## 1~4 做坯：泥团 → 加木拍 → 上慢轮 → 上快轮；5~10 烧陶：烧坑 → 砖砌烧坑 → 小土窑 → 馒头窑 → 陶坊 → 彩陶大窑，窑前的陶器一级比一级多
	match lv:
		1:
			## 一团橙红湿陶泥，表面按着指印
			_clay(ci, Vector2(0, 22), 15, s, rim)
		2:
			## 泥团旁边放着一把拍泥木拍
			_old(ci, PAPot, "pot", 1, 1.0, Vector2.ZERO, rim)
		3:
			## 慢轮：石盘转台上坐着一只泥坯，旁边一团泥
			_pot_v1(ci, 5, 0.75, Vector2(6, 0), rim)
			_clay(ci, Vector2(-30, 32), 8, s + 3, rim)
		4:
			## 快轮拉坯：脚踢的大飞轮、上面的转盘都画得圆一些，转盘上拉起一只高泥坯，旁边一只烧好的小碗（开始产出）
			_wheel(ci, s, rim)
			_pot_at(ci, Vector2(-40, 42), 0.85, 0, s + 20, rim)
		5:
			## 烧坑：圆圆的一圈石头围着火坑，柴火上坐着三只陶坯，火苗窜出来
			_firepit(ci, 1.0, false, 3, s, rim)
		6:
			## 砖砌烧坑：一圈厚砖墙围着火坑，前墙脚开一个大添柴口，里面烧着三只陶坯，旁边码着等着烧的泥坯
			_brick_pit(ci, 1.2, 3, s, rim)
			_pot_at(ci, Vector2(-52, 48), 0.55, 1, s + 40, rim)
			_pot_at(ci, Vector2(54, 48), 0.6, 0, s + 41, rim)
		7:
			## 小土窑，窑前摆着三只陶罐（比 8 级的馒头窑矮）
			_pot_v1(ci, 7, 0.86, Vector2(0, -4), rim)
			_pot_row(ci, 3, -26, 26, 46, 0.55, s + 20, rim)
		8:
			## 馒头窑：和小土窑一个画法，更宽更高，窑脚砌两层砖，门边码着柴；右后方一座小副窑，窑前四只陶罐
			_pot_v1(ci, 7, 0.58, Vector2(56, -6), rim)
			_dome_kiln(ci, s, rim)
			_pot_row(ci, 4, -36, 44, 48, 0.78, s + 20, rim)
		9:
			## 陶坊：双室窑、晾坯架都齐了，门前一排五只彩陶
			_pot_v1(ci, 8, 0.86, Vector2(-14, -4), rim)
			_shelf(ci, Vector2(40, 34), 0.8, s + 30, rim)
			_pot_row(ci, 5, -40, 26, 47, 0.66, s + 20, rim, true)
		_:
			## 彩陶大窑：画满彩纹的大窑，左后方一座小副窑，门前一排六只彩陶，金光
			glow(ci, Vector2(0, -6), 62, GOLD)
			_pot_v1(ci, 7, 0.58, Vector2(-62, -6), rim)
			_pot_v1(ci, 9, 1.0, Vector2.ZERO, rim)
			_pot_row(ci, 6, -50, 50, 50, 0.66, s + 20, rim, true)
			_sparkles(ci, [Vector2(-54, -30), Vector2(54, -40), Vector2(58, 16)], 6.0)

## 窑前一排陶罐：n 只，从 x0 排到 x1，painted 为真时一半是彩陶
static func _pot_row(ci: CanvasItem, n: int, x0: float, x1: float, y: float, k: float, s: int, rim: bool, painted: bool = false) -> void:
	for j in n:
		var x := lerpf(x0, x1, float(j) / float(maxi(n - 1, 1)))
		var kind := (2 if j % 2 == 0 else 1) if painted else (1 if j % 2 == 0 else 0)
		_pot_at(ci, Vector2(x, y + float(j % 2) * 2.0), k * (1.0 if j % 2 == 0 else 0.88), kind, s + j, rim)

## 一团橙红湿陶泥
static func _clay(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool) -> void:
	sil(ci, [ov(c + Vector2(0, r * 0.8), r * 1.45, r * 0.27, s + 9, Color("7a4f2a"), 0.0, 1), raw_rock(c, r, s, TERRA, 9, 0.1)], rim)
	if Art.rim_only:
		return
	for k in 3:
		ci.draw_arc(c + Vector2((-6.0 + float(k) * 6.0) * r / 15.0, (-4.0 - float(k % 2) * 2.0) * r / 15.0), 3.0 * r / 15.0, 0.2, PI - 0.2, 6, Color(INK, 0.4), 1.8, true)
	hl(ci, c + Vector2(-6, -8) * r / 15.0, 4 * r / 15.0, 2 * r / 15.0)

## 晾坯架：两根木柱架一块木板，板上一排没烧的陶坯
static func _shelf(ci: CanvasItem, c: Vector2, k: float, s: int, rim: bool) -> void:
	sil(ci, [stk(c + Vector2(-14, 0) * k, c + Vector2(-14, -30) * k, 2.4 * k, s, WOOD_D, 2), stk(c + Vector2(14, 0) * k, c + Vector2(14, -30) * k, 2.4 * k, s + 1, WOOD_D, 2),
		bx(c.x - 20.0 * k, c.y - 18.0 * k, 40.0 * k, 4.0 * k, 1, s + 2, WOOD)], rim, 2.2)
	for j in 3:
		_pot_at(ci, c + Vector2(-12.0 + float(j) * 12.0, -18.0) * k, 0.42 * k, j % 2, s + 10 + j, rim)

## 快轮：底下一只脚踢的大飞轮，木轴撑着上面的转盘，转盘上一只拉起来的高泥坯，旁边一张小坐凳。两个轮都画得圆一些（俯视角度大）
static func _wheel(ci: CanvasItem, s: int, rim: bool) -> void:
	var wood := Color("cf6a3c")
	var dark := Color("9e4426")
	sil(ci, [bx(28, 14, 22, 6, 2, s + 4, wood), stk(Vector2(32, 20), Vector2(32, 42), 2.6, s + 5, dark), stk(Vector2(46, 20), Vector2(46, 42), 2.6, s + 6, dark),
		ov(Vector2(0, 32), 32, 14, s, dark, 0.0, 1), stk(Vector2(0, -2), Vector2(0, 32), 3.6, s + 1, dark), ov(Vector2(0, -2), 26, 11, s + 2, wood, 0.0, 1)], rim)
	if Art.rim_only:
		return
	for k in 8:
		var an := TAU * float(k) / 8.0 + 0.2
		ln(ci, Vector2(0, 32), Vector2(0, 32) + Vector2(cos(an) * 28.0, sin(an) * 12.0), 1.4, Color(wood, 0.8), s + k)
	var prof := [Vector2(9, -40), Vector2(12, -32), Vector2(18, -18), Vector2(16, -8), Vector2(10, -2)]
	PAPot.vessel(ci, prof, Color("dc8a56"), s + 3, false)
	for k in 3:
		PAPot.band_at(ci, prof, -28.0 + float(k) * 9.0, Color(Color("dc8a56").darkened(0.25), 0.7), 1.4)
	hl(ci, Vector2(-9, -20), 2.0, 8.0, 0.1, 0.55)
	for k in 3:
		ci.draw_arc(Vector2(0, -2), 30.0 + float(k) * 4.0, PI * 0.6, PI * 0.85, 6, Color(1, 1, 1, 0.5), 1.8, true)

## 火坑：坑里柴火上坐着几只陶坯，火苗从陶坯之间窜出来。
## brick 为假：一圈大小不一的石头围着（不画底下的圆盘）；为真：砖砌一圈矮墙，有一定高度，前面的墙挡住陶坯的底
static func _firepit(ci: CanvasItem, k: float, brick: bool, n: int, s: int, rim: bool) -> void:
	var c := Vector2(0, 26)
	var R := Vector2(40, 29) * k
	var h := 13.0 * k
	var brick_col := Color("b9502c")
	## 石头：沿椭圆一圈，大小不一，后半圈先画、前半圈最后画
	var stones := []
	var m := 15
	for j in m:
		var a := TAU * float(j) / float(m) + 0.1
		var sz := (5.5 + srnd(s + j * 7) * 4.5) * k
		var p := c + Vector2(cos(a) * R.x, sin(a) * R.y)
		stones.append([p, sz, a])
	if Art.rim_only:
		if brick:
			var outer := arcp(c + Vector2(0, -h), R + Vector2(2, 2), PI, TAU, 16) + arcp(c, R + Vector2(2, 2), 0.0, PI, 16)
			sil(ci, [P(poly(outer, s, 0.3), brick_col, 1)], rim)
		else:
			var parts := []
			for q in stones:
				parts.append(ov(q[0], q[1] * 1.25, q[1], s, STONE, 0.0, 1))
			parts.append(ov(c, R.x * 0.95, R.y * 0.9, s + 1, STONE, 0.0, 1))
			sil(ci, parts, rim)
		return
	## 坑底的灰
	ci.draw_colored_polygon(ell(c, R * (1.0 if brick else 0.92), s + 1, 0.03, 24), Color("3a2418"))
	if brick:
		## 后墙的内壁
		var back := arcp(c + Vector2(0, -h), R, PI, TAU, 18)
		var floor_arc := arcp(c, R, TAU, PI, 18)
		var bp := poly(back + floor_arc, s + 2, 0.2)
		safe_poly(ci, bp, brick_col.darkened(0.3))
		_brick_rows(ci, c, R, h, PI, TAU, s, true)
		outline(ci, bp, 1.8)
	else:
		for q in stones:
			if sin(q[2]) < 0.0:
				_stone(ci, q[0], q[1], s + int(q[2] * 10.0))
	sil(ci, [stk(c + Vector2(-24, 6) * k, c + Vector2(20, -8) * k, 3.0 * k, s + 10, WOOD_D), stk(c + Vector2(24, 6) * k, c + Vector2(-20, -8) * k, 3.0 * k, s + 11, WOOD)], false)
	var xs := []
	for j in n:
		xs.append(lerpf(-18.0, 18.0, float(j) / float(maxi(n - 1, 1))) * k if n > 1 else 0.0)
	var lift := 6.0 if brick else 0.0
	flame(ci, c + Vector2(0, -24.0 - lift) * k, 16.0 * k, 44.0 * k, s + 29)
	for j in n:
		var x: float = xs[j]
		flame(ci, c + Vector2(x - 8.0 * k, (-10.0 - lift) * k), 9.0 * k, 26.0 * k, s + 20 + j)
	for j in n:
		var x: float = xs[j]
		var row := 0.0 if j % 2 == 0 else -6.0
		_pot_at(ci, c + Vector2(x, (8.0 + row - lift) * k - absf(x) * 0.12), 0.95 * k, j % 2, s + 30 + j, false)
	if brick:
		## 前墙的外壁：高 h 的一圈砖
		var front := arcp(c + Vector2(0, -h), R, 0.0, PI, 18) + arcp(c, R, PI, 0.0, 18)
		var fp := poly(front, s + 3, 0.2)
		safe_poly(ci, fp, brick_col)
		_brick_rows(ci, c, R, h, 0.0, PI, s + 5, false)
		outline(ci, fp, 2.2)
		## 墙顶一圈
		pl(ci, arcp(c + Vector2(0, -h), R, 0.0, TAU, 36), 4.4, INK, s)
		pl(ci, arcp(c + Vector2(0, -h), R, 0.0, TAU, 36), 2.4, brick_col.lightened(0.25), s)
		hl(ci, c + Vector2(-R.x * 0.55, R.y * 0.45 - h * 0.5), 6 * k, 1.6 * k, 0.3, 0.35)
	else:
		for q in stones:
			if sin(q[2]) >= 0.0:
				_stone(ci, q[0], q[1], s + int(q[2] * 10.0))

## 一块石头（带描边和一点高光）
static func _stone(ci: CanvasItem, p: Vector2, sz: float, s: int) -> void:
	sil(ci, [ov(p, sz * 1.25, sz, s, STONE.lightened((srnd(s) - 0.5) * 0.2), 0.0, 0, 0.1)], false, 2.4)

## 砖墙上的砖缝：在高 h 的墙面上画 3 道横缝、错开的竖缝
static func _brick_rows(ci: CanvasItem, c: Vector2, R: Vector2, h: float, a0: float, a1: float, s: int, back: bool) -> void:
	var rows := 3
	for r in range(1, rows):
		var y := -h * float(r) / float(rows)
		pl(ci, arcp(c + Vector2(0, y), R, a0 + 0.02, a1 - 0.02, 18), 1.3, Color(INK, 0.5), s + r)
	for r in rows:
		var y0 := -h * float(r) / float(rows)
		var y1 := -h * float(r + 1) / float(rows)
		var cnt := 9
		for j in cnt:
			var a := lerpf(a0, a1, (float(j) + (0.5 if r % 2 == 0 else 0.0) + 0.25) / float(cnt))
			if a <= a0 or a >= a1:
				continue
			var p0 := c + Vector2(cos(a) * R.x, sin(a) * R.y + y0)
			var p1 := c + Vector2(cos(a) * R.x, sin(a) * R.y + y1)
			ln(ci, p0, p1, 1.2, Color(INK, 0.45 if back else 0.55), s + r * 10 + j)

## 砖砌火坑：一圈厚砖墙围着火坑，墙有高度、墙顶看得出厚度，正前方墙脚开一个拱形添柴口，口里透出火光
static func _brick_pit(ci: CanvasItem, k: float, n: int, s: int, rim: bool) -> void:
	var c := Vector2(0, 26)
	var R := Vector2(42, 30) * k
	var t := 8.0 * k
	var Ri := R - Vector2(t, t * 0.7)
	var h := 16.0 * k
	var top := c + Vector2(0, -h)
	var col := Color("b9502c")
	if Art.rim_only:
		var outer := arcp(top, R, PI, TAU, 18) + arcp(c, R, 0.0, PI, 18)
		sil(ci, [P(poly(outer, s, 0.3), col, 1)], rim)
		return
	## 坑底
	ci.draw_colored_polygon(ell(c, Ri, s + 1, 0.02, 24), Color("3a2418"))
	## 后墙内壁
	var back := poly(arcp(top, Ri, PI, TAU, 18) + arcp(c, Ri, TAU, PI, 18), s + 2, 0.2)
	safe_poly(ci, back, col.darkened(0.32))
	outline(ci, back, 1.8)
	## 后半圈墙顶
	_wall_top(ci, top, R, Ri, PI, TAU, s + 4, col)
	## 柴火、火苗、陶坯
	sil(ci, [stk(c + Vector2(-22, 4) * k, c + Vector2(18, -8) * k, 3.0 * k, s + 10, WOOD_D), stk(c + Vector2(22, 4) * k, c + Vector2(-18, -8) * k, 3.0 * k, s + 11, WOOD)], false)
	var xs := []
	for j in n:
		xs.append(lerpf(-16.0, 16.0, float(j) / float(maxi(n - 1, 1))) * k)
	flame(ci, c + Vector2(0, -32) * k, 16.0 * k, 44.0 * k, s + 29)
	for j in n:
		var x: float = xs[j]
		_pot_at(ci, c + Vector2(x, (j % 2) * -4.0 * k - absf(x) * 0.1), 1.0 * k, j % 2, s + 30 + j, false)
	## 前墙外壁
	var front := poly(arcp(top, R, 0.0, PI, 18) + arcp(c, R, PI, 0.0, 18), s + 3, 0.2)
	safe_poly(ci, front, col)
	pl(ci, arcp(c + Vector2(0, -h * 0.5), R, 0.08, PI - 0.08, 16), 1.4, Color(INK, 0.45), s)
	for j in 6:
		var a := PI * (float(j) + 0.5) / 6.0
		var off := -h * (0.25 if j % 2 == 0 else 0.75)
		var q := c + Vector2(cos(a) * R.x, sin(a) * R.y + off)
		ln(ci, q + Vector2(0, -h * 0.22), q + Vector2(0, h * 0.22), 1.3, Color(INK, 0.45), s + j)
	outline(ci, front, 2.2)
	## 前半圈墙顶
	_wall_top(ci, top, R, Ri, 0.0, PI, s + 6, col)
	## 添柴口：前墙正中的拱门，里面是火光
	var foot := c + Vector2(0, R.y)
	var door := poly(arcp(foot, Vector2(15, 15) * k, PI, TAU, 14), s + 7, 0.2)
	ci.draw_colored_polygon(door, Color("2a170c"))
	flame(ci, foot + Vector2(0, -4) * k, 10.0 * k, 14.0 * k, s + 8)
	outline(ci, door, 2.0)
	hl(ci, c + Vector2(-R.x * 0.6, R.y * 0.5 - h * 0.5), 5 * k, 1.6 * k, 0.3, 0.35)

## 墙顶：外圈和内圈之间的一段环，浅一点的砖色，带几道砖缝
static func _wall_top(ci: CanvasItem, top: Vector2, R: Vector2, Ri: Vector2, a0: float, a1: float, s: int, col: Color) -> void:
	var band := poly(arcp(top, R, a0, a1, 18) + arcp(top, Ri, a1, a0, 18), s, 0.2)
	safe_poly(ci, band, col.lightened(0.22))
	outline(ci, band, 1.8)
	for j in 3:
		var a := lerpf(a0, a1, (float(j) + 0.5) / 3.0)
		ln(ci, top + Vector2(cos(a) * Ri.x, sin(a) * Ri.y), top + Vector2(cos(a) * R.x, sin(a) * R.y), 1.2, Color(INK, 0.5), s + j)

## 馒头窑：和 7 级小土窑一个画法（光滑的土窑身、烟囱、拱门里的火），但更宽更高；窑脚砌了两层砖，侧面两个通风孔，门边码着柴
static func _dome_kiln(ci: CanvasItem, s: int, rim: bool) -> void:
	var dome := arcp(Vector2(0, 38), Vector2(48, 66), PI, TAU, 22)
	var logs := [stk(Vector2(-58, 38), Vector2(-36, 38), 3.4, s + 2, WOOD), stk(Vector2(-56, 31), Vector2(-38, 31), 3.4, s + 3, WOOD_D), stk(Vector2(-52, 24), Vector2(-42, 24), 3.4, s + 4, WOOD)]
	sil(ci, [stk(Vector2(0, -22), Vector2(0, -40), 6.5, s, PA.TAN_D), pg(dome, s + 1, PA.TAN, 0)] + logs, rim)
	if Art.rim_only:
		return
	var dp := PackedVector2Array(dome)
	## 窑脚两层砖
	for y in [26.0, 32.0]:
		for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(-60, y), Vector2(60, y)]), dp):
			ci.draw_polyline(seg, Color(PA.TAN_D.darkened(0.2), 0.85), 1.4, true)
	for r in 2:
		var y := 26.0 + float(r) * 6.0
		var x := -44.0 + (0.0 if r == 0 else 5.0)
		while x < 44.0:
			ln(ci, Vector2(x, y), Vector2(x, y + 6.0), 1.2, Color(PA.TAN_D.darkened(0.2), 0.85), s + int(x))
			x += 10.0
	## 通风孔
	for p in [Vector2(-24, 2), Vector2(26, 4)]:
		ci.draw_circle(p, 3.6, PAPot.HOLE)
		ci.draw_arc(p, 3.6, 0, TAU, 10, INK, 1.4, true)
	## 拱门和火
	var door := arcp(Vector2(4, 38), Vector2(14, 24), PI, TAU, 10)
	ci.draw_colored_polygon(poly(door, s), PAPot.HOLE)
	flame(ci, Vector2(4, 30), 9, 20, s + 5)
	outline(ci, poly(door, s), 2.0)
	hl(ci, Vector2(-20, -10), 9, 4, -0.5, 0.35)
	smoke(ci, Vector2(2, -46), 0.85)
