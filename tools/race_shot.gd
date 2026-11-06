extends SceneTree
## 篝火竞速界面截图（不连服务器，往 Race 里塞假数据）。不碰真实存档：存档 / 云 / 排行 / 热卖都指向 user://race_shot/。
## Godot --path . --script tools/race_shot.gd -- --save=user://race_shot/s.json --cloud-off --rank-state=user://race_shot/r.json --cloud-state=user://race_shot/c.json --hot-file=user://race_shot/h.json --out=DIR

var _started := false
var out := "."

func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _shot(name: String) -> void:
	var path := out + "/race_" + name + ".png"
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("shot ", path)
	if name.begins_with("board"):
		var k := float(img.get_width()) / 720.0
		var crop := img.get_region(Rect2i(0, int(140 * k), int(720 * k), int(304 * k)))
		crop.save_png(out + "/race_" + name + "_zoom.png")

func _run() -> void:
	var g := root.get_node("G")
	g.set_process(false)
	root.get_node("Cloud").set_process(false)
	root.get_node("Rank").set_process(false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 11
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	var race = load("res://scripts/net/Race.gd").inst()
	var RP = load("res://scripts/ui/RacePopup.gd")
	var now: float = g.now()
	var start := now - 900.0
	var rules := {"unlock_level": 5, "duration_sec": 7200, "fill_sec": 0, "group_size": 5, "target": 300, "podium": 3, "tier_levels": 5,
		"rewards": [[["amber_3", 30], ["fire_1", 100], ["pack_1", 1]], [["amber_3", 15], ["fire_1", 60], ["chest_1", 1]], [["amber_3", 8], ["fire_1", 30]]],
		"title": {"id": "race_champ", "name": "篝火王", "hours": 24}}
	var names := ["原始人4821", "石头哥", "火苗妹", "长矛", "阿呱"]
	var avs := [2, 0, 3, 4, 6]
	var mk := func(sc: Array, state: String) -> Dictionary:
		var ms := []
		for i in 5:
			ms.append({"slot": i, "name": names[i], "avatar": avs[i], "level": 6, "score": sc[i],
				"finished_at": (start + 3000) if sc[i] >= 150 else null, "last_at": start, "place": null, "me": i == 0})
		return {"id": "g0123456789abcdef", "session": "g0123456789abcdef", "start": start, "end": start + 7200, "ended_at": null,
			"target": 150, "size": 5, "state": state, "members": ms}
	var base := {"ok": true, "current": null, "results": [], "title": null, "rules": rules}
	race._absorb(base.duplicate(true))
	race.ok = true
	race.fetched_once = true
	race._last_ms = Time.get_ticks_msec() + 600000
	race.updated.emit()
	# 0) 主界面没有入口了
	main.show_screen("home")
	await create_timer(0.8).timeout
	_shot("home")
	# 1) 棋盘：没到 5 级，锁着
	main.show_screen("board")
	await create_timer(2.5).timeout
	_shot("board_locked")
	# 2) 5 级：入口「匹配」，开始面板
	g.level = 13
	race.updated.emit()
	await create_timer(0.5).timeout
	_shot("board_idle")
	var p = RP.open()
	await create_timer(1.0).timeout
	_shot("panel_start")
	p.close()
	await create_timer(0.4).timeout
	# 3) 匹配中
	var i1: Dictionary = base.duplicate(true)
	i1["current"] = {"group": mk.call([0, 0, 0, 0, 0], "running"), "me": {"score": 0}}
	race._absorb(i1)
	race._match_until = Time.get_ticks_msec() + 3000
	race.updated.emit()
	p = RP.open()
	await create_timer(0.8).timeout
	_shot("panel_matching")
	p.close()
	await create_timer(0.3).timeout
	# 4) 比赛中：两次快照（第二次触发插值）
	race._match_until = -1
	var i2: Dictionary = base.duplicate(true)
	i2["current"] = {"group": mk.call([64, 88, 71, 45, 22], "running"), "me": {"score": 64}}
	race._absorb(i2)
	var i3: Dictionary = base.duplicate(true)
	i3["current"] = {"group": mk.call([86, 103, 79, 58, 22], "running"), "me": {"score": 86}}
	race._absorb(i3)
	race.updated.emit()
	await create_timer(0.4).timeout
	_shot("board_racing")
	# 香蕉从订单卡飞进入口
	var bs = main.board_screen if "board_screen" in main else null
	var entry = null
	for n in root.find_children("*", "", true, false):
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("RaceEntry.gd"):
			entry = n
	if entry != null:
		entry.fly_from(Vector2(560, 300))
		await create_timer(0.3).timeout
		_shot("board_fly")
	await create_timer(0.6).timeout
	race._disp.clear()
	p = RP.open()
	await create_timer(2.0).timeout
	_shot("panel_race")
	p.close()
	await create_timer(0.4).timeout
	# 5) 结算：第 1 名
	var gr: Dictionary = mk.call([150, 150, 131, 150, 77], "ended")
	var places := [1, 2, 4, 3, 5]
	for k in 5:
		gr["members"][k]["place"] = places[k]
	var res := {"group": gr, "me": {"place": 1, "reward": race.rules()["rewards"][0], "claimed": false, "score": 150}}
	var i5: Dictionary = base.duplicate(true)
	i5["current"] = {"group": gr, "me": res["me"]}
	i5["results"] = [res]
	race._absorb(i5)
	race.updated.emit()  # 入口会自动弹结算
	await create_timer(1.0).timeout
	_shot("panel_result")
	main.close_all()
	await create_timer(0.3).timeout
	_shot("board_ended")
	# 6) 领完：再来一局
	p = RP.start(true)
	await create_timer(1.0).timeout
	_shot("panel_again")
	print("DONE")
	quit(0)
