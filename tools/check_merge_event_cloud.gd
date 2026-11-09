extends SceneTree
## Real Godot ↔ FastAPI regression: local activity play while offline/busy,
## durable >400-event queue, multi-batch catch-up before claims, and cloud restore.
## --headless --path . --script tools/check_merge_event_cloud.gd -- --python=/path/to/python
const DIR := "user://merge_event_cloud_check/"
const URL := "http://127.0.0.1:18768"
var failures := 0
var requests := 0
var pid := -1
var g
var cloud
var ev

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func idle() -> void:
	var start := Time.get_ticks_msec()
	await process_frame
	while (cloud._busy or cloud._hot_busy) and Time.get_ticks_msec() - start < 15000:
		await process_frame
	check(not cloud._busy and not cloud._hot_busy, "network request completes")

func finish() -> void:
	if pid > 0: OS.kill(pid)
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func run() -> void:
	g = root.get_node("G")
	cloud = root.get_node("Cloud")
	ev = load("res://scripts/events/MergeEvent.gd")
	g.set_process(false)
	cloud.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for file in DirAccess.get_files_at(DIR): DirAccess.remove_absolute(DIR + file)
	var py := "python"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--python="): py = arg.trim_prefix("--python=")
	OS.set_environment("TRIBE_ENV", "test")
	OS.set_environment("TRIBE_LOG_LEVEL", "WARNING")
	pid = OS.create_process(py, [ProjectSettings.globalize_path("res://server/run.py"), "--port", "18768",
		"--database-url", "sqlite:///" + ProjectSettings.globalize_path(DIR + "server.db")])
	cloud.url = URL
	var ready := false
	for n in 100:
		var health: Array = await cloud._call("GET", "/v1/health", null, "", true)
		if health[0] == 200:
			ready = true
			break
		await create_timer(0.1).timeout
	check(ready, "isolated server starts")
	if not ready:
		finish()
		return
	g.save_path = DIR + "save.json"
	g.new_game()
	g.tutorial_on = false
	g.loaded_save = false
	g.save_game()
	cloud.state_path = DIR + "cloud.json"
	cloud.token = ""
	cloud.account_id = ""
	cloud.events = []
	cloud.kicked = ""
	cloud.enabled = true
	cloud._boot_done = false
	await cloud._register()
	await idle()
	var unlock: Dictionary = await cloud.act("/v1/gm/activities")
	check(cloud._boot_done and unlock.get("ok", false) and g.gm_activities, "isolated online account unlocks the activity for testing")
	cloud.synced.connect(func(_what, _ok): requests += 1)
	cloud.url = "http://127.0.0.1:1"
	cloud.online = false
	cloud._busy = true # A stalled background upload must not lock activity input.
	var c: Dictionary = ev.current()
	var order := {"items": ["fruit_6"], "rw": {"shell": 1}}
	cloud.event({"type": "order", "order": order})
	ev.on_order(order)
	var start := Time.get_ticks_msec()
	var first: Dictionary = await ev.act(c, "spawn")
	check(first.get("to") == 93 and Time.get_ticks_msec() - start < 500, "offline spawn finishes locally while upload is busy")
	await ev.act(c, "drop", {"from": 93, "to": 90})
	await ev.act(c, "spawn")
	var merged: Dictionary = await ev.act(c, "drop", {"from": 93, "to": 90})
	check(merged.get("kind") == "merge" and ev.state(c)["cells"][84]["lock"] == 1, "offline merge reveals the next tile immediately")
	var at_cell := 90
	for n in 450:
		var dest := 91 if at_cell == 90 else 90
		var result: Dictionary = await ev.act(c, "drop", {"from": at_cell, "to": dest})
		if result.has("error"):
			check(false, "local move %d" % n)
			break
		at_cell = dest
	check(requests == 0 and cloud.events.size() >= 455, "455+ operations queue without any network request or truncation")
	var expected: Dictionary = g.merge_events.duplicate(true)
	# JSON reload represents numeric fields as floats; compare persisted values.
	var queued: Array = JSON.parse_string(JSON.stringify(cloud.events))
	var stash: Array = g.stash.duplicate(true)
	g.save_game()
	cloud._save_state()
	g.merge_events = {}
	cloud.events = []
	g.load_game()
	cloud._load_state()
	check(g.merge_events == expected and JSON.stringify(cloud.events) == JSON.stringify(queued), "local board and complete queue survive reload")
	cloud.apply_state({"merge_events": {c["key"]: ev.fresh(c)}})
	check(g.merge_events == expected, "late server state cannot replace pending local moves")
	cloud._busy = false
	cloud._boot_done = false
	var denied: Dictionary = await ev.act(c, "claim")
	check(denied.has("error") and JSON.stringify(cloud.events) == JSON.stringify(queued) and g.stash == stash, "offline claim preserves progress and does not grant rewards")
	cloud._boot_done = true
	cloud.online = true
	cloud.url = URL
	var claim: Dictionary = await ev.act(c, "claim")
	check(claim.has("error") and cloud.events.is_empty(), "claim drains all batches before checking milestone eligibility")
	check(g.merge_events == expected and g.stash == stash, "server replay agrees with local cells, points and resource drops")
	var duplicate: Array = await cloud._call("POST", "/v1/events", {"events": queued.slice(0, 200)})
	check(duplicate[0] == 200 and duplicate[1]["events"].all(func(e): return e.get("dup", false)), "retry acknowledges old inputs without repeating them")
	# Start a real upload, then continue playing before its response arrives.
	cloud._upload()
	await ev.act(c, "drop", {"from": 90, "to": 91})
	await idle()
	check(ev.state(c)["cells"][91]["id"] == "moon_2" and not cloud.events.is_empty(), "in-flight upload leaves later local moves intact")
	await cloud._upload()
	check(cloud.events.is_empty() and ev.state(c)["cells"][91]["id"] == "moon_2", "next upload confirms the later move")
	var saved: Array = await cloud._call("GET", "/v1/save", null)
	expected = g.merge_events.duplicate(true)
	g.merge_events = {}
	cloud._apply_save(saved[1]["data"], saved[1]["version"], saved[1]["hash"])
	check(g.merge_events == expected, "fresh-device cloud restore includes the activity board")
	finish()
