class_name EventEntryArt
extends RefCounted
## 棋盘任务栏的活动入口（香蕉竞速 / 月石遗迹 / 七日任务）：没有卡片底，底部对齐。
## 从下往上：一行活动名 → 状态小牌（数量 / 倒计时 / 领奖 / 锁）→ 程序手绘的主题图。
## 三张图画在同一个 100×100 的格子里、落在同一条地面线上，视觉分量一致。
##
## kind：race / ruins / seven，或一张贴图的 res:// 路径（以后别的合成活动用自己的图）。
## badge：{"text": "×12", "style": "num|time|go|lock|teal|gold|silver|bronze"}，空字典不画。
## dot：右上角红点（有奖可领）。bump：0~1，香蕉飞进来时图片弹一下。

const Banana := preload("res://scripts/ui/Banana.gd")

const PILL := {
	"num": [Color("fff3d2"), Color("6b3f1d")],
	"time": [Color("5a3a22"), Color("ffe9a4")],
	"go": [Color("7cc243"), Color.WHITE],
	"lock": [Color("9b958b"), Color.WHITE],
	"teal": [Color("4fa39a"), Color.WHITE],
	"gold": [Color("ffcf3f"), Color("6b3f1d")],
	"silver": [Color("dfe3e6"), Color("4a4f55")],
	"bronze": [Color("e09a5c"), Color("5a2e12")],
}

static var _grey := false

static func paint(ci: CanvasItem, sz: Vector2, kind: String, title: String, badge := {}, locked := false, dot := false, bump := 0.0) -> void:
	var ground := sz.y - 46.0
	var c := Vector2(sz.x * 0.5, ground)
	# 地面影子
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, -2), Vector2(44, 8), 3, 0.05, 18, 0.0, 0.3), Color(0.16, 0.1, 0.04, 0.28))
	var s := 1.08 * (1.0 + 0.12 * sin(bump * PI))
	ci.draw_set_transform(c, 0.0, Vector2(s, s))
	_grey = locked
	match kind:
		"duel":
			for side in 2:
				var x := -23.0 if side==0 else 23.0
				ci.draw_circle(Vector2(x,-55),29,Art.INK)
				ci.draw_circle(Vector2(x,-55),25,_c(Art.MOSS if side==0 else Art.CLAY))
				Paint.bust(ci,Vector2(x,-52),42)
			text(ci,"VS",Vector2(0,-12),24,Color("ffd23f"))
		"race": _race(ci)
		"ruins": _ruins(ci)
		"seven": _seven(ci)
		_:
			ci.draw_texture_rect(MergeEvent.texture(kind), Rect2(-50, -104, 100, 110), false, Color(.7, .7, .7) if locked else Color.WHITE)
	_grey = false
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if locked: Paint.glyph(ci, "lock", c + Vector2(0, -50), .7)
	if dot: Paint.badge_num(ci, c + Vector2(42, -100), 8, 10)
	if not badge.is_empty(): _pill(ci, c + Vector2(0, 4), str(badge.get("text", "")), str(badge.get("style", "num")))
	text(ci, title, Vector2(sz.x * 0.5, sz.y - 8), 21, Color("fff0c5"))

static func text(ci: CanvasItem, s: String, center: Vector2, fs: int, color: Color, ol := 6) -> void:
	var f: Font = G.font_title
	var p := center - Vector2(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2, 0)
	ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Art.INK)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

## 状态小牌：压在图片脚下，宽度随字
static func _pill(ci: CanvasItem, c: Vector2, s: String, style: String) -> void:
	var cols: Array = PILL.get(style, PILL["num"])
	var f: Font = G.font_title
	var fs := 18
	var w := maxf(44.0, f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 20.0)
	var r := Rect2(c - Vector2(w * 0.5, 13), Vector2(w, 26))
	Art.fill(ci, Art.rrect(r, 13, 41, 0.5), cols[0], 3)
	if style in ["go", "gold", "teal"]:
		ci.draw_line(r.position + Vector2(10, 6), r.position + Vector2(w - 10, 6), Color(1, 1, 1, 0.45), 3, true)
	var p := Vector2(c.x - f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, c.y + 7)
	if style in ["go", "lock", "teal"]:
		ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Art.INK)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cols[1])

# ---------------------------------------------------------------- 三张主题图（原点 = 地面中点，往上画约 100）

static func _c(col: Color) -> Color:
	if not _grey: return col
	var l := col.get_luminance()
	return Color(l, l, l * 0.96, col.a).lerp(Color("8d877d"), 0.25)

static func _parts(ci: CanvasItem, parts: Array) -> void:
	for p in parts: p[1] = _c(p[1])
	Art.sil(ci, parts, true, 3.0)

## 香蕉竞速：一串香蕉靠着方格赛旗
static func _race(ci: CanvasItem) -> void:
	# 旗杆 + 方格旗
	var pole := Art.capsule(Vector2(-26, -4), Vector2(-26, -100), 3.5, 51)
	var flag := Art.poly([Vector2(-24, -98), Vector2(4, -103), Vector2(30, -96), Vector2(28, -70), Vector2(2, -76), Vector2(-24, -72)], 52, 0.6)
	_parts(ci, [Art.P(pole, Color("8a5a2b"), 1), Art.P(flag, Color("fff7e6"), 2)])
	# 格子：两行四列，跟着旗面的上下边插值
	var top := [Vector2(-24, -98), Vector2(4, -103), Vector2(30, -96)]
	var bot := [Vector2(-24, -72), Vector2(2, -76), Vector2(28, -70)]
	for col in 4:
		for row in 2:
			if (col + row) % 2 == 1: continue
			var q := PackedVector2Array()
			for corner in [[col, row], [col + 1, row], [col + 1, row + 1], [col, row + 1]]:
				var u := float(corner[0]) / 4.0
				var a := _along(top, u)
				var b := _along(bot, u)
				q.append(a.lerp(b, float(corner[1]) / 2.0))
			ci.draw_colored_polygon(q, _c(Color("3b2314")))
	Art.outline(ci, flag, 2.6, Art.INK)
	Art.dot(ci, Vector2(-26, -102), 5.5, Art.INK)
	Art.dot(ci, Vector2(-26, -102), 3.5, _c(Art.OCHRE))
	# 香蕉串：三根同向弯（都往左鼓）的香蕉，下端汇到同一个果柄，上端像扇子一样散开
	var stem := Vector2(4, -12)
	var bunch := []
	for t in [-0.5, 0.42, -0.04]:
		var rot: float = PI * 0.5 + t
		bunch.append([rot, stem - Vector2(0.43 * 60.0, 0.6).rotated(rot)])
	for k in bunch:
		Art.dilate(ci, _banana(k[1], 60.0, k[0]), 7.0, Color(1, 0.98, 0.92, 0.96))
	for k in bunch:
		if _grey:
			Art.fill(ci, _banana(k[1], 60.0, k[0]), _c(Color("ffd84a")), 3)
		else:
			Banana.draw(ci, k[1], 60.0, k[0])
	var knob := Art.capsule(stem + Vector2(-2, 6), stem + Vector2(0, -4), 6.5, 53)
	Art.fill(ci, knob, _c(Color("6b4a2a")), 3)

## 和 Banana.draw 同一个形状，只要轮廓（描白边、置灰用）
static func _banana(c: Vector2, s: float, rot: float) -> PackedVector2Array:
	var body := PackedVector2Array()
	var inner: Array = []
	for i in 13:
		var u := float(i) / 12.0
		var a := lerpf(-1.05, 1.05, u)
		body.append(c + Vector2(sin(a) * s * 0.5, cos(a) * s * 0.34 - s * 0.16).rotated(rot))
		inner.append(c + Vector2(sin(a) * s * 0.46, cos(a) * s * 0.34 - s * 0.16 - sin(u * PI) * s * 0.32).rotated(rot))
	inner.reverse()
	for q in inner: body.append(q)
	return body

static func _along(pts: Array, u: float) -> Vector2:
	var t := u * (pts.size() - 1)
	var i := mini(int(t), pts.size() - 2)
	return (pts[i] as Vector2).lerp(pts[i + 1], t - i)

## 月石遗迹：长苔的石门，门洞里浮着发光的月牙石
static func _ruins(ci: CanvasItem) -> void:
	# 门洞里的幽光
	var hole := Art.poly([Vector2(-20, 0), Vector2(-20, -60), Vector2(-10, -72), Vector2(10, -72), Vector2(20, -60), Vector2(20, 0)], 71, 0.6)
	Art.fill(ci, hole, _c(Color("21434a")), 0)
	if not _grey:
		for k in 4:
			ci.draw_colored_polygon(Art.ell(Vector2(0, -40), Vector2(30 - k * 6, 34 - k * 7), 72, 0.0, 18, 0.0, 0.0), Color(0.5, 1.0, 0.92, 0.10 + k * 0.05))
	# 两根石柱 + 横梁 + 顶石
	var lp := Art.poly([Vector2(-40, 0), Vector2(-42, -72), Vector2(-20, -74), Vector2(-19, 0)], 73, 0.9)
	var rp := Art.poly([Vector2(19, 0), Vector2(20, -74), Vector2(42, -72), Vector2(40, 0)], 74, 0.9)
	var beam := Art.poly([Vector2(-50, -70), Vector2(-46, -88), Vector2(46, -90), Vector2(51, -70)], 75, 0.9)
	var cap := Art.poly([Vector2(-22, -88), Vector2(-14, -100), Vector2(14, -101), Vector2(22, -89)], 76, 0.9)
	_parts(ci, [Art.P(lp, Color("a9a39a"), 1), Art.P(rp, Color("9d978d"), 1), Art.P(beam, Color("b7b1a6"), 1), Art.P(cap, Color("c4beb2"), 1)])
	# 石缝
	for seg in [[Vector2(-38, -46), Vector2(-22, -48)], [Vector2(22, -30), Vector2(38, -28)], [Vector2(-40, -20), Vector2(-28, -18)], [Vector2(-10, -80), Vector2(-4, -88)], [Vector2(24, -78), Vector2(30, -86)]]:
		Art.ln(ci, seg[0], seg[1], 2.2, Art.INK, 77)
	# 苔藓
	for m in [[Vector2(-30, -88), 13.0], [Vector2(36, -70), 10.0], [Vector2(-40, -6), 11.0], [Vector2(38, -4), 9.0]]:
		var moss := Art.ell(m[0], Vector2(m[1], m[1] * 0.55), 78 + int(m[1]), 0.18, 12, 0.0, 0.6)
		Art.fill(ci, moss, _c(Art.LEAF), 2.4)
	# 月牙石：外发光 + 双色月牙 + 两颗小星
	var mc := Vector2(0, -40)
	if not _grey:
		ci.draw_circle(mc, 22, Color(0.55, 1.0, 0.93, 0.25))
	var cres := Geometry2D.clip_polygons(Art.ell(mc, Vector2(18, 18), 85, 0.03, 24), Art.ell(mc + Vector2(9, -7), Vector2(15, 15), 86, 0.0, 24, 0.0, 0.0))
	var moon: PackedVector2Array = cres[0] if not cres.is_empty() else Art.ell(mc, Vector2(12, 12), 85)
	Art.sil(ci, [Art.P(moon, _c(Color("8ff5e6")), 0)], false, 3.0)
	if not _grey:
		Art.fill(ci, Art.star_pts(mc + Vector2(14, -18), 5, 2, 4, 79), Color("fffbe0"), 1.6)
		Art.fill(ci, Art.star_pts(mc + Vector2(-13, 15), 4, 1.6, 4, 80), Color("fffbe0"), 1.4)

## 七日任务：系着皮绳的石板日历，刻着大大的 7，两边是计日刻痕
static func _seven(ci: CanvasItem) -> void:
	var slab := Art.rrect(Rect2(-40, -94, 80, 92), 14, 81, 1.1, 30)
	var strap := Art.poly([Vector2(-44, -84), Vector2(44, -86), Vector2(44, -70), Vector2(-44, -68)], 82, 0.7)
	_parts(ci, [Art.P(slab, Color("b4aea2"), 0), Art.P(strap, Color("b0682e"), 1)])
	# 皮绳上的两个骨扣
	for x in [-26.0, 26.0]:
		Art.fill(ci, Art.ell(Vector2(x, -77), Vector2(7, 5), 83, 0.08, 10), _c(Art.BONE), 2.4)
	# 大 7（凹刻：深色描边 + 赭红填色），居中
	var f: Font = G.font_title
	var fs := 58
	var w := f.get_string_size("7", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(-w * 0.5 - 2, -14)
	ci.draw_string_outline(f, p + Vector2(1, 2), "7", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.18, 0.12, 0.08, 0.55))
	ci.draw_string_outline(f, p, "7", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Art.INK)
	ci.draw_string(f, p, "7", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _c(Color("d2512d")))
	# 两边各三道计日刻痕
	for k in 3:
		Art.ln(ci, Vector2(-31, -58 + k * 12), Vector2(-21, -58 + k * 12), 3.0, Color(0.23, 0.14, 0.08, 0.75), 84 + k)
		Art.ln(ci, Vector2(21, -58 + k * 12), Vector2(31, -58 + k * 12), 3.0, Color(0.23, 0.14, 0.08, 0.75), 88 + k)
	# 底下一丛草
	for g in [[-38.0, 1.0], [-30.0, -1.0], [40.0, 1.0]]:
		var x: float = g[0]
		Art.fill(ci, Art.poly([Vector2(x - 6, 0), Vector2(x - 4 * g[1], -14), Vector2(x, -4), Vector2(x + 3, -16), Vector2(x + 7, 0)], 98 + int(x), 0.5), _c(Art.LEAF_D), 2.2)
