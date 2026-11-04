@tool
extends EditorPlugin

var host: Control

func _enter_tree() -> void:
	host = preload("res://addons/tribe_config/host.gd").new()
	EditorInterface.get_editor_main_screen().add_child(host)
	_make_visible(false)

func _exit_tree() -> void:
	if host:
		host.queue_free()
		host = null

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if host:
		host.visible = visible

func _get_plugin_name() -> String:
	return "配置"

func _get_plugin_icon() -> Texture2D:
	var theme := EditorInterface.get_editor_theme()
	if theme == null:
		return null
	return theme.get_icon(&"Edit", &"EditorIcons")
