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
	Ui.lbl(bar, "模式", 40)
	var items := Ui.btn(bar, "● 编辑物品" if _mode == "item" else "编辑物品")
	var locks := Ui.btn(bar, "● 编辑解锁" if _mode == "lock" else "编辑解锁")
	var rewards := Ui.btn(bar, "● 编辑奖励" if _mode == "reward" else "编辑奖励")
	items.pressed.connect(_set_mode.bind("item"))
	locks.pressed.connect(_set_mode.bind("lock"))
	rewards.pressed.connect(_set_mode.bind("reward"))
	if _mode == "lock":
		Ui.lbl(box, "点一格，在开放、藤蔓、巨石之间切换。和默认一样时，保存会省略 locks。")
	elif _mode == "reward":
		Ui.lbl(box, "每一格一件奖励：物品 id 和数量。留空表示没有。巨石裂开时送出。体力、贝币、琥珀按数量飞到顶栏，其他物品飞进暂存。")
	else:
		Ui.lbl(box, "只保存物品 id，从左到右、从上到下。空格留空。锁和奖励留在格子上。")
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
				tag.text = id if id != "" else "空"
				cell.add_child(tag)
				var cycle := Ui.btn(cell, ["开放", "藤蔓", "巨石"][lock])
				cycle.custom_minimum_size = Vector2(108, 0)
				cycle.pressed.connect(_cycle_lock.bind(n, cols, rows))
			elif _mode == "reward":
				var rw := Layout.reward_of(data.get("rewards", {}), n)
				var rid := str(rw[0]) if not rw.is_empty() else ""
				var count := int(rw[1]) if not rw.is_empty() else 1
				tag.text = ["开放", "藤蔓", "巨石"][lock]
				cell.add_child(tag)
				var id_edit := Ui.line(cell, rid, 108)
				id_edit.placeholder_text = "无奖励"
				var spin := Ui.spin(cell, count, 1, 9999, 108)
				id_edit.text_changed.connect(_apply_reward.bind(n, spin))
				spin.value_changed.connect(_apply_reward_n.bind(n, id_edit))
			else:
				if id == "":
					tag.text = "空" if lock == 0 else "巨石"
				else:
					tag.text = ["开放", "藤蔓", "巨石"][lock]
				cell.add_child(tag)
				var edit := Ui.line(cell, id, 108)
				edit.placeholder_text = "空"
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
