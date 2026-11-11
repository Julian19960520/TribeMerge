class_name PAPot
extends PA
## 陶艺线：陶窑 / 陶器皿 / 陶制工艺品

const RAW := Color("c99a6a")
const FIRED := Color("c8693a")
const PAINT := Color("e8a060")
const DARK := Color("3a2418")
const WHITE_P := Color("f6e8cc")
const RED_P := Color("c4532e")
const HOLE := Color("2a170c")
const PLANK_C := Color("c48a4a")

## 旋转体器皿；mouth 为真时在口沿画一圈深色内壁
static func vessel(ci: CanvasItem, prof: Array, col: Color, s: int, rim: bool, extra: Array = [], mouth: bool = true) -> void:
	var parts := extra.duplicate()
	parts.append(pg(lathe(prof), s, col, 0))
	sil(ci, parts, rim)
	if mouth:
		var top: Vector2 = prof[0]
		var m := ell(Vector2(0, top.y), Vector2(top.x - 1.0, maxf(top.x * 0.22, 2.5)), s, 0.0, 16, 0.0, 0.3)
		ci.draw_colored_polygon(m, col.darkened(0.45))
		outline(ci, m, 1.8)

static func band_at(ci: CanvasItem, prof: Array, y: float, col: Color, w: float = 3.0) -> void:
	var hw := prof_w(prof, y) - 1.5
	ln(ci, Vector2(-hw, y), Vector2(hw, y), w, col, int(y))

static func zig_at(ci: CanvasItem, prof: Array, y: float, h: float, n: int, col: Color, w: float = 2.2) -> void:
	var hw := prof_w(prof, y) - 3.0
	zig(ci, -hw, hw, y, h, n, col, w, int(y))

static func dots_at(ci: CanvasItem, prof: Array, y: float, n: int, r: float, col: Color) -> void:
	var hw := prof_w(prof, y) - 6.0
	for k in n:
		ci.draw_circle(Vector2(lerpf(-hw, hw, (float(k) + 0.5) / float(n)), y), r, col)

static func spiral_at(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float = 2.4) -> void:
	var arr := []
	for k in 24:
		var t := float(k) / 23.0
		var a := t * TAU * 1.6
		arr.append(c + Vector2(cos(a), sin(a) * 0.8) * r * (0.15 + t * 0.85))
	ci.draw_polyline(PackedVector2Array(arr), col, w, true)

static func loop(c: Vector2, r: float, side: float, s: int, col: Color) -> Array:
	return band(c, r, 2.8, -PI * 0.5 if side > 0.0 else PI * 0.5, PI * 0.5 if side > 0.0 else PI * 1.5, s, col)

## 等级感：低级缩小，高级放大并带金光，顶级加火星
static func _tier(ci: CanvasItem, lv: int, n: int, body: Callable, ks: Array = []) -> void:
	var t: float = clampf(float(lv - 1) / float(n - 1), 0.0, 1.0)
	var k: float = float(ks[lv - 1]) if ks.size() >= lv else lerpf(0.66, 1.0, t)
	set_xf(ci, Transform2D(0.0, Vector2.ONE * k, 0.0, Vector2(0, (1.0 - k) * 30.0)))
	var g: int = lv - (n - 3)
	if g >= 1:
		glow(ci, Vector2(0, -2), 34.0 + 9.0 * float(g), GOLD)
	body.call()
	if lv >= n:
		sparks(ci, [Vector2(-44, -36), Vector2(44, -40), Vector2(44, 28)])
	reset_xf(ci)

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	_tier(ci, lv, 9, func(): _gen(ci, lv, s, rim), [0.66, 0.72, 0.78, 0.82, 0.86, 0.92, 0.95, 1.0, 1.0])

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	_tier(ci, lv, 14, func(): _main(ci, lv, s, rim))

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	_tier(ci, lv, 11, func(): _sub(ci, lv, s, rim))

## 生产器 ------------------------------------------------------------------
static func _gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 黏土块
			sil(ci, [raw_rock(Vector2(0, 12), 30, s, RAW, 9, 0.12)], rim)
			for k in 3:
				ci.draw_arc(Vector2(-8.0 + float(k) * 9.0, 2), 4.0, 0.2, PI - 0.2, 6, Color(INK, 0.35), 2.0, true)
		2:
			## 泥坯：刚捏出来的湿泥碗坯，口沿歪歪的，外壁按满手指印
			var prof := [Vector2(30, -8), Vector2(29, 6), Vector2(22, 20), Vector2(13, 26)]
			vessel(ci, prof, RAW.lightened(0.04), s, rim, [ov(Vector2(38, 26), 9, 6, s + 9, RAW.darkened(0.06), 0.3, 1)])
			for p in [Vector2(-18, 4), Vector2(-6, 10), Vector2(7, 10), Vector2(19, 5), Vector2(-10, 20), Vector2(4, 21)]:
				var v: Vector2 = p
				ci.draw_colored_polygon(ell(v, Vector2(3.4, 4.6), s + int(v.x), 0.05, 10, 0.2), RAW.darkened(0.16))
			hl(ci, Vector2(-16, -2), 7, 3, -0.3, 0.6)
			hl(ci, Vector2(36, 23), 3, 2, -0.3, 0.5)
		3:
			## 泥条盘：一圈圈泥条盘成罐身，旁边还拖着一根没盘完的泥条
			var ws := [16.0, 22.0, 26.0, 27.0, 25.0]
			var parts := [ov(Vector2(0, 36), 30, 5, s, RAW.darkened(0.15), 0.0, 1)]
			for k in 5:
				var y := 30.0 - float(k) * 9.5
				parts.append(stk(Vector2(-float(ws[k]), y), Vector2(float(ws[k]), y), 5.2, s + 1 + k, RAW.darkened(0.05 * float(k % 2))))
			var path := [Vector2(24, -8), Vector2(36, -13), Vector2(45, -3), Vector2(43, 13), Vector2(35, 25), Vector2(44, 34)]
			for i in path.size() - 1:
				parts.append(stk(path[i], path[i + 1], 4.6, s + 10 + i, RAW.lightened(0.03)))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(0, -9), Vector2(20, 3.4), s, 0.0, 14), RAW.darkened(0.45))
			for k in 5:
				var y := 30.0 - float(k) * 9.5
				ln(ci, Vector2(-float(ws[k]) + 4.0, y - 2.4), Vector2(float(ws[k]) - 4.0, y - 2.4), 1.4, Color(1, 1, 1, 0.35), s + k)
				ln(ci, Vector2(-float(ws[k]) + 2.0, y + 4.6), Vector2(float(ws[k]) - 2.0, y + 4.6), 1.4, Color(INK, 0.3), s + k)
		4:
			## 制陶台
			var prof := [Vector2(12, -26), Vector2(16, -14), Vector2(16, -4), Vector2(10, 2)]
			sil(ci, [bx(-40, 4, 80, 12, 4, s, PLANK_C), stk(Vector2(-32, 16), Vector2(-34, 38), 4.0, s + 1, WOOD_D), stk(Vector2(32, 16), Vector2(34, 38), 4.0, s + 2, WOOD_D),
				stk(Vector2(22, -4), Vector2(40, -14), 2.2, s + 3, WOOD, 2), _scallop_shell(Vector2(-28, -4), s + 4)], rim)
			vessel(ci, prof, RAW, s + 6, false)
		5:
			## 慢轮
			var prof := [Vector2(14, -34), Vector2(20, -20), Vector2(18, -8), Vector2(12, -2)]
			sil(ci, [stk(Vector2(0, 2), Vector2(0, 34), 5.0, s, WOOD_D), ov(Vector2(0, 34), 18, 5, s + 1, WOOD_D, 0.0, 1),
				ov(Vector2(0, 0), 36, 8, s + 2, WOOD, 0.0, 1)], rim)
			vessel(ci, prof, RAW, s + 3, false)
			for k in 3:
				ci.draw_arc(Vector2(0, 2), 40.0 + float(k) * 4.0, PI * 0.15, PI * 0.45, 6, Color(1, 1, 1, 0.6), 2.0, true)
		6:
			## 露天烧坑：石头围一圈，柴火堆里埋着三只陶坯，火苗窜得老高
			var parts := [ov(Vector2(0, 28), 52, 14, s, Color("6a4428"), 0.0, 1)]
			for i in 8:
				var a := lerpf(PI * 0.98, PI * 2.02, float(i) / 7.0)
				parts.append(circ(Vector2(0, 26) + Vector2(cos(a) * 46.0, sin(a) * 11.0), 6.5, s + 1 + i, STONE_D.lightened(0.15), 1))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(0, 26), Vector2(40, 8), s, 0.04, 18), HOLE)
			flame(ci, Vector2(-22, 16), 11, 34, s + 2)
			flame(ci, Vector2(22, 16), 11, 34, s + 3)
			flame(ci, Vector2(0, 8), 13, 50, s + 4)
			sil(ci, [pg(lathe([Vector2(12, -2), Vector2(18, 8), Vector2(16, 20), Vector2(10, 26)]), s + 5, FIRED, 0),
				pg(lathe([Vector2(14, 10), Vector2(12, 20), Vector2(7, 26)], -30.0), s + 6, FIRED.darkened(0.06), 0),
				pg(lathe([Vector2(14, 10), Vector2(12, 20), Vector2(7, 26)], 30.0), s + 7, FIRED.darkened(0.04), 0)], false)
			for c in [Vector2(0, -2), Vector2(-30, 10), Vector2(30, 10)]:
				var v: Vector2 = c
				ci.draw_colored_polygon(ell(v, Vector2(11.0 if v.x == 0.0 else 12.0, 2.8), s, 0.0, 12), FIRED.darkened(0.45))
			flame(ci, Vector2(-15, 24), 9, 34, s + 8)
			flame(ci, Vector2(16, 24), 9, 30, s + 9)
			sil(ci, [stk(Vector2(-42, 36), Vector2(8, 24), 3.6, s + 10, WOOD), stk(Vector2(42, 36), Vector2(-8, 24), 3.6, s + 11, WOOD_D)], false)
			for i in 5:
				var a := lerpf(PI * 0.1, PI * 0.9, float(i) / 4.0)
				sil(ci, [circ(Vector2(0, 26) + Vector2(cos(a) * 48.0, sin(a) * 12.0), 7.0, s + 20 + i, STONE, 1)], false)
			smoke(ci, Vector2(4, -52), 0.7)
		7:
			## 土窑
			var dome := arcp(Vector2(0, 36), Vector2(40, 64), PI, TAU, 18)
			sil(ci, [stk(Vector2(0, -26), Vector2(0, -40), 6.0, s, TAN_D), pg(dome, s + 1, TAN, 0),
				ov(Vector2(-40, 30), 10, 8, s + 2, FIRED), ov(Vector2(40, 32), 8, 7, s + 3, FIRED.darkened(0.05))], rim)
			var door := arcp(Vector2(0, 36), Vector2(14, 22), PI, TAU, 10)
			ci.draw_colored_polygon(poly(door, s), HOLE)
			flame(ci, Vector2(0, 26), 9, 20, s + 4)
			outline(ci, poly(door, s), 2.0)
			smoke(ci, Vector2(2, -46), 0.8)
		8:
			## 双室陶窑：前面低矮的火膛烧柴，火道通到后面高起的窑室，窑室里码着陶坯
			sil(ci, [stk(Vector2(22, -34), Vector2(23, -52), 5.5, s, TAN_D), bx(-18, 10, 66, 28, 6, s + 1, TAN_D),
				pg(arcp(Vector2(15, 14), Vector2(32, 48), PI, TAU, 16), s + 2, TAN.darkened(0.04), 0),
				pg(arcp(Vector2(-22, 38), Vector2(26, 32), PI, TAU, 14), s + 3, TAN, 0)], rim)
			var win := rrect(Rect2(6, -16, 22, 20), 7, s, 0.5)
			ci.draw_colored_polygon(win, HOLE)
			sil(ci, [ov(Vector2(12, -1), 5, 6, s + 4, FIRED, 0.0, 1), ov(Vector2(22, 0), 5, 5, s + 5, FIRED.darkened(0.06), 0.0, 1)], false)
			outline(ci, win, 2.0)
			ln(ci, Vector2(-4, 22), Vector2(14, 14), 2.0, Color(INK, 0.45), s)
			var d1 := arcp(Vector2(-22, 38), Vector2(11, 16), PI, TAU, 8)
			ci.draw_colored_polygon(poly(d1, s), HOLE)
			flame(ci, Vector2(-22, 32), 8, 18, s + 6)
			outline(ci, poly(d1, s), 2.0)
			hl(ci, Vector2(-32, 14), 5, 3, -0.5, 0.4)
			smoke(ci, Vector2(24, -58), 0.8)
		_:
			## 彩陶大窑：又宽又高的圆顶大窑，两根烟囱，窑身画满红黑白彩纹，门口摆着刚出窑的彩陶罐
			sil(ci, [stk(Vector2(-28, -28), Vector2(-30, -44), 6.5, s, TAN_D), stk(Vector2(30, -28), Vector2(32, -44), 6.5, s + 1, TAN_D),
				bx(-50, 4, 100, 36, 10, s + 2, Color("e09a5a")),
				pg(arcp(Vector2(0, 6), Vector2(44, 52), PI, TAU, 18), s + 3, Color("e8aa6a"), 0),
				pg(lathe([Vector2(6, 18), Vector2(11, 26), Vector2(10, 34), Vector2(6, 40)], -44.0), s + 4, RED_P, 0),
				pg(lathe([Vector2(5, 22), Vector2(9, 30), Vector2(8, 36), Vector2(5, 40)], 45.0), s + 5, PAINT, 0)], rim)
			ln(ci, Vector2(-48, 6), Vector2(48, 6), 4.0, RED_P, s)
			zig(ci, -46, 46, 14, 3, 16, DARK, 2.4, s)
			dots_at(ci, [Vector2(48, 20), Vector2(48, 30)], 24, 9, 1.8, WHITE_P)
			ln(ci, Vector2(-36, -12), Vector2(36, -12), 3.0, WHITE_P, s + 1)
			spiral_at(ci, Vector2(-20, -26), 9, DARK)
			spiral_at(ci, Vector2(20, -26), 9, DARK)
			ci.draw_circle(Vector2(0, -36), 5, RED_P)
			ci.draw_circle(Vector2(0, -36), 2, WHITE_P)
			var d1 := arcp(Vector2(0, 40), Vector2(13, 20), PI, TAU, 8)
			ci.draw_colored_polygon(poly(d1, s), HOLE)
			flame(ci, Vector2(0, 33), 9, 20, s + 6)
			outline(ci, poly(d1, s), 2.0)
			ln(ci, Vector2(-48, 28), Vector2(-40, 28), 1.8, DARK, s)
			ln(ci, Vector2(41, 32), Vector2(49, 32), 1.8, WHITE_P, s)
			smoke(ci, Vector2(-30, -50), 0.65)
			smoke(ci, Vector2(33, -50), 0.65)

static func _scallop_shell(c: Vector2, s: int) -> Array:
	return pg(arcp(c, Vector2(9, 8), PI, TAU, 8) + [c + Vector2(3, 6), c + Vector2(-3, 6)], s, SHELL)

## 主产物：陶器皿 ------------------------------------------------------------
static func _main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 小陶杯
			var prof := [Vector2(16, -12), Vector2(15, 8), Vector2(12, 24), Vector2(8, 30)]
			vessel(ci, prof, RAW.darkened(0.05), s, rim)
		2:
			## 捏制小碟：手捏的歪口浅碟，碟里留着几个指印
			var col := RAW.lerp(FIRED, 0.45)
			sil(ci, [ov(Vector2(0, 24), 20, 7, s + 1, col.darkened(0.12), 0.0, 1), ov(Vector2(0, 12), 38, 17, s, col, 0.0, 0, 0.1)], rim)
			var inner := ell(Vector2(0, 8), Vector2(30, 10), s + 2, 0.08, 16)
			ci.draw_colored_polygon(inner, col.darkened(0.22))
			outline(ci, inner, 1.6)
			for p in [Vector2(-12, 9), Vector2(2, 11), Vector2(14, 8)]:
				var v: Vector2 = p
				ci.draw_colored_polygon(ell(v, Vector2(4.4, 2.6), s + int(v.x), 0.05, 10), col.darkened(0.34))
			hl(ci, Vector2(-22, 16), 5, 2.5, -0.2, 0.5)
		3:
			## 陶碗
			var prof := [Vector2(34, -6), Vector2(30, 10), Vector2(20, 22), Vector2(12, 26)]
			vessel(ci, prof, FIRED, s, rim)
			band_at(ci, prof, 4, CLAY.darkened(0.2), 2.4)
		4:
			## 陶盘
			sil(ci, [ov(Vector2(0, 14), 44, 16, s, FIRED, 0.0, 0)], rim)
			ci.draw_colored_polygon(ell(Vector2(0, 10), Vector2(36, 10), s + 1, 0.0, 18), FIRED.darkened(0.2))
			outline(ci, ell(Vector2(0, 10), Vector2(36, 10), s + 1, 0.0, 18), 1.8)
			ci.draw_colored_polygon(ell(Vector2(-6, 10), Vector2(18, 4), s + 2, 0.0, 14), Color(1, 1, 1, 0.15))
		5:
			## 陶罐
			var prof := [Vector2(14, -30), Vector2(16, -24), Vector2(28, -6), Vector2(28, 14), Vector2(18, 32)]
			vessel(ci, prof, FIRED, s, rim)
			zig_at(ci, prof, -10, 3, 8, CLAY.darkened(0.25))
		6:
			## 尖底瓶：小口尖底的汲水瓶，腰间两只小耳穿着草绳背带
			var prof := [Vector2(5, -40), Vector2(8, -32), Vector2(17, -20), Vector2(19, -2), Vector2(13, 20), Vector2(5, 38), Vector2(1, 42)]
			pl(ci, [Vector2(-21, -4), Vector2(-26, -28), Vector2(-14, -48), Vector2(0, -52), Vector2(14, -48), Vector2(26, -28), Vector2(21, -4)], 5.0, INK, s)
			pl(ci, [Vector2(-21, -4), Vector2(-26, -28), Vector2(-14, -48), Vector2(0, -52), Vector2(14, -48), Vector2(26, -28), Vector2(21, -4)], 2.6, ROPE, s)
			vessel(ci, prof, FIRED, s, rim, [loop(Vector2(-19, -4), 6, -1, s + 1, FIRED.darkened(0.12)), loop(Vector2(19, -4), 6, 1, s + 2, FIRED.darkened(0.12))])
			for k in 4:
				band_at(ci, prof, -14.0 + float(k) * 9.0, Color(DARK, 0.45), 1.4)
			for k in 3:
				ln(ci, Vector2(-7, -32.0 + float(k) * 2.6), Vector2(7, -30.0 + float(k) * 2.6), 1.8, ROPE, s + k)
		7:
			## 双耳罐
			var prof := [Vector2(14, -32), Vector2(16, -26), Vector2(30, -8), Vector2(30, 12), Vector2(18, 34)]
			vessel(ci, prof, FIRED, s, rim, [loop(Vector2(-30, -6), 9, -1, s + 1, FIRED.darkened(0.06)), loop(Vector2(30, -6), 9, 1, s + 2, FIRED.darkened(0.06))])
			band_at(ci, prof, -14, CLAY.darkened(0.25))
			band_at(ci, prof, 18, CLAY.darkened(0.25))
		8:
			## 陶壶
			var prof := [Vector2(10, -34), Vector2(12, -24), Vector2(28, -4), Vector2(28, 16), Vector2(16, 34)]
			vessel(ci, prof, FIRED, s, rim, [pg([Vector2(-18, -18), Vector2(-40, -32), Vector2(-36, -24), Vector2(-24, -8)], s + 1, FIRED.darkened(0.04)),
				band(Vector2(30, -6), 14, 3.2, -PI * 0.6, PI * 0.45, s + 2, FIRED.darkened(0.08))])
			zig_at(ci, prof, 0, 3, 8, CLAY.darkened(0.25))
		9:
			## 三足鼎：开始上黑白彩
			var prof := [Vector2(34, -18), Vector2(32, -4), Vector2(24, 12), Vector2(10, 18)]
			vessel(ci, prof, FIRED.darkened(0.06), s, rim, [stk(Vector2(-18, 8), Vector2(-24, 40), 4.5, s + 1, FIRED.darkened(0.2)),
				stk(Vector2(18, 8), Vector2(24, 40), 4.5, s + 2, FIRED.darkened(0.2)), stk(Vector2(0, 10), Vector2(0, 38), 4.5, s + 3, FIRED.darkened(0.28)),
				bx(-30, -30, 8, 14, 3, s + 4, FIRED.darkened(0.1)), bx(22, -30, 8, 14, 3, s + 5, FIRED.darkened(0.1))])
			band_at(ci, prof, -12, DARK, 3.0)
			zig_at(ci, prof, -4, 2.6, 10, DARK)
			dots_at(ci, prof, 6, 6, 1.8, WHITE_P)
		10:
			## 陶甑：上甑下釜蒸饭，甑身一圈黑带白点
			var low := [Vector2(20, 4), Vector2(30, 16), Vector2(26, 30), Vector2(14, 38)]
			var up := [Vector2(28, -30), Vector2(26, -12), Vector2(18, 4)]
			vessel(ci, low, FIRED.darkened(0.08), s, rim, [], false)
			vessel(ci, up, RED_P, s + 1, rim)
			band_at(ci, up, -16, DARK, 5.0)
			dots_at(ci, up, -16, 6, 1.6, WHITE_P)
			band_at(ci, low, 22, DARK, 2.4)
			for k in 5:
				ci.draw_circle(Vector2(-14.0 + float(k) * 7.0, -4), 2.0, HOLE)
			steam(ci, Vector2(0, -36), 3, 16)
		11:
			## 大陶缸：红陶大缸，黑白两道宽彩带
			var prof := [Vector2(32, -36), Vector2(36, -28), Vector2(42, -6), Vector2(40, 16), Vector2(28, 36)]
			vessel(ci, prof, RED_P, s, rim)
			band_at(ci, prof, -24, DARK, 5.0)
			band_at(ci, prof, -18, WHITE_P, 2.4)
			for k in 6:
				ci.draw_arc(Vector2(-28.0 + float(k) * 11.0, 2), 5, 0.0, PI, 6, DARK, 2.4, true)
			band_at(ci, prof, 18, WHITE_P, 2.4)
			band_at(ci, prof, 24, DARK, 5.0)
			hl(ci, Vector2(-26, -6), 4, 10, 0.2, 0.35)
		12:
			## 人面鱼纹盆：宽口大盆，盆里画着戴尖帽的人面，两边衔着鱼
			var prof := [Vector2(50, -16), Vector2(46, 4), Vector2(32, 24), Vector2(18, 32)]
			vessel(ci, prof, PAINT, s, rim)
			band_at(ci, prof, -6, DARK, 3.0)
			var c := Vector2(-8, 13)
			ci.draw_circle(c, 13, DARK)
			ci.draw_circle(c, 10.5, PAINT)
			ci.draw_colored_polygon(poly([c + Vector2(-9, -6), c + Vector2(0, -20), c + Vector2(9, -6)], s), DARK)
			ln(ci, c + Vector2(-6, -1), c + Vector2(-2, -1), 2.0, DARK, s)
			ln(ci, c + Vector2(2, -1), c + Vector2(6, -1), 2.0, DARK, s + 1)
			ci.draw_colored_polygon(poly([c + Vector2(-3, 4), c + Vector2(3, 4), c + Vector2(0, 7)], s), DARK)
			for sd in [-1.0, 1.0]:
				var f: float = sd
				ci.draw_colored_polygon(poly([c + Vector2(f * 9, -2), c + Vector2(f * 20, -6), c + Vector2(f * 26, -2), c + Vector2(f * 20, 2), c + Vector2(f * 9, 2)], s), DARK)
				ci.draw_colored_polygon(poly([c + Vector2(f * 26, -2), c + Vector2(f * 31, -7), c + Vector2(f * 31, 3)], s + 1), DARK)
			var fish := [Vector2(14, 22), Vector2(26, 15), Vector2(38, 18), Vector2(44, 13), Vector2(43, 23), Vector2(38, 21), Vector2(26, 26)]
			ci.draw_colored_polygon(poly(fish, s), DARK)
			ci.draw_circle(Vector2(22, 20), 1.4, WHITE_P)
			zig_at(ci, prof, 4, 2.0, 14, WHITE_P, 1.6)
		13:
			## 彩陶罐：橙红底，黑色漩涡纹，白色描边
			var prof := [Vector2(14, -34), Vector2(16, -28), Vector2(32, -10), Vector2(32, 10), Vector2(18, 34)]
			vessel(ci, prof, PAINT, s, rim)
			band_at(ci, prof, -22, RED_P, 4.0)
			zig_at(ci, prof, -26, 2.4, 6, DARK)
			spiral_at(ci, Vector2(-14, -8), 10, WHITE_P, 4.2)
			spiral_at(ci, Vector2(-14, -8), 10, DARK)
			spiral_at(ci, Vector2(12, -10), 10, WHITE_P, 4.2)
			spiral_at(ci, Vector2(12, -10), 10, DARK)
			ci.draw_circle(Vector2(-1, 6), 3, RED_P)
			band_at(ci, prof, 14, DARK, 3.0)
			zig_at(ci, prof, 22, 3, 8, DARK)
		_:
			## 彩陶大瓮：最大的一只，红黑白三色满身彩绘
			var prof := [Vector2(16, -44), Vector2(18, -36), Vector2(42, -14), Vector2(42, 10), Vector2(22, 40)]
			vessel(ci, prof, PAINT, s, rim, [loop(Vector2(-36, 8), 7, -1, s + 1, PAINT.darkened(0.12)), loop(Vector2(36, 8), 7, 1, s + 2, PAINT.darkened(0.12))])
			zig_at(ci, prof, -32, 2.4, 6, DARK)
			band_at(ci, prof, -24, RED_P, 5.0)
			band_at(ci, prof, -20, WHITE_P, 2.0)
			spiral_at(ci, Vector2(-20, -4), 11, WHITE_P, 4.4)
			spiral_at(ci, Vector2(-20, -4), 11, DARK)
			spiral_at(ci, Vector2(8, -6), 11, WHITE_P, 4.4)
			spiral_at(ci, Vector2(8, -6), 11, DARK)
			ci.draw_circle(Vector2(28, -4), 4, RED_P)
			ci.draw_circle(Vector2(28, -4), 1.6, WHITE_P)
			zig_at(ci, prof, 16, 3, 10, DARK)
			band_at(ci, prof, 26, RED_P, 4.0)
			dots_at(ci, prof, 32, 6, 1.6, WHITE_P)

## 副产物：陶工艺品 ----------------------------------------------------------
static func _sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 陶珠
			var pts := arcp(Vector2(0, -16), Vector2(28, 38), PI * 0.15, PI * 0.85, 4)
			ci.draw_arc(Vector2(0, -16), 28, PI * 0.08, PI * 0.92, 14, INK, 3.0, true)
			var parts := []
			for i in pts.size():
				parts.append(circ(pts[i], 8, s + i, FIRED if i % 2 == 0 else PAINT))
			sil(ci, parts, rim)
			for p in pts:
				ci.draw_circle(p, 2.0, DARK)
		2:
			## 陶哨
			sil(ci, [ov(Vector2(4, 4), 28, 14, s, FIRED, -0.2), bx(-38, 0, 18, 12, 4, s + 1, FIRED.darkened(0.08))], rim)
			ci.draw_circle(Vector2(6, 0), 3.6, DARK)
			ci.draw_arc(Vector2(-40, 6), 12, PI * 0.5, PI * 1.3, 8, ROPE, 2.4, true)
		3:
			## 陶纺轮
			sil(ci, [stk(Vector2(0, -42), Vector2(0, 40), 2.6, s, WOOD, 2), ov(Vector2(0, 8), 30, 10, s + 1, FIRED, 0.0, 1),
				pg(arcp(Vector2(0, 8), Vector2(30, 10), 0.0, PI, 10) + [Vector2(-30, 4), Vector2(30, 4)], s + 2, FIRED.darkened(0.1))], rim)
			ci.draw_colored_polygon(ell(Vector2(0, 6), Vector2(26, 7), s, 0.0, 14), FIRED)
			ci.draw_circle(Vector2(0, 6), 4, WOOD)
			zig(ci, -24, 24, 6, 2.0, 10, DARK, 1.6, s)
			pl(ci, [Vector2(0, -42), Vector2(10, -36), Vector2(-6, -28), Vector2(8, -20)], 1.6, ROPE, s)
		4:
			## 陶埙
			sil(ci, [ov(Vector2(0, 6), 24, 30, s, DARK.lightened(0.15))], rim)
			ci.draw_circle(Vector2(0, -22), 3.6, INK)
			for p in [Vector2(-10, 2), Vector2(10, 2), Vector2(-6, 16), Vector2(6, 16)]:
				ci.draw_circle(p, 3.0, INK)
			zig(ci, -18, 18, -8, 2.0, 8, CLAY, 1.6, s)
		5:
			## 陶响球：空心陶球，里面装着小石子，一摇沙沙响
			sil(ci, [circ(Vector2(0, 6), 26, s, FIRED)], rim)
			zig(ci, -23, 23, 6, 3.4, 8, DARK, 2.2, s)
			for p in [Vector2(-10, -9), Vector2(5, -12), Vector2(15, -2), Vector2(-15, 19), Vector2(1, 22), Vector2(16, 16)]:
				ci.draw_circle(p, 2.8, HOLE)
			ci.draw_circle(Vector2(5, -12), 1.2, STONE)
			hl(ci, Vector2(-12, -4), 5, 3, -0.6, 0.45)
			for k in 3:
				var r := 32.0 + float(k) * 5.0
				ci.draw_arc(Vector2(0, 6), r, -0.35, 0.35, 5, Color(INK, 0.45), 1.8, true)
				ci.draw_arc(Vector2(0, 6), r, PI - 0.35, PI + 0.35, 5, Color(INK, 0.45), 1.8, true)
		6:
			## 陶龟：拱背陶龟，龟甲刻着六边格
			sil(ci, [stk(Vector2(-20, 22), Vector2(-24, 32), 5.0, s, FIRED.darkened(0.12)), stk(Vector2(18, 22), Vector2(22, 32), 5.0, s + 1, FIRED.darkened(0.12)),
				pg([Vector2(-32, 20), Vector2(-42, 26), Vector2(-30, 26)], s + 2, FIRED.darkened(0.1)),
				stk(Vector2(26, 16), Vector2(36, 8), 5.0, s + 3, FIRED.darkened(0.06)), circ(Vector2(39, 6), 9, s + 4, FIRED.darkened(0.04)),
				pg(arcp(Vector2(0, 24), Vector2(34, 30), PI, TAU, 16), s + 5, FIRED, 0)], rim)
			ln(ci, Vector2(-33, 22), Vector2(33, 22), 3.0, FIRED.darkened(0.25), s)
			for c in [Vector2(-14, 12), Vector2(0, 2), Vector2(14, 12)]:
				var hx := []
				for k in 7:
					var a := float(k) / 6.0 * TAU
					hx.append(c + Vector2(cos(a) * 7.5, sin(a) * 6.5))
				ci.draw_polyline(PackedVector2Array(hx), DARK, 2.0, true)
			ci.draw_circle(Vector2(42, 3), 2.0, INK)
			ln(ci, Vector2(41, 10), Vector2(46, 9), 1.4, INK, s)
		7:
			## 陶猪
			sil(ci, [ov(Vector2(4, 8), 32, 20, s, FIRED), circ(Vector2(-28, 2), 14, s + 1, FIRED),
				ov(Vector2(-40, 6), 6, 7, s + 2, FIRED.darkened(0.08)), pg([Vector2(-26, -10), Vector2(-20, -22), Vector2(-16, -8)], s + 3, FIRED.darkened(0.05)),
				stk(Vector2(-10, 22), Vector2(-12, 34), 4.0, s + 4, FIRED.darkened(0.1)), stk(Vector2(20, 22), Vector2(22, 34), 4.0, s + 5, FIRED.darkened(0.1))], rim)
			ci.draw_circle(Vector2(-42, 4), 1.6, INK)
			ci.draw_circle(Vector2(-42, 9), 1.6, INK)
			ci.draw_circle(Vector2(-28, -2), 2.4, INK)
			spiral_at(ci, Vector2(8, 6), 9, DARK)
		8:
			## 陶灯：带捏嘴的浅油灯，下面一根短柱，灯芯上跳着火苗
			var prof := [Vector2(28, -2), Vector2(25, 9), Vector2(10, 16)]
			glow(ci, Vector2(40, -20), 20, Color(1.0, 0.75, 0.3))
			sil(ci, [ov(Vector2(0, 34), 18, 6, s, FIRED.darkened(0.12), 0.0, 1), stk(Vector2(0, 14), Vector2(0, 32), 6.0, s + 1, FIRED.darkened(0.06)),
				pg(lathe(prof), s + 2, FIRED, 0), pg([Vector2(20, -6), Vector2(42, -11), Vector2(42, -3), Vector2(22, 6)], s + 3, FIRED.darkened(0.04)),
				band(Vector2(-30, 4), 8, 2.8, PI * 0.5, PI * 1.5, s + 4, FIRED.darkened(0.08))], rim)
			var oil := ell(Vector2(0, -2), Vector2(26, 5), s, 0.0, 16)
			ci.draw_colored_polygon(oil, Color("7a4a1c"))
			outline(ci, oil, 1.6)
			ln(ci, Vector2(26, -4), Vector2(41, -8), 2.4, ROPE, s)
			flame(ci, Vector2(41, -10), 7, 24, s + 5)
			band_at(ci, prof, 8, DARK, 2.2)
		9:
			## 陶塑人头像：短颈接在罐肩上的人头，刘海齐额，眼睛和嘴都是镂空的
			sil(ci, [pg(lathe([Vector2(10, 14), Vector2(26, 26), Vector2(30, 36), Vector2(24, 42)]), s, RED_P, 0),
				stk(Vector2(0, 2), Vector2(0, 18), 9.0, s + 1, FIRED),
				ov(Vector2(-21, -14), 4, 7, s + 2, FIRED.darkened(0.06), 0.0, 1), ov(Vector2(21, -14), 4, 7, s + 3, FIRED.darkened(0.06), 0.0, 1),
				ov(Vector2(0, -16), 20, 24, s + 4, FIRED, 0.0, 0)], rim)
			ci.draw_colored_polygon(poly([Vector2(-20, -22), Vector2(-17, -34), Vector2(-6, -40), Vector2(8, -40), Vector2(17, -34), Vector2(20, -22),
				Vector2(13, -28), Vector2(6, -24), Vector2(-1, -28), Vector2(-8, -24), Vector2(-14, -28)], s), DARK)
			for sd in [-1.0, 1.0]:
				var f: float = sd
				ci.draw_colored_polygon(ell(Vector2(f * 8.0, -14), Vector2(5, 2), s, 0.0, 10), HOLE)
				ci.draw_circle(Vector2(f * 21.0, -13), 1.6, HOLE)
			ci.draw_colored_polygon(poly([Vector2(0, -12), Vector2(-3.5, -3), Vector2(3.5, -3)], s), FIRED.darkened(0.18))
			ci.draw_colored_polygon(ell(Vector2(0, 2), Vector2(4, 2.4), s, 0.0, 10), HOLE)
			zig(ci, -24, 24, 30, 3, 8, DARK, 2.2, s)
			for k in 5:
				ci.draw_circle(Vector2(-16.0 + float(k) * 8.0, 37), 1.6, WHITE_P)
		10:
			## 鹰形陶鼎
			sil(ci, [stk(Vector2(-12, 22), Vector2(-16, 42), 5.0, s, FIRED.darkened(0.12)), stk(Vector2(12, 22), Vector2(16, 42), 5.0, s + 1, FIRED.darkened(0.12)),
				pg([Vector2(16, 12), Vector2(36, 34), Vector2(26, 38), Vector2(12, 22)], s + 2, FIRED.darkened(0.08)),
				ov(Vector2(2, 6), 26, 24, s + 3, FIRED), circ(Vector2(-14, -24), 13, s + 4, FIRED),
				pg([Vector2(-26, -24), Vector2(-40, -18), Vector2(-28, -14), Vector2(-24, -18)], s + 5, DARK.lightened(0.2)),
				pg([Vector2(-6, -30), Vector2(10, -36), Vector2(10, -24)], s + 6, FIRED.darkened(0.06))], rim)
			ci.draw_circle(Vector2(-16, -28), 3.0, INK)
			ci.draw_circle(Vector2(-16, -28), 1.2, Color.WHITE)
			for k in 3:
				ci.draw_arc(Vector2(10, 4), 6.0 + float(k) * 6.0, PI * 1.2, PI * 1.9, 6, Color(DARK, 0.6), 2.0, true)
		_:
			## 大地母神像：放大一圈，丰满的陶塑女神，胸前挂琥珀，身上彩绘
			var q := 1.28
			sil(ci, [ov(Vector2(0, 12) * q, 26 * q, 26 * q, s, FIRED), ov(Vector2(-14, -4) * q, 11 * q, 12 * q, s + 1, FIRED.darkened(0.04)),
				ov(Vector2(14, -4) * q, 11 * q, 12 * q, s + 2, FIRED.darkened(0.04)), ov(Vector2(0, -22) * q, 12 * q, 9 * q, s + 3, FIRED),
				circ(Vector2(0, -35) * q, 9 * q, s + 4, FIRED), ov(Vector2(0, 36) * q, 15 * q, 5 * q, s + 5, FIRED.darkened(0.1))], rim)
			ln(ci, Vector2(-16, 4) * q, Vector2(16, 4) * q, 2.4, Color(DARK, 0.6), s)
			ci.draw_arc(Vector2(0, -35) * q, 9.0 * q, PI * 1.1, PI * 1.9, 8, DARK, 3.0, true)
			zig(ci, -20 * q, 20 * q, 22 * q, 3, 8, DARK, 2.2, s)
			ln(ci, Vector2(-18, 28) * q, Vector2(18, 28) * q, 2.4, WHITE_P, s)
			pl(ci, [Vector2(-10, -20) * q, Vector2(0, -12) * q, Vector2(10, -20) * q], 1.8, ROPE, s)
			for k in 3:
				ci.draw_circle(Vector2(-6.0 + float(k) * 6.0, -14 + absf(float(k) - 1.0) * -3.0) * q, 2.6, AMBER)
			ci.draw_circle(Vector2(-3, -36) * q, 1.6, INK)
			ci.draw_circle(Vector2(3, -36) * q, 1.6, INK)
