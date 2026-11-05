extends SceneTree
## 排行榜联调：上传 → 查询 → 建造一件后自动上传 → 弹窗显示 → 服务器关掉时弹窗显示提示。
## 不写主存档（G 的 _process 关掉、玩家 id 只在内存里换成测试 id），排行状态写到单独的测试文件。
## 用法（先启动服务器）：
##   Godot --headless --path . --script tools/rank_check.gd -- --rank-state=user://rank_check_state.json [--rank-url=http://127.0.0.1:8765] [--shot=out.png]

var _started := false
var _fail := 0

func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _ok(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1

func _run() -> void:
	var g := root.get_node("G")
	g.set_process(false)
	var rank := root.get_node("Rank")
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rank-url="):
			rank.url = a.trim_prefix("--rank-url=")
		if a.begins_with("--shot="):
			shot = a.trim_prefix("--shot=")
	print("rank server: ", rank.url)
	# 启动时 Rank 会先补传一次真实存档的进度，等它结束再换测试 id
	if rank._sending:
		await rank.synced
	g.player_id = "TRBCHECK%04d" % (randi() % 10000)
	g.builds = {"fire": 1}
	rank.nick = "联调部落"
	rank._check()
	_ok(rank.progress == 1, "初始进度 = 1（篝火广场第一件）")
	var ok: bool = await rank.synced
	_ok(ok, "首次上传成功")

	var res := [false, {}]
	rank.fetch(func(o, d): res[0] = o; res[1] = d)
	while res[1].is_empty() and not res[0]:
		await process_frame
		if not res[0] and res[1].is_empty():
			await create_timer(0.05).timeout
	var me = res[1].get("me")
	_ok(res[0] and me is Dictionary and int(me["progress"]) == 1, "查询到自己，进度 1，名次 %s" % (str(int(me["rank"])) if me is Dictionary else "?"))

	# 建造一件 → G.changed → 自动上传
	g.shells += 100000
	var built: Dictionary = g.do_build("fire")
	_ok(not built.is_empty(), "建造篝火广场第二件")
	_ok(rank.progress == 2, "本地进度涨到 2")
	ok = await rank.synced
	_ok(ok and rank.sent == 2, "建造后自动上传成功")
	res = [false, {}]
	rank.fetch(func(o, d): res[0] = o; res[1] = d)
	while not res[0] and res[1].is_empty():
		await create_timer(0.05).timeout
	me = res[1].get("me")
	_ok(me is Dictionary and int(me["progress"]) == 2, "服务器上的进度 = 2，名次 %s / %d" % [str(int(me["rank"])) if me is Dictionary else "?", int(res[1].get("total", 0))])

	# 弹窗
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	if shot != "":
		root.get_viewport().get_texture().get_image().save_png(shot.trim_suffix(".png") + "_home.png")
	var p = load("res://scripts/ui/RankPopup.gd").open()
	await create_timer(1.0).timeout
	var texts := _texts(p)
	_ok(texts.any(func(t): return t.contains("联调部落（我）")), "弹窗里有自己那行并标了（我）")
	_ok(texts.any(func(t): return t.begins_with("第 ") and t.ends_with(" 名")), "弹窗显示名次")
	if shot != "":
		await create_timer(0.5).timeout
		root.get_viewport().get_texture().get_image().save_png(shot)
		print("  shot ", shot)
	p.close()
	await create_timer(0.4).timeout

	# 服务器不通
	rank.url = "http://127.0.0.1:1"
	var t0 := Time.get_ticks_msec()
	p = load("res://scripts/ui/RankPopup.gd").open()
	var waited := 0
	while waited < 60 and not _texts(p).any(func(t): return t.contains("连不上")):
		await create_timer(0.1).timeout
		waited += 1
	_ok(_texts(p).any(func(t): return t.contains("连不上")), "连不上时显示提示（%d ms）" % (Time.get_ticks_msec() - t0))
	if shot != "":
		await create_timer(0.5).timeout
		root.get_viewport().get_texture().get_image().save_png(shot.trim_suffix(".png") + "_offline.png")
	print("RESULT: ", "PASS" if _fail == 0 else "FAIL %d" % _fail)
	quit(0 if _fail == 0 else 1)

func _texts(n: Node) -> Array:
	var out := []
	if n is Label:
		out.append(n.text)
	for c in n.get_children():
		out.append_array(_texts(c))
	return out
