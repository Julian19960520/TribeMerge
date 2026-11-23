extends RefCounted
## 桌面上打开时把窗口等比放大到屏幕可用区域的上下边缘（扣掉任务栏和标题栏），水平居中。
## 网页、手机、无界面、嵌在编辑器里运行时不动。试玩（Main）和统一演算都调用。

const ASPECT := 720.0 / 1480.0

static func fit(window: Window) -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web") or OS.has_feature("mobile"): return
	if Engine.is_embedded_in_editor(): return
	if window.mode != Window.MODE_WINDOWED: return
	var area := DisplayServer.screen_get_usable_rect(window.current_screen)
	# 标题栏和边框：带装饰的尺寸减去内容尺寸（Windows 上左右下有隐形边框，上面是标题栏）
	var deco := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var side := deco.x / 2
	var top := maxi(deco.y - side, 0)
	var h := area.size.y - top - side
	var w := int(round(h * ASPECT))
	if w + deco.x > area.size.x:
		w = area.size.x - deco.x
		h = int(round(w / ASPECT))
	window.size = Vector2i(w, h)
	window.position = Vector2i(area.position.x + (area.size.x - w) / 2, area.position.y + top)
