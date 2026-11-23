extends SceneTree
## Drives the actual UI and shared commands from the opening through construction 3.
## No board items or currencies are injected. --shots-dir=DIR captures each lesson.
var failures := 0
var main
var game
var replay
var shots := ""
var checkpoint_out := ""
var checkpoint_checked := false
var bot
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
## 每进入一个新步骤：截图，并在生产器升级中途验证一次快照恢复
func _on_step(step: String) -> void:
	if shots != "":
		await create_timer(0.45).timeout
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(shots + "/" + step + ".png")
	if not checkpoint_checked and step == "gen_merge3":
		var snap: Dictionary = replay.snapshot()
		var before := JSON.stringify(game.rules.onboarding.progress())
		replay.restore(snap)
		check(JSON.stringify(game.rules.onboarding.progress()) == before, "中途恢复保留当前步骤和已发订单，不重发奖励")
		checkpoint_checked = true
func run() -> void:
	game = root.get_node("G"); replay = root.get_node("Replay")
	game.simulation_time = 1794240000
	game.new_game()
	replay.meta = {}; replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = 1794240000
	game.random_seed = "reference-full-playthrough"; game.random_streams = {}
	replay.executing = true; replay.advance(); replay._canonicalize_live(); replay.executing = false
	game.clear_presentations()
	main = load("res://main.tscn").instantiate(); root.add_child(main)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots-dir="): shots = arg.trim_prefix("--shots-dir=")
		if arg.begins_with("--checkpoint-out="): checkpoint_out = arg.trim_prefix("--checkpoint-out=")
	await create_timer(0.2).timeout
	check(main.screen == "home" and game.orders.is_empty(), "#1 外景开场，尚无订单")
	check(game.energy == 100 and game.shells == 0 and game.amber == 30, "开局100体力、0不那那、30琥珀")
	bot = load("res://tools/sim/GuideBot.gd").new()
	bot.main = main; bot.game = game; bot.replay = replay
	bot.on_step = _on_step
	root.add_child(bot)
	if not await bot.play() and bot.error != "":
		check(false, bot.error.get_slice(char(10), 0))
		print(bot.error)
	check(not game.tutorial_on and game.level >= 5 and int(game.builds.get("fire", 0)) >= 4, "#131 完整流程走到5级、第三次建设完")
	for row in game.rules.onboarding.config()["stages"]:
		var key := str(row["key"])
		if key == "complete": continue
		check(bot.seen.has(key) or game.rules.onboarding.progress().get("completed", []).has(key), "实际经过 " + key)
	check(bot.free_seen, "体力耗尽后用过首次免费补充")
	check(bot.manual_seen, "菜做完后从设备取出，再提交订单")
	check(checkpoint_checked, "在生产器升级中途恢复过快照")
	var opened := []
	for i in game.board.size():
		if int(game.board[i]["lock"]) != 2: opened.append(i)
	print("OPENED ", opened)
	print("COMMANDS ", bot.steps, " WAITED_MIN ", bot.waited_min, " AMBER ", game.amber)
	if failures == 0 and checkpoint_out != "":
		var file := FileAccess.open(checkpoint_out, FileAccess.WRITE)
		file.store_string(JSON.stringify(replay.snapshot(), "\t")); file.close()
	await create_timer(1.0).timeout
	main.free(); game.main = null
	await process_frame
	await process_frame
	quit(1 if failures else 0)
