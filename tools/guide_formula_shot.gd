extends SceneTree
## 新手引导「配方」气泡截图：merge1 / merge2 / make_fruit2 这几步带「物品 + 物品 → 结果」一行。
## Godot --path . --script tools/guide_formula_shot.gd -- --cloud-off --save=user://guide_shot/s.json --cloud-state=user://guide_shot/c.json --rank-state=user://guide_shot/r.json --hot-file=user://guide_shot/h.json
var g
var main
func _initialize() -> void:
	run.call_deferred()
func _shot(n: String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://_shots/guide")
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_viewport().get_texture().get_image().save_png(dir + "/guide_" + n + ".png")
	print("shot ", dir + "/guide_" + n + ".png")
func run() -> void:
	g = root.get_node("G")
	var replay = root.get_node("Replay")
	replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = false; replay.authorized = true
	replay.executing = true
	replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = 1794240000; replay.meta = {}; g.simulation_time = replay.clock
	g.random_seed = "guide-shot"; g.random_streams = {}
	g.new_game()
	replay.advance(); replay._canonicalize_live(); replay.executing = false
	g.clear_presentations()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	main.show_screen("board", true)
	await create_timer(0.6).timeout
	var ob = g.rules.onboarding
	print("active=", ob.active(), " guide=", main._guide)
	for key in ["merge1", "merge2", "welcome"]:
		var i: int = ob.stage_index(key)
		ob.progress()["step"] = i
		if main._guide != null: main._guide.present()
		await _shot(key)
	quit()
