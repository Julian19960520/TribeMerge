extends RefCounted
## 原始人梗头像（Meme.portrait）和剑齿虎逃生活动（剑齿虎头、落脚点、碎石、顶部牌子、两边草丛）的界面图登记和原始画法。
## 只给「生成物品图.bat」用；游戏里 Meme.portrait / TigerArt.draw / TigerEscapePopup 只贴这里生成的图。
## 登记格式见 scripts/BakeSprites.gd。

const Meme := preload("res://scripts/Meme.gd")

## 头像按最大用到的尺寸画（s=140），运行时按 s/140 缩放
const PORTRAIT_S := 140.0
## 头像在 portrait(c, 140) 坐标里占的位置（含装饰、歪头）
const PORTRAIT_BOX := Rect2(-92, -124, 184, 218)
## 剑齿虎按 size=140 画；框是相对脸中心
const TIGER_S := 140.0
const TIGER_BOX := Rect2(-76, -74, 152, 152)
## 落脚点（相对节点中心）
const NODE_BOX := Rect2(-110, -44, 220, 106)
const HEADER_SIZE := Vector2(652, 243)

static func entries() -> Array:
	var out: Array = []
	for role in Meme.ROLE_COUNT:
		out.append({"key": "meme_portrait_%d" % role, "w": int(PORTRAIT_BOX.size.x), "h": int(PORTRAIT_BOX.size.y), "pad": 12,
			"draw": func(ci, r): Meme.live_portrait(ci, role, r.position - PORTRAIT_BOX.position, PORTRAIT_S)})
	out.append({"key": "tiger_head", "w": int(TIGER_BOX.size.x), "h": int(TIGER_BOX.size.y), "pad": 10,
		"draw": func(ci, r): live_tiger(ci, r.position - TIGER_BOX.position, TIGER_S)})
	# 弹窗里这些都画在不跟着抖的框里，只要 1 帧
	out.append({"key": "tiger_header", "w": int(HEADER_SIZE.x), "h": int(HEADER_SIZE.y), "pad": 12, "static": true,
		"draw": func(ci, r): live_header(ci, r)})
	out.append({"key": "tiger_node", "w": int(NODE_BOX.size.x), "h": int(NODE_BOX.size.y), "pad": 8, "static": true,
		"draw": func(ci, r): live_node(ci, r.position - NODE_BOX.position, 0)})
	out.append({"key": "tiger_frag", "w": 52, "h": 28, "pad": 6, "static": true,
		"draw": func(ci, r): live_frag(ci, r.get_center(), 0, 0.0)})
	out.append({"key": "tiger_bush", "w": 152, "h": 58, "pad": 6, "static": true,
		"draw": func(ci, r): live_bush(ci, r.get_center(), 0, 0.0)})
	return out

# ---------------------------------------------------------------- 剑齿虎

## 与游戏墨线、土色贴纸一致的剑齿虎；坐标原点在脸部中央。
static func live_tiger(ci: CanvasItem, center: Vector2, size: float) -> void:
	var scale := size / 120.0
	ci.draw_set_transform(center, 0, Vector2.ONE * scale)
	var orange := Color("e7a23e")
	for side in [-1, 1]:
		Art.fill(ci, Art.ell(Vector2(side * 39, -35), Vector2(20, 22), 12, 0, 18), Art.WOOD_D, 3)
		ci.draw_circle(Vector2(side * 39, -35), 12, Color("cf7951"))
	Art.fill(ci, Art.ell(Vector2(0, 0), Vector2(57, 46), 7, 0.02, 30), orange, 4)
	ci.draw_colored_polygon(Art.ell(Vector2(0, 15), Vector2(42, 25), 13, 0, 24), Color("ffdea1"))
	for side in [-1, 1]:
		for k in 3:
			var y := -17 + k * 14
			ci.draw_colored_polygon(PackedVector2Array([Vector2(side * 51, y - 7), Vector2(side * 30, y), Vector2(side * 52, y + 6)]), Art.WOOD_D)
		ci.draw_line(Vector2(side * 29, -13), Vector2(side * 12, -8), Art.INK, 6, true)
		ci.draw_circle(Vector2(side * 22, -4), 5, Art.INK)
		ci.draw_circle(Vector2(side * 23, -6), 1.8, Color.WHITE)
		var tooth := PackedVector2Array([Vector2(side * 17, 19), Vector2(side * 30, 18), Vector2(side * 22, 60), Vector2(side * 16, 48)])
		Art.dilate(ci, tooth, 3, Art.INK)
		ci.draw_colored_polygon(tooth, Color("fff5d7"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, 7), Vector2(10, 7), Vector2(0, 17)]), Art.INK)
	ci.draw_line(Vector2(0, 16), Vector2(0, 26), Art.INK, 3, true)
	for k in 3:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-6 + k * 7, -43), Vector2(-2 + k * 5, -20), Vector2(3 + k * 6, -43)]), Art.WOOD_D)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# ---------------------------------------------------------------- 逃生弹窗

## 顶部木牌（物品图标运行时另贴）
static func live_header(ci: CanvasItem, r: Rect2) -> void:
	Art.fill(ci, Art.rrect(r, 30, 83, 0.2), Color("507456"), 5)
	ci.draw_colored_polygon(Art.ell(r.position + Vector2(326, 117), Vector2(137, 78), 35, 0, 28), Color("65864c"))

## 落脚点：at 是节点中心，n 是种子
static func live_node(ci: CanvasItem, at: Vector2, n: int) -> void:
	ci.draw_colored_polygon(Art.ell(at + Vector2(0, 26), Vector2(103, 32), n, 0, 24), Color(0.05, 0.12, 0.08, 0.5))
	Art.fill(ci, Art.ell(at + Vector2(0, 10), Vector2(98, 43), n, 0.04, 22), Color("795035"), 4)
	Art.fill(ci, Art.ell(at, Vector2(98, 35), n + 1, 0.04, 24), Color("b99859"), 3)
	ci.draw_arc(at, 73, PI * 0.15, PI * 0.87, 20, Color("775234"), 3, true)
	ci.draw_colored_polygon(Art.ell(at + Vector2(0, -10), Vector2(88, 22), n, 0.05, 22), Color("71984d"))

## 被摧毁的落脚点碎石
static func live_frag(ci: CanvasItem, c: Vector2, seed: int, rot: float) -> void:
	Art.fill(ci, Art.ell(c, Vector2(22, 10), seed, 0.1, 8, rot), Color("574b39"), 2)

## 背景两边的草丛
static func live_bush(ci: CanvasItem, c: Vector2, seed: int, rot: float) -> void:
	ci.draw_colored_polygon(Art.ell(c, Vector2(72, 25), seed, 0.06, 14, rot), Color("41734c"))
