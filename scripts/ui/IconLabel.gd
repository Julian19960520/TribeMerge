class_name IconLabel
extends Label
## 能嵌资源图标的 Label：文字里的 {xp}、{energy} 等记号（见 IconText）换成占位空格，再在占位处画图标。
## 直接改 .text 也行：画的时候发现还有记号，就在本帧渲染前换好重画。

var _icons: Array = []

func set_icon_text(value: String) -> void:
	if IconText.has_icons(value):
		var parts := IconText.split(value)
		_icons = parts["icons"]
		text = parts["text"]
	else:
		_icons = []
		text = value
	queue_redraw()

func _draw() -> void:
	if IconText.has_icons(text):
		set_icon_text.call_deferred(text)
		return
	if _icons.is_empty():
		return
	var fs := label_settings.font_size if label_settings != null else get_theme_font_size("font_size")
	for ic in _icons:
		var at := int(ic[0])
		# 文字被换掉、占位不在原处了，就不画
		if at >= text.length() or text[at] != IconText.SLOT:
			continue
		var r := get_character_bounds(at)
		if r.size.x <= 0.0:
			continue
		IconText.paint(self, str(ic[1]), r.get_center(), fs)
