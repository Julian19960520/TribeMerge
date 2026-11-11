extends SceneTree
## Real Godot client -> FastAPI cloud saves: first upload, offline play, lost replies,
## client authority and adopting progress written by another device.
## Usage: godot --headless --path . --script res://tools/check_cloud_save.gd -- --replay-test --cloud-off --save=user://cloud_save_check/boot.json --cloud-state=user://cloud_save_check/boot-cloud.json --python=<server python>
var g
var replay
var cloud
var failures := 0
var pid := -1
const DIR := "user://cloud_save_check/"
const URL := "http://127.0.0.1:18769"

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func idle() -> void:
	var start := Time.get_ticks_msec()
	await process_frame
	while (cloud._busy or not replay.inflight.is_empty()) and Time.get_ticks_msec() - start < 30000:
		await process_frame

func session(token := "") -> Dictionary:
	var response: Array = await cloud._call("POST", "/v2/session", {}, "", false, token)
	return response[1] if response[0] == 200 else {}

func unpack(data: Dictionary) -> Dictionary:
	var raw := Marshalls.base64_to_raw(str(data["data"])).decompress_dynamic(4 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	return JSON.parse_string(raw.get_string_from_utf8())

func pack(state: Dictionary, base: int) -> Dictionary:
	var text := JSON.stringify(state)
	return {"base": base, "hash": text.sha256_text(),
		"data": Marshalls.raw_to_base64(text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))}

func merge_once() -> bool:
	# Ping-pong a mergeable pair on the tutorial board; each move is one command.
	return g.try_drop(28, 29) != "" or g.try_drop(29, 28) != ""

func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay"); cloud = root.get_node("Cloud")
	g.set_process(false); replay.set_process(false); cloud.set_process(false)
	DirAccess.make_dir_recursive_absolute(DIR)
	for file in DirAccess.get_files_at(DIR): DirAccess.remove_absolute(DIR + file)
	var py := "python"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--python="): py = arg.trim_prefix("--python=")
	OS.set_environment("TRIBE_ENV", "test"); OS.set_environment("TRIBE_LOG_LEVEL", "WARNING")
	pid = OS.create_process(py, [ProjectSettings.globalize_path("res://server/run.py"), "--port", "18769",
		"--database-url", "sqlite:///" + ProjectSettings.globalize_path(DIR + "server.db")])
	cloud.url = URL
	var healthy := false
	for n in 150:
		var response: Array = await cloud._call("GET", "/v1/health", null, "", true)
		if response[0] == 200: healthy = true; break
		await create_timer(0.1).timeout
	check(healthy, "cloud server starts without any Godot dependency")
	if not healthy: finish(); return
	g.save_path = DIR + "save.json"; cloud.state_path = DIR + "cloud.json"
	cloud.token = ""; cloud.kicked = ""; cloud.enabled = true

	# 1. Play starts before any network; the first login uploads this device's progress.
	check(replay.authorized and merge_once(), "a new player can merge before contacting the server")
	await cloud._register()
	await idle()
	var first := await session()
	check(cloud._boot_done and replay.base == 1 and not replay.needs_upload(), "first login uploads local progress as version 1")
	check(first.get("hash", "") == replay.digest() and first.get("mine", false), "cloud stores exactly the local snapshot")

	# 2. Offline play keeps working and uploads once connectivity returns.
	cloud.url = "http://127.0.0.1:1"
	var moved := 0
	for n in 40: moved += int(merge_once())
	await replay.upload()
	check(moved == 40 and replay.needs_upload() and replay.base == 1 and not cloud.online, "offline commands stay local and pending")
	cloud.url = URL
	await replay.upload()
	await idle()
	check(replay.base == 2 and replay.pending.is_empty() and (await session())["hash"] == replay.digest(), "reconnecting uploads the newest snapshot")

	# 3. Commands performed during an in-flight upload stay pending for the next one.
	merge_once()
	replay.upload()  # not awaited: the request is in flight while the player keeps merging
	merge_once()
	await idle()
	check(replay.base == 3 and replay.pending.size() == 1, "input during upload is kept for the next upload")
	await replay.upload()
	await idle()

	# 4. Lost reply: the server committed but the client never learned the new version.
	merge_once()
	var lost: Array = await cloud._call("POST", "/v2/save", pack(replay.snapshot(), replay.base))
	check(lost[0] == 200 and not lost[1]["conflict"], "server commits an upload whose reply is then lost")
	merge_once()
	var stale_base: int = replay.base
	await replay.upload()
	await idle()
	check(replay.base == stale_base + 2 and (await session())["hash"] == replay.digest(), "same device overwrites its own unacknowledged save")

	# 5. Restarting the client keeps the confirmed version and pending commands.
	merge_once()
	var expected: String = replay.digest()
	g.save_game()
	var stored = JSON.parse_string(FileAccess.get_file_as_string(g.save_path))
	check(int(stored["replay_local"]["base"]) == replay.base and stored["replay_local"]["pending"].size() == 1, "checkpoint persists cloud version and unsynced commands")
	replay.restore(stored)
	check(replay.digest() == expected, "checkpoint restores the same state")
	await replay.upload()
	await idle()

	# 6. Another device takes over the account and progresses; this device adopts that progress on relogin.
	var code: String = await cloud.make_transfer_code()
	var other: Array = await cloud._call("POST", "/v1/auth/transfer", {"account_id": cloud.account_id, "code": code, "device_id": "device-B"}, "", true)
	check(other[0] == 200, "second device logs in with a transfer code")
	var token_b := str(other[1]["token"])
	var cloud_b := await session(token_b)
	check(not cloud_b["mine"], "second device sees a save written by someone else")
	var state_b := unpack(cloud_b)
	state_b["amber"] = int(state_b["amber"]) + 7
	var upload_b: Array = await cloud._call("POST", "/v2/save", pack(state_b, int(cloud_b["version"])), "", false, token_b)
	check(upload_b[0] == 200 and not upload_b[1]["conflict"], "second device uploads newer progress")
	merge_once()
	await replay.upload()
	check(cloud.kicked == "session_replaced", "the replaced device cannot overwrite the account")
	var code_b: Array = await cloud._call("POST", "/v1/account/transfer-code", {}, "", false, token_b)
	var relogin: Dictionary = await cloud.login_transfer(cloud.account_id, str(code_b[1]["code"]))
	await idle()
	check(relogin.get("same", false) and replay.base == int(upload_b[1]["version"]) and g.amber == int(state_b["amber"]), "relogin adopts the other device's newer save")
	check(replay.pending.is_empty() and not replay.needs_upload(), "adopting discards this device's superseded commands")
	finish()

func finish() -> void:
	if pid > 0: OS.kill(pid)
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
