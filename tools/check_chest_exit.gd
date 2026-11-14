extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	var g = root.get_node("G"); var replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	replay.executing = true
	replay.meta = {}; replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = 1794240000; g.simulation_time = replay.clock
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true; g.level = 4
	replay.advance(); replay.executing = false
	for i in g.board.size(): g.board[i] = {"id": "fruit_1", "lock": 0}
	g.board[0] = {"id": "chest_1", "lock": 0, "chest": ["fruit_3"]}
	var blocked: Dictionary = replay.perform("tap", {"cell": 0}, replay.clock)
	check(blocked.has("error") and g.board[0]["id"] == "chest_1" and g.board[0]["chest"] == ["fruit_3"], "最后一件也需要其他空格，满盘时保留箱子与内容")
	g.board[8]["id"] = ""
	var main = load("res://main.tscn").instantiate(); root.add_child(main)
	main.show_screen("board", true)
	var board = main.board_screen.board
	# Real board taps select first; only the next tap opens a previously untouched box.
	g.board[0] = {"id": "chest_1", "lock": 0}; g.board[1]["id"] = ""; g.board[2]["id"] = ""
	board.select(-1)
	board._tap(0)
	check(board.selected == 0 and not g.board[0].has("chest") and g.board[1]["id"] == "", "宝箱首击只选中，不生成内容或产物")
	board._tap(0)
	await process_frame
	check(g.board[0].has("chest") and g.board[0]["id"] == "chest_1", "选中后第二击才放出一件物品并保留箱子")
	var art = load("res://scripts/Art.gd")
	check(art.chest_visual("chest_1", true) == "chest_1_open" and root.get_node("Items").has_animation("chest_1_open"), "已打开状态使用独立开盖图片")
	g.board[2] = {"id": "chest_1", "lock": 0}
	check(replay.perform("drop", {"from": 0, "to": 2}, replay.clock).get("kind", "") != "merge", "首次放出物品后不能与同级箱子合并")
	board.flights.clear(); board.hid.clear()
	for i in g.board.size(): g.board[i] = {"id": "fruit_1", "lock": 0}
	g.board[0] = {"id": "chest_1", "lock": 0, "chest": ["fruit_3"]}; g.board[8]["id"] = ""
	await main.board_screen._on_activate(0)
	check(g.board[0]["id"] == "" and g.board[8]["id"] == "fruit_3" and board.chest_shells.has(0) and board.hid.has(8), "最后物品去其他格，箱子外观留在原地等飞行动画")
	check(not board._settle(0), "箱子退场前原格不接受拖放")
	await create_timer(0.12).timeout
	check(board.chest_shells.has(0), "飞行途中箱子仍存在")
	await create_timer(0.22).timeout
	check(not board.chest_shells.has(0) and not board.hid.has(8) and board.flights.is_empty(), "最后物品落下后再销毁箱子外观")
	g.board[0] = {"id": "chest_1", "lock": 0, "chest": ["fruit_2"]}; g.board[1]["id"] = ""
	await main.board_screen._on_activate(0)
	check(board.chest_shells.has(0) and board._settle(1) and not board.chest_shells.has(0), "快速操作将飞行收尾时，箱子同步退场而不残留")
	g.board[0] = {"id": "chest_1", "lock": 0, "chest": ["fruit_4"]}; g.board[2]["id"] = ""
	await main.board_screen._on_activate(0)
	main.show_screen("home", true)
	check(board.chest_shells.is_empty() and board.flights.is_empty() and g.board[0]["id"] == "", "中途切页清理外观，业务物品不重发")
	await process_frame
	main.free(); g.main = null
	await process_frame
	quit(1 if failures else 0)
