extends RefCounted
## 「兄弟，我发现……」原始人梗。
## 头直接用梗图原图抠出来的贴纸（tools/bake_meme.gd 生成，歪歪扭扭的白边），
## 上面再叠卡通画风的帽子、墨镜、衣服，故意保留网友 P 图那种拼贴的违和感。
## 角色下标和 data/people.json 对应：同一张脸，靠贴上去的装饰扮演不同的人。
## 头部局部坐标：1 单位 = 原图 6 像素，原点在脸中心；头宽约 100（耳朵到耳朵）。
## 眼睛约在 (±17, -9)，眉毛 y=-14，鼻底 y=16，嘴 y=34，下巴 y=53，头顶 y=-53。

const HEAD_TEX := preload("res://assets/meme/caveman_head.png")
const BUST_TEX := preload("res://assets/meme/caveman_bust.png")
## 两张贴纸在头部局部坐标里占的位置（由 bake_meme.gd 的裁切框换算）
const HEAD_RECT := Rect2(-53.67, -57.83, 107.67, 117.0)
const BUST_RECT := Rect2(-70.33, -57.83, 140.0, 150.0)
## 每个角色的头歪多少（弧度）：P 图没摆正
const TILT := [-0.05, 0.06, -0.03, 0.08, -0.07, 0.04, -0.06, 0.05, -0.04, 0.07]
## people.json 之外的两个角色：主角阿焰、小牙（原来的剑齿虎，现在是披着虎皮帽的族人）
const HERO := 8
const XIAOYA := 9
## 每个角色的身子颜色（兽皮）
const BODY := [Color("9c5a2a"), Color("6e8a3a"), Color("8a4b2a"), Color("d88aa0"), Color("e9e2d0"), Color("c98a4a"), Color("3d5a8a"), Color("6b4a8a"), Color("b0472a"), Color("d98a3a")]

## 装饰和衣服统一压暗、去饱和，和黑白照片放在一起不刺眼
static func _m(c: Color) -> Color:
	var o := Color.from_hsv(c.h, c.s * 0.22, lerpf(c.v, 0.55, 0.25), c.a)
	return o.lerp(Color(0.62, 0.55, 0.46, c.a), 0.12)

## 兄弟我发现：[台词, 需要哪个区域开工过（"" 表示一直有）]
const LINES := [
	["兄弟，我发现两个一样的东西放一起，会变成一个更好的。", ""],
	["兄弟，我发现野兽对尖尖的石头过敏。", ""],
	["兄弟，我发现酋长分的肉，总是比我们的多。", ""],
	["兄弟，我发现贝壳能换肉，肉换不回贝壳。", ""],
	["兄弟，我发现在藤蔓旁边合一下，藤蔓就断了。", ""],
	["兄弟，我发现集市的货，总是刚好差我一件。", ""],
	["兄弟，我发现小牙好像不是猫。", ""],
	["兄弟，我发现我们好像住在一个格子里。", ""],
	["兄弟，我发现火苗用完了，就该睡觉了。", ""],
	["兄弟，我发现大家站在一起，就不害怕了。", ""],
	["兄弟，我发现我对石头过敏，头一碰石头就睡着了。", ""],
	["兄弟，其实我什么也没发现。", ""],
	["兄弟，我发现两块石头撞一下会亮，放点干草还能一直亮。", "fire"],
	["兄弟，我发现肉在火上烤过，就不咬我肚子了。", "fire"],
	["兄弟，我发现吃不完的种子扔地上，过几个月又长出来了。", "gather"],
	["兄弟，我发现拿石头敲石头，尖的那边能划开树皮。", "stone"],
	["兄弟，我发现草编起来能装东西，装满了还能再编一个。", "weave"],
	["兄弟，我发现把尖石头绑在木棍上，不用凑过去就能戳到野猪。", "hunt"],
	["兄弟，我发现肉和果子一起煮，比分开吃香。", "cook"],
	["兄弟，我发现这种木头能在水上漂，能漂到河对岸去。", "wood"],
	["兄弟，我发现泥巴烧过之后会变硬，还能装水。", "kiln"],
]

static var _line_bag: Array = []

## 随机一句当前能说的（按区域开工情况过滤；洗牌发完再洗，不会连着重复）
static func line() -> String:
	if _line_bag.is_empty():
		for row in LINES:
			var need := str(row[1])
			if need == "" or int(G.builds.get(need, 0)) > 0:
				_line_bag.append(str(row[0]))
		_line_bag.shuffle()
	if _line_bag.is_empty():
		return str(LINES[0][0])
	return str(_line_bag.pop_back())

# ---------------------------------------------------------------- 照片头

## 在 c 处画照片大头。w 是头宽（像素，耳朵到耳朵）。
static func head(ci: CanvasItem, c: Vector2, w: float, rot: float = 0.0) -> void:
	_photo(ci, HEAD_TEX, HEAD_RECT, c, w, rot)

## 在 c 处画照片半身（头 + 肩膀），c 和 w 同 head()。
static func bust(ci: CanvasItem, c: Vector2, w: float, rot: float = 0.0) -> void:
	_photo(ci, BUST_TEX, BUST_RECT, c, w, rot)

static func _photo(ci: CanvasItem, tex: Texture2D, r: Rect2, c: Vector2, w: float, rot: float) -> void:
	ci.draw_set_transform(c, rot, Vector2.ONE * (w / 100.0))
	ci.draw_texture_rect(tex, r, false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- 装饰（贴纸）

## 头后面的装饰（羽冠、鹿角）
static func props_back(ci: CanvasItem, role: int, c: Vector2, w: float, rot: float) -> void:
	ci.draw_set_transform(c, rot, Vector2.ONE * (w / 100.0))
	match role:
		0:
			var cols := [_m(Art.CLAY), _m(Art.OCHRE), _m(Art.BONE), _m(Art.TEAL), _m(Art.OCHRE), _m(Art.CLAY), _m(Art.BONE)]
			var parts := []
			for i in 7:
				var a := -PI * 0.5 + (float(i) - 3.0) * 0.3
				parts.append(Art.P(Art.ell(Vector2(0, -30) + Vector2(cos(a), sin(a)) * 50.0, Vector2(10, 26), 20 + i, 0.03, 14, a + PI * 0.5), cols[i], 1))
			Art.sil(ci, parts, true)
		1:
			for sx in [-1.0, 1.0]:
				var base := Vector2(30 * sx, -42)
				var tip := Vector2(56 * sx, -92)
				var parts := [Art.P(Art.capsule(base, tip, 5.0, 30), _m(Art.BONE), 1),
					Art.P(Art.capsule(base.lerp(tip, 0.45), Vector2(76 * sx, -70), 4.0, 31), _m(Art.BONE), 1),
					Art.P(Art.capsule(base.lerp(tip, 0.7), Vector2(34 * sx, -96), 3.5, 32), _m(Art.BONE), 1)]
				Art.sil(ci, parts, true)
		HERO:
			# 阿焰：两根垂到肩上的粗辫子
			for sx in [-1.0, 1.0]:
				var parts := []
				for k in 5:
					parts.append(Art.P(Art.ell(Vector2(46 * sx, -6 + k * 13), Vector2(9, 9), 220 + k, 0.06, 12), _m(Color("3a2414")), 1))
				Art.sil(ci, parts, true, 2.0)
		XIAOYA:
			# 小牙：虎皮帽的后半截和两只耳朵
			var fur := _m(Color("e08a34"))
			Art.sil(ci, [Art.P(Art.ell(Vector2(0, -22), Vector2(60, 50), 230, 0.04, 20), fur, 1),
				Art.P(Art.poly([Vector2(-48, -50), Vector2(-40, -84), Vector2(-18, -60)], 231), fur, 1),
				Art.P(Art.poly([Vector2(48, -50), Vector2(40, -84), Vector2(18, -60)], 232), fur, 1)], true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 贴在脸上的装饰
static func props_front(ci: CanvasItem, role: int, c: Vector2, w: float, rot: float) -> void:
	ci.draw_set_transform(c, rot, Vector2.ONE * (w / 100.0))
	match role:
		0:
			# 酋长：额头一道红泥 + 鼻子上的骨头
			Art.sil(ci, [Art.P(Art.capsule(Vector2(-30, -26), Vector2(30, -26), 4.0, 40), _m(Art.CLAY), 1)], true, 2.0)
		1:
			# 巫医：叶子花环 + 脸上的白点彩绘
			var parts := []
			for i in 7:
				var a := PI + float(i) / 6.0 * PI
				parts.append(Art.P(Art.ell(Vector2(cos(a) * 40.0, -36 + sin(a) * 14.0), Vector2(11, 6), 50 + i, 0.05, 12, a + 0.6), _m(Art.LEAF), 1))
			parts.append(Art.P(Art.ell(Vector2(0, -52), Vector2(8, 8), 58, 0.04, 12), _m(Color("f2a7c0")), 1))
			Art.sil(ci, parts, true, 2.0)
			for sx in [-1.0, 1.0]:
				for k in 3:
					ci.draw_circle(Vector2(30 * sx, 14 + k * 6), 2.6, _m(Color("fff5e0")))
		2:
			# 猎手：兽牙头带 + 像素墨镜
			Art.sil(ci, [Art.P(Art.capsule(Vector2(-42, -30), Vector2(42, -30), 5.0, 60), _m(Art.TEAL), 1),
				Art.P(Art.poly([Vector2(-5, -27), Vector2(5, -27), Vector2(0, -12)], 61), _m(Art.BONE), 2)], true, 2.0)
			_pixel_shades(ci, Vector2(0, -9))
		3:
			# 小不点：粉蝴蝶结 + 奶嘴 + 腮红贴纸
			for sx in [-1.0, 1.0]:
				ci.draw_circle(Vector2(32 * sx, 18), 9.0, _m(Color(1, 0.45, 0.55, 0.45)))
			var bow := Vector2(26, -48)
			Art.sil(ci, [Art.P(Art.poly([bow, bow + Vector2(-22, -14), bow + Vector2(-20, 12)], 70), _m(Color("ff7fa8")), 1),
				Art.P(Art.poly([bow, bow + Vector2(22, -14), bow + Vector2(20, 12)], 71), _m(Color("ff7fa8")), 1),
				Art.P(Art.ell(bow, Vector2(6, 6), 72, 0.03, 10), _m(Color("ff4f86")), 1)], true, 2.0)
			Art.sil(ci, [Art.P(Art.ell(Vector2(0, 34), Vector2(16, 9), 73, 0.03, 14), _m(Color("8fd3e8")), 1),
				Art.P(Art.ell(Vector2(0, 40), Vector2(7, 7), 74, 0.03, 12), _m(Color("ff9fc0")), 1)], true, 2.0)
		4:
			# 厨子：高高的白厨师帽 + 八字胡
			Art.sil(ci, [Art.P(Art.rrect(Rect2(-30, -64, 60, 22), 6, 80, 0.4), _m(Color("fffaf0")), 1),
				Art.P(Art.ell(Vector2(-16, -80), Vector2(18, 18), 81, 0.05, 14), _m(Color("fffaf0")), 1),
				Art.P(Art.ell(Vector2(16, -80), Vector2(18, 18), 82, 0.05, 14), _m(Color("fffaf0")), 1),
				Art.P(Art.ell(Vector2(0, -92), Vector2(18, 18), 83, 0.05, 14), _m(Color("fffaf0")), 1)], true, 2.0)
			for sx in [-1.0, 1.0]:
				Art.sil(ci, [Art.P(Art.ell(Vector2(11 * sx, 24), Vector2(13, 4.5), 84, 0.05, 12, 0.35 * sx), _m(Color("2a1a10")), 1)], false, 1.5)
		5:
			# 工匠：黄色安全帽 + 耳朵上夹一支炭笔
			Art.sil(ci, [Art.P(Art.capsule(Vector2(-50, -36), Vector2(50, -36), 5.0, 90), _m(Color("f2c230")), 1),
				Art.P(Art.ell(Vector2(0, -44), Vector2(40, 26), 91, 0.02, 20), _m(Color("f7cf3c")), 1),
				Art.P(Art.capsule(Vector2(0, -68), Vector2(0, -40), 4.0, 92), _m(Color("e0ac1c")), 2)], true, 2.0)
			Art.sil(ci, [Art.P(Art.capsule(Vector2(36, -10), Vector2(58, -22), 3.5, 93), _m(Art.WOOD_D), 1)], true, 1.6)
		6:
			# 电竞选手：头戴式耳机 + 麦克风
			Art.sil(ci, [Art.P(Art.capsule(Vector2(-44, -18), Vector2(-40, -48), 5.0, 100), _m(Color("2b2b33")), 1),
				Art.P(Art.capsule(Vector2(40, -48), Vector2(44, -18), 5.0, 101), _m(Color("2b2b33")), 1),
				Art.P(Art.capsule(Vector2(-40, -48), Vector2(40, -48), 5.0, 102), _m(Color("2b2b33")), 1)], true, 2.0)
			for sx in [-1.0, 1.0]:
				Art.sil(ci, [Art.P(Art.ell(Vector2(46 * sx, -8), Vector2(11, 16), 103, 0.03, 14), _m(Color("e8414a")), 1)], true, 2.0)
			Art.sil(ci, [Art.P(Art.capsule(Vector2(-46, 2), Vector2(-16, 34), 2.5, 104), _m(Color("2b2b33")), 1),
				Art.P(Art.ell(Vector2(-14, 34), Vector2(5, 5), 105, 0.03, 10), _m(Color("3a3a44")), 1)], false, 1.5)
		HERO:
			# 阿焰：额头一条皮头带，正中一枚火苗骨片，耳边插根羽毛
			Art.sil(ci, [Art.P(Art.capsule(Vector2(-44, -30), Vector2(44, -30), 5.0, 240), _m(Color("b0472a")), 1)], true, 2.0)
			Art.sil(ci, [Art.P(Art.flame_pts(Vector2(0, -24), 9, 26, 241), _m(Color("e8902c")), 1)], false, 1.6)
			Art.sil(ci, [Art.P(Art.ell(Vector2(48, -46), Vector2(6, 18), 242, 0.05, 12, 0.5), _m(Art.BONE), 1)], true, 1.6)
		XIAOYA:
			# 小牙：虎皮帽的帽檐压到眉毛，两颗大剑齿垂在额头，脸上画三道虎须
			var fur := _m(Color("e08a34"))
			Art.sil(ci, [Art.P(Art.ell(Vector2(0, -42), Vector2(54, 22), 250, 0.04, 20), fur, 1)], true, 2.0)
			for k in 3:
				Art.pl(ci, [Vector2(-30 + k * 22, -60), Vector2(-26 + k * 22, -46)], 3.0, _m(Color("5a3416")), 251 + k)
			for sx in [-1.0, 1.0]:
				Art.sil(ci, [Art.P(Art.poly([Vector2(16 * sx - 5, -24), Vector2(16 * sx + 5, -24), Vector2(16 * sx, -6)], 255), _m(Art.BONE), 2)], false, 1.6)
				for k in 3:
					Art.ln(ci, Vector2(30 * sx, 14 + k * 5), Vector2(46 * sx, 10 + k * 7), 2.0, Art.INK, 256 + k)
		_:
			# 学者：学士帽 + 圆眼镜
			Art.sil(ci, [Art.P(Art.poly([Vector2(-50, -50), Vector2(0, -66), Vector2(50, -50), Vector2(0, -36)], 110), _m(Color("2a2438")), 1),
				Art.P(Art.rrect(Rect2(-26, -46, 52, 14), 4, 111, 0.3), _m(Color("2a2438")), 1)], true, 2.0)
			Art.pl(ci, [Vector2(0, -52), Vector2(34, -48), Vector2(38, -26)], 2.0, _m(Color("f2c230")), 112)
			ci.draw_circle(Vector2(38, -24), 3.5, _m(Color("f2c230")))
			for sx in [-1.0, 1.0]:
				ci.draw_arc(Vector2(17 * sx, -9), 11.0, 0.0, TAU, 20, Art.INK, 2.4, true)
			ci.draw_line(Vector2(-6, -10), Vector2(6, -10), Art.INK, 2.2, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 网上那种 8-bit 墨镜：黑方块拼的，每片镜左上角两格白高光
static func _pixel_shades(ci: CanvasItem, c: Vector2) -> void:
	var p := 4.0
	var rows := [
		"##############",
		"#ww###  #ww###",
		"######  ######",
		" ####    #### ",
	]
	var x0 := c.x - 7.0 * p
	var y0 := c.y - 2.0 * p
	for r in rows.size():
		var row: String = rows[r]
		for k in row.length():
			var ch := row[k]
			if ch == " ":
				continue
			ci.draw_rect(Rect2(x0 + k * p, y0 + r * p, p + 0.5, p + 0.5), Color.WHITE if ch == "w" else Color("111111"))

# ---------------------------------------------------------------- 组合

## 订单卡片、配置页用的头像：原图半身，上面叠衣服和装饰。c 是头的中心附近，s 和 Paint.portrait 的尺寸差不多。
## 只贴 scripts/sprites/meme.gd 生成的图（按 s=140 画，这里按比例缩）。
static func portrait(ci: CanvasItem, role: int, c: Vector2, s: float) -> void:
	var k := s / 140.0
	Sprites.at(ci, "meme_portrait_%d" % (role % BODY.size()), c + Vector2(0, -15) * k, k)

## 头像的原始画法：只给生成界面图用
static func live_portrait(ci: CanvasItem, role: int, c: Vector2, s: float) -> void:
	var k := s / 100.0
	var rot: float = TILT[role % TILT.size()]
	var hc := c + Vector2(0, -4) * k
	var hw := 70.0 * k
	props_back(ci, role, hc, hw, rot)
	bust(ci, hc, hw, rot)
	clothes(ci, role, hc, hw, rot)
	props_front(ci, role, hc, hw, rot)

## 套在照片半身上的衣服（头部局部坐标，肩膀在 y=45～87、x=±70）
static func clothes(ci: CanvasItem, role: int, c: Vector2, w: float, rot: float) -> void:
	ci.draw_set_transform(c, rot, Vector2.ONE * (w / 100.0))
	var r := role
	var col: Color = _m(BODY[r])
	var cape := Art.poly([Vector2(-66, 90), Vector2(-62, 64), Vector2(-40, 54), Vector2(-16, 62), Vector2(0, 76), Vector2(16, 62), Vector2(40, 54), Vector2(62, 64), Vector2(66, 90)], 120 + r, 0.8)
	match r:
		0:
			# 酋长：豹纹兽皮披肩 + 骨头项链
			Art.sil(ci, [Art.P(cape, _m(Color("d9a441")), 1)], true, 2.0)
			for i in 9:
				var p := Vector2(-50 + (i % 5) * 25 + (i / 5) * 12, 70 + (i / 5) * 10)
				ci.draw_colored_polygon(Art.ell(p, Vector2(5, 4), 130 + i, 0.2, 8), _m(Color("5a3416")))
			for i in 7:
				var x := -30.0 + float(i) * 10.0
				var y := 62.0 + absf(float(i) - 3.0) * -2.0 + 4.0
				Art.sil(ci, [Art.P(Art.poly([Vector2(x - 3.5, y), Vector2(x + 3.5, y), Vector2(x, y + 11)], 140 + i), _m(Art.BONE), 2)], false, 1.6)
		1:
			# 巫医：树叶披风 + 一串彩珠
			var parts := []
			for i in 9:
				var x := -60.0 + float(i) * 15.0
				parts.append(Art.P(Art.ell(Vector2(x, 76 + absf(x) * 0.12), Vector2(10, 18), 150 + i, 0.05, 12, 0.3 * signf(x)), _m(Art.LEAF) if i % 2 == 0 else _m(Art.LEAF_D), 1))
			Art.sil(ci, parts, true, 2.0)
			var bead := [_m(Art.CLAY), _m(Art.TEAL), _m(Art.OCHRE), _m(Art.BONE)]
			for i in 9:
				var a := PI * 0.15 + float(i) / 8.0 * PI * 0.7
				ci.draw_circle(Vector2(cos(a) * 28.0, 52.0 + sin(a) * 16.0), 3.4, bead[i % 4])
		2:
			# 猎手：斜挎兽皮带 + 狼牙
			Art.sil(ci, [Art.P(Art.poly([Vector2(-58, 62), Vector2(-44, 54), Vector2(50, 86), Vector2(30, 90)], 160), col, 1)], true, 2.0)
			Art.sil(ci, [Art.P(Art.poly([Vector2(-6, 62), Vector2(4, 62), Vector2(-1, 80)], 161), _m(Art.BONE), 2)], false, 1.6)
		3:
			# 小不点：粉色口水兜
			Art.sil(ci, [Art.P(Art.ell(Vector2(0, 74), Vector2(34, 22), 170, 0.04, 20), _m(Color("ffb3c8")), 1)], true, 2.0)
			Art.dashed(ci, Art.ell(Vector2(0, 74), Vector2(28, 17), 171, 0.0, 20), 5, 4, Color.WHITE, 2.0)
			ci.draw_circle(Vector2(0, 74), 5.0, _m(Color("ff7fa8")))
		4:
			# 厨子：白围裙 + 红领巾
			Art.sil(ci, [Art.P(Art.poly([Vector2(-34, 92), Vector2(-30, 62), Vector2(30, 62), Vector2(34, 92)], 180), _m(Color("fffaf0")), 1),
				Art.P(Art.poly([Vector2(-26, 54), Vector2(26, 54), Vector2(0, 72)], 181), _m(Color("e0413a")), 1)], true, 2.0)
		5:
			# 工匠：橙色反光背心
			Art.sil(ci, [Art.P(cape, _m(Color("ff8a1f")), 1)], true, 2.0)
			for sx in [-1.0, 1.0]:
				Art.sil(ci, [Art.P(Art.poly([Vector2(26 * sx, 60), Vector2(36 * sx, 58), Vector2(40 * sx, 90), Vector2(30 * sx, 90)], 190), _m(Color("dfe6ea")), 1)], false, 1.6)
			Art.sil(ci, [Art.P(Art.rrect(Rect2(-62, 76, 124, 7), 3, 191, 0.3), _m(Color("dfe6ea")), 1)], false, 1.6)
		6:
			# 电竞选手：蓝色队服 + 号码
			Art.sil(ci, [Art.P(cape, col, 1)], true, 2.0)
			Art.sil(ci, [Art.P(Art.poly([Vector2(-14, 60), Vector2(14, 60), Vector2(0, 74)], 200), _m(Color("f2c230")), 1)], false, 1.6)
			var f: Font = G.font_title
			ci.draw_string_outline(f, Vector2(-34, 90), "66", HORIZONTAL_ALIGNMENT_CENTER, 68, 20, 5, Art.INK)
			ci.draw_string(f, Vector2(-34, 90), "66", HORIZONTAL_ALIGNMENT_CENTER, 68, 20, Color.WHITE)
		HERO:
			# 阿焰：树叶短披肩 + 兽牙项链
			var parts := []
			for k in 9:
				var x := -60.0 + float(k) * 15.0
				parts.append(Art.P(Art.ell(Vector2(x, 78 + absf(x) * 0.1), Vector2(10, 16), 260 + k, 0.05, 12, 0.3 * signf(x)), _m(Art.LEAF if k % 2 == 0 else Art.LEAF_D), 1))
			Art.sil(ci, parts, true, 2.0)
			for k in 5:
				var x := -20.0 + float(k) * 10.0
				Art.sil(ci, [Art.P(Art.poly([Vector2(x - 3.5, 60), Vector2(x + 3.5, 60), Vector2(x, 71)], 270 + k), _m(Art.BONE), 2)], false, 1.6)
		XIAOYA:
			# 小牙：虎皮披肩带条纹
			Art.sil(ci, [Art.P(cape, _m(Color("e08a34")), 1)], true, 2.0)
			for k in 5:
				var x := -48.0 + float(k) * 24.0
				Art.pl(ci, [Vector2(x, 66), Vector2(x + 6, 78), Vector2(x + 2, 88)], 3.2, _m(Color("5a3416")), 280 + k)
		_:
			# 学者：紫色学袍 + 白领子
			Art.sil(ci, [Art.P(cape, col, 1)], true, 2.0)
			for sx in [-1.0, 1.0]:
				Art.sil(ci, [Art.P(Art.poly([Vector2(0, 66), Vector2(30 * sx, 54), Vector2(22 * sx, 74)], 210), _m(Color("fffaf0")), 1)], false, 1.6)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 部落里走来走去的小人：没有手脚，就是一张半身贴纸一蹦一蹦地挪，像 P 图里硬拖过去的。
## feet 是底边落地点，t 是走路相位（秒），facing ±1，moving 是否在走，h 是整张贴纸多高。
static func walker(ci: CanvasItem, role: int, feet: Vector2, t: float, facing: float, moving: bool, h: float = 84.0) -> void:
	var w := h / BUST_RECT.size.y * 100.0
	var ph := t * 7.0
	var hop := absf(sin(ph)) * (7.0 if moving else 0.0) * (h / 84.0)
	var sh := 1.0 - hop / (h * 0.5)
	ci.draw_colored_polygon(Art.ell(feet + Vector2(0, 1), Vector2(22, 6) * (h / 84.0) * sh, 5, 0.0, 14, 0.0, 0.0), Color(0, 0, 0, 0.22))
	var rot: float = TILT[role % TILT.size()]
	var c := feet + Vector2(0, -BUST_RECT.end.y * w / 100.0 - hop)
	props_back(ci, role, c, w, rot)
	bust(ci, c, w, rot)
	clothes(ci, role, c, w, rot)
	props_front(ci, role, c, w, rot)

## 头顶对话气泡。anchor 是气泡尾巴指向的点（人头顶）。a 是透明度。
static func bubble(ci: CanvasItem, anchor: Vector2, text: String, a: float = 1.0, max_w: float = 250.0) -> void:
	var f: Font = G.font_body
	var fs := 18
	var tw := minf(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, max_w)
	var lines := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, tw + 1.0, fs)
	var box := Vector2(tw + 28.0, lines.y + 20.0)
	var x := clampf(anchor.x - box.x * 0.5, 8.0, 712.0 - box.x)
	var r := Rect2(Vector2(x, anchor.y - 14.0 - box.y), box)
	var ink := Color(Art.INK, a)
	var paper := Color(1, 0.99, 0.95, a)
	var tail := Art.poly([Vector2(anchor.x - 9, r.end.y - 2), Vector2(anchor.x + 9, r.end.y - 2), anchor + Vector2(2, -2)], 3, 0.2)
	var b := Art.rrect(r, 14, 9, 0.4)
	Art.dilate(ci, b, 3.0, ink)
	Art.dilate(ci, tail, 3.0, ink)
	ci.draw_colored_polygon(b, paper)
	ci.draw_colored_polygon(tail, paper)
	ci.draw_multiline_string(f, r.position + Vector2(14, 10 + f.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, tw + 1.0, fs, -1, ink)
