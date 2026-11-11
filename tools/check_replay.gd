extends SceneTree
## Real Godot client -> FastAPI -> independent headless Godot replay.
var g
var replay
var cloud
var failures := 0
var pid := -1
var calls := 0
const DIR := "user://replay_check/"
const URL := "http://127.0.0.1:18769"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func idle() -> void:
	var start := Time.get_ticks_msec()
	await process_frame
	while (cloud._busy or not replay.inflight.is_empty()) and Time.get_ticks_msec()-start < 30000:
		await process_frame
func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay"); cloud = root.get_node("Cloud")
	g.set_process(false); replay.set_process(false); cloud.set_process(false)
	DirAccess.make_dir_recursive_absolute(DIR)
	for file in DirAccess.get_files_at(DIR): DirAccess.remove_absolute(DIR+file)
	var py := "/tmp/tribemerge-test-venv/bin/python"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--python="): py = arg.trim_prefix("--python=")
	OS.set_environment("TRIBE_ENV", "test"); OS.set_environment("TRIBE_LOG_LEVEL", "WARNING")
	OS.set_environment("TRIBE_REPLAY_GODOT", OS.get_executable_path())
	pid = OS.create_process(py, [ProjectSettings.globalize_path("res://server/run.py"), "--port", "18769", "--database-url", "sqlite:///"+ProjectSettings.globalize_path(DIR+"server.db")])
	cloud.url = URL
	var healthy := false
	for n in 100:
		var response: Array = await cloud._call("GET", "/v1/health", null, "", true)
		if response[0] == 200: healthy = true; break
		await create_timer(0.1).timeout
	check(healthy, "replay server starts")
	if not healthy: finish(); return
	g.save_path = DIR+"save.json"; cloud.state_path = DIR+"cloud.json"
	cloud.token = ""; cloud.kicked = ""; cloud.enabled = true
	replay.authorized = false; replay.pending = []; replay.inflight = {}
	await cloud._register()
	await idle()
	check(replay.authorized and cloud._boot_done, "login receives a trusted snapshot and seed")
	var seed: String = g.random_seed
	var initial: String = replay.digest()
	cloud.synced.connect(func(what, _ok):
		calls+=1
		if what == "replay":
			print("WIRE_STATS ", JSON.stringify(cloud.replay_wire_stats))
			check(int(cloud.replay_wire_stats.get("gzip", 0)) > 0 and (int(cloud.replay_wire_stats.get("ops", 0)) < 10 or int(cloud.replay_wire_stats["gzip"]) < int(cloud.replay_wire_stats["compact"])), "upload sends raw gzip and compresses large batches"))
	cloud.url = "http://127.0.0.1:1"; cloud.online = false
	check(g.try_drop(28,29)=="merge", "main board command executes without network")
	var at_cell := 29
	for n in 400:
		var to := 28 if at_cell == 29 else 29
		check_move(g.try_drop(at_cell,to)!="")
		at_cell=to
	check(calls==0 and replay.pending.size()==401, "401 offline inputs queue without requests or truncation")
	var expected: String = replay.digest()
	g.save_game()
	var stored = JSON.parse_string(FileAccess.get_file_as_string(g.save_path))
	replay.restore(stored); replay.pending=stored["replay_local"]["pending"]
	check(replay.digest()==expected and replay.pending.size()==401, "atomic save restores state, streams and the journal")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	check(replay.digest()==expected, "opening the game UI does not change unlogged game state")
	cloud.url=URL; cloud.online=true
	await replay.upload()
	await idle()
	check(replay.pending.is_empty() and replay.digest()==expected, "all offline batches match independent server replay")
	var session: Array=await cloud._call("POST","/v2/session",{})
	check(session[0]==200 and session[1]["hash"]==expected and g.random_seed==seed, "re-login preserves random seed and confirmed progress")
	# The local file/hash can be modified, but the server only evaluates commands.
	g.amber += 99999
	g.try_drop(at_cell, 28 if at_cell==29 else 29)
	await replay.upload()
	await idle()
	check(replay.digest()==expected and replay.pending.is_empty() and g.amber<99999, "tampered state is rejected and restored to the server checkpoint")
	# New local actions during an in-flight request are retained for a later batch.
	g.try_drop(at_cell,28 if at_cell==29 else 29)
	at_cell=28 if at_cell==29 else 29
	replay.upload()
	g.try_drop(at_cell,28 if at_cell==29 else 29)
	await idle()
	check(replay.pending.is_empty() and g.random_seed==seed, "input during upload is retained and confirmed in the next batch")
	# Simulate server commit followed by a lost response and a process restart.
	g.try_drop(29, 28)
	var ops := []
	for entry in replay.pending:
		var copy: Dictionary = entry.duplicate(true); copy.erase("hash"); ops.append(copy)
	replay.inflight = {"base": replay.base, "rules": replay.rules_hash(), "hash": replay.digest(), "ops": ops,
		"batch": Crypto.new().generate_random_bytes(16).hex_encode()}
	var lost: Array = await cloud._call("POST", "/v2/sync", replay.inflight)
	check(lost[0]==200 and not lost[1].get("reset",true), "server can commit before the client records its acknowledgement")
	g.try_drop(28, 29)
	var after_lost: String = replay.digest()
	g.save_game()
	var restart = JSON.parse_string(FileAccess.get_file_as_string(g.save_path))
	replay.restore(restart)
	replay.pending = restart["replay_local"]["pending"]
	replay.inflight = restart["replay_local"]["inflight"]
	replay.base = int(restart["replay_local"]["base"])
	await replay.connect_session("boot")
	await idle()
	check(replay.pending.is_empty() and replay.digest()==after_lost, "lost acknowledgement and restart preserve later operations without duplicate rewards")
	main.free(); g.main=null
	finish()
func check_move(ok: bool) -> void:
	if not ok: failures+=1
func finish() -> void:
	if pid>0: OS.kill(pid)
	print("RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
