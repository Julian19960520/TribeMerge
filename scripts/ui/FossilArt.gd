class_name FossilArt
extends RefCounted
## 恐龙化石活动的贴图入口：土块、坑、骨头、铲子都贴 scripts/sprites/fossil.gd 预生成的图。
## 同一块骨头在土里、陈列卡和飞行动画里用的是同一张图。

const FS := preload("res://scripts/sprites/fossil.gd")

## 兼容旧调用：淡色圆角底板
static func plate(ci: CanvasItem, r: Rect2, color: Color, rim := Color("68452e"), radius := 18.0) -> void:
	ci.draw_colored_polygon(Art.rrect(r.grow(3), radius + 3, 984, 0), rim)
	ci.draw_colored_polygon(Art.rrect(r, radius, 985, 0), color)

static func shovel(ci: CanvasItem, c: Vector2, diameter: float, angle := -0.5) -> void:
	Sprites.at(ci, "fos_shovel", c, diameter / 110.0, angle)

## 骨头的原始（竖放）尺寸，单位：格
static func base_dims(p: Dictionary) -> Vector2i:
	var w := int(p.get("w", 1))
	var h := int(p.get("h", 2))
	return Vector2i(w, h) if int(p.get("turn", 0)) == 0 else Vector2i(h, w)

## 把骨头贴进 r。shadow 为真时只画剪影（陈列卡上还没挖到的）
static func piece(ci: CanvasItem, r: Rect2, p: Dictionary, shadow := false, shadow_col := Color(0.36, 0.24, 0.14, 0.55)) -> void:
	var d := base_dims(p)
	var turn := int(p.get("turn", 0))
	var key := FS.bone_key(str(p.get("kind", "limb")), d.x, d.y, shadow)
	var size := Vector2(d) * FS.CELL
	var shown := size if turn == 0 else Vector2(size.y, size.x)
	var s := minf(r.size.x / shown.x, r.size.y / shown.y)
	Sprites.at(ci, key, r.get_center(), s, PI * 0.5 * turn, shadow_col if shadow else Color.WHITE)

static func dirt(ci: CanvasItem, r: Rect2, cell: int) -> void:
	Sprites.draw(ci, "fos_dirt_%d" % ((cell * 7 + cell / 3) % 4), r)

static func pit(ci: CanvasItem, r: Rect2) -> void:
	Sprites.draw(ci, "fos_pit", r)
