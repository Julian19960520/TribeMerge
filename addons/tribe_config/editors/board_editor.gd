@tool
extends "res://addons/tribe_config/editor_base.gd"

const Files := preload("res://scripts/config/config_files.gd")
const Layout := preload("res://scripts/config/board_layout.gd")

var _mode := "item"

func refresh() -> void:
	var box := clear_ui()
	var rules := _rules()
	var cols := int(rules.get("cols", 7))
	var rows := int(rules.get("rows", 9))
	var bar := Ui.row(box)
	Ui.lbl(bar, TextCatalog.source("developer.board_editor.47a270081ab2"), 40)
	var items := Ui.btn(bar, TextCatalog.source("developer.board_editor.e0fa6e252448") if _mode == "item" else TextCatalog.source("developer.board_editor.7f559289d410"))
	var locks := Ui.btn(bar, TextCatalog.source("developer.board_editor.6e1ac0aca13f") if _mode == "lock" else TextCatalog.source("developer.board_editor.d7720405e424"))
	var rewards := Ui.btn(bar, TextCatalog.source("developer.board_editor.efc140d80290") if _mode == "reward" else TextCatalog.source("developer.board_editor.ae7643cbbde4"))
	items.pressed.connect(_set_mode.bind("item"))
	locks.pressed.connect(_set_mode.bind("lock"))
	rewards.pressed.connect(_set_mode.bind("reward"))
	if _mode == "lock":
		Ui.lbl(box, TextCatalog.source("developer.board_editor.c0cddea6ba91"))
	elif _mode == "reward":
		Ui.lbl(box, TextCatalog.source("developer.board_editor.37fac26c586e"))
	else:
		Ui.lbl(box, TextCatalog.source("developer.board_editor.fbb10b58b3aa"))
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var cells: Array = data["cells"]
	for row in rows:
		for col in cols:
			var n := row * cols + col
			var id := str(cells[n]) if n < cells.size() else ""
			var cell := VBoxContainer.new()
			cell.custom_minimum_size.x = 108
			grid.add_child(cell)
			var tag := Label.new()
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag.add_theme_font_size_override("font_size", 12)
			var lock := _lock_at(n, col, row, cols, rows)
			if _mode == "lock":
				tag.text = TextCatalog.resolve(id if id != "" else TextCatalog.source("developer.board_editor.2f8267a89ad5"))
				cell.add_child(tag)
				var cycle := Ui.btn(cell, [TextCatalog.source("developer.board_editor.c14c915da5fb"), TextCatalog.source("developer.board_editor.4d05dc80fd37"), TextCatalog.source("developer.board_editor.78f83cd0be53")][lock])
				cycle.custom_minimum_size = Vector2(108, 0)
				cycle.pressed.connect(_cycle_lock.bind(n, cols, rows))
			elif _mode == "reward":
				var rw := Layout.reward_of(data.get("rewards", {}), n)
				var rid := str(rw[0]) if not rw.is_empty() else ""
				var count := int(rw[1]) if not rw.is_empty() else 1
				tag.text = TextCatalog.resolve([TextCatalog.source("developer.board_editor.c14c915da5fb"), TextCatalog.source("developer.board_editor.4d05dc80fd37"), TextCatalog.source("developer.board_editor.78f83cd0be53")][lock])
				cell.add_child(tag)
				var id_edit := Ui.line(cell, rid, 108)
				id_edit.placeholder_text = TextCatalog.resolve(TextCatalog.source("developer.board_editor.4fe31469b882"))
				var spin := Ui.spin(cell, count, 1, 9999, 108)
				id_edit.text_changed.connect(_apply_reward.bind(n, spin))
				spin.value_changed.connect(_apply_reward_n.bind(n, id_edit))
			else:
				if id == "":
					tag.text = TextCatalog.resolve(TextCatalog.source("developer.board_editor.2f8267a89ad5") if lock == 0 else TextCatalog.source("developer.board_editor.78f83cd0be53"))
				else:
					tag.text = TextCatalog.resolve([TextCatalog.source("developer.board_editor.c14c915da5fb"), TextCatalog.source("developer.board_editor.4d05dc80fd37"), TextCatalog.source("developer.board_editor.78f83cd0be53")][lock])
				cell.add_child(tag)
				var edit := Ui.line(cell, id, 108)
				edit.placeholder_text = TextCatalog.resolve(TextCatalog.source("developer.board_editor.2f8267a89ad5"))
				edit.text_changed.connect(_set_cell.bind(n))

func _set_mode(mode: String) -> void:
	if _mode == mode:
		return
	_mode = mode
	rebuild()

func _apply_reward(text: String, i: int, spin: SpinBox) -> void:
	_write_reward(i, text, int(spin.value))

func _apply_reward_n(_v: float, i: int, edit: LineEdit) -> void:
	_write_reward(i, edit.text, int(_v))

func _write_reward(i: int, text: String, n: int) -> void:
	if not (data.get("rewards") is Dictionary):
		data["rewards"] = {}
	var rewards: Dictionary = data["rewards"]
	var id := text.strip_edges()
	var key := str(i)
	if id == "":
		if rewards.erase(key):
			touch()
		return
	var next := [id, maxi(1, n)]
	var prev = rewards.get(key, null)
	if prev is Array and prev.size() >= 2 and str(prev[0]) == next[0] and int(prev[1]) == next[1]:
		return
	rewards[key] = next
	touch()

func _set_cell(text: String, i: int) -> void:
	var cells: Array = data["cells"]
	while cells.size() <= i:
		cells.append("")
	cells[i] = text.strip_edges()
	touch()

func _cycle_lock(i: int, cols: int, rows: int) -> void:
	var cur := _lock_at(i, i % cols, int(i / cols), cols, rows)
	_set_lock((cur + 1) % 3, i, cols, rows)
	rebuild()

func _set_lock(v: int, i: int, cols: int, rows: int) -> void:
	if _lock_at(i, i % cols, int(i / cols), cols, rows) == v:
		return
	if not data.has("locks") or not (data["locks"] is Array):
		data["locks"] = []
	var locks: Array = data["locks"]
	Layout.ensure(locks, i, cols, rows)
	locks[i] = v
	touch()

func _lock_at(n: int, col: int, row: int, cols: int, rows: int) -> int:
	var locks = data.get("locks", [])
	if not (locks is Array):
		locks = []
	return Layout.lock_of(locks, n, col, row, cols, rows)

func _rules() -> Dictionary:
	if host != null and host.pages.has(Files.RULES) and host.pages[Files.RULES] is Dictionary:
		return host.pages[Files.RULES]
	var loaded = Files.read(Files.RULES)
	return loaded if loaded is Dictionary else {}

func before_save() -> void:
	var rules := _rules()
	var cols := int(rules.get("cols", 7))
	var rows := int(rules.get("rows", 9))
	var need := cols * rows
	var cells: Array = data["cells"]
	while cells.size() < need:
		cells.append("")
	if cells.size() > need:
		data["cells"] = cells.slice(0, need)
	Layout.normalize(data, cols, rows)
	Layout.normalize_rewards(data, cols, rows)
