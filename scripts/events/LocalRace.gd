class_name LocalRace
extends RefCounted
## 单机版香蕉竞速（没开服务器时 Race.gd 走这里），规则和服务器 race.py 一样，数值读 data/race.json：
## - 假匹配：我 + 4 个影子。影子按等级生成一条阶梯曲线（开局先交一波，之后一单一单地涨，偶尔歇一会儿），
##   和服务器 gen_curve 同一套参数；按开赛后的时间回放。
## - 前 podium 名都收满或时间到就结束；名次先比收满时间，再比香蕉数；只有前三名有奖。
## 状态存在 G.local_race（随存档）。

static var _rules := {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/race.json"))
	return _rules

static func state() -> Dictionary:
	if G.local_race.is_empty():
		G.local_race = {"rules": rules(), "current": {}, "results": []}
	G.local_race["rules"] = rules()
	return G.local_race

## 按等级生成影子曲线 [[距开赛秒数, 累计香蕉], ...]（和服务器 race.gen_curve 一样）
static func gen_curve(rng: RandomNumberGenerator, level: int, dur: float, target: float) -> Array:
	var sh: Dictionary = rules().get("shadow", {})
	var nominal := float(sh.get("nominal_sec", 14400))
	var pace := (float(sh.get("pace_base", 12)) + float(sh.get("pace_per_level", 1.6)) * level) \
		* rng.randf_range(float(sh.get("pace_min", 0.6)), float(sh.get("pace_max", 1.4)))
	var total := pace * nominal / 3600.0
	var avg := float(sh.get("order_base", 8)) + float(sh.get("order_per_level", 2.2)) * level
	var mean_gap := nominal / maxf(3.0, total / avg)
	var t := rng.randf_range(0.0, 0.06) * nominal
	var s := 0.0
	var pts := []
	var opening := (float(sh.get("opening", 30)) + float(sh.get("opening_per_level", 1.5)) * level) * rng.randf_range(0.6, 1.3)
	while s < opening and s < target:
		t += rng.randf_range(40.0, 160.0) * nominal / 7200.0
		s += maxf(1.0, round(avg * rng.randf_range(0.4, 1.7)))
		pts.append([t * dur / nominal, minf(s, target)])
	while s < target:
		var gap := -log(maxf(1e-6, rng.randf())) * mean_gap
		if rng.randf() < 0.07:
			gap *= 4.0
		t += gap
		if t >= nominal:
			break
		s += maxf(1.0, round(avg * rng.randf_range(0.4, 1.7)))
		pts.append([t * dur / nominal, minf(s, target)])
	return pts

static func _replay(m: Dictionary, start: float, t: float, target: float) -> void:
	var s := 0.0
	var fin = null
	for p in m.get("points", []):
		if float(p[0]) > t - start:
			break
		s = float(p[1])
		if fin == null and s >= target:
			fin = start + float(p[0])
	m["score"] = s
	m["finished_at"] = fin

static func tick() -> void:
	var s := state()
	var g: Dictionary = s.get("current", {}).get("group", {})
	if g.is_empty() or g["state"] == "ended":
		return
	var now := G.now()
	var tg := float(g["target"])
	var end_t := minf(now, float(g["end"]))
	for m in g["members"]:
		if not m["me"]:
			_replay(m, float(g["start"]), end_t, tg)
	var fins := []
	for m in g["members"]:
		if m.get("finished_at") != null:
			fins.append(float(m["finished_at"]))
	fins.sort()
	var podium := int(rules().get("podium", 3))
	var ended_at := -1.0
	if fins.size() >= podium:
		ended_at = fins[podium - 1]
	elif now >= float(g["end"]):
		ended_at = float(g["end"])
	if ended_at < 0.0 or now < ended_at:
		return
	# 结束：影子成绩冻结在结束那一刻，排名次
	for m in g["members"]:
		if not m["me"]:
			_replay(m, float(g["start"]), ended_at, tg)
	g["state"] = "ended"
	g["ended_at"] = ended_at
	var sorted: Array = g["members"].duplicate()
	sorted.sort_custom(func(a, b):
		var fa = a.get("finished_at")
		var fb = b.get("finished_at")
		if (fa != null) != (fb != null):
			return fa != null
		if fa != null and float(fa) != float(fb):
			return float(fa) < float(fb)
		if float(a["score"]) != float(b["score"]):
			return float(a["score"]) > float(b["score"])
		return int(a["slot"]) < int(b["slot"]))
	var rws: Array = rules().get("rewards", [])
	var mine := {}
	for k in sorted.size():
		sorted[k]["place"] = k + 1
		if sorted[k]["me"]:
			mine = sorted[k].duplicate(true)
			mine["reward"] = (rws[k] as Array).duplicate(true) if k < mini(3, rws.size()) else []
	s["current"]["me"] = mine
	s["results"] = [{"group": g.duplicate(true), "me": mine}]
	G.save_game()

static func join() -> Dictionary:
	var s := state()
	var rl := rules()
	if not G.gm_activities and G.level < int(rl.get("unlock_level", 12)):
		return {"ok": false, "message": "%d 级解锁香蕉竞速" % int(rl.get("unlock_level", 12))}
	tick()
	var cur: Dictionary = s.get("current", {})
	if not cur.is_empty() and cur.get("group", {}).get("state", "") != "ended":
		return {"ok": true}  # 这一局还没比完：还是这一局
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var now := G.now()
	var dur := float(rl.get("duration_sec", 14400))
	var tg := float(rl.get("target", 150))
	var names: Array = (rl.get("names", []) as Array).duplicate()
	for i in range(names.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = names[i]
		names[i] = names[j]
		names[j] = x
	var avs := int(rl.get("avatars", 8))
	var my_av := 0
	var ms: Array = [{"slot": 0, "me": true, "name": "我", "avatar": my_av, "level": G.level, "score": 0.0, "finished_at": null, "place": null}]
	var used := {my_av: true}
	for k in 4:
		var av := rng.randi_range(0, avs - 1)
		while used.has(av) and used.size() < avs:
			av = rng.randi_range(0, avs - 1)
		used[av] = true
		var lv := maxi(1, G.level + rng.randi_range(-1, 1))
		ms.append({"slot": k + 1, "me": false, "name": str(names[k]) if k < names.size() else "原始人%02d" % rng.randi_range(0, 99),
			"avatar": av, "level": lv, "score": 0.0, "finished_at": null, "place": null, "points": gen_curve(rng, lv, dur, tg)})
	var gid := "local_" + str(int(now)) + "_" + str(rng.randi_range(1000, 9999))
	s["current"] = {"group": {"id": gid, "start": now, "end": now + dur, "ended_at": null, "target": tg, "size": 5,
		"state": "running", "members": ms}, "me": {"score": 0.0}}
	G.save_game()
	return {"ok": true}

static func order(items: Array) -> void:
	tick()
	var g: Dictionary = state()["current"].get("group", {})
	if g.is_empty() or g["state"] == "ended":
		return
	var m: Dictionary = g["members"][0]
	m["score"] = minf(float(g["target"]), float(m["score"]) + OrderRoll.total(items))
	if float(m["score"]) >= float(g["target"]) and m.get("finished_at") == null:
		m["finished_at"] = G.now()
	tick()
	G.save_game()

static func claim(gid: String) -> Dictionary:
	tick()
	var s := state()
	if s["results"].is_empty() or str(s["results"][0]["group"]["id"]) != gid:
		return {"ok": false, "error": "already_claimed"}
	var r: Dictionary = s["results"][0]
	var rw: Array = (r["me"].get("reward", []) as Array).duplicate(true)
	var out := {"ok": true, "rewards": rw}
	if int(r["me"].get("place", 0)) == 1 and rules().get("title") is Dictionary:
		var tt: Dictionary = (rules()["title"] as Dictionary).duplicate(true)
		tt["until"] = G.now() + int(tt.get("hours", 24)) * 3600
		s["title"] = tt
		out["title"] = tt
	s["current"] = {}
	s["results"] = []
	G.save_game()
	return out
