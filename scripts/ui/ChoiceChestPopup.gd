extends PopupBase
var cell := -1
var box_id := ""
var options: Array[TButton] = []
var _pending := false
func _ready() -> void:
	var c := ChoiceChest.definition(box_id)
	Popups.frame(self, Rect2(38, 405, 644, 600), str(c.get("title", "自选宝箱")), Art.TEAL, "")
	UI.lbl(box, "选择一件物品", Rect2(90, 485, 540, 48), 30, Art.INK)
	var choices: Array = c.get("choices", [])
	if choices.size() != 3: return
	for k in 3:
		var id := str(choices[k])
		var x := 68 + k * 200
		var button := UI.btn(box, Rect2(x, 570, 184, 310), "", "hide", _choose.bind(k), 24)
		button.extra = func(ci, sz): Art.item(ci, id, Vector2(sz.x / 2, 106), 138)
		UI.lbl(button, Data.name_of(id), Rect2(6, 182, 172, 42), 24, Art.INK)
		UI.lbl(button, "选择", Rect2(12, 240, 160, 48), 28, Color("346b59"))
		options.append(button)
	UI.lbl(box, "选择后替换棋盘上的宝箱", Rect2(90, 915, 540, 38), 22, Color("806141"))
func _choose(option: int) -> void:
	if _pending: return
	_pending = true
	for b in options: b.enabled = false; b.queue_redraw()
	var result: Dictionary = await ChoiceChest.choose(cell, box_id, option)
	if not is_instance_valid(self): return
	_pending = false
	if result.has("error"):
		G.main.toast(str(result["error"]))
		for b in options: b.enabled = true; b.queue_redraw()
		return
	G.main.board_screen.board.pop(cell)
	G.main.board_screen.board.burst(cell)
	Sfx.play("merge")
	close()
func close() -> void:
	if _pending: return
	super.close()
