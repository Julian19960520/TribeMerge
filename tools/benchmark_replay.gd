extends SceneTree
## Repeatable worker benchmark; same fixture and commands across source revisions.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var game = root.get_node("G")
	var replay = root.get_node("Replay")
	game.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = true; replay.authorized = true; replay.executing = true
	replay.seq = 0; replay.clock = 1794240000; replay.meta = {"allow_gm": true}
	game.simulation_time = replay.clock; game.rng.seed = 42
	game.new_game(); game.level = 30; game.gm_activities = true
	game.tutorial_on = false; game.seen_tutorial = true
	replay.advance(); replay._canonicalize_live(); replay.executing = false
	var fixture: Dictionary = replay.snapshot()
	var timings := []
	var digest := ""
	for round_index in 6:
		replay.restore(fixture)
		var started := Time.get_ticks_usec()
		for index in 1024:
			var result: Dictionary = replay.perform("boost", {"on": index % 2 == 0}, replay.clock)
			if result.has("error"):
				push_error(str(result)); quit(1); return
		var duration := Time.get_ticks_usec() - started
		var current: String = replay.digest()
		if digest != "" and digest != current:
			push_error("Non-deterministic benchmark result"); quit(1); return
		digest = current
		if round_index > 0: timings.append(duration / 1024.0)
	timings.sort()
	print("REPLAY_BENCHMARK ", JSON.stringify({"commands": 1024, "rounds": 5, "median_usec_per_command": timings[2], "samples_usec": timings, "hash": digest}))
	quit(0)
