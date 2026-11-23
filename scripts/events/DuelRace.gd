class_name DuelRace
extends RefCounted
## First-to-target practice race, with per-window win milestones and scaling round targets.
const CURVE_STEPS := 40
## pv=1: 老版每单1~4分；pv=2: 200~600活动积分；pv=3: 双人竞速独立难度积分（匹配 30→300 渐进目标）
const DUEL_PV := 3

static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/duel_race.json")

static func state() -> Dictionary:
	return G.duel_race if not G.duel_race.is_empty() else {"window": "", "wins": 0, "rounds": 0, "claimed": [], "match": {}}

static func unlocked() -> bool:
	return G.gm_activities or G.level >= int(config()["unlock_level"])

static func _has_active_match(s: Dictionary) -> bool:
	var m: Dictionary = s.get("match", {})
	return not m.is_empty() and (str(m.get("status", "")) == "running" or not bool(m.get("claimed", false)))

## 每期独立：再次轮到双人竞速的新档期时，重置本期胜场、局数与里程碑奖励。
## 若上一期仍有进行中或未领奖的残局，先保留到玩家领完奖后再重置。
static func sync_window() -> void:
	if G.duel_race.is_empty(): return
	var key := ActivitySchedule.window_key("duel")
	if key == "": return
	if not G.duel_race.has("window") or str(G.duel_race.get("window", "")) == "":
		G.duel_race["window"] = key
		return
	if str(G.duel_race.get("window", "")) != key and not _has_active_match(G.duel_race):
		G.duel_race = {"window": key, "wins": 0, "rounds": 0, "claimed": [], "match": {}}
		G.dirty()

static func initialize() -> void:
	if G.duel_race.is_empty():
		G.duel_race = {"window": ActivitySchedule.window_key("duel"), "wins": 0, "rounds": 0, "claimed": [], "match": {}}
	else:
		sync_window()

## 档期里，或者这一局还没打完/没领奖、有没领的里程碑时显示入口。
static func visible() -> bool:
	if not unlocked(): return false
	sync_window()
	var s := state()
	return ActivitySchedule.scheduled("duel") or _has_active_match(s) or not ready_milestones().is_empty()

## 当前是否处于新版双人竞速进行中（用于订单卡显示积分、交单/合成计分）。
static func active_v3() -> bool:
	if G.duel_race.is_empty(): return false
	var m: Dictionary = state().get("match", {})
	return not m.is_empty() and str(m.get("status", "")) == "running" and int(m.get("pv", 1)) >= DUEL_PV

## 第 round_num 局（从 1 开始）的目标分：第 1 局 30 分，递增至第 12 局 300 分。
static func target_for_round(round_num: int) -> int:
	var targets: Array = config().get("round_targets", [])
	if not targets.is_empty():
		var idx := clampi(round_num - 1, 0, targets.size() - 1)
		return int(targets[idx])
	return int(config()["target"])

## 下一局的目标分（给开始界面显示）。
static func next_target() -> int:
	sync_window()
	return target_for_round(int(state().get("rounds", 0)) + 1)

## 根据本局目标分插值计算对手完赛时间区间 [min_sec, max_sec]。
static func opponent_seconds_for(target: int) -> Array:
	var base: Array = config()["opponent_seconds"]
	var top: Array = config().get("opponent_seconds_max", base)
	var targets: Array = config().get("round_targets", [])
	var u := 1.0
	if targets.size() >= 2:
		var lo := float(targets[0])
		var hi := float(targets[targets.size() - 1])
		u = clampf((float(target) - lo) / maxf(1.0, hi - lo), 0.0, 1.0)
	return [lerpf(float(base[0]), float(top[0]), u), lerpf(float(base[1]), float(top[1]), u)]

## 新版（pv=3）订单奖励积分：按订单难度确定性计算（10~45 分），与订单卡显示一致。
static func order_score(order: Dictionary) -> int:
	var r: Array = config().get("order_point_range", [10, 45])
	var lo := float(r[0])
	var hi := float(r[1])
	var d := ActivityPoints.difficulty(order, G.level)
	return clampi(int(round(lerpf(lo, hi, d))), int(lo), int(hi))

## 新版（pv=3）合成高级物品积分：7 级起给 5 分，每高 1 级 +3，封顶 20 分。
static func merge_score(id: String) -> int:
	if not Data.is_board_item(id) or Data.is_dish(id) or Data.type_of(id) != "item":
		return 0
	var from_lv := int(config().get("merge_from", 7))
	var lv := Data.lv(id)
	if lv < from_lv:
		return 0
	var base_pts := int(config().get("merge_base", 5))
	var step_pts := int(config().get("merge_step", 3))
	var max_pts := int(config().get("merge_max", 20))
	return mini(max_pts, base_pts + step_pts * (lv - from_lv))

## 老版（pv=1）每单 1~4 分（仅保留兼容老存档残局）。
static func order_points(order: Dictionary) -> int:
	var score := 1
	for id in order.get("items", []): score = maxi(score, Data.lv(str(id)))
	score += maxi(0, order.get("items", []).size() - 1)
	var tier := 0
	for at in config()["order_thresholds"]:
		if score >= int(at): tier += 1
	return int(config()["order_points"][mini(tier, config()["order_points"].size() - 1)])

static func _finish(won: bool, at: float) -> void:
	var s := state()
	var m: Dictionary = s["match"]
	if m.is_empty() or m["status"] != "running": return
	m["status"] = "won" if won else "lost"
	m["finished_at"] = at
	if won: s["wins"] = int(s["wins"]) + 1
	G.dirty()

static func tick() -> void:
	if G.replay_input(): return
	var m: Dictionary = state()["match"]
	if m.is_empty() or m["status"] != "running": return
	var elapsed := G.now() - float(m["start"])
	for p in m["opponent_curve"]:
		if elapsed < float(p[0]): break
		m["opponent"] = int(p[1])
		if int(m["opponent"]) >= int(m["target"]):
			_finish(false, float(m["start"]) + float(p[0]))
			break

## 老版本的局（pv=1）还按每单 1~4 分算；pv=2 走 ActivityPoints.grant；pv=3 走 add_duel_points。
static func on_order(order: Dictionary) -> void:
	tick()
	var m: Dictionary = state()["match"]
	if m.is_empty() or m["status"] != "running": return
	if int(m.get("pv", 1)) >= ActivityPoints.VERSION: return
	m["me"] = mini(int(m["target"]), int(m["me"]) + order_points(order))
	if int(m["me"]) >= int(m["target"]): _finish(true, G.now())
	G.dirty()

## 通用活动积分入口（仅记 pv == 2 的旧版局，避免 200~600 分直接灌进 30~300 的新版局）。
static func add_points(n: int) -> bool:
	if G.duel_race.is_empty() or n <= 0: return false
	tick()
	var m: Dictionary = state()["match"]
	if m.is_empty() or m["status"] != "running": return false
	var pv := int(m.get("pv", 1))
	if pv < ActivityPoints.VERSION or pv >= DUEL_PV: return false
	m["me"] = mini(int(m["target"]), int(m["me"]) + n)
	if int(m["me"]) >= int(m["target"]): _finish(true, G.now())
	G.dirty()
	return true

## 新版（pv >= 3）双人竞速专用加分入口，记上了返回 true。
static func add_duel_points(n: int) -> bool:
	if G.duel_race.is_empty() or n <= 0: return false
	tick()
	var m: Dictionary = state()["match"]
	if m.is_empty() or m["status"] != "running" or int(m.get("pv", 1)) < DUEL_PV: return false
	m["me"] = mini(int(m["target"]), int(m["me"]) + n)
	if int(m["me"]) >= int(m["target"]): _finish(true, G.now())
	G.dirty()
	return true

static func ready_milestones() -> Array:
	var s := state()
	var out := []
	for m in config()["milestones"]:
		if int(s["wins"]) >= int(m["wins"]) and not str(int(m["wins"])) in s["claimed"]: out.append(int(m["wins"]))
	return out

static func pending() -> bool:
	tick()
	sync_window()
	var m: Dictionary = state()["match"]
	return (not m.is_empty() and m["status"] in ["won", "lost"] and not m.get("claimed", false)) or not ready_milestones().is_empty()

static func act(action: String, milestone := 0) -> Dictionary:
	if G.replay_input(): return Replay.perform("duel", {"action": action, "milestone": milestone})
	var result := local_action(action, milestone)
	if not result.has("error"):
		Rewards.settle(result.get("rewards", []))
	return result

static func local_action(action: String, milestone := 0) -> Dictionary:
	if not unlocked(): return {"error": TextCatalog.fill(TextCatalog.source("notice.duelrace.2821c8ca32bd"), int(config()["unlock_level"]))}
	# 存档里还没有活动状态时先建好，免得开局写进临时字典丢失。
	if G.duel_race.is_empty(): G.duel_race = {"window": ActivitySchedule.window_key("duel"), "wins": 0, "rounds": 0, "claimed": [], "match": {}}
	tick()
	sync_window()
	var s := state()
	var m: Dictionary = s["match"]
	match action:
		"refresh": return {}
		"join":
			if not m.is_empty() and (m["status"] == "running" or not m.get("claimed", false)): return {"error": TextCatalog.source("notice.duelrace.285eedc7ae25")}
			if not ActivitySchedule.scheduled("duel"): return {"error": ActivitySchedule.closed_message("duel")}
			var next_round := int(s["rounds"]) + 1
			var target := target_for_round(next_round)
			var seconds: Array = opponent_seconds_for(target)
			var duration := G.random_for("duel").randf_range(float(seconds[0]), float(seconds[1]))
			var curve := []
			var steps := mini(CURVE_STEPS, target)
			for k in range(1, steps + 1):
				var score := int(round(float(target) * k / steps))
				curve.append([duration * (float(k) - G.random_for("duel").randf_range(0, 0.4)) / steps, score])
			s["window"] = ActivitySchedule.window_key("duel")
			s["rounds"] = next_round
			s["match"] = {"id": next_round, "start": G.now(), "target": target, "me": 0, "opponent": 0, "status": "running", "claimed": false, "opponent_curve": curve, "pv": DUEL_PV}
			return {}
		"claim":
			if m.is_empty() or m["status"] == "running" or m.get("claimed", false): return {"error": TextCatalog.source("notice.duelrace.4aefe032c871")}
			m["claimed"] = true
			var rewards: Array = config()["win_rewards"] if m["status"] == "won" else config()["lose_rewards"]
			# 如果这局是上一期的残局且现在已轮到新一期，领完奖后自动切到新一期（清空上一期累胜）
			sync_window()
			return {"rewards": rewards}
		"milestone":
			if not milestone in ready_milestones(): return {"error": TextCatalog.source("notice.duelrace.843577782f5f")}
			s["claimed"].append(str(milestone))
			for row in config()["milestones"]:
				if int(row["wins"]) == milestone: return {"rewards": row["rewards"]}
	return {"error": TextCatalog.source("notice.duelrace.f242d2db4cea")}
