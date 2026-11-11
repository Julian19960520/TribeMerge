class_name TigerEscape
extends RefCounted
## Shared elimination-race rules executed by the operation reducer.

static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/tiger_escape.json")

static func state() -> Dictionary:
	return G.tiger_escape if not G.tiger_escape.is_empty() else {"rounds": 0, "round": {}}

static func round_state() -> Dictionary:
	return state()["round"]

static func unlocked() -> bool:
	return G.gm_activities or G.level >= int(config()["unlock_level"])

static func _fraction(m: Dictionary, bot: int, leg: int) -> float:
	var key := "%d:%d:%d:%d" % [int(m["id"]), int(m["start"]), bot, leg]
	return float(key.sha256_text().substr(0, 8).hex_to_int()) / 4294967296.0

static func _create_bots(m: Dictionary) -> Array:
	var rules: Dictionary = config().get("bots", {})
	var names: Array = rules.get("names", ["同行者"])
	var bots: Array = []
	for i in clampi(int(rules.get("count", 15)), 0, 50):
		var pace := lerpf(float(rules.get("pace_min", 0.45)), float(rules.get("pace_max", 1.4)), _fraction(m, i, -1))
		var elapsed := 0.0
		var arrivals: Array = []
		for leg in m["stages"].size():
			elapsed += float(m["interval"]) * pace * (0.8 + 0.4 * _fraction(m, i, leg))
			arrivals.append(elapsed)
		bots.append({"name": str(names[i % names.size()]) if not names.is_empty() else "同行者", "avatar": i % 8, "arrivals": arrivals, "stage": 0, "status": "running"})
	return bots



static func _tick_bots(m: Dictionary, now: float) -> void:
	var elapsed := maxf(0, minf(now, float(m.get("finished_at", now))) - float(m["start"]))
	for bot in m.get("bots", []):
		var stage := 0
		var status := "running"
		for arrival in bot["arrivals"]:
			var deadline := (stage + 1) * float(m["interval"])
			if float(arrival) >= deadline:
				if elapsed >= deadline: status = "lost"
				break
			if elapsed < float(arrival): break
			stage += 1
		if stage == m["stages"].size(): status = "won"
		if int(bot["stage"]) != stage or bot["status"] != status: G.dirty()
		bot["stage"] = stage
		bot["status"] = status

static func tick() -> void:
	if G.replay_input(): return
	var m := round_state()
	if m.is_empty(): return
	if m["status"] == "running":
		var destroyed := mini(m["stages"].size() - 1, int(maxf(0, G.now() - float(m["start"])) / float(m["interval"])) - 1)
		var previous := int(m["destroyed"])
		m["destroyed"] = maxi(previous, mini(destroyed, int(m["stage"])))
		if destroyed >= int(m["stage"]):
			m["status"] = "lost"
			m["finished_at"] = float(m["start"]) + (int(m["stage"]) + 1) * float(m["interval"])
		if previous != int(m["destroyed"]): G.dirty()
	_tick_bots(m, G.now())

static func on_order(_order: Dictionary) -> void:
	tick()
	var m := round_state()
	if m.is_empty() or m["status"] != "running": return
	m["points"] = int(m["points"]) + int(m["points_per_order"])
	while int(m["stage"]) < m["stages"].size() and int(m["points"]) >= int(m["stages"][int(m["stage"])]["points"]):
		m["points"] = int(m["points"]) - int(m["stages"][int(m["stage"])]["points"])
		m["stage"] = int(m["stage"]) + 1
	if int(m["stage"]) == m["stages"].size():
		m["status"] = "won"
		m["points"] = 0
		m["finished_at"] = G.now()
	G.dirty()

static func seen_attack(m: Dictionary) -> int:
	return int(G.tiger_escape_seen.get("destroyed", -1)) if int(G.tiger_escape_seen.get("round_id", -1)) == int(m.get("id", 0)) and int(G.tiger_escape_seen.get("rule_version", 0)) == int(m.get("rule_version", 0)) else -1

static func acknowledge_attack(m: Dictionary, node: int) -> void:
	G.tiger_escape_seen = {"round_id": int(m["id"]), "destroyed": node, "rule_version": int(m.get("rule_version", 2))}
	G.dirty()

static func survivors(m: Dictionary) -> int:
	if m.is_empty(): return int(config().get("bots", {}).get("count", 15)) + 1
	var left := 0 if m["status"] == "lost" else 1
	for bot in m.get("bots", []):
		if bot["status"] != "lost": left += 1
	return left

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
			"interval": config()["attack_interval_sec"], "points_per_order": maxi(1, int(config()["points_per_order"])), "rule_version": 2}
		s["round"]["bots"] = _create_bots(s["round"])
		return {"rewards": rewards}
	if action == "claim":
		if m.is_empty() or node < 1 or node > int(m["stage"]) or node in m["claimed"]: return {"error": "礼包尚未到达或已领取"}
		m["claimed"].append(node)
		return {"rewards": m["stages"][node - 1]["rewards"].duplicate(true)}
	return {"error": "未知操作"}

static func act(action: String, node := 0) -> Dictionary:
	if G.replay_input(): return Replay.perform("tiger", {"action": action, "node": node})
	var result := local_action(action, node)
	if not result.has("error"):
		Rewards.settle(result.get("rewards", []))
	return result

static func attack_left() -> int:
	var m := round_state()
	if m.is_empty() or m["status"] != "running": return 0
	var interval := float(m["interval"])
	var passed := int(maxf(0, G.now() - float(m["start"])) / interval)
	return maxi(0, int(ceil(float(m["start"]) + (passed + 1) * interval - G.now())))
