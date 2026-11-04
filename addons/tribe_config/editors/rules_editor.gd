@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, "列数和行数决定初始棋盘多大。用奇数才有唯一的中心格。改完保存，重新运行游戏后生效。")
	_field(box, "cols", "列数", 1, 15)
	_field(box, "rows", "行数", 1, 20)
	_field(box, "max_energy", "火种上限", 1, 9999)
	_field(box, "regen_sec", "火种恢复秒数", 1, 9999)
	_field(box, "random_orders", "每批订单数", 0, 12)
	_field(box, "token_step", "祭典鼓换卡包", 1, 999)
	_field(box, "inv_max", "储物洞上限", 1, 50)

func _field(box: Node, key: String, label: String, lo: int, hi: int) -> void:
	var r := Ui.row(box)
	Ui.lbl(r, label, 140)
	var s := Ui.spin(r, int(data[key]), lo, hi, 100)
	s.value_changed.connect(_set_num.bind(data, key))

func validate() -> String:
	if int(data["cols"]) < 1 or int(data["rows"]) < 1:
		return "列数和行数至少是 1"
	if int(data["max_energy"]) < 1:
		return "火种上限至少是 1"
	if int(data["regen_sec"]) < 1:
		return "火种恢复秒数至少是 1"
	return ""
