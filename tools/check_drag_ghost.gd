extends SceneTree
## 拖动时跟手的物品画在主界面最上层，盖住订单栏和顶栏。
## godot --headless --path . --script tools/check_drag_ghost.gd -- --replay-test --cloud-off
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	var g = root.get_node("G")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.show_screen("board", true)
	await process_frame
	var board = main.board_screen.board
	var layer = board._drag_layer
	check(layer != null and layer.get_parent() == main, "跟手图层挂在主界面上")
	check(layer.z_index > main.topbar.z_index and layer.z_index > main.board_screen.z_index, "图层压过顶栏和棋盘")
	check(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "图层不挡点击")
	var cell := -1
	for i in g.board.size():
		if str(g.board[i].get("id", "")) != "" and int(g.board[i].get("lock", 0)) == 0:
			cell = i
			break
	check(cell >= 0, "棋盘上有可拖的物品")
	board.dragging = true
	board.drag_from = cell
	var finger := Vector2(360, 220)
	board.drag_pos = board.get_global_transform().affine_inverse() * finger
	board.drag_vis = board.drag_pos
	board.hide_drag = false
	board._sync_drag_ghost()
	check(layer.visible, "拖动时跟手图显示")
	var at: Vector2 = layer.get_global_transform().affine_inverse() * (board.get_global_transform() * (board.drag_vis + board.DRAG_LIFT))
	var global_at: Vector2 = layer.get_global_transform() * at
	var orders: Rect2 = main.board_screen._orders.get_global_rect()
	check(orders.has_point(global_at), "手指在订单栏时，物品图画在订单栏上（y=%.0f）" % global_at.y)
	check(layer.z_index > main.board_screen._orders.z_index, "物品图层压过订单栏")
	board.hide_drag = true
	board._sync_drag_ghost()
	check(not layer.visible, "引导藏拖影时不画")
	board.hide_drag = false
	board.dragging = false
	board._sync_drag_ghost()
	check(not layer.visible, "松手后跟手图消失")
	print("%d failures" % failures)
	quit(1 if failures else 0)
