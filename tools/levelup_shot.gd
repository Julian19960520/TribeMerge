extends SceneTree
## 升级领奖流程截图：丰收圣筐、升级面板、新生产器面板、获得奖励、引导里的「新的心愿来啦」（不碰真实存档）。
## Godot --path . --script tools/levelup_shot.gd -- --save=user://lv_shot/s.json --cloud-off --rank-state=user://lv_shot/r.json --cloud-state=user://lv_shot/c.json --hot-file=user://lv_shot/h.json --out=DIR [--level=N] [--only=a,b]
var out := "."
var lv := 5
var only: Array = []
var g
var main

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--level="): lv = int(a.trim_prefix("--level="))
		if a.begins_with("--only="): only = a.trim_prefix("--only=").split(",")
	_run.call_deferred()

func _want(n: String) -> bool:
	return only.is_empty() or n in only

func _shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/lv_" + n + ".png")
	print("shot ", n)

func _close_popups() -> void:
	for c in main.popup_layer.get_children(): c.queue_free()
	await create_timer(0.3).timeout

func _run() -> void:
	g = root.get_node("G")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = lv
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board")
	await create_timer(1.2).timeout
	if _want("chest"):
		main._play_order_chest([["xp_1", 1], ["coin_1", 2], ["energy_1", 1]], 0)
		await create_timer(0.9).timeout
		await _shot("chest_a")
		await create_timer(0.9).timeout
		await _shot("chest_b")
		await create_timer(3.0).timeout
	if _want("levelup"):
		main.open("levelup")
		await create_timer(0.25).timeout
		await _shot("levelup_early")
		await create_timer(1.2).timeout
		await _shot("levelup")
		await _close_popups()
	if _want("gen"):
		main._rw_q.append(func(): return load("res://scripts/ui/popups/RewardPopups.gd").new_generator(_gen_id()))
		main._pump_rewards()
		await create_timer(2.6).timeout
		await _shot("gen")
		await _close_popups()
	if _want("gen1"):
		main._rw_q.append(func(): return load("res://scripts/ui/popups/RewardPopups.gd").new_generator(_first_gen()))
		main._pump_rewards()
		await create_timer(2.6).timeout
		await _shot("gen1")
		await _close_popups()
	if _want("board"):
		main.popup_layer.present(load("res://scripts/ui/popups/RewardPopups.gd").reward_screen([["coin_1", 3], ["energy_1", 20], ["xp_1", 2]]))
		await create_timer(1.4).timeout
		await _shot("board_reward")
		await _close_popups()
	if _want("info"):
		main.open("level")
		await create_timer(0.8).timeout
		await _shot("level_info")
		await _close_popups()
	if _want("start"):
		main.open("orders_start")
		await create_timer(0.8).timeout
		await _shot("orders_start")
		await _close_popups()
	quit()

func _gen_id() -> String:
	var D = load("res://scripts/Data.gd")
	var hits: Array = []
	for ch in D.CHAINS.keys():
		for k in range(2, 6):
			var id := "%s_%d" % [ch, k]
			if D.type_of(id) == "gen" and not D.gen_stats(id).is_empty() and not D.gen_stats("%s_%d" % [ch, k - 1]).is_empty():
				hits.append(id)
	return str(hits[0]) if not hits.is_empty() else ""

## 第一级就能生产的生产器（「新宝物！」那一版）
func _first_gen() -> String:
	var D = load("res://scripts/Data.gd")
	for ch in D.CHAINS.keys():
		for k in range(1, 6):
			var id := "%s_%d" % [ch, k]
			if D.type_of(id) == "gen" and not D.gen_stats(id).is_empty():
				if k == 1 or D.gen_stats("%s_%d" % [ch, k - 1]).is_empty(): return id
				break
	return ""
