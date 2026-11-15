extends RefCounted
## 卡册角色共用完整彩图与头像裁切，所有界面保持相同身份，不再叠加衣服或头饰。
const Portraits := preload("res://scripts/ui/CharacterPortraits.gd")
## 旧人物编号保持稳定，兼容已有订单、活动对手和存档。
const HERO := 8
const XIAOYA := 9
const ROLE_COUNT := 10
const WALKER_DIAMETER := 64.0
const WALKER_BORDER := 4.0

## 交单后客人说的话：[台词, 需要哪个区域开工过（"" 表示一直有）]。订单自带台词时不用这里的。
static var LINES := [
	[TextCatalog.source("dialogue.meme.30e8acb518f0"), ""],
	[TextCatalog.source("dialogue.meme.047ebbd00d91"), ""],
	[TextCatalog.source("dialogue.meme.9797037f2d1e"), ""],
	[TextCatalog.source("dialogue.meme.f7c17b842ed4"), ""],
	[TextCatalog.source("dialogue.meme.25c231b10b18"), ""],
	[TextCatalog.source("dialogue.meme.0d6f1320811b"), ""],
	[TextCatalog.source("dialogue.meme.be2179f46ae1"), ""],
	[TextCatalog.source("dialogue.meme.603ed235908d"), ""],
	[TextCatalog.source("dialogue.meme.9beefa25a7a0"), "fire"],
	[TextCatalog.source("dialogue.meme.0a46276ea75f"), "fire"],
	[TextCatalog.source("dialogue.meme.59d5850dd662"), "gather"],
	[TextCatalog.source("dialogue.meme.152797381c2d"), "stone"],
	[TextCatalog.source("dialogue.meme.fb9d3591691a"), "weave"],
	[TextCatalog.source("dialogue.meme.0832b4f42634"), "hunt"],
	[TextCatalog.source("dialogue.meme.569e28a8466e"), "cook"],
	[TextCatalog.source("dialogue.meme.a4e90661543a"), "wood"],
	[TextCatalog.source("dialogue.meme.cb00359bcd65"), "kiln"],
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

## 任意界面的完整半身像，保持原图比例。
static func draw_portrait(ci: CanvasItem, role: int, rect: Rect2) -> void:
	Portraits.draw(ci, role, rect)

static func draw_chest(ci: CanvasItem, role: int, rect: Rect2) -> void:
	Portraits.chest(ci, role, rect)

## 小头像使用同一原图的头肩裁切，直接适配圆形头像框。
static func portrait(ci: CanvasItem, role: int, c: Vector2, s: float) -> void:
	Portraits.face(ci, role, c, s)

## 烘焙工具也调用同一套彩图，避免重新生成旧黑白人像。
static func live_portrait(ci: CanvasItem, role: int, c: Vector2, s: float) -> void:
	portrait(ci, role, c, s)

static func customer_name(role: int, short: bool = false) -> String:
	var value := Portraits.person_name(role)
	return value.get_slice(" ", 1) if short and value.contains(" ") else value

## 地图角色使用圆形头像，浅色底和细描边保证在草地与道路上清楚可辨。
static func walker_portrait(ci: CanvasItem, role: int, feet: Vector2, diameter: float = WALKER_DIAMETER) -> void:
	var center := feet - Vector2(0, diameter * 0.5)
	# 奶白外边 + 粗墨线，都跟着沸腾线抖（和其他贴纸描边一个手感）
	var r := diameter * 0.5
	ci.draw_colored_polygon(Art.ell(center, Vector2.ONE * (r + WALKER_BORDER + 4.0), role * 7 + 1, 0.0, 28, 0.0, 1.2), Color(1, 0.98, 0.92, 0.96))
	ci.draw_colored_polygon(Art.ell(center, Vector2.ONE * (r + WALKER_BORDER), role * 7 + 2, 0.0, 28, 0.0, 1.2), Art.INK)
	ci.draw_circle(center, r, Art.BONE)
	portrait(ci, role, center, diameter)

## 圆形头像沿用原有走动、跳动和脚下影子。
static func walker(ci: CanvasItem, role: int, feet: Vector2, t: float, _facing: float, moving: bool, diameter: float = WALKER_DIAMETER) -> void:
	var scale := diameter / WALKER_DIAMETER
	var hop := absf(sin(t * 7.0)) * (7.0 if moving else 0.0) * scale
	var sh := 1.0 - hop / (diameter * 0.5)
	ci.draw_colored_polygon(Art.ell(feet + Vector2(0, 1), Vector2(22, 6) * scale * sh, 5, 0.0, 14, 0.0, 0.0), Color(0, 0, 0, 0.22))
	walker_portrait(ci, role, feet - Vector2(0, hop), diameter)

## 头顶对话气泡。anchor 是气泡尾巴指向的点（人头顶）。a 是透明度。
static func bubble(ci: CanvasItem, anchor: Vector2, text: String, a: float = 1.0, max_w: float = 250.0) -> void:
	var f: Font = G.font_body
	var fs := 18
	var tw := minf(f.get_string_size(TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, max_w)
	var lines := f.get_multiline_string_size(TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, tw + 1.0, fs)
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
	ci.draw_multiline_string(f, r.position + Vector2(14, 10 + f.get_ascent(fs)), TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, tw + 1.0, fs, -1, ink)
