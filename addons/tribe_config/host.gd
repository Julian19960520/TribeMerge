@tool
extends Control

const Files := preload("res://scripts/config/config_files.gd")

var catalog: Array = []
var pages := {}
var dirty := {}
var current := 0
var editor: Control
var file_list: ItemList
var title: Label
var path_lbl: Label
var status: Label
var split: HSplitContainer
var confirm: ConfirmationDialog
var _syncing := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog = [
		{"title": TextCatalog.source("developer.host.4ab3d0c189e3"), "path": Files.CHAINS, "script": "res://addons/tribe_config/editors/chains_editor.gd"},
		{"title": TextCatalog.source("developer.people_editor.8d7aff5a595f"), "path": Files.PEOPLE, "script": "res://addons/tribe_config/editors/people_editor.gd"},
		{"title": TextCatalog.source("developer.host.d2e3cba99db0"), "path": Files.STORY, "script": "res://addons/tribe_config/editors/story_editor.gd"},
		{"title": TextCatalog.source("developer.host.600fd878d296"), "path": Files.ALBUMS, "script": "res://addons/tribe_config/editors/albums_editor.gd"},
		{"title": TextCatalog.source("developer.host.12ee32b40734"), "path": Files.AMBER, "script": "res://addons/tribe_config/editors/amber_editor.gd"},
		{"title": TextCatalog.source("developer.host.5b46860a8e8b"), "path": Files.BUILDS, "script": "res://addons/tribe_config/editors/builds_editor.gd"},
		{"title": TextCatalog.source("developer.story_editor.34243df4d613"), "path": Files.LEVELS, "script": "res://addons/tribe_config/editors/levels_editor.gd"},
		{"title": TextCatalog.source("developer.host.2f0a2b5a01ff"), "path": Files.PASS, "script": "res://addons/tribe_config/editors/pass_editor.gd"},
		{"title": TextCatalog.source("developer.host.4a5eab404c52"), "path": Files.BOARD, "script": "res://addons/tribe_config/editors/board_editor.gd"},
		{"title": TextCatalog.source("developer.host.1123245d1bed"), "path": Files.RULES, "script": "res://addons/tribe_config/editors/rules_editor.gd"},
	]
	for info in catalog:
		var loaded = Files.read(info["path"])
		pages[info["path"]] = loaded if loaded != null else []
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 18)
	bar.add_child(title)
	path_lbl = Label.new()
	path_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(path_lbl)
	var reload_btn := Button.new()
	reload_btn.text = TextCatalog.resolve(TextCatalog.source("developer.host.df7392cc96be"))
	reload_btn.pressed.connect(_reload_pressed)
	bar.add_child(reload_btn)
	var save_btn := Button.new()
	save_btn.text = TextCatalog.resolve(TextCatalog.source("developer.host.59ce804379ac"))
	save_btn.pressed.connect(_save)
	bar.add_child(save_btn)
	status = Label.new()
	root.add_child(status)
	split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 148
	root.add_child(split)
	file_list = ItemList.new()
	file_list.custom_minimum_size = Vector2(140, 0)
	file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for info in catalog:
		file_list.add_item(TextCatalog.resolve(info["title"]))
	file_list.item_selected.connect(_on_file)
	split.add_child(file_list)
	confirm = ConfirmationDialog.new()
	confirm.dialog_text = TextCatalog.source("developer.host.4b3e0f9e16aa")
	confirm.confirmed.connect(_reload_now)
	add_child(confirm)
	_open(0)

func _on_file(i: int) -> void:
	if _syncing:
		return
	if i == current and editor != null:
		return
	_open(i)

func _open(i: int) -> void:
	current = i
	_syncing = true
	file_list.select(i)
	_syncing = false
	if editor and is_instance_valid(editor):
		editor.free()
	editor = null
	var info: Dictionary = catalog[i]
	editor = load(info["script"]).new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(editor)
	editor.edit(pages[info["path"]], self)
	title.text = TextCatalog.resolve(info["title"])
	path_lbl.text = TextCatalog.resolve(info["path"])
	_refresh_status()

func touch() -> void:
	dirty[catalog[current]["path"]] = true
	set_status(TextCatalog.source("developer.host.c2277872cdce"))

func set_status(text: String, bad: bool = false) -> void:
	status.text = TextCatalog.resolve((TextCatalog.source("developer.host.159b970778f6") + text) if bad else text)

func _refresh_status() -> void:
	var path: String = catalog[current]["path"]
	if dirty.get(path, false):
		set_status(TextCatalog.source("developer.host.c2277872cdce"))
	else:
		set_status(TextCatalog.source("developer.host.80a507984a56"))

func _save() -> void:
	if editor and editor.has_method("validate"):
		var msg := str(editor.validate())
		if msg != "":
			set_status(msg, true)
			return
	if editor and editor.has_method("before_save"):
		editor.before_save()
	var path: String = catalog[current]["path"]
	var err := Files.write(path, pages[path])
	if err != OK:
		set_status(TextCatalog.fill(TextCatalog.source("developer.host.1f7c56ff5cdb"), error_string(err)), true)
		return
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.update_file(path)
	dirty.erase(path)
	set_status(TextCatalog.fill(TextCatalog.source("developer.host.da351f64b0f5"), path))

func _reload_pressed() -> void:
	var path: String = catalog[current]["path"]
	if dirty.get(path, false):
		confirm.popup_centered()
	else:
		_reload_now()

func _reload_now() -> void:
	var path: String = catalog[current]["path"]
	var loaded = Files.read(path)
	if loaded == null:
		set_status(TextCatalog.source("developer.host.a92695a59f47") + path, true)
		return
	pages[path] = loaded
	dirty.erase(path)
	_open(current)
	set_status(TextCatalog.source("developer.host.b2cb418c8466"))
