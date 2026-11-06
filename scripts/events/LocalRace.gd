class_name LocalRace
extends RefCounted
static var _rules := {}
static func rules() -> Dictionary:
	if _rules.is_empty(): _rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/race.json"))
	return _rules
static func state() -> Dictionary:
	if G.local_race.is_empty():G.local_race={"rules":rules(),"current":{},"results":[]}
	return G.local_race
static func tick() -> void:
	var s:=state()
	var g: Dictionary=s.get("current",{}).get("group",{})
	if g.is_empty() or g["state"]=="ended":return
	var now:=G.now()
	var finished:=0
	for m in g["members"]:
		if not m["me"]:
			m["score"]=minf(float(g["target"]),floorf(maxf(0,now-float(g["start"]))*float(m["rate"])))
			if float(m["score"])>=float(g["target"]):m["finished_at"]=float(g["start"])+float(g["target"])/float(m["rate"])
		if m.get("finished_at")!=null:finished+=1
	if finished>=3 or now>=float(g["end"]):
		g["state"]="ended"
		var sorted: Array=g["members"].duplicate()
		sorted.sort_custom(func(a,b):
			if a.get("finished_at")!=null or b.get("finished_at")!=null:return float(a.get("finished_at",INF))<float(b.get("finished_at",INF))
			return float(a["score"])>float(b["score"]) if a["score"]!=b["score"] else int(a["slot"])<int(b["slot"]))
		var mine: Dictionary={}
		for k in sorted.size():
			sorted[k]["place"]=k+1
			if sorted[k]["me"]:
				mine=sorted[k].duplicate(true)
				mine["reward"]=rules()["rewards"][k].duplicate(true) if k<3 else []
		s["results"]=[{"group":g.duplicate(true),"me":mine}]
	G.save_game()
static func join() -> Dictionary:
	var s:=state()
	if not G.gm_activities and G.level<int(rules()["unlock_level"]):return {"ok":false,"message":"12级解锁"}
	if not s["current"].is_empty():return {"ok":false,"message":"当前比赛尚未结束"}
	var ms: Array=[{"slot":0,"me":true,"name":"我","avatar":0,"score":0.0}]
	for k in 4:
		ms.append({"slot":k+1,"me":false,"name":str(rules()["names"][k]),"avatar":k+1,"score":0.0,"rate":float(rules()["target"])/float(rules()["duration_sec"])*(.8+.18*k)})
	s["current"]={"group":{"id":"local_"+Crypto.new().generate_random_bytes(8).hex_encode(),"start":G.now(),"end":G.now()+int(rules()["duration_sec"]),"target":rules()["target"],"state":"racing","members":ms}}
	G.save_game()
	return {"ok":true}
static func order(items: Array) -> void:
	tick()
	var g: Dictionary=state()["current"].get("group",{})
	if g.is_empty() or g["state"]=="ended":return
	var m: Dictionary=g["members"][0]
	m["score"]=minf(float(g["target"]),float(m["score"])+OrderRoll.total(items))
	if float(m["score"])>=float(g["target"]) and not m.has("finished_at"):m["finished_at"]=G.now()
	tick()
static func claim(gid: String) -> Dictionary:
	tick()
	var s:=state()
	if s["results"].is_empty() or str(s["results"][0]["group"]["id"])!=gid:return {"ok":false,"error":"already_claimed"}
	var r: Dictionary=s["results"][0]
	var rw: Array=r["me"]["reward"].duplicate(true)
	var result: Dictionary={"ok":true,"rewards":rw}
	if int(r["me"]["place"])==1:
		s["title"]=rules()["title"].duplicate(true)
		s["title"]["until"]=G.now()+int(s["title"]["hours"])*3600
		result["title"]=s["title"]
	s["current"]={};s["results"]=[]
	G.save_game()
	return result
