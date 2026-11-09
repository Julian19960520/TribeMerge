class_name TigerEscape
extends RefCounted
## 本地与服务端共用 tiger_escape.json；在线时只由服务端计分和发奖。
const CONFIG = preload("res://data/tiger_escape.json")
static var busy := false
static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty(): _config = Data.ConfigFiles.ints(CONFIG.data)
	return _config

static func state() -> Dictionary:
	if G.tiger_escape.is_empty(): G.tiger_escape = {"rounds": 0, "round": {}}
	return G.tiger_escape

static func round_state() -> Dictionary:
	return state()["round"]

static func unlocked() -> bool:
	return G.gm_activities or G.level >= int(config()["unlock_level"])

static func tick() -> void:
	if G.server_mode(): return
	var m := round_state()
	if m.is_empty() or m["status"] != "running": return
	var destroyed := mini(m["stages"].size() - 1, int(maxf(0, G.now() - float(m["start"])) / float(m["interval"])) - 1)
	var previous := int(m["destroyed"])
	m["destroyed"] = maxi(previous, mini(destroyed, int(m["stage"])))
	if destroyed >= int(m["stage"]):
		m["status"] = "lost"
		m["finished_at"] = float(m["start"]) + (int(m["stage"]) + 1) * float(m["interval"])
	if previous != int(m["destroyed"]): G.dirty()

static func on_merge() -> void:
	if G.server_mode(): return
	tick()
	var m := round_state()
	if m.is_empty() or m["status"] != "running": return
	m["points"] = int(m["points"]) + int(m["points_per_merge"])
	while int(m["stage"]) < m["stages"].size() and int(m["points"]) >= int(m["stages"][int(m["stage"])]["points"]):
		m["points"] = int(m["points"]) - int(m["stages"][int(m["stage"])]["points"])
		m["stage"] = int(m["stage"]) + 1
	if int(m["stage"]) == m["stages"].size():
		m["status"] = "won"
		m["points"] = 0
		m["finished_at"] = G.now()
	G.dirty()

static func pending_rewards(m: Dictionary) -> Array:
	var rewards: Array = []
	for n in range(1, int(m.get("stage", 0)) + 1):
		if not n in m["claimed"]: rewards.append_array(m["stages"][n - 1]["rewards"].duplicate(true))
	return rewards

static func local_action(action: String, node := 0) -> Dictionary:
	if not unlocked(): return {"error": "%d级解锁逃离剑齿虎" % int(config()["unlock_level"])}
	tick()
	var s := state()
	var m := round_state()
	if action == "refresh": return {}
	if action in ["join", "restart"]:
		if not m.is_empty() and m["status"] == "running": return {"error": "这局逃生还没结束"}
		if action == "join" and not m.is_empty(): return {"error": "请结算后再出发"}
		if action == "restart" and m.is_empty(): return {"error": "请先开始逃生"}
		var rewards := pending_rewards(m) if not m.is_empty() else []
		s["rounds"] = int(s["rounds"]) + 1
		s["round"] = {"id": s["rounds"], "start": G.now(), "stage": 0, "points": 0, "destroyed": -1,
			"status": "running", "claimed": [], "stages": config()["stages"].duplicate(true),
			"interval": config()["attack_interval_sec"], "points_per_merge": maxi(1, int(config()["points_per_merge"]))}
		return {"rewards": rewards}
	if action == "claim":
		if m.is_empty() or node < 1 or node > int(m["stage"]) or node in m["claimed"]: return {"error": "礼包尚未到达或已领取"}
		m["claimed"].append(node)
		return {"rewards": m["stages"][node - 1]["rewards"].duplicate(true)}
	return {"error": "未知操作"}

static func act(action: String, node := 0) -> Dictionary:
	if busy: return {"error": "正在处理"}
	busy = true
	var result: Dictionary
	if G.server_mode():
		var minus: Array = []
		var m := round_state()
		if action == "restart" and not m.is_empty(): minus = pending_rewards(m)
		elif action == "claim" and not m.is_empty() and node > 0 and node <= int(m["stage"]) and not node in m["claimed"]:
			minus = m["stages"][node - 1]["rewards"]
		var response: Dictionary = await G._cloud().act("/v1/tiger/action", {"action": action, "node": node}, minus)
		result = response.get("give", {}) if response.get("ok", false) else {"error": response.get("message", "暂时无法连接")}
	else:
		result = local_action(action, node)
	busy = false
	if not result.has("error"):
		Rewards.grant(result.get("rewards", []), Callable(), false)
		G.save_game()
		G.changed.emit()
	return result

static func attack_left() -> int:
	var m := round_state()
	if m.is_empty() or m["status"] != "running": return 0
	var interval := float(m["interval"])
	var passed := int(maxf(0, G.now() - float(m["start"])) / interval)
	return maxi(0, int(ceil(float(m["start"]) + (passed + 1) * interval - G.now())))
