extends SceneTree
## Real Godot client -> FastAPI payments: buy amber with the mock provider and see it arrive
## exactly once, including a lost payment reply, a restart and a grant delivered twice.
## Usage: godot --headless --path . --script res://tools/check_payments.gd -- --replay-test --cloud-off --save=user://payments_check/boot.json --cloud-state=user://payments_check/boot-cloud.json --python=<server python>
const DIR := "user://payments_check/"
const URL := "http://127.0.0.1:18771"
## Loaded at run time: scripts that use autoloads cannot be preloaded by a --script main loop.
var Payments
var g
var replay
var cloud
var failures := 0
var pid := -1

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func idle() -> void:
	var start := Time.get_ticks_msec()
	await process_frame
	while (cloud._busy or Payments._delivering or not replay.inflight.is_empty()) and Time.get_ticks_msec() - start < 30000:
		await process_frame

func pending_grants() -> Array:
	var response: Array = await cloud._call("GET", "/v1/payments/grants", null)
	return response[1].get("grants", []) if response[0] == 200 else [{"error": response}]

## Pay on the server without the client hearing back (crash or lost reply after paying).
func pay_silently(product: String) -> String:
	var order: Array = await cloud._call("POST", "/v1/payments/orders", {"product": product, "detail": {}}, "silent-" + cloud._uuid())
	var paid: Array = await cloud._call("POST", "/v1/payments/mock/pay", {"order_id": str(order[1]["order"]["id"])})
	return str(paid[1]["grant"]["id"]) if paid[0] == 200 else ""

func cloud_amber() -> int:
	var response: Array = await cloud._call("POST", "/v2/session", {})
	var raw := Marshalls.base64_to_raw(str(response[1]["data"])).decompress_dynamic(4 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	return int(JSON.parse_string(raw.get_string_from_utf8())["amber"])

func run() -> void:
	Payments = load("res://scripts/net/Payments.gd")
	g = root.get_node("G"); replay = root.get_node("Replay"); cloud = root.get_node("Cloud")
	g.set_process(false); replay.set_process(false); cloud.set_process(false)
	DirAccess.make_dir_recursive_absolute(DIR)
	for file in DirAccess.get_files_at(DIR): DirAccess.remove_absolute(DIR + file)
	var py := "python"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--python="): py = arg.trim_prefix("--python=")
	OS.set_environment("TRIBE_ENV", "test"); OS.set_environment("TRIBE_LOG_LEVEL", "WARNING")
	pid = OS.create_process(py, [ProjectSettings.globalize_path("res://server/run.py"), "--port", "18771",
		"--database-url", "sqlite:///" + ProjectSettings.globalize_path(DIR + "server.db")])
	cloud.url = URL
	var healthy := false
	for n in 150:
		var response: Array = await cloud._call("GET", "/v1/health", null, "", true)
		if response[0] == 200: healthy = true; break
		await create_timer(0.1).timeout
	check(healthy, "payment server starts")
	if not healthy: finish(); return
	g.save_path = DIR + "save.json"; cloud.state_path = DIR + "cloud.json"
	cloud.token = ""; cloud.kicked = ""; cloud.enabled = true

	# 0. Without a server session there is no purchase, only a clear message.
	var before: int = g.amber
	var refused: Dictionary = await Payments.buy("amber:0")
	check(not refused["ok"] and refused["message"] == Payments.OFFLINE and g.amber == before, "buying before login is refused with the offline message")
	await cloud._register()
	await idle()
	check(cloud._boot_done and replay.base == 1, "guest account is online with its first cloud save")

	# 1. Unreachable server after login: refused with the offline message, nothing granted.
	cloud.url = "http://127.0.0.1:1"
	refused = await Payments.buy("amber:0")
	check(not refused["ok"] and refused["message"] == Payments.OFFLINE and g.amber == before, "an unreachable server refuses the purchase with the offline message")
	cloud.url = URL

	# 2. A normal purchase arrives once, is uploaded and acknowledged.
	var bought: Dictionary = await Payments.buy("amber:0")
	await idle()
	check(bought.get("ok", false) and int(bought.get("amber", 0)) == 80 and g.amber == before + 80, "buying the ¥6 pack adds 80 amber")
	check((await pending_grants()).is_empty() and not replay.needs_upload() and await cloud_amber() == before + 80, "the grant is uploaded and acknowledged")
	await Payments.deliver()
	check(g.amber == before + 80, "delivering again does not add amber twice")

	# 3. Paid but the reply was lost and the client restarted: the grant arrives once on the next delivery.
	var lost := await pay_silently("amber:1")
	check(lost != "" and g.amber == before + 80 and (await pending_grants()).size() == 1, "a payment whose reply was lost leaves one pending grant")
	g.save_game()
	var stored = JSON.parse_string(FileAccess.get_file_as_string(g.save_path))
	replay.restore(stored)
	await Payments.deliver()
	await idle()
	check(g.amber == before + 580 and replay.meta["grants"].has(lost), "after a restart the lost purchase is applied once")
	check((await pending_grants()).is_empty() and await cloud_amber() == before + 580, "the recovered grant is uploaded and acknowledged")

	# 4. Applied locally but neither uploaded nor acknowledged: the server sends it again and it is not applied twice.
	var twice := await pay_silently("amber:0")
	var listed: Array = await pending_grants()
	var applied: Dictionary = replay.perform("grant", {"id": twice, "content": listed[0]["content"]})
	check(applied.get("ok", false) and g.amber == before + 660 and (await pending_grants()).size() == 1, "a grant applied before upload is still pending on the server")
	await Payments.deliver()
	await idle()
	check(g.amber == before + 660 and (await pending_grants()).is_empty(), "redelivering an applied grant changes nothing and settles it")
	check(not replay.perform("grant", {"id": twice, "content": listed[0]["content"]}).get("ok", false) and g.amber == before + 660, "the grant command refuses an id it already applied")

	# 5. Server-owned pass tier.
	var pass_tier: int = g.pass_tier
	var vip: Dictionary = await Payments.buy("pass:vip")
	await idle()
	check(pass_tier == 0 and vip.get("ok", false) and g.pass_tier == 1, "buying the pass raises pass_tier")
	var again: Dictionary = await Payments.buy("pass:vip")
	check(not again["ok"] and again["error"] == "already_owned" and g.pass_tier == 1, "the same pass cannot be bought twice in a season")
	finish()

func finish() -> void:
	if pid > 0: OS.kill(pid)
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
