extends SceneTree
## 新手引导第二下合成：第一下刚合完、石头还在裂、物品还在滑时立刻拖，也要成功。
## godot --headless --path . --script tools/check_guide_fast_merge.gd -- --replay-test --cloud-off
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
	var replay = root.get_node("Replay")
	g.new_game()
	replay.meta = {}; replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.executing = true; replay.advance(); replay._canonicalize_live(); replay.executing = false
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var guide = main._guide
	check(guide.visible and guide._step == "welcome" and main.screen == "home", "开场先在外景引导进入棋盘")
	main.home.go.pressed.emit()
	for _i in 24:
		if guide._step == "motive" and guide.visible: break
		await create_timer(0.1).timeout
	check(guide._step == "motive", "第一次合成前先说明为何需要大草篓")
	check(not guide.allows_drop(23, 30), "说明文字出现时不能抢先合成")
	guide.skip_beat()
	await process_frame
	var board = main.board_screen.board
	_drag(board, 23, 30)
	check(str(g.board[30]["id"]) == "basket_2", "参考图第4行第3列向下合出草绳卷")
	check(not board.crumbles.is_empty() or not board.moves.is_empty(), "第一下合成的开石动画还在播放")
	await process_frame
	_drag(board, 30, 31)
	check(str(g.board[31]["id"]) == "basket_3", "动画未完也能紧接着合成第二次")
	quit(1 if failures > 0 else 0)
