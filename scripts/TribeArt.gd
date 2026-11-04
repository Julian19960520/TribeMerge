class_name TribeArt
extends RefCounted
## 部落主页的建筑部件，全部程序绘制，沿用「石纹手作」：墨线外轮廓 + 双色块面 + 线条沸腾。
## 每件部件以「落地中点」为原点，向上是负 y，1 个单位约等于主页上 1 像素。
## 部件 id 写在 data/builds.json；画法在 _draw_kind() 里按 id 分支。没有画法的新 id 先画一堆碎石占位。

const DIRT := Color("8a5a32")
const HAY := Color("e2b950")
const FLINT := Color("4c5260")
const OBSID := Color("3b3050")
const CLAYW := Color("b65a38")
const SMOKE := Color(0.96, 0.94, 0.9, 0.6)
const PLUM := Color("7d3c8c")

## 主页上部件的缩放
const VS := 0.8
## 区域在主页上的中心；parts 是每件部件相对中心的落地点（按 builds.json 里的部件顺序）；tag 是区域牌子的位置。
## 高的部件尽量放在后排两角，给牌子让出中间。
const AREAS := {
	"fire": {"at": Vector2(360, 872), "tag": Vector2(0, 100), "parts": [
		Vector2(0, 6), Vector2(-104, 34), Vector2(98, 40), Vector2(-118, -34), Vector2(96, -54), Vector2(-14, -66)]},
	"gather": {"at": Vector2(360, 600), "tag": Vector2(0, -124), "parts": [
		Vector2(0, -46), Vector2(-66, -24), Vector2(-46, 40), Vector2(62, -22), Vector2(6, 8), Vector2(88, 36)]},
	"stone": {"at": Vector2(124, 600), "tag": Vector2(0, -124), "parts": [
		Vector2(-50, 38), Vector2(44, 40), Vector2(0, -44), Vector2(-62, -22), Vector2(2, 6), Vector2(64, -22)]},
	"weave": {"at": Vector2(596, 600), "tag": Vector2(0, -124), "parts": [
		Vector2(0, -44), Vector2(-64, -24), Vector2(-46, 40), Vector2(4, 6), Vector2(48, 42), Vector2(90, -8)]},
	"hunt": {"at": Vector2(124, 884), "tag": Vector2(0, -124), "parts": [
		Vector2(-92, 14), Vector2(0, -46), Vector2(-44, 44), Vector2(4, 4), Vector2(62, -22), Vector2(56, 46)]},
	"cook": {"at": Vector2(596, 884), "tag": Vector2(0, -124), "parts": [
		Vector2(0, -44), Vector2(-46, 42), Vector2(-62, -18), Vector2(8, 10), Vector2(62, -22), Vector2(52, 44)]},
	"wood": {"at": Vector2(124, 1176), "tag": Vector2(0, -124), "parts": [
		Vector2(-48, 40), Vector2(0, -44), Vector2(6, 8), Vector2(62, -22), Vector2(-62, -18), Vector2(70, 42)]},
	"kiln": {"at": Vector2(596, 1176), "tag": Vector2(0, -124), "parts": [
		Vector2(-46, 40), Vector2(0, -44), Vector2(-62, -22), Vector2(8, 8), Vector2(62, -20), Vector2(54, 44)]},
}

## 非透明时整件画成单色剪影（弹窗里还没轮到的部件）
static var flat := Color(0, 0, 0, 0)
## 是否带贴纸白边（弹窗里的大图标用）
static var rim := false
static var _o := Vector2.ZERO
static var _k := Vector2.ONE

# ---------------------------------------------------------------- 对外

static func area_at(id: String) -> Vector2:
	if AREAS.has(id):
		return AREAS[id]["at"]
	var k := absi(id.hash()) % 5
	return Vector2(140 + k * 110, 1100)

static func tag_at(id: String) -> Vector2:
	if AREAS.has(id):
		return area_at(id) + (AREAS[id]["tag"] as Vector2)
	return area_at(id) + Vector2(0, -120)

## 第 idx 件部件在主页上的落地点
static func part_at(id: String, idx: int) -> Vector2:
	var base := area_at(id)
	if AREAS.has(id):
		var arr: Array = AREAS[id]["parts"]
		if idx >= 0 and idx < arr.size():
			return base + (arr[idx] as Vector2)
	var a := float(idx) * 2.4
	return base + Vector2(cos(a) * 70.0, sin(a) * 34.0)

## 在 c 处画一件部件。squash 是建造动画里的挤压拉伸（以落地点为轴）。
static func part(ci: CanvasItem, kind: String, c: Vector2, s: float = 1.0, squash: Vector2 = Vector2.ONE) -> void:
	_o = c
	_k = squash * s
	_tf(ci)
	_draw_kind(ci, kind)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 弹窗卡片里的图标：自动缩放到 box 里，落地点在底部偏上
static func icon(ci: CanvasItem, kind: String, r: Rect2, dim := false) -> void:
	var h := float(_HEIGHT.get(kind, 80))
	var w := float(_WIDTH.get(kind, 100))
	var s := minf(r.size.y * 0.8 / h, r.size.x * 0.86 / w)
	s = minf(s, 1.5)
	var old_rim := rim
	rim = not dim
	if dim:
		flat = Color("8f7a5e")
	part(ci, kind, Vector2(r.get_center().x, r.end.y - r.size.y * 0.1), s)
	flat = Color(0, 0, 0, 0)
	rim = old_rim

## 整个村庄的部件层。hide = {区域 id: 部件下标}：这件正在播建造动画，先不画。
static func village(ci: CanvasItem, builds: Dictionary, level: int, hide: Dictionary = {}) -> void:
	for b in Data.BUILDS:
		if b is not Dictionary:
			continue
		var id := str(b.get("id", ""))
		var parts := Data.build_parts(b)
		var st := clampi(int(builds.get(id, 0)), 0, parts.size())
		var open := level >= Data.build_unlock(b)
		var at := area_at(id)
		var plot := Art.ell(at + Vector2(0, 10), Vector2(118, 74), absi(id.hash()) % 50, 0.05, 30, 0.0, 0.0)
		if open:
			ci.draw_colored_polygon(plot, Color(0.62, 0.45, 0.24, 0.28))
		else:
			ci.draw_colored_polygon(plot, Color(0.25, 0.3, 0.12, 0.12))
			Art.dashed(ci, plot, 12, 9, Color(1, 1, 1, 0.55), 3.0)
		var order: Array = []
		for k in st:
			if hide.has(id) and int(hide[id]) == k:
				continue
			order.append(k)
		order.sort_custom(func(a, c): return part_at(id, a).y < part_at(id, c).y)
		# 下一件的地基：虚线圈 + 木桩
		if open and st < parts.size() and not (hide.has(id) and int(hide[id]) == st):
			var gp := part_at(id, st)
			var ring := Art.ell(gp, Vector2(30, 12), st + 3, 0.0, 18, 0.0, 0.0)
			ci.draw_colored_polygon(ring, Color(1, 1, 1, 0.16))
			Art.dashed(ci, ring, 7, 6, Color(1, 1, 1, 0.85), 2.5)
			for sx in [-1.0, 1.0]:
				Art.ln(ci, gp + Vector2(24 * sx, 4), gp + Vector2(22 * sx, -14), 3.0, Art.WOOD_D, st * 7 + int(sx))
		for k in order:
			var pid := str(parts[k].get("id", "")) if parts[k] is Dictionary else ""
			part(ci, pid, part_at(id, k), VS)

## 部件名字 → 画法里能认的 id（新 id 没有画法时用碎石堆）
static func has_art(kind: String) -> bool:
	return _HEIGHT.has(kind)

# ---------------------------------------------------------------- 尺寸（给弹窗图标缩放用）

const _HEIGHT := {
	"campfire": 86, "logpile": 56, "stumps": 40, "drum": 70, "totem": 150, "chiefhut": 130,
	"berrybush": 62, "basketrack": 80, "dryingmat": 34, "seedjar": 60, "sprouts": 40, "fruittree": 150,
	"rockpile": 46, "anvilstone": 48, "flintpit": 44, "toolrack": 86, "whetstone": 56, "obsidian": 86,
	"grassstack": 70, "loomframe": 96, "dyepot": 64, "clothesline": 92, "hidetent": 118, "featherpole": 140,
	"spears": 106, "snare": 74, "meatrack": 96, "hidedry": 92, "hunttent": 96, "skullgate": 120,
	"stonestove": 58, "spit": 76, "smokehouse": 112, "cookpit": 40, "firewood": 62, "sacredfire": 130,
	"logs": 58, "chopblock": 66, "bench": 40, "sawhorse": 56, "woodshed": 110, "carvedpole": 150,
	"claypit": 34, "wheel": 64, "potshelf": 92, "firepit": 56, "kilndome": 104, "bigjar": 92,
	"rubble": 40,
}
const _WIDTH := {
	"campfire": 104, "logpile": 100, "stumps": 104, "drum": 70, "totem": 96, "chiefhut": 170,
	"berrybush": 80, "basketrack": 86, "dryingmat": 104, "seedjar": 74, "sprouts": 96, "fruittree": 120,
	"rockpile": 84, "anvilstone": 82, "flintpit": 92, "toolrack": 82, "whetstone": 92, "obsidian": 80,
	"grassstack": 84, "loomframe": 84, "dyepot": 76, "clothesline": 120, "hidetent": 110, "featherpole": 70,
	"spears": 76, "snare": 80, "meatrack": 104, "hidedry": 86, "hunttent": 116, "skullgate": 120,
	"stonestove": 88, "spit": 104, "smokehouse": 96, "cookpit": 100, "firewood": 92, "sacredfire": 86,
	"logs": 100, "chopblock": 84, "bench": 104, "sawhorse": 90, "woodshed": 124, "carvedpole": 90,
	"claypit": 100, "wheel": 76, "potshelf": 100, "firepit": 100, "kilndome": 110, "bigjar": 80,
	"rubble": 70,
}

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

static func _shadow(ci: CanvasItem, w: float, h: float = 0.0) -> void:
	if flat.a > 0.0:
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
		_: _rubble(ci)

static func _rubble(ci: CanvasItem) -> void:
	_shadow(ci, 34)
	_sil(ci, [_stone(Vector2(-14, -10), Vector2(16, 12), 1), _stone(Vector2(14, -8), Vector2(14, 10), 2, Art.STONE_D),
		_stone(Vector2(0, -24), Vector2(12, 10), 3)])

# ================================================================ 篝火广场

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

static func _totem(ci: CanvasItem) -> void:
	_shadow(ci, 30)
	_totem_face(ci, 0, Art.WOOD, 1)
	_totem_face(ci, -38, Art.TEAL, 2)
	_totem_face(ci, -76, Art.CLAY, 3)
	var wing := Art.poly([Vector2(-48, -108), Vector2(-22, -120), Vector2(0, -114), Vector2(22, -120), Vector2(48, -108), Vector2(24, -102), Vector2(0, -108), Vector2(-24, -102)], 4)
	_sil(ci, [Art.P(wing, Art.OCHRE, 1)], 2.6)
	var beak := Art.poly([Vector2(-14, -112), Vector2(14, -112), Vector2(10, -134), Vector2(0, -146), Vector2(-10, -134)], 5)
	_sil(ci, [Art.P(beak, Art.OCHRE.darkened(0.1), 1)], 2.6)
	_dot(ci, Vector2(-4, -130), 3, Art.INK)
	_dot(ci, Vector2(4, -130), 3, Art.INK)

static func _chiefhut(ci: CanvasItem) -> void:
	_shadow(ci, 86, 16)
	var wall := Art.rrect(Rect2(-66, -46, 132, 46), 8, 2, 0.8)
	var roof := Art.poly([Vector2(-86, -36), Vector2(-20, -112), Vector2(0, -118), Vector2(20, -112), Vector2(86, -36), Vector2(0, -44)], 3)
	var door := Art.rrect(Rect2(-16, -36, 32, 36), 14, 4, 0.5)
	_sil(ci, [Art.P(wall, Art.WOOD, 1), Art.P(roof, Color("d9a54a"), 1)])
	for i in 9:
		_ln(ci, Vector2(-10 + i * 2.5, -112), Vector2(-76 + i * 19, -40), 1.8, Color(0.45, 0.28, 0.05, 0.55), i)
	for i in 7:
		var x := -78.0 + i * 26.0
		_fill(ci, Art.poly([Vector2(x, -40), Vector2(x + 14, -40), Vector2(x + 7, -28)], 40 + i), Art.CLAY if i % 2 == 0 else Art.TEAL)
	_sil(ci, [Art.P(door, Art.LEATHER_D, 2)], 2.4)
	for sx in [-1.0, 1.0]:
		_sil(ci, [_log(Vector2(10 * sx, -114), Vector2(26 * sx, -132), 3.6, 7, Art.BONE2)], 2.0)
	var skull := Art.ell(Vector2(0, -124), Vector2(12, 10), 9, 0.05)
	_sil(ci, [Art.P(skull, Art.BONE, 2)], 2.4)
	_dot(ci, Vector2(-4, -125), 2.4, Art.INK)
	_dot(ci, Vector2(4, -125), 2.4, Art.INK)

# ================================================================ 采集园

static func _berrybush(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	_sil(ci, [Art.P(Art.ell(Vector2(-16, -24), Vector2(24, 22), 1, 0.1), Art.LEAF_D),
		Art.P(Art.ell(Vector2(16, -26), Vector2(24, 24), 2, 0.1), Art.LEAF_D),
		Art.P(Art.ell(Vector2(0, -40), Vector2(26, 22), 3, 0.1), Art.LEAF)])
	for k in 9:
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

static func _basketrack(ci: CanvasItem) -> void:
	_shadow(ci, 42)
	_sil(ci, [_post(-34, 74, 3.5, 1, Art.WOOD_D, 4), _post(34, 74, 3.5, 2, Art.WOOD_D, -4),
		_log(Vector2(-36, -40), Vector2(36, -40), 3.2, 3), _log(Vector2(-34, -72), Vector2(34, -72), 3.2, 4)], 2.4)
	_basket(ci, Vector2(-14, -42), 30, 24, 5)
	_basket(ci, Vector2(16, -42), 26, 20, 6)
	_it(ci, "fruit_6", Vector2(-14, -70), 22)
	_basket(ci, Vector2(4, 0), 38, 30, 7)
	_it(ci, "fruit_2", Vector2(-2, -32), 20)
	_it(ci, "fruit_1", Vector2(10, -32), 18)

static func _dryingmat(ci: CanvasItem) -> void:
	_shadow(ci, 52, 10)
	var mat := Art.poly([Vector2(-50, -2), Vector2(-36, -22), Vector2(50, -22), Vector2(38, -2)], 1, 0.5)
	_sil(ci, [Art.P(mat, HAY, 1)], 2.4)
	for k in 7:
		var x := -40.0 + k * 13.0
		_ln(ci, Vector2(x - 2, -3), Vector2(x + 12, -21), 1.2, Color(0.55, 0.38, 0.12, 0.6), k)
	_ln(ci, Vector2(-44, -12), Vector2(44, -12), 1.2, Color(0.55, 0.38, 0.12, 0.6), 9)
	var fr := ["fruit_4", "fruit_2", "fruit_5", "fruit_1", "fruit_4"]
	for k in fr.size():
		_it(ci, fr[k], Vector2(-30 + k * 15, -14 - (k % 2) * 4), 20)

static func _seedjar(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	_sil(ci, [Art.P(_jar(Vector2(-12, 0), 40, 56, 18, 1), CLAYW, 0)], 2.6)
	_ln(ci, Vector2(-30, -34), Vector2(6, -34), 2.0, Art.OCHRE, 2)
	_ln(ci, Vector2(-30, -28), Vector2(6, -28), 2.0, Art.INK, 3)
	_sil(ci, [Art.P(_jar(Vector2(22, 0), 28, 38, 14, 4), Art.CLAY.lightened(0.1), 0)], 2.4)
	_fill(ci, Art.ell(Vector2(22, -38), Vector2(8, 2.6), 5, 0.0, 10), Art.SEED)
	for k in 6:
		var p := Vector2(-2 + k * 6.5, 2 - Art.srnd(k) * 4)
		_fill(ci, Art.ell(p, Vector2(3.2, 2.2), k, 0.0, 8, 0.4), Art.SEED)

static func _sprouts(ci: CanvasItem) -> void:
	_shadow(ci, 50, 10)
	var bed := Art.poly([Vector2(-48, 0), Vector2(-40, -14), Vector2(40, -14), Vector2(48, 0)], 1, 0.6)
	_sil(ci, [Art.P(bed, DIRT, 1)], 2.4)
	for k in 4:
		var x := -30.0 + k * 20.0
		_ln(ci, Vector2(x, -12), Vector2(x, -24), 2.2, Art.LEAF_D, k)
		_leaf(ci, Vector2(x, -22), -PI * 0.5 - 0.7, 14, k * 3, Art.LEAF)
		_leaf(ci, Vector2(x, -22), -PI * 0.5 + 0.7, 14, k * 3 + 1, Art.MOSS)
	for k in 5:
		_dot(ci, Vector2(-38 + k * 19, -5), 2.0, Color(0.3, 0.16, 0.05, 0.6))

static func _fruittree(ci: CanvasItem) -> void:
	_shadow(ci, 56, 14)
	var trunk := Art.poly([Vector2(-10, 0), Vector2(-6, -60), Vector2(-24, -84), Vector2(-14, -88), Vector2(0, -70),
		Vector2(14, -92), Vector2(22, -86), Vector2(6, -60), Vector2(10, 0)], 1, 0.7)
	_sil(ci, [Art.P(trunk, Art.WOOD_D, 1)], 2.6)
	_sil(ci, [Art.P(Art.ell(Vector2(-30, -98), Vector2(32, 28), 2, 0.1), Art.LEAF_D),
		Art.P(Art.ell(Vector2(30, -100), Vector2(32, 28), 3, 0.1), Art.LEAF_D),
		Art.P(Art.ell(Vector2(0, -122), Vector2(40, 30), 4, 0.1), Art.LEAF)], 2.8)
	var fr := [Vector2(-34, -100), Vector2(-8, -128), Vector2(24, -110), Vector2(6, -96), Vector2(40, -96), Vector2(-20, -122)]
	for k in fr.size():
		_dot(ci, fr[k], 7.2, Art.INK)
		_dot(ci, fr[k], 6.0, Art.CLAY if k % 2 == 0 else Art.OCHRE)
		_dot(ci, fr[k] + Vector2(-2, -2), 1.8, Color(1, 1, 1, 0.75))
	_it(ci, "fruit_6", Vector2(-22, -6), 22)

# ================================================================ 石匠坊

static func _rockpile(ci: CanvasItem) -> void:
	_shadow(ci, 44)
	_sil(ci, [_stone(Vector2(-22, -12), Vector2(20, 13), 1), _stone(Vector2(18, -11), Vector2(22, 12), 2, Art.STONE_D),
		_stone(Vector2(-2, -30), Vector2(18, 13), 3), _stone(Vector2(30, -28), Vector2(10, 8), 4),
		_stone(Vector2(-36, -2), Vector2(9, 6), 5, Art.STONE_D)], 2.6)
	for k in 3:
		_pl(ci, [Vector2(-12 + k * 18, -26 + k * 6), Vector2(-6 + k * 18, -30 + k * 6)], 1.6, Color(1, 1, 1, 0.55), k)

static func _anvilstone(ci: CanvasItem) -> void:
	_shadow(ci, 44)
	var slab := Art.poly([Vector2(-40, 0), Vector2(-36, -26), Vector2(-10, -34), Vector2(34, -30), Vector2(42, 0)], 1, 0.7)
	_sil(ci, [Art.P(slab, Art.STONE, 0)], 2.8)
	_pl(ci, [Vector2(-30, -22), Vector2(-4, -28), Vector2(30, -24)], 1.6, Color(1, 1, 1, 0.5), 2)
	_sil(ci, [Art.P(Art.ell(Vector2(14, -40), Vector2(13, 9), 3, 0.12, 12, -0.3), Art.STONE_D, 0)], 2.4)
	_sil(ci, [Art.P(Art.poly([Vector2(-22, -32), Vector2(-6, -38), Vector2(-14, -28)], 4), FLINT, 1)], 2.0)
	for k in 4:
		_fill(ci, Art.poly([Vector2(-38 + k * 6, 2), Vector2(-34 + k * 6, -2), Vector2(-31 + k * 6, 3)], 10 + k), FLINT)

static func _flintpit(ci: CanvasItem) -> void:
	_shadow(ci, 48, 14)
	var rim_pts := Art.ell(Vector2(0, -8), Vector2(44, 16), 1, 0.06, 22)
	_sil(ci, [Art.P(rim_pts, DIRT, 1)], 2.6)
	_fill(ci, Art.ell(Vector2(0, -6), Vector2(34, 10), 2, 0.05, 18), Color("3d2716"))
	for k in 5:
		var c := Vector2(-22 + k * 11, -8 + Art.srnd(k) * 4)
		var sh := Art.poly([c + Vector2(-5, 2), c + Vector2(0, -10), c + Vector2(6, 1)], k)
		Art.dilate(ci, sh, 1.6, _c(Art.INK))
		_fill(ci, sh, FLINT if k % 2 == 0 else Color("6a7184"))
	_sil(ci, [_log(Vector2(30, -6), Vector2(44, -40), 2.6, 7), Art.P(Art.poly([Vector2(36, -44), Vector2(56, -40), Vector2(40, -34)], 8), Art.STONE_D, 1)], 2.2)

static func _toolrack(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	_sil(ci, [_post(-30, 66, 3.2, 1, Art.WOOD_D), _post(30, 66, 3.2, 2, Art.WOOD_D), _log(Vector2(-34, -58), Vector2(34, -58), 3.2, 3)], 2.4)
	# 石斧
	_sil(ci, [_log(Vector2(-16, -2), Vector2(-8, -74), 2.8, 4), Art.P(Art.poly([Vector2(-14, -64), Vector2(-28, -74), Vector2(-28, -56)], 5), Art.STONE, 1)], 2.2)
	# 石矛
	_sil(ci, [_log(Vector2(6, -2), Vector2(10, -82), 2.6, 6), Art.P(Art.poly([Vector2(6, -80), Vector2(10, -98), Vector2(14, -80)], 7), FLINT, 1)], 2.2)
	# 石锤
	_sil(ci, [_log(Vector2(22, -2), Vector2(24, -52), 2.6, 8), Art.P(Art.rrect(Rect2(16, -62, 18, 12), 4, 9, 0.4), Art.STONE_D, 1)], 2.2)

static func _whetstone(ci: CanvasItem) -> void:
	_shadow(ci, 46)
	_sil(ci, [_stone(Vector2(-28, -10), Vector2(10, 12), 1, Art.STONE_D), _stone(Vector2(28, -10), Vector2(10, 12), 2, Art.STONE_D)], 2.4)
	var top := Art.poly([Vector2(-46, -20), Vector2(-40, -34), Vector2(42, -36), Vector2(48, -20)], 3, 0.6)
	_sil(ci, [Art.P(top, Art.STONE, 0)], 2.6)
	_fill(ci, Art.poly([Vector2(-34, -34), Vector2(36, -35), Vector2(30, -31), Vector2(-30, -30)], 4), Color("c9c4ba"))
	_sil(ci, [Art.P(Art.poly([Vector2(-26, -40), Vector2(6, -46), Vector2(10, -40), Vector2(-24, -36)], 5), FLINT, 1),
		_log(Vector2(10, -42), Vector2(26, -46), 2.6, 6, Art.BONE2)], 2.0)
	_dot(ci, Vector2(30, -40), 3.0, Art.TEAL)

static func _obsidian(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	_sil(ci, [_stone(Vector2(0, -8), Vector2(38, 12), 1, Art.STONE_D)], 2.4)
	var shards := [[Vector2(-18, -10), 12.0, 50.0, -0.25], [Vector2(18, -10), 11.0, 46.0, 0.3], [Vector2(0, -12), 14.0, 76.0, 0.0],
		[Vector2(-30, -6), 8.0, 28.0, -0.5], [Vector2(30, -6), 8.0, 30.0, 0.55]]
	for k in shards.size():
		var sh = shards[k]
		var b: Vector2 = sh[0]
		var w: float = sh[1]
		var h: float = sh[2]
		var a: float = sh[3]
		var pts := Art.poly(Art.rot_pts([Vector2(-w, 0), Vector2(-w * 0.8, -h * 0.7), Vector2(0, -h), Vector2(w * 0.8, -h * 0.7), Vector2(w, 0)], a, b), k + 3, 0.5)
		_sil(ci, [Art.P(pts, OBSID if k != 2 else PLUM, 1)], 2.4)
		_ln(ci, b + Vector2(0, -h * 0.9).rotated(a), b + Vector2(-w * 0.3, -h * 0.2).rotated(a), 1.6, Color(1, 1, 1, 0.45), k)
	if flat.a == 0.0:
		ci.draw_colored_polygon(Art.star_pts(Vector2(10, -70), 6, 2, 4, 9), Color(1, 1, 1, 0.85))

# ================================================================ 编织棚

static func _grassstack(ci: CanvasItem) -> void:
	_shadow(ci, 44)
	var dome := Art.poly([Vector2(-42, 0), Vector2(-38, -30), Vector2(-20, -56), Vector2(0, -64), Vector2(20, -56), Vector2(38, -30), Vector2(42, 0)], 1, 0.8)
	_sil(ci, [Art.P(dome, HAY, 0)], 2.8)
	for k in 9:
		var x := -34.0 + k * 8.5
		_ln(ci, Vector2(x * 0.4, -58), Vector2(x, -2), 1.3, Color(0.6, 0.4, 0.1, 0.55), k)
	_ln(ci, Vector2(-36, -24), Vector2(36, -24), 3.0, Art.ROPE, 11)
	_ln(ci, Vector2(-36, -24), Vector2(36, -24), 1.2, Art.WOOD_D, 12)
	_sil(ci, [_log(Vector2(4, -60), Vector2(8, -74), 2.0, 13, HAY)], 1.6)

static func _loomframe(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	_sil(ci, [_post(-32, 92, 3.4, 1, Art.WOOD_D), _post(32, 92, 3.4, 2, Art.WOOD_D),
		_log(Vector2(-38, -84), Vector2(38, -84), 3.4, 3), _log(Vector2(-36, -16), Vector2(36, -16), 3.4, 4)], 2.4)
	for k in 8:
		var x := -26.0 + k * 7.4
		_ln(ci, Vector2(x, -82), Vector2(x, -18), 1.2, Art.ROPE, k)
	var band := Art.rrect(Rect2(-28, -50, 56, 30), 3, 5, 0.4)
	_sil(ci, [Art.P(band, Art.TEAL, 2)], 2.0)
	for k in 3:
		_ln(ci, Vector2(-26, -45 + k * 9), Vector2(26, -45 + k * 9), 2.4, Art.OCHRE if k != 1 else Art.CLAY, 10 + k)
	_sil(ci, [_log(Vector2(-14, -58), Vector2(22, -62), 2.0, 6, Art.BONE2)], 1.8)

static func _dyepot(ci: CanvasItem) -> void:
	_shadow(ci, 38)
	var pot := _jar(Vector2(0, 0), 64, 50, 52, 1)
	_sil(ci, [Art.P(pot, CLAYW, 0)], 2.8)
	_fill(ci, Art.ell(Vector2(0, -50), Vector2(26, 6), 2, 0.03, 16), Art.TEAL)
	_fill(ci, Art.ell(Vector2(-6, -51), Vector2(10, 2), 3, 0.0, 12), Color(1, 1, 1, 0.45))
	_sil(ci, [_log(Vector2(10, -48), Vector2(28, -84), 2.6, 4)], 2.0)
	_cloth(ci, Vector2(-14, -52), 14, 26, Art.TEAL.lightened(0.15), 5)
	_ln(ci, Vector2(-26, -28), Vector2(26, -28), 2.0, Art.INK, 6)
	for k in 4:
		_dot(ci, Vector2(-20 + k * 13, -20), 2.4, Art.BONE)

static func _clothesline(ci: CanvasItem) -> void:
	_shadow(ci, 58, 10)
	_sil(ci, [_post(-52, 84, 3.2, 1, Art.WOOD_D, 3), _post(52, 84, 3.2, 2, Art.WOOD_D, -3)], 2.4)
	var pts := _rope_line(ci, Vector2(-50, -78), Vector2(50, -78), 10, 3)
	_cloth(ci, pts[2] + Vector2(0, -2), 22, 34, Art.CLAY, 4)
	_cloth(ci, pts[4] + Vector2(0, -2), 20, 40, Art.HIDE2, 5)
	_cloth(ci, pts[6] + Vector2(0, -2), 22, 30, Art.MOSS, 6)
	for k in 3:
		_ln(ci, pts[4] + Vector2(-8, 10 + k * 8), pts[4] + Vector2(8, 10 + k * 8), 1.4, Art.LEATHER, 10 + k)

static func _hidetent(ci: CanvasItem) -> void:
	_shadow(ci, 54, 14)
	_sil(ci, [_log(Vector2(-8, -96), Vector2(-22, -116), 2.6, 1, Art.WOOD_D), _log(Vector2(8, -96), Vector2(22, -116), 2.6, 2, Art.WOOD_D),
		_log(Vector2(0, -96), Vector2(0, -118), 2.6, 3, Art.WOOD_D)], 2.0)
	var tent := Art.poly([Vector2(-52, 0), Vector2(-6, -98), Vector2(6, -98), Vector2(52, 0), Vector2(0, 6)], 4, 0.8)
	_sil(ci, [Art.P(tent, Art.HIDE2, 0)], 2.8)
	var door := Art.poly([Vector2(-14, 2), Vector2(0, -40), Vector2(14, 2)], 5, 0.5)
	_fill(ci, door, Art.LEATHER_D)
	Art.outline(ci, door, 2.0, _c(Art.INK))
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

static func _featherpole(ci: CanvasItem) -> void:
	_shadow(ci, 26)
	_sil(ci, [_post(0, 132, 3.6, 1, Art.WOOD_D)], 2.4)
	_sil(ci, [_log(Vector2(-28, -116), Vector2(28, -116), 2.8, 2)], 2.2)
	var cols := [Art.CLAY, Art.OCHRE, Art.TEAL, Art.BONE, Art.CLAY]
	for k in 5:
		var x := -24.0 + k * 12.0
		_feather(ci, Vector2(x, -114), PI * 0.5 + (x / 200.0), 34, cols[k], k * 5)
	_feather(ci, Vector2(0, -132), -PI * 0.5 - 0.3, 22, Art.CLAY, 40)
	_feather(ci, Vector2(0, -132), -PI * 0.5 + 0.3, 22, Art.OCHRE, 41)
	for k in 3:
		_ln(ci, Vector2(-4, -30 - k * 6), Vector2(4, -28 - k * 6), 2.4, Art.ROPE, 50 + k)

# ================================================================ 猎人营

static func _spears(ci: CanvasItem) -> void:
	_shadow(ci, 36)
	_sil(ci, [_log(Vector2(-36, -30), Vector2(36, -30), 3.0, 1, Art.WOOD_D)], 2.2)
	for k in 3:
		var x := -20.0 + k * 20.0
		var lean := (float(k) - 1.0) * 6.0
		_sil(ci, [_log(Vector2(x, 0), Vector2(x + lean, -88), 2.4, 2 + k),
			Art.P(Art.poly([Vector2(x + lean - 5, -86), Vector2(x + lean, -104), Vector2(x + lean + 5, -86)], 6 + k), FLINT, 1)], 2.0)
		_ln(ci, Vector2(x + lean * 0.95 - 3, -84), Vector2(x + lean * 0.95 + 3, -80), 2.0, Art.ROPE, 10 + k)
	_sil(ci, [_log(Vector2(-36, -2), Vector2(-34, -36), 3.0, 14, Art.WOOD_D), _log(Vector2(36, -2), Vector2(34, -36), 3.0, 15, Art.WOOD_D)], 2.2)

static func _snare(ci: CanvasItem) -> void:
	_shadow(ci, 42, 10)
	var sap := [Vector2(-30, 0), Vector2(-30, -30), Vector2(-24, -56), Vector2(-8, -70), Vector2(12, -72)]
	_pl(ci, sap, 6.0, Art.INK, 1)
	_pl(ci, sap, 3.4, Art.WOOD, 1)
	_leaf(ci, Vector2(-26, -50), PI + 0.4, 14, 2)
	_leaf(ci, Vector2(-14, -66), -PI * 0.5 - 0.5, 12, 3)
	_rope_line(ci, Vector2(12, -72), Vector2(16, -14), 0, 4)
	var loop := Art.ell(Vector2(16, -6), Vector2(22, 7), 5, 0.06, 18)
	Art.outline(ci, loop, 3.6, _c(Art.INK))
	Art.outline(ci, loop, 1.8, _c(Art.ROPE))
	_sil(ci, [_log(Vector2(34, 0), Vector2(36, -14), 2.6, 6, Art.WOOD_D)], 2.0)
	_it(ci, "fruit_1", Vector2(16, -8), 16)

static func _meatrack(ci: CanvasItem) -> void:
	_shadow(ci, 52, 12)
	_sil(ci, [_post(-44, 88, 3.4, 1, Art.WOOD_D, 6), _post(44, 88, 3.4, 2, Art.WOOD_D, -6),
		_log(Vector2(-46, -80), Vector2(46, -80), 3.4, 3)], 2.4)
	var meats := [Vector2(-24, -78), Vector2(0, -78), Vector2(24, -78)]
	for k in 3:
		var p: Vector2 = meats[k]
		_ln(ci, p, p + Vector2(0, 10), 1.8, Art.ROPE, k)
		var m := Art.poly([p + Vector2(-8, 10), p + Vector2(8, 10), p + Vector2(10, 32), p + Vector2(0, 40), p + Vector2(-10, 32)], k + 4, 0.6)
		_sil(ci, [Art.P(m, Art.MEAT if k != 1 else Art.ROAST, 1)], 2.2)
		_ln(ci, p + Vector2(-5, 20), p + Vector2(5, 26), 2.0, Color(1, 1, 1, 0.6), k + 9)
	_it(ci, "bird_3", Vector2(30, -14), 26)

static func _hidedry(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	_sil(ci, [_post(-34, 86, 3.2, 1, Art.WOOD_D), _post(34, 86, 3.2, 2, Art.WOOD_D),
		_log(Vector2(-38, -80), Vector2(38, -80), 3.2, 3), _log(Vector2(-38, -14), Vector2(38, -14), 3.2, 4)], 2.4)
	var hide := Art.poly([Vector2(-22, -72), Vector2(-8, -66), Vector2(8, -66), Vector2(22, -72), Vector2(24, -52), Vector2(18, -36),
		Vector2(24, -22), Vector2(8, -26), Vector2(-8, -26), Vector2(-24, -22), Vector2(-18, -36), Vector2(-24, -52)], 5, 0.6)
	_sil(ci, [Art.P(hide, Color("c98a4a"), 0)], 2.4)
	for p in [Vector2(-22, -72), Vector2(22, -72), Vector2(-24, -22), Vector2(24, -22), Vector2(-24, -52), Vector2(24, -52)]:
		var edge := Vector2(signf(p.x) * 33.0, p.y if absf(p.y + 47) > 20 else p.y)
		_ln(ci, p, edge, 1.4, Art.ROPE, int(p.x + p.y))
	for k in 4:
		_dot(ci, Vector2(-10 + (k % 2) * 18, -56 + int(k / 2) * 16), 3.0, Color("8a5426"))

static func _hunttent(ci: CanvasItem) -> void:
	_shadow(ci, 56, 14)
	var tent := Art.poly([Vector2(-56, 0), Vector2(-30, -66), Vector2(-20, -74), Vector2(44, -60), Vector2(56, 0)], 1, 0.8)
	_sil(ci, [Art.P(tent, Art.LEATHER, 0)], 2.8)
	var fur := Art.poly([Vector2(-32, -64), Vector2(-20, -72), Vector2(44, -58), Vector2(40, -44), Vector2(30, -50), Vector2(18, -42), Vector2(6, -52), Vector2(-8, -44), Vector2(-20, -54)], 2, 0.6)
	_sil(ci, [Art.P(fur, Color("8b6a4a"), 1)], 2.2)
	var door := Art.poly([Vector2(-28, 2), Vector2(-14, -40), Vector2(2, 2)], 3, 0.5)
	_fill(ci, door, Art.LEATHER_D.darkened(0.3))
	Art.outline(ci, door, 2.0, _c(Art.INK))
	_sil(ci, [_log(Vector2(-22, -72), Vector2(-30, -94), 2.4, 4, Art.WOOD_D), _log(Vector2(-18, -72), Vector2(-6, -92), 2.4, 5, Art.WOOD_D)], 1.8)
	_sil(ci, [_log(Vector2(26, -2), Vector2(50, -40), 2.4, 6), Art.P(Art.poly([Vector2(48, -38), Vector2(58, -54), Vector2(54, -34)], 7), FLINT, 1)], 1.8)

static func _skullgate(ci: CanvasItem) -> void:
	_shadow(ci, 58, 12)
	_sil(ci, [_post(-48, 82, 4.2, 1, Art.WOOD_D), _post(48, 82, 4.2, 2, Art.WOOD_D)], 2.6)
	for sx in [-1.0, 1.0]:
		var pts: Array = []
		for k in 8:
			var t := float(k) / 7.0
			pts.append(Vector2(sx * (48.0 - t * 40.0), -70.0 - sin(t * PI * 0.85) * 40.0))
		_pl(ci, pts, 13.0, Art.INK, 3)
		_pl(ci, pts, 8.5, Art.BONE, 3)
	var skull := Art.poly([Vector2(-18, -96), Vector2(-14, -116), Vector2(0, -122), Vector2(14, -116), Vector2(18, -96), Vector2(8, -84), Vector2(-8, -84)], 4, 0.6)
	_sil(ci, [Art.P(skull, Art.BONE2, 0)], 2.6)
	_dot(ci, Vector2(-7, -104), 4.4, Art.INK)
	_dot(ci, Vector2(7, -104), 4.4, Art.INK)
	_ln(ci, Vector2(-6, -90), Vector2(6, -90), 1.8, Art.INK, 5)
	for sx in [-1.0, 1.0]:
		_ln(ci, Vector2(48 * sx, -50), Vector2(48 * sx, -40), 6.0, Art.CLAY, 6)
		_feather(ci, Vector2(48 * sx, -40), PI * 0.5, 22, Art.OCHRE, 7 + int(sx))

# ================================================================ 火塘灶

static func _stonestove(ci: CanvasItem) -> void:
	_shadow(ci, 46, 12)
	var back: Array = []
	for k in 4:
		var a := PI + PI * float(k + 0.5) / 4.0
		back.append(_stone(Vector2(cos(a) * 36, sin(a) * 10 - 10), Vector2(10, 9), 1 + k))
	_sil(ci, back, 2.2)
	_flame(ci, Vector2(0, -26), 16, 34, 7)
	var slab := Art.poly([Vector2(-34, -30), Vector2(30, -34), Vector2(36, -26), Vector2(-30, -22)], 6, 0.5)
	_sil(ci, [Art.P(slab, Art.STONE_D, 1)], 2.4)
	_it(ci, "veg_2", Vector2(-10, -38), 22)
	_it(ci, "veg_1", Vector2(14, -40), 20)
	var front: Array = []
	for k in 5:
		var a := PI * float(k + 0.5) / 5.0
		front.append(_stone(Vector2(cos(a) * 40, sin(a) * 10 - 6), Vector2(10, 8), 10 + k))
	_sil(ci, front, 2.2)

static func _spit(ci: CanvasItem) -> void:
	_shadow(ci, 52, 12)
	_flame(ci, Vector2(0, -18), 18, 30, 3)
	for sx in [-1.0, 1.0]:
		_sil(ci, [_log(Vector2(44 * sx, 0), Vector2(42 * sx, -50), 3.0, 1, Art.WOOD_D),
			_log(Vector2(42 * sx, -50), Vector2(50 * sx, -64), 2.6, 2, Art.WOOD_D),
			_log(Vector2(42 * sx, -50), Vector2(34 * sx, -62), 2.6, 3, Art.WOOD_D)], 2.2)
	_sil(ci, [_log(Vector2(-50, -54), Vector2(50, -54), 2.4, 4, Art.WOOD)], 2.0)
	var meat := Art.ell(Vector2(0, -54), Vector2(24, 14), 5, 0.1)
	_sil(ci, [Art.P(meat, Art.ROAST, 0)], 2.6)
	for k in 3:
		_ln(ci, Vector2(-12 + k * 12, -64), Vector2(-16 + k * 12, -46), 2.0, Color(0.45, 0.2, 0.05, 0.7), k)
	_smoke(ci, Vector2(0, -72), 9)

static func _smokehouse(ci: CanvasItem) -> void:
	_shadow(ci, 50, 12)
	var wall := Art.rrect(Rect2(-38, -54, 76, 54), 6, 1, 0.7)
	_sil(ci, [Art.P(wall, Art.WOOD_D, 1)])
	for k in 5:
		_ln(ci, Vector2(-30 + k * 15, -50), Vector2(-30 + k * 15, -4), 1.4, Color(0.2, 0.1, 0.03, 0.5), k)
	var roof := Art.poly([Vector2(-50, -46), Vector2(0, -92), Vector2(50, -46), Vector2(0, -54)], 2)
	_sil(ci, [Art.P(roof, HAY.darkened(0.08), 1)])
	for k in 6:
		_ln(ci, Vector2(-2 + k, -90), Vector2(-42 + k * 17, -48), 1.4, Color(0.45, 0.28, 0.05, 0.5), 10 + k)
	var door := Art.rrect(Rect2(-14, -34, 28, 34), 4, 3, 0.4)
	_fill(ci, door, Color("2a170b"))
	Art.outline(ci, door, 2.0, _c(Art.INK))
	_fill(ci, Art.ell(Vector2(0, -6), Vector2(8, 4), 4, 0.1, 10), Art.FIRE)
	for k in 2:
		var p := Vector2(-6 + k * 12, -30)
		_ln(ci, p, p + Vector2(0, 6), 1.4, Art.ROPE, 20 + k)
		_fill(ci, Art.ell(p + Vector2(0, 12), Vector2(3, 7), 21 + k, 0.1, 10), Art.FISH)
	_smoke(ci, Vector2(0, -92), 4)

static func _cookpit(ci: CanvasItem) -> void:
	_shadow(ci, 52, 12)
	var mound := Art.ell(Vector2(0, -10), Vector2(48, 14), 1, 0.06, 22)
	_sil(ci, [Art.P(mound, DIRT, 1)], 2.4)
	_fill(ci, Art.ell(Vector2(0, -10), Vector2(36, 9), 2, 0.05, 18), Color("3a1c0c"))
	for k in 7:
		var p := Vector2(-28 + k * 9.5, -10 + Art.srnd(k) * 4 - 2)
		_dot(ci, p, 3.6, Art.FIRE if k % 2 == 0 else Art.FIRE2)
	for k in 3:
		var c := Vector2(-20 + k * 20, -18)
		var pts := Art.ell(c, Vector2(10, 6), 5 + k, 0.08, 12, 0.3 * (k - 1))
		_sil(ci, [Art.P(pts, Art.LEAF_D, 1)], 2.0)
		_ln(ci, c + Vector2(-8, 0), c + Vector2(8, 0), 1.2, Art.MOSS, 9 + k)
	_smoke(ci, Vector2(-14, -24), 11)

static func _firewood(ci: CanvasItem) -> void:
	_shadow(ci, 46)
	_sil(ci, [_post(-42, 58, 3.0, 1, Art.WOOD_D), _post(42, 58, 3.0, 2, Art.WOOD_D)], 2.2)
	var back := Art.rrect(Rect2(-40, -54, 80, 52), 3, 3, 0.5)
	_fill(ci, back, Color("5a3416"))
	Art.outline(ci, back, 2.4, _c(Art.INK))
	for row in 4:
		for col in 5:
			var c := Vector2(-32 + col * 16 + (row % 2) * 5, -10 - row * 13)
			if c.x > 34:
				continue
			_ring(ci, c, 6.8, row * 7 + col)
	_sil(ci, [Art.P(Art.poly([Vector2(-48, -50), Vector2(48, -50), Vector2(44, -62), Vector2(-44, -62)], 4), HAY.darkened(0.1), 1)], 2.2)

static func _sacredfire(ci: CanvasItem) -> void:
	_shadow(ci, 44, 12)
	var base := Art.poly([Vector2(-40, 0), Vector2(-34, -22), Vector2(34, -22), Vector2(40, 0)], 1, 0.6)
	var mid := Art.poly([Vector2(-28, -22), Vector2(-24, -46), Vector2(24, -46), Vector2(28, -22)], 2, 0.6)
	var bowl := Art.poly([Vector2(-36, -50), Vector2(36, -50), Vector2(24, -66), Vector2(-24, -66)], 3, 0.6)
	_sil(ci, [Art.P(base, Art.STONE, 0), Art.P(mid, Art.STONE_D, 1), Art.P(bowl, Art.STONE, 0)], 2.6)
	for k in 3:
		_fill(ci, Art.star_pts(Vector2(-14 + k * 14, -34), 5, 2, 4, 4 + k), Art.OCHRE)
	_flame(ci, Vector2(0, -98), 30, 76, 5)
	if flat.a == 0.0:
		var t := float(Art.boil % 8) / 8.0
		for k in 4:
			var a := TAU * (float(k) / 4.0 + t * 0.25)
			ci.draw_colored_polygon(Art.star_pts(Vector2(cos(a) * 34, -96 + sin(a) * 26), 4, 1.5, 4, 20 + k), Color(1, 0.9, 0.5, 0.9))

# ================================================================ 木工场

static func _logs(ci: CanvasItem) -> void:
	_shadow(ci, 52)
	var logs := [_log(Vector2(-44, -12), Vector2(36, -18), 11, 1), _log(Vector2(-40, -36), Vector2(40, -40), 11, 2, Art.WOOD_D),
		_log(Vector2(-30, -58), Vector2(30, -60), 10, 3)]
	_sil(ci, [logs[0]], 2.6)
	_ring(ci, Vector2(-44, -12), 10, 10)
	_sil(ci, [logs[1]], 2.6)
	_ring(ci, Vector2(-40, -36), 10, 11)
	_sil(ci, [logs[2]], 2.6)
	_ring(ci, Vector2(-30, -58), 9, 12)
	for k in 3:
		_ln(ci, Vector2(-20 + k * 18, -16), Vector2(-10 + k * 18, -18), 1.4, Color(0.3, 0.16, 0.05, 0.5), 20 + k)

static func _chopblock(ci: CanvasItem) -> void:
	_shadow(ci, 46)
	_stump(ci, Vector2(0, 0), 22, 30, 1)
	_sil(ci, [_log(Vector2(-4, -36), Vector2(24, -64), 3.0, 2),
		Art.P(Art.poly([Vector2(-12, -30), Vector2(-4, -44), Vector2(4, -34), Vector2(-6, -26)], 3), Art.STONE, 1)], 2.2)
	for k in 3:
		var c := Vector2(-36 + k * 9, -6 - (k % 2) * 6)
		_sil(ci, [Art.P(Art.poly([c + Vector2(-5, 6), c + Vector2(-2, -10), c + Vector2(5, -8), c + Vector2(4, 6)], 4 + k), Color("e0b070"), 1)], 1.8)
	_sil(ci, [_log(Vector2(28, -4), Vector2(44, -8), 5, 8)], 2.0)
	_ring(ci, Vector2(44, -8), 5, 9)

static func _bench(ci: CanvasItem) -> void:
	_shadow(ci, 52, 10)
	for x in [-36.0, 36.0]:
		_sil(ci, [Art.P(Art.rrect(Rect2(x - 6, -22, 12, 22), 3, int(x), 0.4), Art.WOOD_D, 1)], 2.2)
	var top := Art.poly([Vector2(-50, -20), Vector2(-46, -32), Vector2(48, -32), Vector2(52, -20)], 1, 0.5)
	_sil(ci, [Art.P(top, Art.WOOD, 0)], 2.6)
	_ln(ci, Vector2(-40, -26), Vector2(40, -27), 1.4, Color(0.3, 0.16, 0.05, 0.5), 2)
	_it(ci, "craft_5", Vector2(22, -38), 18)
	_it(ci, "craft_2", Vector2(-18, -36), 16)

static func _sawhorse(ci: CanvasItem) -> void:
	_shadow(ci, 46, 10)
	for sx in [-1.0, 1.0]:
		_sil(ci, [_log(Vector2(30 * sx - 10, 0), Vector2(30 * sx + 6, -40), 3.0, 1 + int(sx), Art.WOOD_D),
			_log(Vector2(30 * sx + 10, 0), Vector2(30 * sx - 6, -40), 3.0, 3 + int(sx), Art.WOOD_D)], 2.0)
	var plank := Art.poly([Vector2(-46, -36), Vector2(46, -40), Vector2(46, -48), Vector2(-46, -46)], 5, 0.4)
	_sil(ci, [Art.P(plank, Color("dca866"), 1)], 2.4)
	for k in 5:
		var p := Vector2(-20 + k * 7, -50 - (k % 2) * 3)
		_pl(ci, [p, p + Vector2(3, -5), p + Vector2(7, -3)], 1.6, Color("e8c48a"), k)
	_sil(ci, [Art.P(Art.rrect(Rect2(4, -58, 22, 10), 3, 6, 0.4), Art.STONE, 1)], 2.0)

static func _woodshed(ci: CanvasItem) -> void:
	_shadow(ci, 62, 14)
	_sil(ci, [_post(-50, 78, 3.4, 1, Art.WOOD_D), _post(50, 70, 3.4, 2, Art.WOOD_D)], 2.4)
	_stump(ci, Vector2(-14, 0), 14, 18, 3)
	_sil(ci, [_log(Vector2(10, -6), Vector2(40, -12), 7, 4)], 2.2)
	_ring(ci, Vector2(10, -6), 6.5, 5)
	_it(ci, "furn_3", Vector2(-14, -28), 24)
	var roof := Art.poly([Vector2(-64, -76), Vector2(-56, -94), Vector2(60, -82), Vector2(64, -64)], 6, 0.7)
	_sil(ci, [Art.P(roof, HAY.darkened(0.05), 1)])
	for k in 8:
		_ln(ci, Vector2(-56 + k * 15, -92 + k * 1.5), Vector2(-60 + k * 16, -76 + k * 1.6), 1.4, Color(0.45, 0.28, 0.05, 0.55), 10 + k)
	_sil(ci, [_log(Vector2(-30, -64), Vector2(-20, -40), 2.0, 20), Art.P(Art.poly([Vector2(-34, -66), Vector2(-24, -70), Vector2(-22, -60)], 21), Art.STONE, 1)], 1.6)

static func _carvedpole(ci: CanvasItem) -> void:
	_shadow(ci, 30)
	var pole := Art.rrect(Rect2(-16, -124, 32, 124), 6, 1, 0.6)
	_sil(ci, [Art.P(pole, Art.WOOD, 1)], 2.6)
	var bands := [Art.CLAY, Art.TEAL, Art.OCHRE, Art.CLAY]
	for k in 4:
		var y := -18.0 - k * 28.0
		_fill(ci, Art.poly([Vector2(-16, y), Vector2(16, y - 2), Vector2(16, y - 8), Vector2(-16, y - 6)], 10 + k), bands[k])
		for j in 3:
			_fill(ci, Art.poly([Vector2(-12 + j * 9, y - 10), Vector2(-6 + j * 9, y - 10), Vector2(-9 + j * 9, y - 18)], 20 + k * 3 + j), Art.INK)
	var wing := Art.poly([Vector2(-44, -122), Vector2(-16, -130), Vector2(16, -130), Vector2(44, -122), Vector2(30, -112), Vector2(16, -118), Vector2(-16, -118), Vector2(-30, -112)], 2)
	_sil(ci, [Art.P(wing, Art.TEAL, 1)], 2.4)
	var head := Art.ell(Vector2(0, -138), Vector2(13, 12), 3, 0.05)
	_sil(ci, [Art.P(head, Art.WOOD, 0)], 2.4)
	_fill(ci, Art.poly([Vector2(-4, -136), Vector2(4, -136), Vector2(0, -126)], 4), Art.OCHRE)
	_dot(ci, Vector2(-5, -141), 2.4, Art.INK)
	_dot(ci, Vector2(5, -141), 2.4, Art.INK)

# ================================================================ 陶窑坊

static func _claypit(ci: CanvasItem) -> void:
	_shadow(ci, 52, 12)
	var rim_pts := Art.ell(Vector2(0, -8), Vector2(48, 15), 1, 0.06, 22)
	_sil(ci, [Art.P(rim_pts, DIRT, 1)], 2.4)
	_fill(ci, Art.ell(Vector2(0, -7), Vector2(38, 10), 2, 0.06, 18), Color("9a4528"))
	_fill(ci, Art.ell(Vector2(-10, -10), Vector2(12, 3), 3, 0.0, 12), Color(1, 1, 1, 0.3))
	for k in 3:
		var c := Vector2(30 + k * 6, -14 - k * 8)
		_sil(ci, [Art.P(Art.ell(c, Vector2(8, 6), 4 + k, 0.12, 10), CLAYW, 0)], 2.0)
	_sil(ci, [_log(Vector2(-30, -10), Vector2(-46, -30), 2.4, 8, Art.WOOD_D)], 1.8)

static func _wheel(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	_sil(ci, [_stone(Vector2(0, -8), Vector2(18, 10), 1, Art.STONE_D)], 2.2)
	var disc := Art.ell(Vector2(0, -22), Vector2(36, 10), 2, 0.03, 20)
	_sil(ci, [Art.P(Art.poly([Vector2(-36, -22), Vector2(36, -22), Vector2(34, -14), Vector2(-34, -14)], 3), Art.STONE, 1)], 2.4)
	Art.dilate(ci, disc, 2.4, _c(Art.INK))
	_fill(ci, disc, Color("c9c4ba"))
	_sil(ci, [Art.P(_jar(Vector2(0, -24), 34, 40, 18, 4), Color("cf7a4e"), 0)], 2.4)
	_pl(ci, [Vector2(-12, -46), Vector2(0, -48), Vector2(12, -46)], 1.4, Color(1, 1, 1, 0.5), 5)
	if flat.a == 0.0:
		var t := float(Art.boil % 8) / 8.0 * TAU
		for k in 2:
			var a := t + PI * k
			ci.draw_line(Vector2(cos(a) * 30, -22 + sin(a) * 8), Vector2(cos(a + 0.5) * 30, -22 + sin(a + 0.5) * 8), Color(1, 1, 1, 0.8), 2.0, true)

static func _potshelf(ci: CanvasItem) -> void:
	_shadow(ci, 50)
	_sil(ci, [_post(-44, 88, 3.0, 1, Art.WOOD_D), _post(44, 88, 3.0, 2, Art.WOOD_D)], 2.2)
	for y in [-40.0, -80.0]:
		_sil(ci, [Art.P(Art.poly([Vector2(-50, y), Vector2(50, y), Vector2(50, y + 7), Vector2(-50, y + 7)], int(-y)), Art.WOOD, 1)], 2.2)
	_sil(ci, [Art.P(_jar(Vector2(-24, -40), 24, 32, 12, 3), CLAYW, 0), Art.P(_jar(Vector2(8, -40), 30, 26, 22, 4), Color("cf7a4e"), 0),
		Art.P(_jar(Vector2(34, -40), 18, 30, 10, 5), CLAYW.darkened(0.1), 0)], 2.2)
	_sil(ci, [Art.P(_jar(Vector2(-14, -80), 28, 30, 14, 6), Color("cf7a4e"), 0), Art.P(_jar(Vector2(20, -80), 22, 22, 18, 7), CLAYW, 0)], 2.2)
	_ln(ci, Vector2(-26, -54), Vector2(-4, -56), 1.6, Art.INK, 8)
	_ln(ci, Vector2(-8, -96), Vector2(-20, -94), 1.6, Art.BONE, 9)
	_it(ci, "pot_3", Vector2(-24, -6), 26)
	_it(ci, "ware_2", Vector2(22, -8), 22)

static func _firepit(ci: CanvasItem) -> void:
	_shadow(ci, 52, 12)
	var rim_pts := Art.ell(Vector2(0, -10), Vector2(48, 14), 1, 0.06, 22)
	_sil(ci, [Art.P(rim_pts, Art.STONE_D, 1)], 2.4)
	_fill(ci, Art.ell(Vector2(0, -9), Vector2(38, 9), 2, 0.05, 18), Color("3a1c0c"))
	_sil(ci, [Art.P(_jar(Vector2(-16, -6), 24, 26, 14, 3), CLAYW, 0), Art.P(_jar(Vector2(14, -4), 28, 30, 16, 4), Color("cf7a4e"), 0)], 2.2)
	_flame(ci, Vector2(-28, -18), 9, 22, 5)
	_flame(ci, Vector2(30, -18), 9, 24, 6)
	_flame(ci, Vector2(0, -12), 8, 18, 7)
	for k in 6:
		_dot(ci, Vector2(-36 + k * 14, -4), 2.6, Art.FIRE2 if k % 2 == 0 else Art.FIRE)
	_smoke(ci, Vector2(0, -36), 3)

static func _kilndome(ci: CanvasItem) -> void:
	_shadow(ci, 56, 14)
	var dome := Art.poly([Vector2(-50, 0), Vector2(-48, -30), Vector2(-36, -56), Vector2(-16, -72), Vector2(16, -72), Vector2(36, -56), Vector2(48, -30), Vector2(50, 0)], 1, 0.9)
	_sil(ci, [Art.P(dome, CLAYW, 0)], 2.8)
	_sil(ci, [Art.P(Art.rrect(Rect2(-12, -98, 24, 30), 4, 2, 0.5), CLAYW.darkened(0.12), 1)], 2.4)
	var mouth := Art.poly([Vector2(-18, 0), Vector2(-16, -24), Vector2(0, -34), Vector2(16, -24), Vector2(18, 0)], 3, 0.5)
	Art.dilate(ci, mouth, 2.4, _c(Art.INK))
	_fill(ci, mouth, Color("3a1c0c"))
	_fill(ci, Art.flame_pts(Vector2(0, -12), 10, 22, 4), Art.FIRE)
	_fill(ci, Art.flame_pts(Vector2(0, -9), 5, 13, 5), Art.FIRE2)
	for k in 5:
		var y := -10.0 - k * 12.0
		var w := 44.0 - k * 6.0
		_ln(ci, Vector2(-w, y), Vector2(-w + 10, y - 2), 1.6, Color(0.4, 0.15, 0.05, 0.5), k)
		_ln(ci, Vector2(w - 10, y - 2), Vector2(w, y), 1.6, Color(0.4, 0.15, 0.05, 0.5), k + 9)
	_smoke(ci, Vector2(0, -100), 7)

static func _bigjar(ci: CanvasItem) -> void:
	_shadow(ci, 40)
	var jar := _jar(Vector2.ZERO, 72, 88, 30, 1)
	_sil(ci, [Art.P(jar, Color("d8854e"), 0)], 3.0)
	_ln(ci, Vector2(-30, -62), Vector2(30, -62), 3.0, Art.INK, 2)
	for k in 6:
		var x := -28.0 + k * 11.0
		_pl(ci, [Vector2(x, -56), Vector2(x + 5.5, -46), Vector2(x + 11, -56)], 2.6, Art.INK, 3 + k)
	_ln(ci, Vector2(-34, -40), Vector2(34, -40), 2.4, Art.CLAY.darkened(0.2), 10)
	_fill(ci, Art.ell(Vector2(-2, -26), Vector2(13, 7), 11, 0.0, 14), Art.INK)
	_fill(ci, Art.poly([Vector2(9, -26), Vector2(20, -33), Vector2(20, -19)], 12, 0.4), Art.INK)
	_dot(ci, Vector2(-8, -27), 1.6, Art.BONE)
	for k in 4:
		_dot(ci, Vector2(-24 + k * 16, -10), 2.6, Art.INK)
	for sx in [-1.0, 1.0]:
		var ear := Art.ell(Vector2(34 * sx, -56), Vector2(6, 9), 12, 0.05, 10)
		Art.outline(ci, ear, 3.6, _c(Art.INK))
		Art.outline(ci, ear, 2.0, _c(Color("d8854e")))
