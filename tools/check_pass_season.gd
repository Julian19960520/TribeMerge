extends SceneTree
## 通行证赛季换季检查 + 换季后面板截图（独立存档，不碰真实存档）。
## Godot --path . --script tools/check_pass_season.gd -- --cloud-off --save=user://pass_season/s.json --cloud-state=user://pass_season/c.json --rank-state=user://pass_season/r.json --hot-file=user://pass_season/h.json --out=_shots/pass
var _started := false
var out := "."
var fails := 0
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false
func ok(c: bool, label: String) -> void:
	print(("PASS " if c else "FAIL ") + label)
	if not c: fails += 1
func _run() -> void:
	var g := root.get_node("G")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	var start := float(Time.get_unix_time_from_datetime_string(str(Data.PASS_SEASON.get("start", "2026-11-02")) + "T00:00:00")) - 8 * 3600
	var span: int = int(Data.PASS_SEASON.get("days", 35)) * 86400
	g.simulation_time = start + 5 * 86400 + 3600
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 14
	ok(g.pass_season == "0", "season 0 five days after start")
	ok(g.rules.clock.pass_secs_left() == span - 5 * 86400 - 3600, "countdown reads the real season end")
	g.pass_pts = 120
	g.pass_tier = 2
	g.pass_super_bonus = true
	ok(not (await g.claim_pass_free(1)).is_empty(), "claim free tier 1 in season 0")
	ok(not (await g.claim_pass_prem(1)).is_empty(), "claim vip tier 1 in season 0")
	g.save_game()
	g.load_game()
	ok(g.pass_season == "0" and g.pass_pts == 120 and g.pass_free == [1], "same season survives save/load")
	g.rules.clock._check_day()
	ok(g.pass_pts == 120 and g.pass_tier == 2, "no reset inside the season")
	g.simulation_time = start + span + 60
	g.rules.clock._check_day()
	ok(g.pass_season == "1", "season 1 after one span")
	ok(g.pass_pts == 0 and g.pass_tier == 0 and g.pass_free.is_empty() and g.pass_prem.is_empty() and g.pass_super.is_empty() and g.pass_endless == 0 and not g.pass_super_bonus, "rollover clears points, claims and tier")
	ok((await g.claim_pass_free(2)).is_empty(), "old-season tier is not claimable after rollover")
	g.simulation_time = start + span + 120
	g.pass_pts += 1
	ok(g.pass_season == "1" and g.pass_pts == 1, "points accrue in the new season")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board")
	await create_timer(1.5).timeout
	main.open("pass")
	await create_timer(1.5).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/pass_after_rollover.png")
	print("RESULT: %d failures" % fails)
	quit(1 if fails > 0 else 0)
