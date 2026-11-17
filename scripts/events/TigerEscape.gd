class_name TigerEscape
extends RefCounted
## Shared 100-player 10-stage async elimination-race rules executed by the operation reducer.

static var _notified_lost_round := -1
static var _sync_busy := false

static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/tiger_escape.json")

static func state() -> Dictionary:
	return G.tiger_escape if not G.tiger_escape.is_empty() else {"rounds": 0, "round": {}}

static func round_state() -> Dictionary:
	return state()["round"]

static func unlocked() -> bool:
	return G.gm_activities or G.level >= int(config()["unlock_level"])

## 档期里，或者这一局还在逃、还有没领的礼包时显示入口。
static func visible() -> bool:
	if not unlocked(): return false
	var m := round_state()
	return ActivitySchedule.scheduled("tiger") or (not m.is_empty() and (m.get("status", "") == "running" or not pending_rewards(m).is_empty()))

static func _default_quotas(num_stages: int, count: int) -> Array:
	var cfg_q: Array = config().get("stage_quotas", [])
	if cfg_q.size() == num_stages:
		return cfg_q.duplicate()
	var out: Array = []
	for i in num_stages:
		if i < num_stages - 1:
			out.append(maxi(1, count - (i + 1) * 10))
		else:
			out.append(maxi(1, mini(10, count)))
	return out

static func _fraction(m: Dictionary, bot: int, leg: int) -> float:
	var key := "%d:%d:%d:%d" % [int(m["id"]), int(m["start"]), bot, leg]
	return float(key.sha256_text().substr(0, 8).hex_to_int()) / 4294967296.0

static func _create_bots(m: Dictionary) -> Array:
	var rules: Dictionary = config().get("bots", {})
	var names: Array = rules.get("names", [TextCatalog.source("notice.tigerescape.3a66496b74b1")])
	var target_bots := maxi(1, int(m.get("player_count", config().get("player_count", 100))) - 1)
	var bots: Array = []
	for i in target_bots:
		var pace := lerpf(float(rules.get("pace_min", 0.45)), float(rules.get("pace_max", 1.4)), _fraction(m, i, -1))
		var elapsed := 0.0
		var arrivals: Array = []
		for leg in m["stages"].size():
			elapsed += float(m["interval"]) * pace * (0.8 + 0.4 * _fraction(m, i, leg))
			arrivals.append(elapsed)
		var base_name := str(names[i % names.size()]) if not names.is_empty() else TextCatalog.source("notice.tigerescape.3a66496b74b1")
		var display_name := base_name if i < names.size() else "%s%d" % [base_name, i + 1]
		bots.append({"slot": i + 1, "name": display_name, "avatar": i % 8, "arrivals": arrivals, "stage": 0, "status": "running", "is_bot": true})
	return bots

static func _evaluate(m: Dictionary, now: float) -> void:
	if m.is_empty(): return
	if str(m.get("cohort_id", "")) != "": return
	var stages: Array = m.get("stages", [])
	var num_stages := stages.size()
	if num_stages <= 0: return
	var total_players := maxi(2, int(m.get("player_count", config().get("player_count", 100))))
	var quotas: Array = m.get("quotas", [])
	if quotas.size() != num_stages:
		quotas = _default_quotas(num_stages, total_players)
		m["quotas"] = quotas

	var elapsed := maxf(0.0, now - float(m.get("start", now)))
	var bots: Array = m.get("bots", [])
	var n_runners := 1 + bots.size()

	# 0 = 玩家本人, 1..bots.size() = 其他参赛者
	var times_list: Array = []
	times_list.append(m.get("stage_times", []))
	for bot in bots:
		times_list.append(bot.get("arrivals", []))

	var alive: Array[bool] = []
	var vis_stages: Array[int] = []
	var statuses: Array[String] = []
	alive.resize(n_runners)
	vis_stages.resize(n_runners)
	statuses.resize(n_runners)

	for i in n_runners:
		alive[i] = true
		statuses[i] = "running"
		if i == 0:
			vis_stages[i] = mini(int(m.get("stage", 0)), num_stages)
		else:
			var s := 0
			for t in times_list[i]:
				if float(t) <= elapsed:
					s += 1
				else:
					break
			vis_stages[i] = mini(s, num_stages)

	var destroyed := int(m.get("destroyed", -1))
	for s_idx in num_stages:
		var q := int(quotas[s_idx])
		var completed: Array = []
		for i in n_runners:
			if not alive[i]: continue
			var ts: Array = times_list[i]
			if ts.size() > s_idx:
				completed.append([float(ts[s_idx]), i])
		completed.sort_custom(func(a, b):
			if float(a[0]) != float(b[0]): return float(a[0]) < float(b[0])
			return int(a[1]) < int(b[1]))
		if completed.size() >= q:
			var cutoff_t := float(completed[q - 1][0])
			if elapsed >= cutoff_t:
				var kept := {}
				for k in q:
					kept[int(completed[k][1])] = true
				for i in n_runners:
					if alive[i] and not kept.has(i):
						alive[i] = false
						statuses[i] = "lost"
						vis_stages[i] = mini(vis_stages[i], s_idx)
						if i == 0 and m.get("status", "") == "running":
							m["status"] = "lost"
							m["finished_at"] = float(m["start"]) + cutoff_t
				destroyed = maxi(destroyed, s_idx)
				continue
		break

	if int(m.get("destroyed", -1)) != destroyed:
		m["destroyed"] = destroyed
		G.dirty()

	# 同步写回每个对手的阶段与状态
	for b_idx in bots.size():
		var i := b_idx + 1
		var st := statuses[i]
		if st == "running" and vis_stages[i] >= num_stages:
			st = "won"
		var bot: Dictionary = bots[b_idx]
		if int(bot.get("stage", 0)) != vis_stages[i] or str(bot.get("status", "")) != st:
			G.dirty()
		bot["stage"] = vis_stages[i]
		bot["status"] = st

	if str(m.get("status", "")) == "running" and int(m.get("stage", 0)) >= num_stages:
		m["status"] = "won"
		m["finished_at"] = now
		G.dirty()

	# 计算当前目标阶段的剩余名额
	var p_stage := int(m.get("stage", 0))
	var target_idx := mini(p_stage, num_stages - 1)
	var sq := int(quotas[target_idx])
	var passed := 0
	for i in n_runners:
		if alive[i] and vis_stages[i] > target_idx:
			passed += 1
	var rem := 0 if str(m.get("status", "")) == "won" else maxi(0, sq - passed)
	m["stage_quota"] = sq
	m["stage_remaining"] = rem

static func tick() -> void:
	if G.replay_input(): return
	var m := round_state()
	if m.is_empty(): return
	var prev_status := str(m.get("status", ""))
	if prev_status == "running" or int(m.get("rule_version", 0)) >= 3:
		_evaluate(m, G.now())
	var cur_status := str(m.get("status", ""))
	if prev_status == "running" and cur_status == "lost":
		G.dirty()
		_notify_open("eliminated", {"destroyed": int(m.get("destroyed", -1))})
	elif cur_status == "lost" and int(m.get("destroyed", -1)) > seen_attack(m):
		var rid := int(m.get("id", 0))
		if _notified_lost_round != rid:
			_notified_lost_round = rid
			_notify_open("eliminated", {"destroyed": int(m.get("destroyed", -1))})

static func _notify_open(reason: String, extra := {}) -> void:
	if G.replay_input(): return
	var payload := {"reason": reason}
	for k in extra:
		payload[k] = extra[k]
	G.present("tiger_open", payload)

static func on_order(_order: Dictionary) -> void:
	tick()
	var m := round_state()
	if m.is_empty() or m["status"] != "running": return
	var prev_stage := int(m["stage"])
	m["points"] = int(m["points"]) + int(m["points_per_order"])
	if not m.has("stage_times") or not (m["stage_times"] is Array):
		m["stage_times"] = []
	var elapsed := maxf(0.0, G.now() - float(m.get("start", G.now())))
	while int(m["stage"]) < m["stages"].size() and int(m["points"]) >= int(m["stages"][int(m["stage"])]["points"]):
		m["points"] = int(m["points"]) - int(m["stages"][int(m["stage"])]["points"])
		m["stage"] = int(m["stage"]) + 1
		m["stage_times"].append(snappedf(elapsed, 0.01))
	if int(m["stage"]) == m["stages"].size():
		m["status"] = "won"
		m["points"] = 0
		m["finished_at"] = G.now()
	_evaluate(m, G.now())
	G.dirty()
	if int(m["stage"]) > prev_stage:
		_notify_open("stage_up", {"stage": int(m["stage"])})
	if not G.replay_input() and Cloud.can_talk() and str(m.get("cohort_id", "")) != "":
		sync_progress_server()

static func seen_attack(m: Dictionary) -> int:
	return int(G.tiger_escape_seen.get("destroyed", -1)) if int(G.tiger_escape_seen.get("round_id", -1)) == int(m.get("id", 0)) and int(G.tiger_escape_seen.get("rule_version", 0)) == int(m.get("rule_version", 0)) else -1

static func acknowledge_attack(m: Dictionary, node: int) -> void:
	G.tiger_escape_seen = {"round_id": int(m["id"]), "destroyed": node, "rule_version": int(m.get("rule_version", 3))}
	G.dirty()

static func player_count(m: Dictionary) -> int:
	if m.is_empty(): return int(config().get("player_count", 100))
	return maxi(2, int(m.get("player_count", m.get("bots", []).size() + 1)))

static func survivors(m: Dictionary) -> int:
	if m.is_empty(): return int(config().get("player_count", 100))
	if m.has("server_survivors"): return int(m["server_survivors"])
	var left := 0 if m.get("status", "") == "lost" else 1
	for bot in m.get("bots", []):
		if str(bot.get("status", "")) != "lost": left += 1
	return left

static func stage_quota(m: Dictionary) -> int:
	if m.is_empty():
		var qs := _default_quotas(config()["stages"].size(), int(config().get("player_count", 100)))
		return int(qs[0])
	if m.has("stage_quota"): return int(m["stage_quota"])
	var qs := _default_quotas(m.get("stages", []).size(), player_count(m))
	var idx := mini(int(m.get("stage", 0)), qs.size() - 1)
	return int(qs[idx])

static func stage_remaining(m: Dictionary) -> int:
	if m.is_empty(): return stage_quota(m)
	if m.has("stage_remaining"): return int(m["stage_remaining"])
	return stage_quota(m)

static func pending_rewards(m: Dictionary) -> Array:
	var rewards: Array = []
	for n in range(1, int(m.get("stage", 0)) + 1):
		if not n in m["claimed"]: rewards.append_array(m["stages"][n - 1]["rewards"].duplicate(true))
	return rewards

static func local_action(action: String, node := 0) -> Dictionary:
	if not unlocked(): return {"error": TextCatalog.source("notice.tigerescape.72a4a2cc2623") % int(config()["unlock_level"])}
	# 存档里还没有活动状态时（未经 ActivityRules.initialize），先建好，免得开局写进临时字典丢失。
	if G.tiger_escape.is_empty(): G.tiger_escape = {"rounds": 0, "round": {}}
	tick()
	var s := state()
	var m := round_state()
	if action == "refresh": return {}
	if action in ["join", "restart"]:
		if not m.is_empty() and m["status"] == "running": return {"error": TextCatalog.source("notice.tigerescape.9321aa28efc0")}
		if action == "join" and not m.is_empty(): return {"error": TextCatalog.source("notice.tigerescape.e552f18430ca")}
		if action == "restart" and m.is_empty(): return {"error": TextCatalog.source("notice.tigerescape.6b01ffc9870f")}
		if not ActivitySchedule.scheduled("tiger"): return {"error": ActivitySchedule.closed_message("tiger")}
		var rewards := pending_rewards(m) if not m.is_empty() else []
		s["rounds"] = int(s["rounds"]) + 1
		var stages: Array = config()["stages"].duplicate(true)
		var p_count := int(config().get("player_count", 100))
		var quotas := _default_quotas(stages.size(), p_count)
		s["round"] = {
			"id": s["rounds"],
			"start": G.now(),
			"stage": 0,
			"points": 0,
			"stage_times": [],
			"destroyed": -1,
			"status": "running",
			"claimed": [],
			"stages": stages,
			"quotas": quotas,
			"player_count": p_count,
			"stage_quota": int(quotas[0]),
			"stage_remaining": int(quotas[0]),
			"interval": config()["attack_interval_sec"],
			"points_per_order": maxi(1, int(config()["points_per_order"])),
			"cohort_id": "",
			"rule_version": 3,
		}
		s["round"]["bots"] = _create_bots(s["round"])
		_notified_lost_round = -1
		return {"rewards": rewards}
	if action == "claim":
		if m.is_empty() or node < 1 or node > int(m["stage"]) or node in m["claimed"]: return {"error": TextCatalog.source("notice.tigerescape.aefe102938d4")}
		m["claimed"].append(node)
		return {"rewards": m["stages"][node - 1]["rewards"].duplicate(true)}
	return {"error": TextCatalog.source("notice.duelrace.f242d2db4cea")}

static func act(action: String, node := 0) -> Dictionary:
	if G.replay_input(): return Replay.perform("tiger", {"action": action, "node": node})
	var result := local_action(action, node)
	if not result.has("error"):
		Rewards.settle(result.get("rewards", []))
	return result

static func _apply_server_cohort(cohort: Dictionary) -> void:
	var m := round_state()
	if m.is_empty() or cohort.is_empty(): return
	var prev_status := str(m.get("status", ""))
	m["cohort_id"] = str(cohort.get("cohort_id", m.get("cohort_id", "")))
	if cohort.has("start"): m["start"] = float(cohort["start"])
	if cohort.has("player_count"): m["player_count"] = int(cohort["player_count"])
	if cohort.get("quotas") is Array: m["quotas"] = cohort["quotas"]
	if cohort.get("bots") is Array: m["bots"] = cohort["bots"]
	if cohort.has("stage_quota"): m["stage_quota"] = int(cohort["stage_quota"])
	if cohort.has("stage_remaining"): m["stage_remaining"] = int(cohort["stage_remaining"])
	if cohort.has("survivors"): m["server_survivors"] = int(cohort["survivors"])
	if cohort.has("destroyed"): m["destroyed"] = maxi(int(m.get("destroyed", -1)), int(cohort["destroyed"]))
	if str(cohort.get("status", "")) == "lost" and prev_status == "running":
		m["status"] = "lost"
		if cohort.get("finished_at") != null:
			m["finished_at"] = float(cohort["finished_at"])
		_notify_open("eliminated", {"destroyed": int(m.get("destroyed", -1))})
	G.dirty()

static func sync_join_server() -> void:
	if not Cloud.can_talk(): return
	var r: Array = await Cloud._call("POST", "/v1/tiger/join", {})
	if int(r[0]) == 200 and r[1] is Dictionary and r[1].get("cohort") is Dictionary:
		_apply_server_cohort(r[1]["cohort"])

static func sync_progress_server() -> void:
	if _sync_busy or not Cloud.can_talk(): return
	var m := round_state()
	var cid := str(m.get("cohort_id", ""))
	if cid == "": return
	_sync_busy = true
	var payload := {
		"cohort_id": cid,
		"stage": int(m.get("stage", 0)),
		"points": int(m.get("points", 0)),
		"stage_times": m.get("stage_times", []),
	}
	var r: Array = await Cloud._call("POST", "/v1/tiger/sync", payload)
	_sync_busy = false
	if int(r[0]) == 200 and r[1] is Dictionary and r[1].get("cohort") is Dictionary:
		_apply_server_cohort(r[1]["cohort"])

static func refresh_from_server() -> void:
	if _sync_busy or not Cloud.can_talk(): return
	var m := round_state()
	if m.is_empty(): return
	var cid := str(m.get("cohort_id", ""))
	if cid == "":
		if str(m.get("status", "")) == "running":
			await sync_join_server()
		return
	_sync_busy = true
	var r: Array = await Cloud._call("GET", "/v1/tiger/state?cohort_id=" + cid, null)
	_sync_busy = false
	if int(r[0]) == 200 and r[1] is Dictionary and r[1].get("cohort") is Dictionary:
		_apply_server_cohort(r[1]["cohort"])

static func attack_left() -> int:
	var m := round_state()
	if m.is_empty() or m["status"] != "running": return 0
	var interval := float(m["interval"])
	var passed := int(maxf(0, G.now() - float(m["start"])) / interval)
	return maxi(0, int(ceil(float(m["start"]) + (passed + 1) * interval - G.now())))
