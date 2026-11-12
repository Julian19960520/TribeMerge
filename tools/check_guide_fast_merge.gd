extends SceneTree
## 新手引导第二下合成：第一下刚合完、石头还在裂、物品还在滑时立刻拖，也要成功。
## godot --headless --path . --script tools/check_guide_fast_merge.gd
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _press(board, i: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = board.cell_center(i)
	board._gui_input(e)

func _move(board, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	board._gui_input(e)

func _release(board, i: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = board.cell_center(i)
	board._gui_input(e)

func _drag(board, a: int, b: int) -> void:
	_press(board, a)
	var pa: Vector2 = board.cell_center(a)
	var pb: Vector2 = board.cell_center(b)
	_move(board, pa.lerp(pb, 0.3))
	_move(board, pb)
	_release(board, b)

func run() -> void:
	var g = root.get_node("G")
	g.new_game()
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var board = main.board_screen.board
	var guide = main._guide
	check(guide.visible and guide._step == "merge1", "tutorial starts at merge1")
	check(guide._beat == "merge1", "tutorial opens with the intro line before the first merge")
	guide.skip_beat()
	_drag(board, guide.SRC, guide.DST)
	check(str(g.board[guide.DST]["id"]) == "basket_2", "first merge made basket_2")
	check(not board.crumbles.is_empty() or not board.moves.is_empty(), "animations still running right after first merge")
	await process_frame
	_drag(board, guide.DST, guide.VINE2)
	check(str(g.board[guide.VINE2]["id"]) == "basket_3", "fast second merge onto vine succeeds")
	quit(1 if failures > 0 else 0)
