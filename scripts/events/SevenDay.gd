class_name SevenDay
extends RefCounted
## All seven pages share lifetime counters; page numbers never gate progress.
static var _config: Dictionary = {}
static var busy := false
static func config() -> Dictionary:
	if _config.is_empty(): _config = JSON.parse_string(FileAccess.get_file_as_string("res://data/seven_day.json"))
	return _config
static func state() -> Dictionary:
	if G.seven_day.is_empty():
		G.seven_day = {"id": config()["id"], "stats": {}, "claimed": {}, "stages": {}, "days": {}}
		G.dirty()
	return G.seven_day
static func login(day := "") -> void:
	if G.server_mode(): return
	if day == "": day = G.today()
	var s := state()
	if not s["days"].has(day):
		s["days"][day] = true
		s["stats"]["login_days"] = s["days"].size()
		_changed()
static func record(metric: String, amount: int) -> void:
	if G.server_mode() or amount <= 0 or metric == "paid_cents": return
	var s := state()
	s["stats"][metric] = int(s["stats"].get(metric, 0)) + amount
	_changed()
static func _changed() -> void:
	G.dirty()
	G.seven_day_changed.emit()
static func value(task: Dictionary) -> int:
	return int(state()["stats"].get(str(task["metric"]), 0))
static func done(task: Dictionary) -> bool: return value(task) >= int(task["target"])
static func got(task: Dictionary) -> bool: return state()["claimed"].has(str(task["id"]))
static func points() -> int:
	var total := 0
	for day in config()["days"]:
		for task in day["tasks"]:
			if got(task): total += int(task["points"])
	return total
static func task_count() -> int:
	var n := 0
	for day in config()["days"]: n += day["tasks"].size()
	return n
static func claimed_count() -> int:
	var n := 0
	for day in config()["days"]:
		for task in day["tasks"]:
			if got(task): n += 1
	return n
static func stage_got(stage: Dictionary) -> bool: return state()["stages"].has(str(stage["id"]))
static func stage_ready(stage: Dictionary) -> bool: return points() >= int(stage["points"]) and not stage_got(stage)
static func day_done(day: int) -> bool:
	for task in config()["days"][day]["tasks"]:
		if not got(task): return false
	return true
static func ready(day := -1) -> bool:
	var days: Array = config()["days"]
	for k in days.size():
		if day >= 0 and day != k: continue
		for task in days[k]["tasks"]:
			if done(task) and not got(task): return true
	if day < 0:
		for stage in config()["milestones"]:
			if points() >= int(stage["points"]) and not state()["stages"].has(str(stage["id"])): return true
	return false
static func find_entry(id: String, stage: bool) -> Dictionary:
	if stage:
		for entry in config()["milestones"]:
			if str(entry["id"]) == id: return entry
	else:
		for day in config()["days"]:
			for task in day["tasks"]:
				if str(task["id"]) == id: return task
	return {}
static func claim(id: String, stage := false) -> Dictionary:
	if G.replay_input(): return await Replay.perform("seven", {"id": id, "stage": stage})
	if busy: return {"error": ""}
	var entry := find_entry(id, stage)
	if entry.is_empty(): return {"error": "任务不存在"}
	var s := state()
	var book: Dictionary = s["stages"] if stage else s["claimed"]
	if book.has(id): return {"error": "已领取"}
	if (points() < int(entry["points"]) if stage else not done(entry)): return {"error": "尚未完成"}
	busy = true
	if G.server_mode():
		var response: Dictionary = await G._cloud().act("/v1/seven-day/claim", {"entry": id, "stage": stage}, entry["rewards"])
		if not response.get("ok", false):
			busy = false
			return {"error": str(response.get("message", "领取失败"))}
	else: book[id] = true
	Rewards.grant(entry["rewards"], Callable(), true)
	G.save_game()
	busy = false
	_changed()
	return {"ok": true}
