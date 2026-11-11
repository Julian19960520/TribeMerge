extends Node
## Account transport and cloud snapshot synchronization. Gameplay stays in Reducer.
signal restored
signal notice(text: String)
signal synced(what: String, ok: bool)
signal account_changed

const DEFAULT_URL := "http://127.0.0.1:8765"
const TIMEOUT := 6.0
const UPLOAD_GAP := 60.0
const RETRY_SEC := 15.0
const QUIT_WAIT := 2.0
const DAY_OFFSET := 28800
var state_path := "user://cloud_state.json"
var url := DEFAULT_URL
var enabled := true
var debug_skew := 0.0
var device_id := ""
var account_id := ""
var token := ""
var expires_at := 0.0
var renew_after := 0.0
var transfer_code := ""
var last_sync := 0.0
var clock_offset := 0.0
var kicked := ""
var online := false
var clock_ready := false
var uploads := 0
var _boot_done := false
var _busy := false
var _last_up := -1.0e9
var _retry_t := -1.0
var _srv_unix := 0.0
var _srv_tick := 0
var _quitting := false
var _pending_login: Dictionary = {}

func _ready() -> void:
	var own_state := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cloud-state="):
			state_path = a.trim_prefix("--cloud-state=")
			own_state = true
		elif a.begins_with("--clock-skew="):
			debug_skew = float(a.trim_prefix("--clock-skew="))
		elif a.begins_with("--cloud-url="):
			url = a.trim_prefix("--cloud-url=")
		elif a == "--cloud-off":
			enabled = false
	# 跑 --script 测试脚本时，没给单独的状态文件就不同步，免得动到真实存档
	if (get_tree().get_script() != null and not own_state) or "--replay-worker" in OS.get_cmdline_user_args() or "--replay-service" in OS.get_cmdline_user_args():
		enabled = false
	if url == DEFAULT_URL:
		url = str(Data.RULES.get("rank_server", DEFAULT_URL))
	url = url.strip_edges().trim_suffix("/")
	get_tree().set_auto_accept_quit(false)
	_load_state()
	if device_id == "":
		device_id = _uuid()
		_save_state()
	if enabled and kicked == "":
		_boot.call_deferred()
	else:
		_set_clock_ready()
		if kicked != "":
			_say.call_deferred(_kick_text(kicked))

func _process(delta: float) -> void:
	if not enabled or _quitting or kicked != "" or _busy: return
	if _retry_t > 0:
		_retry_t -= delta
		return
	if not _boot_done:
		_boot()
	elif token != "" and renew_after > 0 and server_now() > renew_after:
		_refresh_token()
	elif Replay.needs_upload() and _ticks() - _last_up >= UPLOAD_GAP:
		Replay.upload()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		G.save_game()
		flush.call_deferred()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()

func flush() -> void:
	if can_talk(): Replay.upload()

func can_talk() -> bool:
	return enabled and _boot_done and token != "" and kicked == ""

func server_now() -> float:
	if _srv_tick > 0:
		return _srv_unix + float(Time.get_ticks_msec() - _srv_tick) / 1000.0
	return Time.get_unix_time_from_system() + clock_offset + debug_skew

func today() -> String:
	return Time.get_date_string_from_unix_time(int(server_now()) + DAY_OFFSET)

func secs_to_midnight() -> int:
	return 86400 - (int(server_now()) + DAY_OFFSET) % 86400

# ================================================================ 对外：同步

## 关键事件后调用：记一笔「待上传」

func account_info() -> Dictionary:
	if not can_talk():
		return {"ok": false, "message": _kick_text(kicked) if kicked != "" else "连不上服务器"}
	var r := await _call("GET", "/v1/account", null)
	return r[1] if int(r[0]) == 200 else _fail(r)

## 生成新的转移码（旧的作废）。返回 "XXXXX-XXXXX" 或 ""。

func make_transfer_code() -> String:
	if not can_talk():
		return ""
	var r := await _call("POST", "/v1/account/transfer-code", {})
	if int(r[0]) != 200:
		return ""
	transfer_code = str(r[1].get("code", ""))
	_save_state()
	account_changed.emit()
	return transfer_code

func bind_provider(provider: String, credential: String) -> Dictionary:
	if not can_talk():
		return {"ok": false, "message": "连不上服务器"}
	var r := await _call("POST", "/v1/account/bind", {"provider": provider, "credential": credential, "device_id": device_id})
	if int(r[0]) == 200:
		account_changed.emit()
	return r[1] if int(r[0]) == 200 else _fail(r)

## 用转移码登录别的账号。成功后不立刻切换：返回 {"ok", "cloud": 云端摘要, "local": 本机摘要}，
## 由玩家选 use_cloud_login()（推荐）或 keep_local_login()。

func login_transfer(acc: String, code: String) -> Dictionary:
	var r := await _call("POST", "/v1/auth/transfer", {"account_id": acc.strip_edges().to_upper(), "code": code.strip_edges(), "device_id": device_id}, "", true)
	return await _after_login(r)

func login_provider(provider: String, credential: String) -> Dictionary:
	var r := await _call("POST", "/v1/auth/provider", {"provider": provider, "credential": credential, "device_id": device_id}, "", true)
	return await _after_login(r)

func _after_login(r: Array) -> Dictionary:
	if int(r[0]) != 200:
		return _fail(r)
	var d: Dictionary = r[1]
	_pending_login = d
	if str(d.get("account_id", "")) == account_id:
		# 本来就是这个号（比如被顶下线后重新登录）：直接换上新 token，按正常启动拉存档
		await use_cloud_login()
		return {"ok": true, "same": true}
	return {"ok": true, "account_id": d.get("account_id", ""), "cloud": d.get("cloud", {}), "local": local_summary()}

## 用云端进度：作废本机游客号的 token，丢掉本机存档，换成登录的账号并拉它的存档。

func use_cloud_login() -> bool:
	if _pending_login.is_empty(): return false
	var d := _pending_login
	_pending_login = {}
	var same := str(d["account_id"]) == account_id
	if token != "" and not same and kicked == "":
		await _call("POST", "/v1/auth/logout", {}, "", false, token)
	account_id = str(d["account_id"])
	token = str(d["token"])
	expires_at = float(d["expires_at"])
	renew_after = float(d["renew_after"])
	kicked = ""
	if not same: transfer_code = ""
	_save_state()
	await Replay.connect_session("relogin" if same else "login")
	account_changed.emit()
	return true

func keep_local_login() -> void:
	if _pending_login.is_empty():
		return
	var d := _pending_login
	_pending_login = {}
	await _call("POST", "/v1/auth/logout", {}, "", false, str(d.get("token", "")))

## 本机进度摘要，和云端摘要对比给玩家看

func local_summary() -> Dictionary:
	var parts := 0
	for b in Data.BUILDS:
		if b is Dictionary:
			parts += clampi(int(G.builds.get(str(b.get("id", "")), 0)), 0, Data.build_stages(b))
	return {"level": G.level, "parts": parts, "amber": G.amber}

## 进度明显（不是刚开局）：用来决定要不要额外提醒
static func has_progress(s: Dictionary) -> bool:
	return int(s.get("level", 1)) >= 3 or int(s.get("parts", 0)) >= 3

func _fail(r: Array) -> Dictionary:
	var d: Dictionary = r[1] if r[1] is Dictionary else {}
	var msg := str(d.get("message", "连不上服务器，请稍后再试" if int(r[0]) == 0 else "操作失败"))
	return {"ok": false, "error": str(d.get("error", "offline")), "message": msg}

func _boot() -> void:
	if _busy: return
	_retry_t = -1.0
	if token == "": _register()
	else: Replay.connect_session("boot")

func _register() -> void:
	_busy = true
	var r := await _call("POST", "/v1/auth/guest", {"device_id": device_id}, "", true)
	_busy = false
	if int(r[0]) != 200:
		_offline("boot")
		return
	var d: Dictionary = r[1]
	account_id = str(d["account_id"])
	token = str(d["token"])
	expires_at = float(d["expires_at"])
	renew_after = float(d["renew_after"])
	_save_state()
	account_changed.emit()
	Replay.connect_session("login")

func _after_boot() -> void:
	_boot_done = true
	online = true
	_save_state()
	_set_clock_ready()
	synced.emit("boot", true)

func _set_clock_ready() -> void:
	clock_ready = true

func _offline(what: String) -> void:
	online = false
	_retry_t = RETRY_SEC
	if not clock_ready:
		_set_clock_ready()
	synced.emit(what, false)

func _refresh_token() -> void:
	_busy = true
	var r := await _call("POST", "/v1/auth/refresh", {})
	_busy = false
	if int(r[0]) == 200:
		token = str(r[1]["token"])
		expires_at = float(r[1].get("expires_at", 0.0))
		renew_after = float(r[1].get("renew_after", 0.0))
		_save_state()
	else:
		renew_after = server_now() + 3600.0

# ================================================================ 上传

## 规范化后的存档 JSON：先过一遍 parse，读档前后（int / float 混着）得到同一份文本，哈希才对得上

func _quit() -> void:
	if _quitting: return
	_quitting = true
	G.save_game()
	await get_tree().process_frame
	if can_talk() and not _busy: Replay.upload()
	var start := _ticks()
	while _busy and _ticks() - start < QUIT_WAIT:
		await get_tree().process_frame
	_save_state()
	get_tree().quit()

func _ticks() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _uuid() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

## 发请求，返回 [code, data]。连不上 / 超时 code = 0。每次成功都顺手校一下服务器时间。
## 401（被顶下线 / 过期）统一在这里处理。anon = 不带 token；use_token 指定用哪个 token（不触发下线处理）。

func _call(method: String, path: String, body, idem := "", anon := false, use_token := "") -> Array:
	var h := HTTPRequest.new()
	h.timeout = TIMEOUT
	add_child(h)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var tk := use_token if use_token != "" else token
	if not anon and tk != "":
		headers.append("Authorization: Bearer " + tk)
	if idem != "":
		headers.append("Idempotency-Key: " + idem)
	var m := HTTPClient.METHOD_GET
	match method:
		"POST": m = HTTPClient.METHOD_POST
	var sent_at := Time.get_ticks_msec()
	var err := h.request(url + path, headers, m, "" if body == null else JSON.stringify(body))
	if err != OK:
		h.queue_free()
		await get_tree().process_frame
		return [0, {}]
	var res: Array = await h.request_completed
	h.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return [0, {}]
	var d = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not (d is Dictionary):
		return [0, {}]
	var code := int(res[1])
	if d.has("now"):
		var rtt := Time.get_ticks_msec() - sent_at
		var estimate := float(d["now"]) + float(rtt) / 2000.0
		if _srv_tick > 0: estimate = maxf(estimate, server_now())
		_srv_unix = estimate
		_srv_tick = Time.get_ticks_msec()
		clock_offset = _srv_unix - Time.get_unix_time_from_system()
	if code == 401 and not anon and use_token == "":
		if str(d.get("error", "")) == "unauthorized":
			_on_kicked("session_revoked")
		else:
			_on_kicked(str(d.get("error", "")))
	return [code, d]

## 服务器根本不认识这个 token（多半是服务器数据库重建过）：不是被顶下线，
## 用本机存档重新注册一个游客号接着玩，不弹「已退出登录」。

func _on_kicked(why: String) -> void:
	if kicked != "":
		return
	kicked = why if why in ["session_replaced", "token_expired", "session_revoked"] else "session_revoked"
	_save_state()
	_say(_kick_text(kicked))
	account_changed.emit()

func _kick_text(why: String) -> String:
	match why:
		"session_replaced": return "账号已在其他设备登录，本机不再同步。可在 设置 → 账号与数据 重新登录"
		"token_expired": return "登录已过期，请在 设置 → 账号与数据 重新登录"
	return "已退出登录，请在 设置 → 账号与数据 重新登录"

func _load_state() -> void:
	if not FileAccess.file_exists(state_path): return
	var d = JSON.parse_string(FileAccess.get_file_as_string(state_path))
	if not d is Dictionary or int(d.get("schema", 0)) != 1: return
	device_id = str(d["device_id"])
	account_id = str(d["account_id"])
	token = str(d["token"])
	expires_at = float(d["expires_at"])
	renew_after = float(d["renew_after"])
	transfer_code = str(d["transfer_code"])
	last_sync = float(d["last_sync"])
	clock_offset = float(d["clock_offset"])
	kicked = str(d["kicked"])

func _save_state() -> void:
	var temp := state_path + ".tmp"
	DirAccess.make_dir_recursive_absolute(state_path.get_base_dir())
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_error("Cannot persist account state")
		return
	file.store_string(JSON.stringify({"schema": 1, "device_id": device_id, "account_id": account_id, "token": token,
		"expires_at": expires_at, "renew_after": renew_after, "transfer_code": transfer_code,
		"last_sync": last_sync, "clock_offset": clock_offset, "kicked": kicked}))
	file.flush()
	file.close()
	var error := DirAccess.rename_absolute(temp, state_path)
	if error != OK: push_error("Cannot commit account state: " + error_string(error))

func _say(message: String) -> void:
	notice.emit(message)
