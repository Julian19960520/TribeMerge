@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, TextCatalog.source("developer.people_editor.17aeadb3ddeb"))
	string_rows(box, data, TextCatalog.source("developer.people_editor.8d7aff5a595f"))

func validate() -> String:
	if data.is_empty():
		return TextCatalog.source("developer.people_editor.9864db9b9a92")
	return ""
