extends SceneTree
## 在真实棋盘上按顺序摆满几条物品链的各级（默认石料 + 宝石），再截图鉴，看新物品在游戏里的样子。不碰真实存档。
## Godot --path . --script tools/gen_shot.gd -- --save=user://gen_shot/s.json --cloud-off --rank-state=user://gen_shot/r.json --cloud-state=user://gen_shot/c.json --hot-file=user://gen_shot/h.json --out=DIR [--chains=tool,gem] [--book=2]
const D := preload("res://scripts/Data.gd")
var _started := false
var out := "."
var chains := ["tool", "gem"]
var book_idx := [2]
var g
var main
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false
func _shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/gs_" + n + ".png")
	print("shot ", n)
func _run() -> void:
	g = root.get_node("G")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--chains="): chains = Array(a.trim_prefix("--chains=").split(","))
		if a.begins_with("--book="): book_idx = Array(a.trim_prefix("--book=").split(",")).map(func(x): return int(x))
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 50
	for i in g.board.size():
		g.board[i] = {"id": "", "lock": 0}
	var ids := []
	for ch in chains:
		for lv in range(1, Data.CHAINS[ch]["items"].size() + 1):
			ids.append("%s_%d" % [ch, lv])
	for k in mini(ids.size(), g.board.size()):
		g.board[k]["id"] = ids[k]
	for id in ids:
		g.rules.board.discover(id)
		g.book_claimed[id] = true
	## 新功能介绍、小提示都标成看过，免得挡住截图
	var src := FileAccess.get_file_as_string("res://scripts/ui/Tips.gd")
	var re := RegEx.new()
	re.compile('(?:_intro|show_once)[(]"([a-z0-9_]+)"')
	for m in re.search_all(src):
		g.tips_seen[m.get_string(1)] = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board")
	await create_timer(2.0).timeout
	## 开局自动弹的面板（七日签到之类）先关掉，棋盘才露出来
	for k in 3:
		main.close_all()
		await create_timer(0.6).timeout
	await _shot("items_board")
	for idx in book_idx:
		var p = main.open("book", idx)
		await create_timer(1.0).timeout
		await _shot("items_book_%d" % idx)
		if p != null: p.close()
		await create_timer(0.3).timeout
	print("DONE")
	quit(0)
