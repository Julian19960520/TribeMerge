extends Node
## 排行榜客户端（自动加载 Rank）。
## 排名指标：部落解锁进度 = 所有区域已建成的部件总数（G.builds 里每个区域的段数，按部件上限截断）。
## 进度上涨时记下达成时间并自动上传；连不上服务器只记一笔，下次进度变化或打开排行榜时补传。
## 服务器地址：data/rules.json 的 rank_server。状态（昵称、已上传的进度）存在 user://rank_state.json，不动主存档。

signal synced(ok: bool)

## 测试可以用 `-- --rank-state=user://xxx.json` 换一个文件
var state_path := "user://rank_state.json"
const DEFAULT_URL := "http://127.0.0.1:8765"
const TIMEOUT := 4.0
const RETRY_SEC := 90.0

var url := DEFAULT_URL
var top_n := 50
## 主存档里的玩家 id；变了（重新开始）就清空本地记录
var _for_id := ""
var nick := ""
## 本地记到的最高进度和第一次达到它的 Unix 时间
var progress := 0
var reached_at := 0.0
## 服务器已确认的进度；-1 表示还没传上去
var sent := -1
var last_rank := 0
var _sending := false
var _again := false
var _retry_t := -1.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rank-state="):
			state_path = a.trim_prefix("--rank-state=")
	var r: Dictionary = Data.RULES
	url = str(r.get("rank_server", DEFAULT_URL)).strip_edges().trim_suffix("/")
	top_n = clampi(int(r.get("rank_top", 50)), 1, 200)
	_ensure_player_id()
	_load()
	G.changed.connect(_check)
	_check()
	if sent != progress:
		submit.call_deferred()

func _process(delta: float) -> void:
	if _retry_t < 0.0:
		return
	_retry_t -= delta
	if _retry_t < 0.0:
		submit()

## 老存档的默认 id 是 TRB00000000（所有人一样），换成随机的写回存档
func _ensure_player_id() -> void:
	if G.player_id == "" or G.player_id == "TRB00000000":
		G.player_id = "TRB" + str(G.rng.randi_range(10000000, 99999999))
		G.dirty()

# ---------------------------------------------------------------- 进度

## 已建成的部件总数
static func progress_now() -> int:
	var n := 0
	for b in Data.BUILDS:
		if b is Dictionary:
			n += clampi(int(G.builds.get(str(b.get("id", "")), 0)), 0, Data.build_stages(b))
	return n

static func parts_total() -> int:
	var n := 0
	for b in Data.BUILDS:
		if b is Dictionary:
			n += Data.build_stages(b)
	return n

## 全部部件都建好的区域数
static func areas_done() -> int:
	var n := 0
	for b in Data.BUILDS:
		if b is Dictionary and Data.build_stages(b) > 0 and int(G.builds.get(str(b.get("id", "")), 0)) >= Data.build_stages(b):
			n += 1
	return n

static func areas_total() -> int:
	return Data.BUILDS.size()

func _check() -> void:
	if G.player_id != _for_id:
		_reset_for(G.player_id)
	var p := progress_now()
	if p > progress:
		progress = p
		reached_at = Time.get_unix_time_from_system()
		_save()
		submit()

func _reset_for(id: String) -> void:
	_for_id = id
	progress = 0
	reached_at = 0.0
	sent = -1
	last_rank = 0
	if nick == "":
		nick = default_nick()
	_save()

func default_nick() -> String:
	return "原始人" + G.player_id.right(4)

func set_nick(s: String) -> void:
	s = s.strip_edges().replace("\n", " ")
	if s.length() > 12:
		s = s.left(12)
	if s == "":
		s = default_nick()
	if s == nick:
		return
	nick = s
	_save()
	sent = -1
	submit()

# ---------------------------------------------------------------- 网络

## 上传当前进度。上一笔还没回来就排队，回来后再传一次。
func submit() -> void:
	_retry_t = -1.0
	if _sending:
		_again = true
		return
	_sending = true
	var body := JSON.stringify({"id": G.player_id, "name": nick, "progress": progress,
		"time": reached_at if reached_at > 0.0 else Time.get_unix_time_from_system()})
	var want := progress
	_request("/api/submit", HTTPClient.METHOD_POST, body, func(ok: bool, d: Dictionary):
		_sending = false
		if ok:
			sent = want
			last_rank = int(d.get("rank", 0))
			_save()
		else:
			_retry_t = RETRY_SEC
		synced.emit(ok)
		if _again:
			_again = false
			submit()
		elif ok and sent != progress:
			submit())

## 查询前 N 名和自己的名次。cb(ok: bool, data: Dictionary)，data 见 server/README.md。
func fetch(cb: Callable) -> void:
	if sent != progress and not _sending:
		submit()
	_request("/api/top?n=%d&id=%s" % [top_n, G.player_id.uri_encode()], HTTPClient.METHOD_GET, "", func(ok: bool, d: Dictionary):
		if ok:
			var me = d.get("me")
			if me is Dictionary:
				last_rank = int(me.get("rank", 0))
		if cb.is_valid():
			cb.call(ok, d))

## 发一个请求；连不上、超时、返回不是 JSON 都算失败，不抛错。
func _request(path: String, method: int, body: String, done: Callable) -> void:
	var h := HTTPRequest.new()
	h.timeout = TIMEOUT
	add_child(h)
	h.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, raw: PackedByteArray):
		h.queue_free()
		var d = null
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			d = JSON.parse_string(raw.get_string_from_utf8())
		if d is Dictionary and d.get("ok", false):
			done.call(true, d)
		else:
			done.call(false, {}))
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := h.request(url + path, headers, method, body)
	if err != OK:
		h.queue_free()
		done.call.call_deferred(false, {})

# ---------------------------------------------------------------- 本地状态

func _load() -> void:
	var f := FileAccess.open(state_path, FileAccess.READ)
	var d = null
	if f != null:
		d = JSON.parse_string(f.get_as_text())
	if d is Dictionary and str(d.get("player_id", "")) == G.player_id:
		_for_id = G.player_id
		nick = str(d.get("nick", ""))
		progress = int(d.get("progress", 0))
		reached_at = float(d.get("reached_at", 0.0))
		sent = int(d.get("sent", -1))
		if nick == "":
			nick = default_nick()
	else:
		if d is Dictionary:
			nick = str(d.get("nick", ""))
		_reset_for(G.player_id)

func _save() -> void:
	var f := FileAccess.open(state_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"player_id": _for_id, "nick": nick, "progress": progress,
		"reached_at": reached_at, "sent": sent}))
