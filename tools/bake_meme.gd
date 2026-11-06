extends SceneTree
## 把「兄弟，我发现」原图抠成两张贴纸：大头（部落小人用）和半身（订单头像用）。
## 边缘故意抠得歪歪扭扭、带一圈白边，像网友随手 P 的。
## 用法：godot --headless --path . -s tools/bake_meme.gd   然后 godot --headless --path . --import
## 原图在 assets/meme/src/caveman.webp（该目录有 .gdignore，不进游戏包）。

const SRC := "res://assets/meme/src/caveman.webp"
## 原图里头的中心和半径（像素）
const HC := Vector2(572, 465)
const HR := Vector2(300, 322)
const BORDER := 14.0

func _init() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	src.convert(Image.FORMAT_RGBA8)
	_cut(src, Rect2i(250, 118, 646, 702), false, 0.4, "res://assets/meme/caveman_head.png")
	_cut(src, Rect2i(150, 118, 840, 900), true, 0.34, "res://assets/meme/caveman_bust.png")
	print("baked")
	quit()

func _cut(src: Image, r: Rect2i, bust: bool, scale: float, out: String) -> void:
	var img := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	for y in r.size.y:
		for x in r.size.x:
			var p := Vector2(r.position.x + x, r.position.y + y)
			var d := _dist(p, bust)
			if d > BORDER + _wob(p) * 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > 0.0:
				var a := clampf((BORDER + _wob(p) * 0.5 - d) / 1.5, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.99, 0.98, 0.95, a))
			else:
				var c := src.get_pixelv(Vector2i(p))
				# 稍微提一点对比，像翻拍的老照片
				var l := clampf((c.r * 0.3 + c.g * 0.59 + c.b * 0.11 - 0.5) * 1.12 + 0.52, 0.0, 1.0)
				img.set_pixel(x, y, Color(l * 1.02, l, l * 0.96))
	img.resize(int(r.size.x * scale), int(r.size.y * scale), Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(out))

## 抠图边缘的抖动：几条不同频率的正弦叠起来，像剪刀一刀一刀剪的
func _wob(p: Vector2) -> float:
	var a := (p - HC).angle()
	return 4.0 * sin(a * 11.0 + 0.6) + 3.0 * sin(a * 27.0 + 2.1) + 2.0 * sin(p.y * 0.05)

## 到抠图轮廓的近似距离（像素，里面为负）
func _dist(p: Vector2, bust: bool) -> float:
	var f := _f(p, bust)
	var gx := _f(p + Vector2(1, 0), bust) - f
	var gy := _f(p + Vector2(0, 1), bust) - f
	var g := maxf(Vector2(gx, gy).length(), 0.0001)
	return (f - 1.0) / g + _wob(p)

func _f(p: Vector2, bust: bool) -> float:
	var q := (p - HC) / HR
	var head := pow(pow(absf(q.x), 2.3) + pow(absf(q.y), 2.1), 1.0 / 2.2)
	if not bust:
		return head
	# 半身：脖子 + 肩膀，底边一刀切平
	var s := (p - Vector2(570, 1000)) / Vector2(410, 300)
	var sh := pow(pow(absf(s.x), 3.0) + pow(absf(s.y), 2.0), 1.0 / 2.5)
	var cut := 1.0 + (p.y - 990.0) / 300.0
	return minf(head, maxf(sh, cut))
