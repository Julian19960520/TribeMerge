class_name DuelRace
extends RefCounted
## First-to-target practice race, with lifetime win milestones. Server owns state when enabled.
const CURVE_STEPS := 40
static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/duel_race.json")

static func state() -> Dictionary:
	return G.duel_race if not G.duel_race.is_empty() else {"wins": 0, "rounds": 0, "claimed": [], "match": {}}

static func unlocked() -> bool: return G.gm_activities or G.level>=int(config()["unlock_level"])
## 档期里，或者这一局还没打完/没领奖、有没领的里程碑时显示入口。
static func visible() -> bool:
	if not unlocked(): return false
	var m: Dictionary = state().get("match", {})
	return ActivitySchedule.scheduled("duel") or (not m.is_empty() and (m.get("status", "") == "running" or not m.get("claimed", false))) or not ready_milestones().is_empty()
static func order_points(order: Dictionary) -> int:
	var score:=1
	for id in order.get("items",[]): score=maxi(score,Data.lv(str(id)))
	score+=maxi(0,order.get("items",[]).size()-1)
	var tier:=0
	for at in config()["order_thresholds"]:
		if score>=int(at): tier+=1
	return int(config()["order_points"][mini(tier,config()["order_points"].size()-1)])
static func _finish(won: bool, at: float) -> void:
	var s:=state()
	var m: Dictionary=s["match"]
	if m.is_empty() or m["status"]!="running": return
	m["status"]="won" if won else "lost"
	m["finished_at"]=at
	if won: s["wins"]=int(s["wins"])+1
	G.dirty()
static func tick() -> void:
	if G.replay_input(): return
	var m: Dictionary=state()["match"]
	if m.is_empty() or m["status"]!="running": return
	var elapsed:=G.now()-float(m["start"])
	for p in m["opponent_curve"]:
		if elapsed<float(p[0]): break
		m["opponent"]=int(p[1])
		if int(m["opponent"])>=int(m["target"]):
			_finish(false,float(m["start"])+float(p[0]))
			break
## 老版本的局（没有 pv）还按每单 1~4 分算；新局的分走 ActivityPoints.add_points。
static func on_order(order: Dictionary) -> void:
	tick()
	var m: Dictionary=state()["match"]
	if m.is_empty() or m["status"]!="running": return
	if int(m.get("pv",1))>=ActivityPoints.VERSION: return
	m["me"]=mini(int(m["target"]),int(m["me"])+order_points(order))
	if int(m["me"])>=int(m["target"]): _finish(true,G.now())
	G.dirty()
## 活动积分（交单、合成高级物品）。只记新版的局，记上了返回 true。
static func add_points(n: int) -> bool:
	if G.duel_race.is_empty(): return false
	tick()
	var m: Dictionary=state()["match"]
	if m.is_empty() or m["status"]!="running" or int(m.get("pv",1))<ActivityPoints.VERSION: return false
	m["me"]=mini(int(m["target"]),int(m["me"])+n)
	if int(m["me"])>=int(m["target"]): _finish(true,G.now())
	G.dirty()
	return true
static func ready_milestones() -> Array:
	var s:=state()
	var out:=[]
	for m in config()["milestones"]:
		if int(s["wins"])>=int(m["wins"]) and not str(int(m["wins"])) in s["claimed"]: out.append(int(m["wins"]))
	return out
static func pending() -> bool:
	tick()
	var m: Dictionary=state()["match"]
	return (not m.is_empty() and m["status"] in ["won","lost"] and not m.get("claimed",false)) or not ready_milestones().is_empty()
static func act(action: String, milestone := 0) -> Dictionary:
	if G.replay_input(): return Replay.perform("duel", {"action": action, "milestone": milestone})
	var result := local_action(action, milestone)
	if not result.has("error"):
		Rewards.settle(result.get("rewards", []))
	return result

static func local_action(action: String, milestone:=0) -> Dictionary:
	if not unlocked(): return {"error":TextCatalog.fill(TextCatalog.source("notice.duelrace.2821c8ca32bd"), int(config()["unlock_level"]))}
	# 存档里还没有活动状态时先建好，免得开局写进临时字典丢失。
	if G.duel_race.is_empty(): G.duel_race={"wins": 0, "rounds": 0, "claimed": [], "match": {}}
	tick()
	var s:=state()
	var m: Dictionary=s["match"]
	match action:
		"refresh": return {}
		"join":
			if not m.is_empty() and (m["status"]=="running" or not m.get("claimed",false)): return {"error":TextCatalog.source("notice.duelrace.285eedc7ae25")}
			if not ActivitySchedule.scheduled("duel"): return {"error":ActivitySchedule.closed_message("duel")}
			var target:=int(config()["target"])
			var seconds: Array=config()["opponent_seconds"]
			var duration:=G.random_for("duel").randf_range(float(seconds[0]),float(seconds[1]))
			# 对手分数按 CURVE_STEPS 段涨上去（分数是几千的量级，不再一分一个点）
			var curve:=[]
			var steps:=mini(CURVE_STEPS,target)
			for k in range(1,steps+1):
				var score:=int(round(float(target)*k/steps))
				curve.append([duration*(float(k)-G.random_for("duel").randf_range(0,0.4))/steps,score])
			s["rounds"]=int(s["rounds"])+1
			s["match"]={"id":int(s["rounds"]),"start":G.now(),"target":target,"me":0,"opponent":0,"status":"running","claimed":false,"opponent_curve":curve,"pv":ActivityPoints.VERSION}
			return {}
		"claim":
			if m.is_empty() or m["status"]=="running" or m.get("claimed",false): return {"error":TextCatalog.source("notice.duelrace.4aefe032c871")}
			m["claimed"]=true
			return {"rewards":config()["win_rewards"] if m["status"]=="won" else config()["lose_rewards"]}
		"milestone":
			if not milestone in ready_milestones(): return {"error":TextCatalog.source("notice.duelrace.843577782f5f")}
			s["claimed"].append(str(milestone))
			for row in config()["milestones"]:
				if int(row["wins"])==milestone: return {"rewards":row["rewards"]}
	return {"error":TextCatalog.source("notice.duelrace.f242d2db4cea")}
