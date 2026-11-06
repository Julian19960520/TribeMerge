extends SceneTree
## 篝火竞速联调：连一个本地服务器（场次用 TRIBE_RACE_OVERRIDES 缩短），报名 → 交单 → 赛道 → 结束 → 结算弹窗领奖。
## 先起服务器（见 DESIGN.md「十三」），再：
## Godot --path . --script tools/race_check.gd -- --cloud-url=http://127.0.0.1:18770 --save=user://race_check/s.json
##   --cloud-state=user://race_check/c.json --rank-state=user://race_check/r.json --hot-file=user://race_check/h.json --out=DIR
## 所有文件都在 user://race_check/ 下，不碰真实存档。

var _started := false
var out := "."
var fails := 0

func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out + "/race_live_" + name + ".png")
	print("shot ", name)

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _run() -> void:
	var g := root.get_node("G")
	g.set_process(false)
	root.get_node("Rank").set_process(false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	g.tutorial_on = false
	g.seen_tutorial = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var cloud = root.get_node("Cloud")
	for i in 100:
		if cloud.can_talk():
			break
		await create_timer(0.2).timeout
	check(cloud.can_talk(), "连上服务器，账号 %s" % cloud.account_id)
	var race = load("res://scripts/net/Race.gd").inst()
	for i in 30:
		if race.ok:
			break
		if not race.loading:
			await race.fetch()
		else:
			await create_timer(0.2).timeout
	check(race.ok, "GET /v1/race")
	# 不限时：直接在棋盘入口打开开始面板、点匹配
	main.show_screen("board")
	await create_timer(2.0).timeout
	var p = load("res://scripts/ui/RacePopup.gd").open()
	await create_timer(1.0).timeout
	_shot("1_start_panel")
	p.close()
	var r: Dictionary = await race.join()
	check(r.get("ok", false), "匹配 %s" % str(r.get("message", "")))
	p = load("res://scripts/ui/RacePopup.gd").race_panel()
	await create_timer(0.8).timeout
	_shot("2_matching")
	await create_timer(3.0).timeout
	_shot("2b_race_panel")
	p.close()
	await create_timer(0.5).timeout
	# 交单：每次在棋盘空格放上订单要的东西，再交付（走 Game.complete_order，事件由 Race 3 秒内交给服务器）
	var amber0: int = g.amber
	var delivered := 0
	var t_end: float = float(race.group().get("end", 0))
	while g.now() < t_end - 3.0 and race.racing():
		var oi := _pick_order(g)
		if oi < 0:
			# 新档只有新手单、G 的 _process 又关着不补单：手动加一张普通随机单（16 火苗，贝币在服务器上限内）
			g.orders.append({"who": 2, "items": ["fruit_5"], "rw": {"shell": 48}, "story": false})
			oi = g.orders.size() - 1
		if oi >= 0:
			_stage(g, g.orders[oi])
			var cells: Array = g.complete_order(oi)
			if not cells.is_empty():
				delivered += 1
		await create_timer(4.0).timeout
		if oi < 0:
			print("没有能交的单：", g.orders.size())
		if delivered % 4 == 1:
			await race.fetch()
			var me: Dictionary = race.me()
			print("t=%d 交了 %d 单，服务器分 %s，名次 %d，组状态 %s" % [int(t_end - g.now()), delivered, str(me.get("score", "?")), race.place_of(me), str(race.group().get("state"))])
		if delivered == 6:
			_shot("3_track_midrace")
	check(delivered > 0, "交了 %d 单" % delivered)
	# 等结束、拉结算
	for i in 60:
		await race.fetch()
		if not race.results().is_empty():
			break
		await create_timer(2.0).timeout
	check(not race.results().is_empty(), "结束后有待领的结算")
	var res: Dictionary = race.results()[0] if not race.results().is_empty() else {}
	var me_res: Dictionary = res.get("me", {})
	print("名次 ", me_res.get("place"), " 分数 ", me_res.get("score"), " 奖励 ", me_res.get("reward"), " 被上限截掉 ", me_res.get("capped"))
	for m in res.get("group", {}).get("members", []):
		print("  #%s %s %s 分%s" % [str(m.get("place")), str(m.get("name")), str(m.get("score")), " (我)" if m.get("me") else ""])
	_shot("4_track_ended")
	main.close_all()
	await create_timer(0.5).timeout
	_shot("5_board_ended")
	p = load("res://scripts/ui/RacePopup.gd").open()
	await create_timer(1.0).timeout
	_shot("6_result_popup")
	var btn = p.find_child("race_claim", true, false)
	check(btn != null, "结算弹窗有领取按钮")
	if btn != null:
		btn.pressed.emit()
		await create_timer(2.5).timeout
		_shot("7_after_claim")
	await race.fetch()
	check(race.results().is_empty(), "领完以后没有待领的结算")
	var rw: Array = me_res.get("reward", []) if me_res.get("reward") is Array else []
	var want := 0
	for x in rw:
		if str(x[0]).begins_with("amber"):
			want += int(x[1])
	# 奖励画面要点「收下」才把琥珀加回本地，这里直接看服务器的余额
	var sv: Array = await cloud._call("GET", "/v1/save", null)
	var srv_amber := int(sv[1].get("state", {}).get("amber", -1)) if sv[1] is Dictionary else -1
	print("服务器琥珀 %d → %d（奖励 %d）" % [amber0, srv_amber, want])
	check(srv_amber == amber0 + want, "琥珀到账（服务器）")
	print("RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)

## 挑一张能交的单：先挑普通单，没有就交剧情单（不挑制作单）
func _pick_order(g) -> int:
	var story := -1
	for i in g.orders.size():
		var o: Dictionary = g.orders[i]
		if str(o.get("kind", "")) == "craft" or (o.get("items", []) as Array).is_empty():
			continue
		if not bool(o.get("story", false)):
			return i
		if story < 0:
			story = i
	return story

## 把订单要的东西摆到棋盘空格上
func _stage(g, o: Dictionary) -> void:
	var need: Array = (o.get("items", []) as Array).duplicate()
	for k in g.board.size():
		if need.is_empty():
			break
		var c: Dictionary = g.board[k]
		if str(c.get("id", "")) == "" or int(c.get("lock", 0)) != 0:
			c["id"] = str(need.pop_back())
			c["lock"] = 0
