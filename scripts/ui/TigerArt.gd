class_name TigerArt
extends RefCounted
## 剑齿虎头；坐标原点在脸部中央。只贴 scripts/sprites/meme.gd 生成的 tiger_head（按 size=140 画）。
const MemeSprites := preload("res://scripts/sprites/meme.gd")

static func draw(ci: CanvasItem, center: Vector2, size: float) -> void:
	var k := size / MemeSprites.TIGER_S
	Sprites.at(ci, "tiger_head", center + MemeSprites.TIGER_BOX.get_center() * k, k)
