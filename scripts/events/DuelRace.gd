class_name DuelRace
extends RefCounted
## First-to-target practice race, with lifetime win milestones. Server owns state when enabled.
static var _config: Dictionary={}
static var busy:=false
static func config() -> Dictionary:
	if _config.is_empty(): _config=JSON.parse_string(FileAccess.get_file_as_string("res://data/duel_race.json"))
	return _config
static func state() -> Dictionary:
	if G.duel_race.is_empty(): G.duel_race={"wins":0,"rounds":0,"claimed":[],"match":{}}
	return G.duel_race
static func unlocked() -> bool: return G.gm_activities or G.level>=int(config()["unlock_level"])
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
	if G.server_mode(): return
	var m: Dictionary=state()["match"]
	if m.is_empty() or m["status"]!="running": return
	var elapsed:=G.now()-float(m["start"])
	for p in m["opponent_curve"]:
		if elapsed<float(p[0]): break
		m["opponent"]=int(p[1])
		if int(m["opponent"])>=int(m["target"]):
			_finish(false,float(m["start"])+float(p[0]))
			break
static func on_order(order: Dictionary) -> void:
	if G.server_mode(): return
	tick()
	var m: Dictionary=state()["match"]
	if m.is_empty() or m["status"]!="running": return
	m["me"]=mini(int(m["target"]),int(m["me"])+order_points(order))
	if int(m["me"])>=int(m["target"]): _finish(true,G.now())
	G.dirty()
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
static func act(action: String, milestone:=0) -> Dictionary:
	if G.replay_input(): return await Replay.perform("duel", {"action": action, "milestone": milestone})
	if busy: return {"error":"正在处理"}
	busy=true
	var result: Dictionary
	if G.server_mode():
		var minus: Array=[]
		if action=="claim": minus=config()["win_rewards"] if state()["match"].get("status","")=="won" else config()["lose_rewards"]
		elif action=="milestone":
			for row in config()["milestones"]:
				if int(row["wins"])==milestone: minus=row["rewards"]
		var r: Dictionary=await G._cloud().act("/v1/duel/action",{"action":action,"milestone":milestone},minus)
		result=r.get("give",{}) if r.get("ok",false) else {"error":r.get("message","暂时无法连接")}
	else: result=local_action(action,milestone)
	busy=false
	if not result.has("error"):
		Rewards.grant(result.get("rewards",[]),Callable(),false)
		G.save_game()
		G.changed.emit()
	return result
static func local_action(action: String, milestone:=0) -> Dictionary:
	if not unlocked(): return {"error":"%d级解锁双人竞速"%int(config()["unlock_level"])}
	tick()
	var s:=state()
	var m: Dictionary=s["match"]
	match action:
		"refresh": return {}
		"join":
			if not m.is_empty() and (m["status"]=="running" or not m.get("claimed",false)): return {"error":"请先完成当前比赛并领取奖励"}
			var target:=int(config()["target"])
			var seconds: Array=config()["opponent_seconds"]
			var duration:=G.random_for("duel").randf_range(float(seconds[0]),float(seconds[1]))
			var curve:=[]
			for score in range(1,target+1): curve.append([duration*(float(score)-G.random_for("duel").randf_range(0,0.4))/target,score])
			s["rounds"]=int(s["rounds"])+1
			s["match"]={"id":int(s["rounds"]),"start":G.now(),"target":target,"me":0,"opponent":0,"status":"running","claimed":false,"opponent_curve":curve}
			return {}
		"claim":
			if m.is_empty() or m["status"]=="running" or m.get("claimed",false): return {"error":"没有可领取的比赛奖励"}
			m["claimed"]=true
			return {"rewards":config()["win_rewards"] if m["status"]=="won" else config()["lose_rewards"]}
		"milestone":
			if not milestone in ready_milestones(): return {"error":"尚未达成或已领取"}
			s["claimed"].append(str(milestone))
			for row in config()["milestones"]:
				if int(row["wins"])==milestone: return {"rewards":row["rewards"]}
	return {"error":"未知操作"}
