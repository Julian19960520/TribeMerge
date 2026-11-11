extends RefCounted
## 恐龙化石活动的界面图：挖掘场的土块、坑、木框，各种骨头（正常 + 剪影），铲子，陈列卡片。
## 只给「生成物品图.bat」用；游戏里只贴生成的图（Sprites.draw / Sprites.at）。登记格式见 scripts/BakeSprites.gd。
## 骨头按 1 格 = 100 像素画，竖着放（w 列 × h 行）；横放时运行时转 90°。

const CELL := 100.0
const BONE := Color("f6e7c3")
const BONE_D := Color("d9c08f")
const SOIL := [Color("b9824a"), Color("c48d52"), Color("ad7742"), Color("c99659")]
const PIT := Color("5b3a22")

## 化石形状（与 data/fossil_dig.json 的 shapes 对应：kind + w×h）
const SHAPES := [["limb", 1, 2], ["spine", 1, 3], ["limb", 1, 4], ["skull", 2, 2], ["ribs", 2, 3], ["pelvis", 3, 3], ["spine", 1, 5], ["ribs", 2, 4]]

static func bone_key(kind: String, w: int, h: int, silhouette := false) -> String:
	return "fos_%s_%s_%dx%d" % ["sil" if silhouette else "bone", kind, w, h]

static func entries() -> Array:
	var out: Array = []
	for v in 4:
		out.append({"key": "fos_dirt_%d" % v, "w": 100, "h": 100, "pad": 6, "draw": func(ci, r): _dirt(ci, r, v)})
	out.append({"key": "fos_pit", "w": 100, "h": 100, "pad": 2, "draw": func(ci, r): _pit(ci, r)})
	out.append({"key": "fos_frame", "w": 300, "h": 300, "pad": 14, "nine": [44, 44, 44, 44], "draw": func(ci, r): _frame(ci, r)})
	out.append({"key": "fos_shelf", "w": 600, "h": 40, "pad": 10, "nine": [30, 10, 30, 10], "draw": func(ci, r): _shelf(ci, r)})
	out.append({"key": "fos_card", "w": 100, "h": 120, "pad": 8, "nine": [22, 22, 22, 22], "draw": func(ci, r): _card(ci, r)})
	out.append({"key": "fos_shovel", "w": 60, "h": 110, "pad": 12, "draw": func(ci, r): _shovel(ci, r)})
	out.append({"key": "fos_entry", "w": 110, "h": 100, "pad": 12, "draw": func(ci, r): _entry(ci, r)})
	var seen := {}
	for s in SHAPES:
		var k := "%s_%dx%d" % s
		if seen.has(k): continue
		seen[k] = true
		var kind: String = s[0]
		var w: int = s[1]
		var h: int = s[2]
		out.append({"key": bone_key(kind, w, h), "w": int(w * CELL), "h": int(h * CELL), "pad": 12,
			"draw": func(ci, r): _bone(ci, r, kind, w, h, false)})
		out.append({"key": bone_key(kind, w, h, true), "w": int(w * CELL), "h": int(h * CELL), "pad": 12, "static": true,
			"draw": func(ci, r): _bone(ci, r, kind, w, h, true)})
	return out

# ---------------------------------------------------------------- 挖掘场

## 土块：圆角泥团，上亮下暗，嵌着小石子，偶尔一撮草
static func _dirt(ci: CanvasItem, r: Rect2, v: int) -> void:
	var col: Color = SOIL[v]
	var body := Art.rrect(Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6)), 16, 300 + v, 0.9, 30)
	Art.dilate(ci, body, 2.5, Art.INK)
	ci.draw_colored_polygon(body, col.darkened(0.18))
	var top := Art.rrect(Rect2(r.position + Vector2(7, 6), Vector2(r.size.x - 14, r.size.y * 0.72)), 13, 310 + v, 0.6, 30)
	ci.draw_colored_polygon(top, col)
	ci.draw_colored_polygon(Art.ell(r.position + Vector2(30, 20), Vector2(16, 5), 320 + v, 0.1, 10, -0.15), Color(1, 0.95, 0.8, 0.35))
	# 小石子
	var stones := [[Vector2(70, 38), 6.0], [Vector2(28, 66), 4.5], [Vector2(78, 76), 3.6], [Vector2(48, 48), 2.8]]
	for i in stones.size():
		if (i + v) % 4 == 3: continue
		var c: Vector2 = r.position + stones[i][0] + Vector2((v * 7) % 11 - 5, (v * 5) % 9 - 4)
		var st := Art.ell(c, Vector2(stones[i][1], stones[i][1] * 0.75), 330 + i + v * 5, 0.12, 9)
		Art.dilate(ci, st, 1.6, Art.INK)
		ci.draw_colored_polygon(st, Art.STONE if i % 2 == 0 else Color("cfc6b6"))
	# 裂纹
	Art.pl(ci, [r.position + Vector2(18, 36), r.position + Vector2(26, 42), r.position + Vector2(24, 52)], 1.6, col.darkened(0.35), 340 + v)
	# 草
	if v % 2 == 0:
		var g := r.position + Vector2(64 if v == 0 else 22, 12)
		for k in 3:
			var a := -0.5 + 0.5 * k
			var tip := g + Vector2(sin(a) * 9, -12 - 3 * (k % 2))
			var blade := Art.poly([g + Vector2(-3 + 3 * k, 2), tip, g + Vector2(1 + 3 * k, 2)], 350 + k + v, 0.3)
			Art.dilate(ci, blade, 1.3, Art.INK)
			ci.draw_colored_polygon(blade, Art.LEAF)

## 挖开后的坑：深色泥，上沿和左沿压一道阴影
static func _pit(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, PIT)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 14)), PIT.darkened(0.35))
	ci.draw_rect(Rect2(r.position, Vector2(10, r.size.y)), PIT.darkened(0.25))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 5), Vector2(r.size.x, 5)), PIT.lightened(0.12))
	for i in 7:
		var c := r.position + Vector2(18 + (i * 37) % 70, 24 + (i * 23) % 64)
		ci.draw_circle(c, 1.6 + (i % 3) * 0.8, PIT.lightened(0.18 + 0.05 * (i % 2)))

## 挖掘场外框：四根原木，四角木桩缠草绳，里面是深色地基
static func _frame(ci: CanvasItem, r: Rect2) -> void:
	var inner := r.grow(-26)
	ci.draw_rect(inner.grow(4), PIT.darkened(0.3))
	var logs := [[r.position + Vector2(16, 16), Vector2(r.end.x - 16, r.position.y + 16)],
		[Vector2(r.position.x + 16, r.end.y - 16), r.end - Vector2(16, 16)],
		[r.position + Vector2(16, 16), Vector2(r.position.x + 16, r.end.y - 16)],
		[Vector2(r.end.x - 16, r.position.y + 16), r.end - Vector2(16, 16)]]
	var parts := []
	for i in logs.size():
		parts.append(Art.P(Art.capsule(logs[i][0], logs[i][1], 12, 400 + i), Art.WOOD, 1))
	Art.sil(ci, parts, false)
	for i in logs.size():
		var a: Vector2 = logs[i][0]
		var b: Vector2 = logs[i][1]
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		for k in 3:
			var p := a.lerp(b, 0.25 + 0.25 * k)
			Art.ln(ci, p - n * 5 - d * 14, p - n * 5 + d * 14, 1.6, Art.WOOD_D, 410 + i * 3 + k)
	for c in [r.position + Vector2(16, 16), Vector2(r.end.x - 16, r.position.y + 16), Vector2(r.position.x + 16, r.end.y - 16), r.end - Vector2(16, 16)]:
		var stake := Art.ell(c, Vector2(16, 16), 420 + int(c.x), 0.06, 14)
		Art.dilate(ci, stake, 2.4, Art.INK)
		ci.draw_colored_polygon(stake, Art.WOOD_D)
		ci.draw_colored_polygon(Art.ell(c, Vector2(10, 10), 430 + int(c.y), 0.05, 12), Art.WOOD.lightened(0.1))
		ci.draw_arc(c, 5.0, 0, TAU, 12, Art.WOOD_D, 1.6, true)
		for k in 2:
			Art.ln(ci, c + Vector2(-15, -3 + k * 6), c + Vector2(15, 3 + k * 6), 3.0, Art.ROPE, 440 + k)

## 陈列架木板
static func _shelf(ci: CanvasItem, r: Rect2) -> void:
	var plank := Art.rrect(Rect2(r.position + Vector2(0, 8), Vector2(r.size.x, 24)), 8, 450, 0.6)
	Art.sil(ci, [Art.P(plank, Art.WOOD, 1)], false)
	for k in 4:
		var x := r.position.x + 40 + k * (r.size.x - 80) / 3.0
		Art.ln(ci, Vector2(x - 20, r.position.y + 18), Vector2(x + 20, r.position.y + 20), 1.6, Art.WOOD_D, 460 + k)

## 陈列卡：兽皮色小卡，虚线内框
static func _card(ci: CanvasItem, r: Rect2) -> void:
	var c := Art.rrect(r.grow(-2), 14, 470, 0.5)
	Art.dilate(ci, c, 2.5, Art.INK)
	ci.draw_colored_polygon(c, Art.HIDE)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(6, r.size.y - 26), Vector2(r.size.x - 12, 20)), 8, 471, 0.3), Art.HIDE2)
	Art.dashed(ci, Art.rrect(r.grow(-10), 9, 472, 0.0), 6, 4, Art.HIDE2.darkened(0.15), 1.8)

## 铲子：木柄 + T 形握把 + 草绳缠 + 燧石铲头
static func _shovel(ci: CanvasItem, r: Rect2) -> void:
	var o := r.position
	var grip := Art.capsule(o + Vector2(16, 8), o + Vector2(44, 8), 6, 480)
	var shaft := Art.capsule(o + Vector2(30, 10), o + Vector2(30, 64), 5.5, 481)
	var blade := Art.poly([o + Vector2(14, 58), o + Vector2(46, 58), o + Vector2(48, 82), o + Vector2(30, 106), o + Vector2(12, 82)], 482, 0.6)
	Art.sil(ci, [Art.P(grip, Art.WOOD, 1), Art.P(shaft, Art.WOOD, 1), Art.P(blade, Art.STONE, 1)], false)
	ci.draw_colored_polygon(Art.poly([o + Vector2(18, 62), o + Vector2(30, 62), o + Vector2(22, 90)], 483, 0.3), Color(1, 1, 1, 0.3))
	for k in 3:
		Art.ln(ci, o + Vector2(23, 50 + k * 5), o + Vector2(37, 54 + k * 5), 2.6, Art.ROPE, 484 + k)

## 棋盘活动入口：土堆里露出半个恐龙头骨，旁边插着铲子
static func _entry(ci: CanvasItem, r: Rect2) -> void:
	var o := r.position
	var mound := Art.poly([o + Vector2(4, 96), o + Vector2(10, 76), o + Vector2(30, 64), o + Vector2(58, 60), o + Vector2(86, 64),
		o + Vector2(104, 78), o + Vector2(106, 96)], 600, 0.8)
	# 外圈奶白贴纸边
	Art.dilate(ci, mound, 9.0, Color(1, 0.98, 0.92, 0.96))
	var skull_parts := []
	for poly in _shapes("skull", 2, 2):
		var moved := PackedVector2Array()
		for q in poly:
			moved.append(o + Vector2(4, -14) + q * 0.46)
		skull_parts.append(moved)
	for q in skull_parts:
		Art.dilate(ci, q, 9.0, Color(1, 0.98, 0.92, 0.96))
	# 铲子（在头骨后面）
	ci.draw_set_transform(o + Vector2(88, 40), 0.45, Vector2.ONE * 0.62)
	_shovel(ci, Rect2(-30, -55, 60, 110))
	ci.draw_set_transform(Vector2.ZERO)
	var parts := []
	for q in skull_parts:
		parts.append(Art.P(q, BONE, 1))
	Art.sil(ci, parts, false)
	var eye := Art.ell(o + Vector2(4, -14) + Vector2(64, 66) * 0.46, Vector2(8, 7), 601, 0.08, 12)
	Art.dilate(ci, eye, 2.0, Art.INK)
	ci.draw_colored_polygon(eye, PIT)
	for k in 5:
		var x := 82.0 + k * 13.0
		var tooth := Art.poly([o + Vector2(4, -14) + Vector2(x - 4, 116) * 0.46, o + Vector2(4, -14) + Vector2(x + 4, 116) * 0.46, o + Vector2(4, -14) + Vector2(x, 128) * 0.46], 602 + k, 0.2)
		ci.draw_colored_polygon(tooth, Color.WHITE)
	# 土堆盖住头骨下半
	Art.sil(ci, [Art.P(mound, SOIL[1], 1)], false)
	for c in [Vector2(30, 82), Vector2(70, 78), Vector2(88, 88)]:
		var st := Art.ell(o + c, Vector2(5, 4), 610 + int(c.x), 0.12, 9)
		Art.dilate(ci, st, 1.5, Art.INK)
		ci.draw_colored_polygon(st, Art.STONE)
	for k in 3:
		var g := o + Vector2(18 + k * 4, 66)
		var blade := Art.poly([g + Vector2(-2, 2), g + Vector2(sin(-0.4 + 0.4 * k) * 6, -10), g + Vector2(2, 2)], 620 + k, 0.2)
		Art.dilate(ci, blade, 1.2, Art.INK)
		ci.draw_colored_polygon(blade, Art.LEAF)

# ---------------------------------------------------------------- 骨头

## 一根骨头的外形：两头各两颗圆疙瘩 + 中间骨干
static func _long_bone(a: Vector2, b: Vector2, r: float, knob: float) -> PackedVector2Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var shape := Art.capsule(a, b, r, 500)
	for end in [a, b]:
		for side in [-1.0, 1.0]:
			var k := Art.ell(end + n * side * knob * 0.62, Vector2(knob, knob), 501 + int(side), 0.05, 14)
			var merged := Geometry2D.merge_polygons(shape, k)
			if merged.size() > 0: shape = merged[0]
	return shape

## 每种骨头的外形（多块）。坐标以内容区左上为原点
static func _shapes(kind: String, w: int, h: int) -> Array:
	var W := w * CELL
	var H := h * CELL
	var out: Array = []
	match kind:
		"limb":
			out.append(_long_bone(Vector2(W * 0.5, 30), Vector2(W * 0.5, H - 30), 13, 17))
		"spine":
			var count := int(round(h * 1.7))
			for i in count:
				var y := lerpf(26, H - 26, float(i) / float(count - 1))
				var wv := 30.0 - absf(float(i) - (count - 1) * 0.5) * 2.5
				out.append(Art.ell(Vector2(W * 0.5, y), Vector2(wv, 15), 510 + i, 0.06, 16))
		"ribs":
			out.append(Art.capsule(Vector2(W * 0.5, 22), Vector2(W * 0.5, H - 22), 12, 520))
			var count := h + 2
			for i in count:
				var y := lerpf(36, H - 46, float(i) / float(count - 1))
				var reach := W * (0.44 - absf(float(i) - (count - 1) * 0.5) * 0.03)
				for side in [-1.0, 1.0]:
					var path := PackedVector2Array([Vector2(W * 0.5, y), Vector2(W * 0.5 + side * reach * 0.7, y - 10),
						Vector2(W * 0.5 + side * reach, y + 14), Vector2(W * 0.5 + side * reach * 0.86, y + 40)])
					for poly in Geometry2D.offset_polyline(path, 7.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
						out.append(poly)
		"pelvis":
			for side in [-1.0, 1.0]:
				var c := Vector2(W * 0.5, H * 0.5)
				var wing := []
				for p in [Vector2(14, -40), Vector2(40, -120), Vector2(104, -128), Vector2(130, -70), Vector2(112, 0), Vector2(70, 60), Vector2(34, 120), Vector2(14, 70)]:
					wing.append(c + Vector2(p.x * side, p.y))
				out.append(Art.poly(wing, 530 + int(side), 0.8))
			out.append(Art.capsule(Vector2(W * 0.5, 34), Vector2(W * 0.5, H - 30), 22, 533))
		_:
			# 头骨：朝右的恐龙侧脸，大眼窝，长嘴带牙
			var skull := Art.poly([Vector2(20, 70), Vector2(52, 30), Vector2(110, 26), Vector2(160, 52), Vector2(186, 84),
				Vector2(184, 112), Vector2(120, 116), Vector2(70, 130), Vector2(34, 128), Vector2(16, 100)], 540, 0.8)
			var jaw := Art.poly([Vector2(42, 132), Vector2(120, 122), Vector2(178, 120), Vector2(172, 140), Vector2(110, 156), Vector2(56, 160), Vector2(36, 148)], 541, 0.8)
			out.append(jaw)
			out.append(skull)
	return out

static func _bone(ci: CanvasItem, r: Rect2, kind: String, w: int, h: int, silhouette: bool) -> void:
	ci.draw_set_transform(r.position)
	var shapes := _shapes(kind, w, h)
	if silhouette:
		for s in shapes:
			Art.dilate(ci, s, 3.0, Color.WHITE)
		ci.draw_set_transform(Vector2.ZERO)
		return
	var parts := []
	for s in shapes:
		parts.append(Art.P(s, BONE, 1))
	Art.sil(ci, parts, false)
	var W := w * CELL
	var H := h * CELL
	var line := BONE_D.darkened(0.2)
	match kind:
		"limb":
			Art.ln(ci, Vector2(W * 0.5 - 5, 46), Vector2(W * 0.5 - 5, H - 46), 3.0, Color(1, 1, 1, 0.6), 550)
			Art.pl(ci, [Vector2(W * 0.5 + 4, H * 0.45), Vector2(W * 0.5 + 7, H * 0.52), Vector2(W * 0.5 + 3, H * 0.58)], 1.6, line, 551)
		"spine":
			var count := int(round(h * 1.7))
			for i in count:
				var y := lerpf(26, H - 26, float(i) / float(count - 1))
				ci.draw_circle(Vector2(W * 0.5, y), 6, line)
				ci.draw_circle(Vector2(W * 0.5 - 1, y - 1), 3.5, BONE.darkened(0.08))
		"ribs":
			Art.ln(ci, Vector2(W * 0.5 - 4, 30), Vector2(W * 0.5 - 4, H - 30), 2.4, Color(1, 1, 1, 0.55), 552)
			var count := h + 2
			for i in count:
				var y := lerpf(36, H - 46, float(i) / float(count - 1))
				ci.draw_circle(Vector2(W * 0.5, y), 4, line)
		"pelvis":
			for side in [-1.0, 1.0]:
				var c := Vector2(W * 0.5 + side * 66, H * 0.5 - 6)
				var hole := Art.ell(c, Vector2(20, 22), 560 + int(side), 0.06, 14)
				Art.dilate(ci, hole, 2.2, Art.INK)
				ci.draw_colored_polygon(hole, PIT)
				Art.pl(ci, [Vector2(W * 0.5 + side * 40, 70), Vector2(W * 0.5 + side * 90, 60)], 1.8, line, 562 + int(side))
			for k in 4:
				ci.draw_circle(Vector2(W * 0.5, 70 + k * 45), 5, line)
		_:
			var eye := Art.ell(Vector2(64, 66), Vector2(18, 16), 570, 0.08, 14)
			Art.dilate(ci, eye, 2.2, Art.INK)
			ci.draw_colored_polygon(eye, PIT)
			var nose := Art.ell(Vector2(150, 70), Vector2(9, 6), 571, 0.08, 10, -0.3)
			Art.dilate(ci, nose, 2.0, Art.INK)
			ci.draw_colored_polygon(nose, PIT)
			var hole := Art.ell(Vector2(104, 82), Vector2(14, 10), 572, 0.08, 12)
			ci.draw_colored_polygon(hole, BONE_D)
			for k in 7:
				var x := 82.0 + k * 13.0
				var tooth := Art.poly([Vector2(x - 4, 116), Vector2(x + 4, 116), Vector2(x, 127)], 573 + k, 0.3)
				Art.dilate(ci, tooth, 1.4, Art.INK)
				ci.draw_colored_polygon(tooth, Color.WHITE)
			Art.ln(ci, Vector2(40, 56), Vector2(90, 38), 3.0, Color(1, 1, 1, 0.6), 580)
	ci.draw_set_transform(Vector2.ZERO)
