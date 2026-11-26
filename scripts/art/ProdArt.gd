class_name ProdArt
extends RefCounted
## 运行时矢量后备图与本地烘焙共用的产线物品绘制入口。kind 是 "G"（生产器）、"M"（主产物）、"S"（副产物）。

## 每条物品链用哪套画法：[画法所在的产线, G/M/S]。跟着链走，不跟产线配置走，
## 所以产线改配产物、或者某条链暂时没挂在产线上，图都不变。
const CHAIN_ART := {
	"basket": ["food", "G"], "fruit": ["food", "M"], "seed": ["food", "S"],
	"anvil": ["tool", "G"], "tool": ["tool", "M"], "gem": ["tool", "S"],
	"loom": ["cloth", "G"], "cloth": ["cloth", "M"], "armor": ["cloth", "S"],
	"trap": ["hunt", "G"], "beast": ["hunt", "M"], "bird": ["hunt", "S"],
	"hearth": ["fire", "G"], "veg": ["fire", "M"], "roast": ["fire", "S"],
	"carve": ["wood", "G"], "furn": ["wood", "M"], "craft": ["wood", "S"],
	"kiln": ["pot", "G"], "pot": ["pot", "M"], "ware": ["pot", "S"],
	"weir": ["fish", "G"], "fish": ["fish", "M"], "clam": ["fish", "S"],
}

## 按物品链画；这条链没有产线画法时返回 false
static func draw_chain(ci: CanvasItem, ch: String, lv: int, c: Vector2, size: float, rim: bool = true) -> bool:
	if not CHAIN_ART.has(ch):
		return false
	var art: Array = CHAIN_ART[ch]
	draw(ci, art[0], art[1], lv, c, size, rim)
	return true

static func draw(ci: CanvasItem, line: String, kind: String, lv: int, c: Vector2, size: float, rim: bool = true) -> void:
	draw_xf(ci, line, kind, lv, Transform2D(0.0, Vector2.ONE * (size / 100.0), 0.0, c), rim, false)

## 按给定变换画；制作产物把材料缩小摆进画面时用（不画地面阴影）
static func draw_xf(ci: CanvasItem, line: String, kind: String, lv: int, t: Transform2D, rim: bool, shadow: bool) -> void:
	PA.xf = t
	ci.draw_set_transform_matrix(t)
	if shadow:
		ci.draw_colored_polygon(Art.ell(Vector2(0, 40), Vector2(30, 6), 1, 0.0, 14, 0.0, 0.0), Color(0.2, 0.1, 0.0, 0.18))
	var s: int = abs((line + kind).hash()) % 97 + lv * 7
	var done := true
	## 生产器统一走新的 10 级画法；旧画法还在各线文件的 gen() 里
	if kind == "G" and PAGen.draw(ci, line, lv, s, rim):
		line = ""
	match line:
		"": pass
		"food": _route(PAFood, ci, kind, lv, s, rim)
		"tool": _route(PATool, ci, kind, lv, s, rim)
		"cloth": _route(PACloth, ci, kind, lv, s, rim)
		"hunt": _route(PAHunt, ci, kind, lv, s, rim)
		"fire": _route(PAFire, ci, kind, lv, s, rim)
		"wood": _route(PAWood, ci, kind, lv, s, rim)
		"pot": _route(PAPot, ci, kind, lv, s, rim)
		"fish": _route(PAFish, ci, kind, lv, s, rim)
		_: done = false
	if not done:
		Art.sil(ci, [Art.P(Art.ell(Vector2.ZERO, Vector2(30, 30), s), Art.STONE)], rim)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	PA.xf = Transform2D.IDENTITY

static func _route(cls, ci: CanvasItem, kind: String, lv: int, s: int, rim: bool) -> void:
	match kind:
		"G": cls.gen(ci, lv, s, rim)
		"M": cls.main(ci, lv, s, rim)
		"S": cls.sub(ci, lv, s, rim)
