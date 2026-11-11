extends RefCounted
## 卡册角色共用完整彩图与头像裁切，所有界面保持相同身份，不再叠加衣服或头饰。
const Portraits := preload("res://scripts/ui/CharacterPortraits.gd")
## 旧人物编号保持稳定，兼容已有订单、活动对手和存档。
const HERO := 8
const XIAOYA := 9
const ROLE_COUNT := 10
const WALKER_DIAMETER := 64.0
const WALKER_BORDER := 1.5

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
	ci.draw_circle(center, diameter * 0.5 + WALKER_BORDER, Art.INK)
	ci.draw_circle(center, diameter * 0.5, Art.BONE)
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
