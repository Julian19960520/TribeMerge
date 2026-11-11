extends Control
## Offline painter only. Runtime uses assets/events/moon/baked PNGs.
var cfg: Dictionary
var cell := 96.0
var _t := 0.0
const INK := Color("3b2314")
const CREAM := Color("fff3c4")
var painter: Callable
func _draw() -> void:
	if painter.is_valid(): painter.call(self, size)
func _c(key: String, fallback: String) -> Color:
	return Color(str(cfg["theme"].get(key, fallback)))
func _color(key: String, fallback: String) -> Color:
	return _c(key, fallback)

func _floor(r: Rect2, i: int, parity: int) -> void:
	var base := _color("tile", "e6d9b2") if parity % 2 == 0 else _color("tile_alt", "d9c99c")
	var pts := Art.rrect(r.grow(-2.5), 12, 700 + i, 0.5)
	draw_colored_polygon(pts, base)
	draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(4, r.size.y * 0.7), Vector2(r.size.x - 8, r.size.y * 0.26)), 10, 900 + i, 0.3), Color(0.45, 0.3, 0.12, 0.1))
	draw_line(r.position + Vector2(12, 8), r.position + Vector2(r.size.x - 14, 8), Color(1, 1, 1, 0.35), 2.5)
	for k in 3:
		var p := r.position + Vector2(0.15 + Art.srnd(i * 7 + k) * 0.7, 0.2 + Art.srnd(i * 13 + k) * 0.65) * r.size
		draw_circle(p, 1.4 + Art.srnd(i + k * 5) * 2.2, Color(0.42, 0.28, 0.12, 0.13))
	Art.outline(self, pts, 1.6, Color(0.36, 0.25, 0.13, 0.35))

## 已显示但锁定：凹陷的暗石槽。
func _recess(r: Rect2, i: int) -> void:
	var pts := Art.rrect(r.grow(-2.5), 12, 300 + i, 0.5)
	draw_colored_polygon(pts, _color("recess", "2f5058"))
	draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, r.size.y * 0.32)), 10, 310 + i, 0.3), Color(0, 0, 0, 0.2))
	Art.outline(self, pts, 2.0, Color(_color("glow", "bff3f0"), 0.22))

## 覆盖格：爬满藤蔓的月纹石板（每块的月纹、裂缝、藤蔓都不同）。
func _slab(r: Rect2, i: int, alpha: float, frontier: bool) -> void:
	if alpha <= 0.01: return
	var h := Art.srnd(i * 3 + 1)
	var base := _color("covered", "6e8d93").lerp(_color("covered_alt", "7f9a97"), h)
	if frontier: base = base.lightened(0.1)
	var ink := Color(INK, alpha)
	var face := Rect2(r.position + Vector2(4, 3), r.size - Vector2(8, 12))
	var side := Art.rrect(Rect2(face.position + Vector2(0, 7), face.size), 13, 100 + i, 0.6)
	Art.dilate(self, side, 2.5, ink)
	draw_colored_polygon(side, Color(base.darkened(0.42), alpha))
	var top := Art.rrect(face, 13, 120 + i, 0.6)
	Art.dilate(self, top, 2.5, ink)
	draw_colored_polygon(top, Color(base, alpha))
	draw_colored_polygon(Art.rrect(Rect2(face.position + Vector2(face.size.x * 0.5, face.size.y * 0.45), face.size * Vector2(0.48, 0.52)), 11, 140 + i, 0.3), Color(0, 0, 0, 0.1 * alpha))
	draw_polyline(PackedVector2Array([face.position + Vector2(9, face.size.y - 16), face.position + Vector2(8, 12), face.position + Vector2(face.size.x - 16, 8)]), Color(1, 1, 1, 0.28 * alpha), 3.0)
	if frontier:
		Art.outline(self, top, 2.0, Color(_color("glow", "bff3f0"), 0.45 * alpha))
	_rune(face.get_center() + Vector2(0, 1), cell * 0.17, int(Art.srnd(i * 11 + 5) * 5.0), base, alpha)
	if Art.srnd(i * 5 + 2) > 0.45:
		var a := face.position + Vector2(face.size.x * (0.6 + Art.srnd(i) * 0.3), face.size.y - 3)
		draw_polyline(PackedVector2Array([a, a + Vector2(-6, -10), a + Vector2(-3, -18), a + Vector2(-10, -26)]), Color(base.darkened(0.55), 0.8 * alpha), 2.0)
	_slab_vine(face, i, alpha)

## 刻在石板上的月纹：凹槽暗线 + 下沿高光。
func _rune(c: Vector2, s: float, kind: int, base: Color, alpha: float) -> void:
	var dark := Color(base.darkened(0.5), alpha)
	var lip := Color(base.lightened(0.35), 0.8 * alpha)
	for pass_ in 2:
		var col := lip if pass_ == 0 else dark
		var o := Vector2(1.2, 1.8) if pass_ == 0 else Vector2.ZERO
		var w := 2.0 if pass_ == 0 else 4.0
		match kind:
			0:
				draw_arc(c + o, s, PI * 0.35, PI * 1.65, 18, col, w, true)
				draw_arc(c + o + Vector2(s * 0.45, 0), s * 0.75, PI * 0.5, PI * 1.5, 14, col, w * 0.7, true)
			1:
				draw_arc(c + o, s, 0, TAU, 22, col, w, true)
				draw_circle(c + o, s * 0.28, col)
			2:
				var pts := PackedVector2Array()
				for k in 22:
					var t := float(k) / 21.0
					pts.append(c + o + Vector2.from_angle(t * TAU * 1.6) * s * (0.15 + t * 0.9))
				draw_polyline(pts, col, w, true)
			3:
				draw_arc(c + o + Vector2(0, s * 0.7), s * 1.15, PI * 1.22, PI * 1.78, 12, col, w, true)
				draw_arc(c + o + Vector2(0, -s * 0.7), s * 1.15, PI * 0.22, PI * 0.78, 12, col, w, true)
				draw_circle(c + o, s * 0.3, col)
			_:
				for k in 3:
					draw_circle(c + o + Vector2.from_angle(-PI / 2 + k * TAU / 3) * s * 0.75, s * 0.22, col)
				draw_arc(c + o, s * 1.05, 0, TAU, 22, col, w * 0.6, true)

## 石板上的藤蔓：从上角垂下，带几片叶子；有的石板只有一撮苔藓。
func _slab_vine(face: Rect2, i: int, alpha: float) -> void:
	var v := Art.srnd(i * 17 + 3)
	var leaf := Color(_color("vine", "7fae5a"), alpha)
	var dark := Color(_color("vine", "7fae5a").darkened(0.5), alpha)
	if v < 0.28:
		var m := face.position + Vector2(face.size.x * (0.25 + Art.srnd(i) * 0.5), face.size.y - 2)
		for k in 3: draw_circle(m + Vector2((k - 1) * 7, -2 - (k % 2) * 3), 5.5, leaf)
		return
	var left := v < 0.64
	var x0 := face.position.x + (8.0 if left else face.size.x - 8.0)
	var dir := 1.0 if left else -1.0
	var pts := PackedVector2Array()
	var len := 0.45 + Art.srnd(i * 23) * 0.45
	for k in 7:
		var t := float(k) / 6.0
		pts.append(Vector2(x0 + dir * sin(t * 3.2 + i) * 6.0 + Art.jit(i * 31 + k) * 0.8, face.position.y - 2 + t * face.size.y * len))
	draw_polyline(pts, Color(INK, alpha), 5.0, true)
	draw_polyline(pts, dark.lightened(0.25), 2.6, true)
	for k in [1, 3, 5]:
		if k >= pts.size(): continue
		var side := 1.0 if k % 4 == 1 else -1.0
		_leaf(pts[k] + Vector2(side * dir * 6, 0), 0.6 * side * dir + 0.3, 7.5, leaf, alpha)

func _leaf(c: Vector2, rot: float, s: float, col: Color, alpha: float) -> void:
	var pts := Art.ell(c, Vector2(s, s * 0.55), int(c.x * 3 + c.y), 0.02, 10, rot, 0.3)
	Art.dilate(self, pts, 1.6, Color(INK, alpha))
	draw_colored_polygon(pts, col)
	draw_line(c - Vector2.from_angle(rot) * s * 0.7, c + Vector2.from_angle(rot) * s * 0.7, Color(col.darkened(0.35), alpha), 1.4)

## 锁定格的藤蔓：两股从对角缠进来，物品还能看清。
func _vines(r: Rect2, i: int) -> void:
	var leaf := _color("vine", "7fae5a")
	for corner in 2:
		var a := r.position + (Vector2(4, 6) if corner == 0 else Vector2(r.size.x - 4, r.size.y - 8))
		var b := r.position + (Vector2(r.size.x * 0.42, 3) if corner == 0 else Vector2(r.size.x * 0.56, r.size.y - 3))
		var mid := r.position + (Vector2(r.size.x * 0.2, r.size.y * 0.24) if corner == 0 else Vector2(r.size.x * 0.8, r.size.y * 0.74))
		var pts := PackedVector2Array()
		for k in 9:
			var t := float(k) / 8.0
			var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
			pts.append(p + Vector2(0, sin(t * 9.0 + i) * 2.0))
		draw_polyline(pts, INK, 5.0, true)
		draw_polyline(pts, leaf.darkened(0.25), 2.6, true)
		_leaf(pts[3] + Vector2(4, 4) * (1 if corner == 0 else -1), 0.8 + corner * PI, 7.0, leaf, 1.0)
		_leaf(pts[6] + Vector2(-3, 5) * (1 if corner == 0 else -1), -0.4 + corner * PI, 6.0, leaf.lightened(0.15), 1.0)

## 石锁：小石块 + 月牙锁孔。
func _lock_badge(c: Vector2) -> void:
	draw_arc(c + Vector2(0, -6), 7.5, PI, TAU, 10, INK, 6.0, true)
	draw_arc(c + Vector2(0, -6), 7.5, PI, TAU, 10, Color("c9d3cf"), 2.6, true)
	var body := Art.rrect(Rect2(c + Vector2(-11, -6), Vector2(22, 17)), 5, 61, 0.3)
	Art.fill(self, body, Color("c9d3cf"), 2.5, INK)
	draw_arc(c + Vector2(-0.5, 2.5), 4.2, PI * 0.35, PI * 1.65, 10, Color("3e6068"), 2.4, true)


func _paint_scene(ci: CanvasItem, sz: Vector2) -> void:
	var r := Art.rrect(Rect2(Vector2.ZERO, sz), 18, 801, 0.4)
	ci.draw_colored_polygon(r, _c("sky_top", "142636"))
	var bands := 10
	for k in bands:
		var t := float(k) / bands
		ci.draw_rect(Rect2(6, 8 + sz.y * t, sz.x - 12, sz.y / bands + 1), Color(_c("sky_top", "142636").lerp(_c("sky_bottom", "2c5a63"), t), 0.9))
	# 月亮（藏在进度板后面露出一角）与星星
	var moon := Vector2(sz.x - 70, 46)
	for k in 3: ci.draw_circle(moon, 64 + k * 22, Color(_c("glow", "bff3f0"), 0.07))
	ci.draw_circle(moon, 46, Color("f4f6dc"))
	ci.draw_circle(moon + Vector2(14, -8), 9, Color("dfe4c6"))
	ci.draw_circle(moon + Vector2(-16, 12), 6, Color("dfe4c6"))
	for k in 36:
		var p := Vector2(16 + Art.srnd(k * 3 + 1) * (sz.x - 32), 14 + Art.srnd(k * 7 + 2) * (sz.y - 28))
		var tw := 0.35 + 0.35 * sin(_t * (1.5 + Art.srnd(k) * 2.0) + k)
		ci.draw_circle(p, 1.2 + Art.srnd(k + 11) * 1.6, Color(0.85, 1, 0.95, tw))
	# 底部远处的断柱剪影
	var sil := Color(_c("sky_top", "142636"), 0.75)
	var base_y := sz.y - 8
	for k in 7:
		var x := 20 + k * (sz.x - 40) / 6.0
		var h := 90 + Art.srnd(k * 5) * 110
		var w := 26 + Art.srnd(k * 9) * 18
		ci.draw_colored_polygon(Art.poly([Vector2(x - w / 2, base_y), Vector2(x - w / 2 + 3, base_y - h), Vector2(x - w / 2 + w * 0.4, base_y - h - 10 * Art.srnd(k)), Vector2(x + w / 2, base_y - h + 6), Vector2(x + w / 2, base_y)], 810 + k, 0.4), sil)
	Art.outline(ci, r, 2.5, Color(INK, 0.9))

# ---------------------------------------------------------------- 状态刷新


func _paint_corner_vines(ci: CanvasItem, sz: Vector2) -> void:
	var leaf := _c("vine", "7fae5a")
	for side in 2:
		var dir := 1.0 if side == 0 else -1.0
		var x0 := 12.0 if side == 0 else sz.x - 12.0
		var pts := PackedVector2Array()
		for k in 9:
			var t := float(k) / 8.0
			pts.append(Vector2(x0 + dir * t * 120.0, 22 + sin(t * 5.0 + side) * 7.0 + t * t * 6.0))
		ci.draw_polyline(pts, INK, 6.0, true)
		ci.draw_polyline(pts, leaf.darkened(0.3), 3.0, true)
		for k in [1, 3, 5, 7]:
			var c: Vector2 = pts[k] + Vector2(0, -7 if k % 4 == 1 else 8)
			var e := Art.ell(c, Vector2(9, 5), 520 + k + side * 9, 0.02, 10, 0.5 * dir * (1 if k % 4 == 1 else -1), 0.4)
			Art.fill(ci, e, leaf if k % 4 == 1 else leaf.lightened(0.12), 1.8, INK)

# ---------------------------------------------------------------- 底部：遗物陈列、积分气泡、说明


func _card(ci: CanvasItem, sz: Vector2, seed: int, glow: float = 0.0) -> void:
	var r := Art.rrect(Rect2(Vector2.ZERO, sz), 18, seed, 0.6)
	if glow > 0.0: Art.dilate(ci, r, 7.0, Color(1, 0.9, 0.5, glow))
	Art.dilate(ci, r, 3.0, INK)
	ci.draw_colored_polygon(r, Color("1e3842"))
	Art.dashed(ci, Art.rrect(Rect2(Vector2(6, 6), sz - Vector2(12, 12)), 13, seed + 1, 0.0), 9, 6, Color(_c("glow", "bff3f0"), 0.22), 1.8)


func _paint_track(ci: CanvasItem, sz: Vector2) -> void:
	var base := Art.rrect(Rect2(Vector2.ZERO, sz), 20, 404, 0.6)
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 6), sz), 20, 405, 0.0), Color(0, 0, 0, 0.3))
	Art.dilate(ci, base, 3.0, INK)
	ci.draw_colored_polygon(base, Color("24404a"))
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(6, 6), Vector2(sz.x - 12, sz.y * 0.42)), 15, 406, 0.3), Color(1, 1, 1, 0.05))
	Art.dashed(ci, Art.rrect(Rect2(Vector2(7, 7), sz - Vector2(14, 14)), 15, 407, 0.0), 10, 7, Color(_c("glow", "bff3f0"), 0.28), 2.0)

func _paint_collection(ci: CanvasItem, sz: Vector2) -> void:
	var ledge := Art.rrect(Rect2(Vector2(0, 8), sz - Vector2(0, 8)), 16, 701, 0.6)
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 14), sz - Vector2(0, 8)), 16, 702, 0.0), Color(0, 0, 0, 0.3))
	Art.dilate(ci, ledge, 3.0, INK)
	ci.draw_colored_polygon(ledge, Color("5b787d"))
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(6, 12), Vector2(sz.x - 12, 10)), 5, 703, 0.0), Color(1, 1, 1, 0.12))

func _paint_earn(ci: CanvasItem, sz: Vector2, glow := false) -> void:
	_card(ci, sz, 601, 0.6 if glow else 0.0)
	# 订单小卡 → 积分
	var tk := Rect2(16, 46, 40, 50)
	Art.fill(ci, Art.rrect(tk, 6, 610, 0.4), Color("f6e7c8"), 2.4, INK)
	for k in 3: ci.draw_line(tk.position + Vector2(8, 14 + k * 11), tk.position + Vector2(32, 14 + k * 11), Color(0.4, 0.27, 0.12, 0.55), 2.0)
	Paint.check_mark(ci, tk.position + Vector2(34, 44), 0.7)
	ci.draw_texture_rect(MergeEventArt.texture(str(cfg["theme"]["point_icon"])), Rect2(56, 52, 40, 40), false)


func _paint_spawn(ci: CanvasItem, sz: Vector2, can := true) -> void:
	var c := Vector2(sz.x / 2, 72)
	ci.draw_circle(c + Vector2(0, 6), 62, Color(0, 0, 0, 0.25))
	var ring := Art.ell(c, Vector2(62, 62), 620, 0.02, 30)
	Art.dilate(ci, ring, 3.5, INK)
	var bub := _c("accent", "8cdece") if can else Color("6b8487")
	ci.draw_colored_polygon(ring, Color(bub, 0.92))
	ci.draw_colored_polygon(Art.ell(c + Vector2(4, 6), Vector2(54, 52), 621, 0.02, 26), Color(bub.darkened(0.25), 0.7))
	ci.draw_colored_polygon(Art.ell(c + Vector2(-2, -2), Vector2(52, 50), 622, 0.02, 26), Color(bub.lightened(0.18), 0.9))
	ci.draw_arc(c + Vector2(-4, -4), 46, PI * 1.08, PI * 1.5, 14, Color(1, 1, 1, 0.85), 6, true)
	ci.draw_circle(c + Vector2(30, -32), 5, Color(1, 1, 1, 0.8))
	var pill := Rect2(Vector2(20, 124), Vector2(112, 36))
	Art.fill(ci, Art.rrect(pill, 18, 623, 0.3), Color("10232a"), 2.5, INK)
	ci.draw_texture_rect(MergeEventArt.texture(str(cfg["theme"]["point_icon"])), Rect2(pill.position + Vector2(-8, -4), Vector2(44, 44)), false)
	if can: Paint.plus_badge(ci, c + Vector2(46, 38))


func _paint_frame(ci: CanvasItem, sz: Vector2) -> void:
	var outer := Art.rrect(Rect2(Vector2.ZERO, sz), 18, 501, 0.6)
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 8), sz), 18, 502, 0.0), Color(0, 0, 0, 0.35))
	Art.dilate(ci, outer, 3.0, INK)
	ci.draw_colored_polygon(outer, Color("4f6c72"))
	for k in 18:
		var p := Vector2(Art.srnd(k * 3 + 7) * sz.x, (0.0 if k % 2 == 0 else sz.y - 5.0) + Art.srnd(k) * 5.0)
		ci.draw_circle(p, 1.5 + Art.srnd(k + 9) * 2.0, Color(0, 0, 0, 0.18))
