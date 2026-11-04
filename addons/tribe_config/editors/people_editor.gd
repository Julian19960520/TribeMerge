@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, "订单上的人物。剧情订单用序号引用，0 是第一个。")
	string_rows(box, data, "人物")

func validate() -> String:
	if data.is_empty():
		return "至少要有一个人物"
	return ""
