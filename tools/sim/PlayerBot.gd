extends Node
## Policy chooses actions; G, Rewards and event controllers execute the actual game rules.
var cfg: Dictionary
var source_hashes: Dictionary = {}
var start: float
var run_id := 0
var action_count := 0
var events: Array = []
var summaries: Array = []
var claimed_levels: Dictionary = {}
var totals: Dictionary = {}
var target: Array = []
var target_name := ""
var target_story := false
var last_target := ""
var before: Dictionary
var output := "res://tools/sim/report.json"
var stream: FileAccess
var wall_start: int
var observed_level := 1
var last_order_time := 0.0
var warned_stall := false
var finish_reason := ""
var main_limit := 0
var main_finished := false
var target_dirty := true
var resource_tracking := false
var resource_last: Dictionary = {}
var resource_initial: Dictionary = {}
var resource_earned: Dictionary = {}
# 玩家作息：只在 schedule 的在线时段操作；空闲过久就下线，等下一段再上线。
var schedule: Dictionary = {}
var lv_acc: Dictionary = {}
var level_rows: Array = []
var regen_pending := 0
var in_session := true
# 占位活动（tools/sim/placeholder_events.json）：活动还没做时用来预留体力预算。现在四个档期都有真活动，默认关闭，配置 placeholder_events 指向文件才启用
var ph_events: Array = []
var ph_state: Dictionary = {}
var pass_season_seen := ""
var _simulation_ready := false
## 用时分解（微秒）：命令执行 / 事件记录 / 其他决策
var prof := {"command": 0, "record": 0}
var summary_only := false
var before_energy := 0
var event_count := 0

func run() -> int:
	var config_path := "res://tools/sim/config.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--config="): config_path = arg.trim_prefix("--config=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var raw = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not raw is Dictionary:
		push_error("Invalid simulation config: " + config_path)
		return 2
	cfg = raw
	summary_only = bool(cfg.get("summary_only", false))
	# The run uses the configuration loaded at startup, even if files are edited later.
	for file in DirAccess.get_files_at("res://data"):
		if file.ends_with(".json"): source_hashes[file] = FileAccess.get_sha256("res://data/" + file)
	schedule = cfg.get("schedule", {}) if cfg.get("schedule", {}) is Dictionary else {}
	var ph_path:=str(cfg.get("placeholder_events",""))
	if ph_path!="" and FileAccess.file_exists(ph_path):
		var ph=JSON.parse_string(FileAccess.get_file_as_string(ph_path))
		if ph is Dictionary: ph_events=ph.get("events",[])
	if float(cfg.get("cycle_days", 0)) <= 0 or int(cfg.get("max_actions", 0)) <= 0 or float(cfg.get("action_seconds", 0)) <= 0:
		push_error("cycle_days, max_actions and action_seconds must be positive")
		return 2
	if int(cfg.get("runs", 1)) < 1:
		push_error("Use run.py --forever for unbounded batches")
		return 2
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	stream = FileAccess.open(output.get_basename() + ".jsonl", FileAccess.WRITE)
	if stream == null: return 2
	G.set_process(false)
	G.main = null
	Cloud.enabled = false
	Cloud.set_process(false)
	Rank.set_process(false)
	for conn in G.changed.get_connections():
		if conn.callable.get_object() == Rank: G.changed.disconnect(conn.callable)
	G.orders_changed.connect(func(): target_dirty=true)
	Replay.set_process(false)
	main_limit=int(cfg.get("main_story_max_level",0))
	if main_limit<=0 and not Data.STORY.is_empty(): main_limit=int(Data.STORY.keys().max())
	wall_start = Time.get_ticks_msec()
	for n in int(cfg.get("runs", 1)):
		run_id = n + 1
		await play()
		if finish_reason == "invariant_failed": return 1
	stream.close()
	write_report()
	print("SIMULATION_RESULT ", JSON.stringify({"runs": summaries, "events": event_count, "wall_seconds": (Time.get_ticks_msec()-wall_start)/1000.0, "profile_sec": prof_report(), "report": ProjectSettings.globalize_path(output)}))
	return 0

func production_line_metrics() -> Array:
	var out: Array=[]
	for line in Data.LINES:
		out.append({"id":str(line["id"]),"name":str(line["name"]),"generator":str(line["gen"]),"metric":"gen_total_"+str(line["id"]),"max_metric":"gen_max_"+str(line["id"])})
	return out

func owned_items() -> Array:
	var owned: Array=G.inv.duplicate()
	owned.append_array(G.stash)
	for cell in G.board:
		if int(cell.get("lock",0))==0: owned.append(str(cell.get("id","")))
	return owned

func production_line_totals() -> Dictionary:
	# Count level-1 equivalents, including low-level parts: 1, 2, 4, 8, ...
	var chain_totals: Dictionary={}
	for raw in owned_items():
		var id:=str(raw)
		var chain:=Data.chain(id)
		if id=="" or not Data.CHAINS.has(chain) or Data.type_of(id)!="gen": continue
		chain_totals[chain]=int(chain_totals.get(chain,0))+(1 << (Data.lv(id)-1))
	var out: Dictionary={}
	for line in Data.LINES:
		out["gen_total_"+str(line["id"])]=int(chain_totals.get(str(line["gen"]),0))
	return out

func production_line_levels() -> Dictionary:
	var highest: Dictionary={}
	for raw in owned_items():
		var id:=str(raw)
		if id=="" or Data.type_of(id)!="gen": continue
		var chain:=Data.chain(id)
		highest[chain]=maxi(int(highest.get(chain,0)),Data.lv(id))
	var out: Dictionary={}
	for line in Data.LINES:
		out["gen_max_"+str(line["id"])]=int(highest.get(str(line["gen"]),0))
	return out

func begin_resource_tracking() -> void:
	resource_initial={"amber":G.amber,"sand":G.rush}
	resource_last=resource_initial.duplicate()
	resource_earned={"amber":0,"sand":0}
	resource_tracking=true
	if not G.changed.is_connected(track_resources): G.changed.connect(track_resources)

func track_resources() -> void:
	if not resource_tracking: return
	var balances:={"amber":G.amber,"sand":G.rush}
	for kind in balances:
		var amount:=int(balances[kind])
		resource_earned[kind]=int(resource_earned.get(kind,0))+maxi(0,amount-int(resource_last.get(kind,amount)))
		resource_last[kind]=amount

func snap() -> Dictionary:
	track_resources()
	var parts := 0
	for b in Data.BUILDS: parts += int(G.builds.get(str(b["id"]), 0))
	var moon := 0
	var c := MergeEvent.current()
	var activity := MergeEvent.state(c) if MergeEvent.available(c) else {}
	if not activity.is_empty(): moon = MergeEvent.progress(c, activity)
	var state: Dictionary={"level": G.level, "xp": G.xp, "energy": G.energy, "coins": G.shells, "gems": G.amber, "empty": G.rules.board.empty_count(), "storage": G.inv.size(), "stash": G.stash.size(), "parts": parts, "moon": moon, "cards": G.rules.progression.cards_total(), "duel_wins": int(DuelRace.state()["wins"]), "orders": G.orders.size()}
	state.merge(production_line_totals())
	state.merge(production_line_levels())
	state.merge({"sand":G.rush,"amber_earned":int(resource_earned.get("amber",0)),"sand_earned":int(resource_earned.get("sand",0))})
	return state

func record(cat: String, title: String, _reason: String, detail: Dictionary = {}, reward_source: String = "") -> void:
	var t0 := Time.get_ticks_usec()
	_record(cat, title, detail, reward_source)
	prof["record"] = int(prof["record"]) + Time.get_ticks_usec() - t0

func _record(cat: String, title: String, detail: Dictionary, reward_source: String) -> void:
	# 快速模式（summary_only）：只记按等级汇总要用的体力收支和计数，不存逐条事件和状态快照
	if summary_only:
		account(cat, reward_source, G.energy - before_energy, detail)
		before_energy = G.energy
		totals[cat] = int(totals.get(cat, 0)) + 1
		event_count += 1
		return
	var after := snap()
	var delta := {}
	for key in after:
		if after[key] != before.get(key, after[key]): delta[key] = after[key] - before[key]
	var e := {"run": run_id, "seq": events.size()+1, "time": snappedf(G.now()-start, 0.01), "category": cat, "title": title, "state": after, "delta": delta, "detail": detail}
	if reward_source!="": e["reward_source"]=reward_source
	account(cat, reward_source, int(delta.get("energy",0)), detail)
	events.append(e)
	stream.store_line(JSON.stringify(e))
	totals[cat] = int(totals.get(cat, 0)) + 1
	event_count += 1
	before = after
	before_energy = G.energy

func record_reward(source: String, title: String, reason: String, detail: Dictionary = {}) -> void:
	record("reward",title,reason,detail,source)

func record_unlock(board_id: String, cell: int, item: String, result: String, cols: int) -> void:
	var merge_seq:=int(events[-1]["seq"]) if not events.is_empty() else event_count
	var item_name:=Data.name_of(item) if board_id=="main" else str(MergeEvent.item(MergeEvent.current(),item).get("name",item))
	var result_name:=Data.name_of(result) if board_id=="main" else str(MergeEvent.item(MergeEvent.current(),result).get("name",result))
	record("unlock",("主棋盘" if board_id=="main" else "月石棋盘")+" · 解锁藤蔓","与藤蔓格内的同级物品合成，格子解除锁定",{"board":board_id,"cell":cell,"row":int(cell/cols)+1,"col":cell%cols+1,"item":item,"item_name":item_name,"result":result,"result_name":result_name,"lock_before":1,"lock_after":0,"merge_seq":merge_seq})

# ---------------------------------------------------------------- 按等级汇总

func new_level_acc() -> Dictionary:
	return {"level":G.level,"reached":snappedf(G.now()-start,0.01),"day":play_day(),"orders":0,"xp_orders":0,"xp":0,
		"produce":0,"merge":0,"energy_spent":0,"energy_regen":0,"energy_wasted":0,"energy_income":{},"energy_peak":G.energy,
		"active_sec":0.0,"idle_sec":0.0,"offline_sec":0.0,"sessions":0,"stuck":0,"stuck_energy":0,"unlocks":unlocks_at(G.level)}

## 本事件里不算体力恢复的体力变化，按来源记入本级收入或支出
func account(cat: String, source: String, energy_delta: int, detail: Dictionary) -> void:
	if lv_acc.is_empty(): return
	var de := energy_delta-regen_pending
	if regen_pending>0: lv_acc["energy_regen"]=int(lv_acc["energy_regen"])+regen_pending
	regen_pending=0
	var key:=source if source!="" else cat
	if de>0: lv_acc["energy_income"][key]=int(lv_acc["energy_income"].get(key,0))+de
	elif de<0: lv_acc["energy_spent"]=int(lv_acc["energy_spent"])-de
	lv_acc["energy_peak"]=maxi(int(lv_acc["energy_peak"]),G.energy)
	match cat:
		"order":
			lv_acc["orders"]=int(lv_acc["orders"])+1
			var xp:=int((detail.get("rw",{}) as Dictionary).get("xp",0))
			if xp>0:
				lv_acc["xp_orders"]=int(lv_acc["xp_orders"])+1
				lv_acc["xp"]=int(lv_acc["xp"])+xp
		"produce": lv_acc["produce"]=int(lv_acc["produce"])+1
		"merge": lv_acc["merge"]=int(lv_acc["merge"])+1

func close_level_row(partial: bool) -> void:
	if lv_acc.is_empty(): return
	var row:=lv_acc.duplicate(true)
	row["duration"]=snappedf(G.now()-start-float(row["reached"]),0.01)
	row["play_sec"]=snappedf(float(row["active_sec"])+float(row["idle_sec"]),0.01)
	row["xp_need"]=Data.xp_need(int(row["level"]))
	row["partial"]=partial
	level_rows.append(row)

## 升到这一级时新出现的东西：产线 / 订单品类 / 玩法 / 活动 / 部落建筑 / 等级奖励里的生产器
func unlocks_at(lv: int) -> Array:
	var out: Array=Data.level_unlocks(lv) if lv>1 else ["新产线：食物"]
	if lv==int(DuelRace.config().get("unlock_level",0)): out.append("活动：双人竞速")
	if lv==int(LocalRace.rules().get("unlock_level",0)): out.append("活动：香蕉竞速")
	for s in MergeEvent.config().get("seasons",[]):
		if bool(s.get("enabled",true)) and lv==int(s.get("unlock_level",1)) and lv>1: out.append("活动：%s"%str(s.get("title","")))
	for b in Data.BUILDS:
		if b is Dictionary and Data.build_unlock(b)==lv and lv>1: out.append("部落建筑：%s"%str(b.get("name","")))
	for rw in Data.LEVEL_REWARDS.get(lv,[]):
		var id:=str(rw[0])
		if Data.CHAINS.has(Data.chain(id)) and Data.type_of(id)=="gen": out.append("等级奖励生产器：%s %d级"%[Data.name_of(id),Data.lv(id)])
	for ev in ph_events:
		if int(ev["unlock_level"])==lv: out.append("活动：%s"%str(ev["name"]))
	return out

# ---------------------------------------------------------------- 作息

## 按北京时间算第几天（从 1 开始）
func play_day() -> int:
	return int((G.now()+28800)/86400.0)-int((start+28800)/86400.0)+1

## 当天的在线时段，[开始秒, 结束秒]（北京时间当天零点起）
func sessions_today(day: int = -1) -> Array:
	if day<0: day=play_day()
	var days: Array=schedule.get("days",[])
	var plan: Array=days[mini(day-1,days.size()-1)] if not days.is_empty() else []
	var out: Array=[]
	for s in plan:
		var hm:=str(s[0]).split(":")
		var a:=int(hm[0])*3600+int(hm[1])*60
		out.append([a,a+int(s[1])*60])
	return out

func local_tod() -> float:
	return fmod(G.now()+28800,86400.0)

## 当前时段剩余秒数；不在线返回 0。没配置作息就视为一直在线。
func session_left() -> float:
	if schedule.is_empty(): return INF
	var t:=local_tod()
	for s in sessions_today():
		if t>=float(s[0]) and t<float(s[1]): return float(s[1])-t
	return 0.0

func secs_to_next_session() -> float:
	var t:=local_tod()
	for s in sessions_today():
		if float(s[0])>t: return float(s[0])-t
	# 明天第一段
	var day_left:=86400.0-t
	var first: Array=sessions_today(play_day()+1)
	return day_left+(float(first[0][0]) if not first.is_empty() else 0.0)

## 下线到下一段在线时段
func go_offline(why: String) -> void:
	var seconds:=minf(secs_to_next_session(),float(cfg["cycle_days"])*86400-(G.now()-start))
	if seconds<=0: return
	var began:=G.now()-start
	tick(seconds,"offline")
	record("offline","下线 "+G.fmt_time(int(seconds)),why,{"seconds":seconds,"from":began,"why":why})
	in_session=false

func target_level_reached() -> bool:
	var limit:=int(cfg.get("stop_level",40))
	var generator: Dictionary = cfg.get("stop_generator", {})
	if not generator.is_empty():
		for id in owned_items():
			if Data.chain(str(id)) == str(generator.get("chain", "")) and Data.lv(str(id)) >= int(generator.get("level", 99)): return true
	return limit>0 and G.level>=limit

func observe_level() -> void:
	if G.level!=observed_level:
		close_level_row(false)
		lv_acc=new_level_acc()
		record("level", "升到 %d 级" % G.level, "订单或建造奖励达到升级条件", {"from": observed_level, "to": G.level, "unlocks": lv_acc["unlocks"]})
		observed_level=G.level

func tick(seconds: float, mode: String = "active") -> void:
	if not lv_acc.is_empty():
		var wasted := maxf(0, seconds - float(G.rules.clock.energy_full_left())) / G.REGEN_SEC
		lv_acc["energy_wasted"] = int(lv_acc["energy_wasted"]) + int(wasted)
		lv_acc[mode + "_sec"] = float(lv_acc[mode + "_sec"]) + seconds
	var energy_before := G.energy
	var cooked_before := G.cooked_pop.size()
	G.simulation_time += seconds
	advance_time()
	regen_pending += maxi(0, G.energy - energy_before)
	for k in range(cooked_before, G.cooked_pop.size()):
		var at := int(G.cooked_pop[k])
		record("craft", "制作完成 · " + Data.name_of(G.rules.board.cell_id(at)), "计时结束", {"dish": G.rules.board.cell_id(at), "cell": at})

## 时间推进：和 Replay.perform("tick") 执行同一套 advance 与数值规整，但不做前后两次完整存档快照
## （时间推进不会失败、不需要回滚；演算不写操作日志）。配置 fast_tick=false 走原来的完整命令。
func advance_time() -> void:
	if not bool(cfg.get("fast_tick", true)):
		command("tick")
		return
	ensure_simulation()
	var t0 := Time.get_ticks_usec()
	var was_blocked: bool = G.is_blocking_signals()
	G.set_block_signals(true)
	G.clear_presentations()
	Replay.clock = maxi(Replay.clock, int(G.simulation_time))
	Replay.executing = true
	Replay.advance()
	Replay._canonicalize_live()
	Replay.executing = false
	G.clear_presentations()
	G.set_block_signals(was_blocked)
	track_resources()
	target_dirty = true
	prof["command"] = int(prof["command"]) + Time.get_ticks_usec() - t0

func play() -> void:
	start = float(Time.get_unix_time_from_datetime_string(str(cfg["start_utc"])))
	G.simulation_time = start
	G.rng.seed = int(cfg["seed"]) + run_id - 1
	seed(int(cfg["seed"]) + run_id - 1)
	resource_tracking=false
	Replay.active = true
	Replay.worker = true
	Replay.authorized = true
	Replay.executing = true
	Replay.meta = {"allow_gm": false}
	Replay.seq = 0
	Replay.base = 0
	Replay.clock = int(start)
	Replay.pending = []
	Replay.inflight = {}
	G.replay_meta = Replay.meta
	G.new_game()
	var resume_path := str(cfg.get("start_snapshot", ""))
	if resume_path != "":
		var saved = JSON.parse_string(FileAccess.get_file_as_string(resume_path))
		if not saved is Dictionary or not Replay.restore(saved):
			push_error("Invalid simulation starting snapshot")
			finish_reason = "invariant_failed"
			return
		start = float(Replay.clock)
		G.simulation_time = start
	# Gameplay uses named random streams, independently of the UI/global RNGs.
	G.random_seed = "simulation:%d" % (int(cfg["seed"]) + run_id - 1)
	G.random_streams = {}
	Replay.advance()
	Replay.executing = false
	G.clear_presentations()
	_simulation_ready = true
	begin_resource_tracking()
	claimed_levels = {}
	ph_state = {}
	pass_season_seen = ""
	totals = {}
	target = []
	last_target = ""
	action_count = 0
	observed_level = G.level
	last_order_time = 0
	warned_stall = false
	finish_reason = "duration_limit"
	main_finished=false
	target_dirty=true
	before = snap()
	before_energy = G.energy
	level_rows=[]
	regen_pending=0
	in_session=session_left()>0
	lv_acc=new_level_acc()
	lv_acc["sessions"]=1 if in_session else 0
	record("start", "从新存档开始", "按当前工程配置初始化，不赠送额外资源", {"seed": int(cfg["seed"])+run_id-1})
	while G.now()-start < float(cfg["cycle_days"])*86400 and action_count < int(cfg["max_actions"]):
		if not main_finished and main_limit>0 and G.level>main_limit:
			main_finished=true
			target_dirty=true
			record("milestone","配置主线完成","之后继续副线、活动和部落建造",{"last_configured_level":main_limit})
		observe_level()
		if target_level_reached():
			finish_reason = "target_level"
			break
		if not valid_state():
			finish_reason = "invariant_failed"
			record("error", "状态校验失败", "停止本轮，保留完整日志")
			break
		if session_left()<=0:
			go_offline("不在作息的在线时段")
			continue
		if not in_session:
			in_session=true
			lv_acc["sessions"]=int(lv_acc["sessions"])+1
		if timed("upgrade_tribe", upgrade_tribe): pass
		elif timed("rewards", rewards): pass
		elif timed("free_extras", free_extras): pass
		elif finish_tutorial(): pass
		elif timed("submit_orders", submit_orders): pass
		else:
			timed("choose_target", func(): choose_target(); return false)
			if timed("retrieve", retrieve): pass
			elif timed("merge_main", merge_main): pass
			elif timed("events", func(): return events_step(false)): pass
			elif timed("produce", produce): pass
			# 活动玩法（月石合成、占位活动抽奖）排在主棋盘生产之后：没体力、没事干时用来填空档
			elif timed("events_play", func(): return events_step(true)): pass
			elif timed("make_room", make_room): pass
			else:
				var previous_target:=str(target)
				target_dirty=true
				choose_target()
				if str(target)==previous_target: wait_next()
		action_count += 1
		if target_level_reached():
			finish_reason="target_level"
			observe_level()
			break
		var tt := Time.get_ticks_usec()
		tick(minf(float(cfg["action_seconds"]),maxf(0,float(cfg["cycle_days"])*86400-(G.now()-start))))
		prof["tick"] = int(prof.get("tick", 0)) + Time.get_ticks_usec() - tt
		if action_count % 1000 == 0:
			print("SIM_PROGRESS run=", run_id, " actions=", action_count, " day=", snappedf((G.now()-start)/86400,0.01), " level=",G.level)
			await get_tree().process_frame
	if finish_reason!="target_level" and action_count >= int(cfg["max_actions"]): finish_reason = "action_limit"
	record("end", "本轮结束", {"duration_limit":"达到配置的模拟时长", "action_limit":"达到动作上限", "target_level":"达到目标等级", "invariant_failed":"状态校验失败"}[finish_reason], {"reason":finish_reason})
	close_level_row(true)
	var summary := {"run":run_id,"seed":int(cfg["seed"])+run_id-1,"duration":G.now()-start,"actions":action_count,"state":snap(),"counts":totals.duplicate(),"finish_reason":finish_reason,"resource_initial":resource_initial.duplicate(),"levels":level_rows.duplicate(true)}
	summaries.append(summary)
	var state_file := FileAccess.open(output.get_basename()+"-run%d-save.json"%run_id,FileAccess.WRITE)
	state_file.store_string(JSON.stringify(G.save_dict()))
	state_file.close()
	stream.flush()
	write_report()

func timed(key: String, f: Callable) -> bool:
	var t0 := Time.get_ticks_usec()
	var r: bool = f.call()
	prof[key] = int(prof.get(key, 0)) + Time.get_ticks_usec() - t0
	return r

func valid_state() -> bool:
	return G.energy >= 0 and G.shells >= 0 and G.amber >= 0 and G.inv.size() <= G.inv_cap and G.board.size() == G.COLS*G.ROWS and G.orders.size() <= Data.order_total(G.level)

func grant(rw: Array) -> void:
	# Placeholder-event budgets are intentionally simulator-only.
	Rewards.settle(rw)
	track_resources()

func reward_summary(rewards: Array) -> String:
	var parts:=PackedStringArray()
	var labels:={"energy":"体力","shell":"不那那","amber":"琥珀","sand":"沙漏","xp":"经验","token":"祭典积分"}
	for rw in rewards:
		if not rw is Array or rw.size()<2: continue
		var id:=str(rw[0])
		var n:=int(rw[1])
		var kind:=Rewards.kind(id)
		if n<=0 or kind=="": continue
		var physical: bool=rw.size()>2 and str(rw[2]) in ["item","physical"]
		if physical and str(rw[2])=="item" and kind in Rewards.RESOURCE_TYPES and Data.value_of(id)>0:
			n*=Data.value_of(id)
			physical=false
		var label:=Data.name_of(id) if physical else str(labels.get(kind,Data.name_of(id)))
		parts.append("%s×%d"%[label,n])
	return "、".join(parts) if not parts.is_empty() else "无奖励"

func rewards() -> bool:
	for lv in range(2, G.level+1):
		if not claimed_levels.has(lv):
			claimed_levels[lv] = true
			var result := command("level", {"level": lv})
			var rw: Array = result.get("rewards", [])
			if result.has("error"): continue
			record_reward("level", "领取 %d 级奖励" % lv, "达到等级，领取一次",{"level":lv,"rewards":rw.duplicate(true),"received":reward_summary(rw)})
			return true
	for id in G.discovered:
		if G.rules.board.book_prize(id):
			var result := command("book", {"id": id})
			if result.has("error"): continue
			var amount := int(result.get("energy", 0))
			record_reward("book", "图鉴 · " + Data.name_of(id), "发现新物品", {"energy":amount})
			return true
	for day in SevenDay.config()["days"]:
		for task in day["tasks"]:
			if SevenDay.done(task) and not SevenDay.got(task):
				command("seven", {"id": str(task["id"]), "stage": false})
				record_reward("seven_day_task", "七日任务奖励", "任务已完成", {"task":task})
				return true
	for stage in SevenDay.config()["milestones"]:
		if SevenDay.stage_ready(stage):
			command("seven", {"id": str(stage["id"]), "stage": true})
			record_reward("seven_day_stage", "七日里程碑", "累计任务积分达标", {"stage":stage})
			return true
	if pass_season_seen != G.pass_season:
		if pass_season_seen != "":
			record("milestone","通行证换季","第 %s 季开始，积分与已领档位清零"%G.pass_season,{"season":G.pass_season})
		pass_season_seen = G.pass_season
	for lv in range(1,G.rules.progression.pass_reached()+1):
		if not G.rules.progression.pass_got(false,lv):
			var result := command("pass", {"track": "free", "level": lv})
			var rw: Array = result.get("rewards", [])
			if not rw.is_empty():
				record_reward("pass", "通行证免费奖励", "已达到第 %d 档"%lv)
				return true
	for deal in Data.daily_deals(G.level):
		if int(deal.get("price",0)) == 0 and str(deal.get("mode","")) != "ad" and DailyShop.can_claim(deal):
			var claimed := command("daily", {"key": str(deal["key"])})
			if not claimed.get("ok",false): continue
			record_reward("daily", "领取每日免费补给", "今日尚未领取", {"key":deal["key"]})
			return true
	for i in G.board.size():
		if int(G.board[i]["lock"]) != 0: continue
		if G.board[i].has("rw"):
			var rw: Array = G.board[i]["rw"]
			var result := command("bubble_reward", {"cell": i})
			if result.has("error"): continue
			record_reward("land", "领取开地奖励", "覆盖已经揭开", {"cell":i,"rewards":rw})
			return true
		var id: String = G.rules.board.cell_id(i)
		if id == "" or G.rules.orders.cooking(i): continue
		var kind := Data.type_of(id)
		if kind in Rewards.RESOURCE_TYPES and Data.value_of(id)>0:
			# Prefer merging resources; collect when needed, full, or at maximum tier.
			# 沙漏：有制作在计时就收，攒着加速
			var urgent: bool = (kind=="energy" and G.energy < 10) or G.rules.board.empty_count()<2 or Data.next_id(id)=="" or (kind=="sand" and cooking_any())
			if urgent:
				var result := command("tap", {"cell": i})
				if result.has("error"): continue
				record_reward("resource_"+kind, "收取 "+Data.name_of(id), "需要资源或腾出棋盘格子", {"item":id})
				return true
		if kind == "pack" and G.level>=Data.CARD_LEVEL:
			command("pack", {"id": id, "cell": i})
			record_reward("cards", "打开典藏卡包", "典藏卡已解锁")
			return true
		if not ChoiceChest.definition(id).is_empty():
			var choices: Array = ChoiceChest.definition(id)["choices"]
			var option := 0
			for j in choices.size():
				if useful(str(choices[j])): option=j; break
			command("choice", {"cell": i, "option": option})
			record_reward("choice_chest", "打开自选宝箱", "优先选择当前订单产线", {"item":choices[option]})
			return true
		if kind == "chest":
			var drop := command("tap", {"cell": i})
			if drop.has("error"): continue
			record_reward("chest", "领取宝箱物品", "每次取出一件，领完宝箱消失", {"items":[drop["id"]]})
			return true
	var si: int = G.rules.board.stash_claim_index()
	if si>=0:
		var id := str(G.stash[si])
		var k := Data.type_of(id)
		if k == "pack":
			command("pack", {"id": id, "stash": si})
			record_reward("cards", "领取暂存卡包", "8 级后开启")
			return true
		if k in Rewards.RESOURCE_TYPES and Data.value_of(id)>0:
			var result := command("stash", {"index": si})
			if result.has("error"): return false
			record_reward("stash", "收取暂存资源", "无需占用棋盘", {"item":id})
			return true
		if G.rules.board.empty_count()>1:
			var result := command("stash", {"index": si})
			if result.has("error"): return false
			record("stash", "取出 "+Data.name_of(id), "棋盘有空位", {"item":id})
			return true
	return false

func submit_orders() -> bool:
	choose_target()
	var needs := xp_needs()
	for i in G.orders.size():
		var o: Dictionary = G.orders[i]
		if main_finished and bool(o.get("story",false)): continue
		if str(o.get("phase", "")) == "finished":
			var at := int(o.get("cell", -1))
			var taken := command("tap", {"cell": at})
			if not taken.has("error"):
				record("craft", "取出制作完成的菜品", "设备已完成制作，先取出再提交", {"dish": o.get("dish", ""), "cell": at})
				return true
		if target_story and not bool(o.get("story",false)) and (o.get("items",[]) as Array).any(func(id):return useful(str(id))): continue
		# 真人策略：经验单还没凑齐时，不拿同产线、不高于所缺等级的材料去交没经验的单（免得把要合上去的料吃掉）
		if int(o.get("rw",{}).get("xp",0))<=0 and str(o.get("phase","need"))=="need" and eats_xp_material(o, needs): continue
		if G.rules.orders.order_ready(o):
			var rw: Dictionary = o["rw"].duplicate(true)
			var detail := o.duplicate(true)
			var completed := command("order", {"cell": i})
			if completed.has("error"): continue
			ph_gain("per_order",1)
			if int(rw.get("xp",0))>0: ph_gain("per_xp_order",1)
			record("order", ("主线" if detail.get("story",false) else "副线")+"订单完成", "所需物品已齐全",detail)
			last_order_time = G.now()-start
			warned_stall = false
			return true
		if G.rules.orders.craft_mats_ready(o):
			var made := command("craft", {"cell": i})
			if made.has("error"): continue
			record("craft", "开始制作 · "+Data.name_of(str(o.get("dish",""))), "材料齐全，等待制作完成",o.duplicate(true))
			return true
	return rush_crafts()

## 开放经验、还没凑齐的订单缺哪些产线的料：产线 -> 所缺最高等级
func xp_needs() -> Dictionary:
	var out := {}
	for o in G.orders:
		if int(o.get("rw",{}).get("xp",0))<=0 or str(o.get("phase","need"))!="need": continue
		if G.rules.orders.order_ready(o) or G.rules.orders.craft_mats_ready(o): continue
		var used: Array=[]
		for raw in o.get("mats", o.get("items", [])):
			var id:=str(raw)
			var cell: int=G.rules.orders.board_has(id,used)
			if cell>=0: used.append(cell); continue
			out[Data.chain(id)]=maxi(int(out.get(Data.chain(id),0)),Data.lv(id))
	return out

func eats_xp_material(o: Dictionary, needs: Dictionary) -> bool:
	for raw in o.get("mats", o.get("items", [])):
		var id:=str(raw)
		if needs.has(Data.chain(id)) and Data.lv(id)<=int(needs[Data.chain(id)]): return true
	return false

func cooking_any() -> bool:
	for i in G.board.size():
		if G.rules.orders.cooking(i): return true
	return false

## 沙漏够把一格制作直接做完就用（剩不到 1 份时间的不浪费沙漏）
func rush_crafts() -> bool:
	if G.rush<1: return false
	for i in G.board.size():
		if not G.rules.orders.cooking(i) or G.rules.orders.cook_left(i)<=int(cfg.get("rush_min_left",60)): continue
		var need: int=G.rules.orders.rush_need(i)
		if need>G.rush: continue
		var dish:=str(G.board[i]["ck"]["dish"])
		var left:=G.rules.orders.cook_left(i)
		var used := int(command("rush", {"cell": i}).get("used", 0))
		record("craft","沙漏加速 · "+Data.name_of(dish),"沙漏够直接做完",{"dish":dish,"sand":used,"saved_sec":left,"sand_left":G.rush})
		return true
	return false

func upgrade_tribe() -> bool:
	var b: String = G.rules.progression.next_build_id()
	if b!="" and G.shells>=G.rules.progression.build_cost(b):
		var cost: int=G.rules.progression.build_cost(b)
		var result := command("build", {"id": b})
		if result.is_empty() or result.has("error"): return false
		record("build", "升级部落 · "+str(Data.build_def(b).get("name",b)), "不那那足够，独立推进部落", {"building":b,"stage":int(G.builds.get(b,0)),"step":int(result.get("step",0)),"finished":bool(result.get("finished",true)),"cost":cost,"rewards":result.get("rewards",[])})
		return true
	return false

func finish_tutorial() -> bool:
	if not G.tutorial_on or int(G.builds.get("fire", 0)) < 2: return false
	for order in G.orders:
		if order.has("tutorial") or "seed_1" in order.get("items", []): return false
	var result := command("tutorial_finish")
	if result.has("error"): return false
	target_dirty = true
	record("milestone", "新手阶段完成", "教学订单与首次部落升级完成，进入正式订单")
	return true

func free_item(i: int) -> bool:
	return G.rules.board.is_free(i) and G.rules.board.cell_id(i)!="" and not G.rules.orders.cooking(i)

func choose_target() -> void:
	if not target_dirty and action_count%50!=0: return
	target_dirty=false
	var best := INF
	target=[]
	target_name=""
	target_story=false
	# 棋盘只扫一遍：各产线最快的生产器产出率、可用物品（产线、等级），以及棋盘上有哪些物品
	var rate_of := {}
	var owned: Array=[]
	var on_board := {}
	for j in G.board.size():
		var cid: String=G.rules.board.cell_id(j)
		if cid!="" and int(G.board[j]["lock"])==0: on_board[cid]=true
		if not free_item(j): continue
		owned.append([Data.chain(cid),Data.lv(cid)])
		var per := {}
		for d in Data.gen_stats(cid).get("drops",[]):
			var dch:=Data.chain(str(d["id"]))
			per[dch]=float(per.get(dch,0.0))+float(d["p"])*pow(2,Data.lv(str(d["id"]))-1)/100.0
		for dch in per: rate_of[dch]=maxf(float(rate_of.get(dch,0.0)),float(per[dch]))
	for o in G.orders:
		if main_finished and bool(o.get("story",false)): continue
		var ids: Array = G.rules.orders._order_need_ids(o)
		if ids.is_empty(): continue
		var cost := 0.0
		var reachable := true
		for raw in ids:
			var id := str(raw)
			if on_board.has(id) or G.inv.has(id): continue
			var ch := Data.chain(id)
			var prob := float(rate_of.get(ch,0.0))
			var mass := 0.0
			var need_lv := Data.lv(id)
			for it in owned:
				if it[0]==ch and int(it[1])<need_lv: mass+=pow(2,int(it[1])-1)
			if prob<=0 and mass<pow(2,Data.lv(id)-1): reachable=false
			cost += maxf(0,pow(2,Data.lv(id)-1)-mass)/maxf(prob,0.01)
		if bool(o.get("story",false)) and bool(cfg.get("story_first",true)): cost-=100000
		# 制作单材料便宜时和主线同等优先（真人会顺手凑齐），贵的等没别的事再做
		elif str(o.get("kind",""))=="craft" and cost<=float(cfg.get("craft_pursue_taps",40)): cost-=100000
		# XP is fixed on displayed orders. Farming cheap zero-XP cards cannot level up.
		if int(o.get("rw", {}).get("xp", 0)) > 0: cost -= 200000
		if not reachable: cost+=1000000
		if cost<best:
			best=cost
			target=ids.duplicate()
			target_story=bool(o.get("story",false))
			target_name=("主线" if o.get("story",false) else "副线")+" · "+"、".join(PackedStringArray(ids.map(func(id):return Data.name_of(str(id)))))
	var signature := str(target)
	if signature!=last_target:
		last_target=signature
		record("decision","目标："+target_name,"优先可生产的经验单，其次主线和低成本制作",{"items":target})

func useful(id: String) -> bool:
	for raw in target:
		if Data.chain(str(raw))==Data.chain(id) and Data.lv(id)<=Data.lv(str(raw)): return true
	return false

func production_rate(ch: String) -> float:
	var rate := 0.0
	for i in G.board.size():
		if not free_item(i): continue
		var st := Data.gen_stats(G.rules.board.cell_id(i))
		var r := 0.0
		for d in st.get("drops",[]):
			if Data.chain(str(d["id"]))==ch: r+=float(d["p"])*pow(2,Data.lv(str(d["id"]))-1)/100.0
		rate=maxf(rate,r)
	return rate

func retrieve() -> bool:
	if G.rules.board.empty_count()<1: return false
	for j in G.inv.size():
		var id := str(G.inv[j])
		var spare := 0
		for cell in G.board.size():
			if free_item(cell) and G.rules.board.cell_id(cell)==id: spare+=1
		spare-=target.count(id)
		var can_merge := spare>0 and Data.next_id(id)!=""
		if (target.has(id) and G.rules.orders.board_has(id)<0) or can_merge:
			var result := command("inventory", {"index": j})
			if result.has("error"): continue
			record("storage","取回 "+Data.name_of(id),"订单需要或可继续合成",{"item":id})
			return true
	return false

func merge_main() -> bool:
	var best := -INF
	var a := -1
	var b := -1
	var reserve := {}
	for id in target: reserve[id]=int(reserve.get(id,0))+1
	# 一遍扫棋盘，按物品分组：可拖动的格子数、可作为落点的格子（与逐对比较结果相同）
	var n_cells: int=G.board.size()
	var ids: Array=[]
	ids.resize(n_cells)
	var free: Array=[]
	free.resize(n_cells)
	var available := {}
	var targets := {}
	for k in n_cells:
		var id: String=G.rules.board.cell_id(k)
		ids[k]=id
		if id=="": free[k]=false; continue
		var cooking: bool=G.rules.orders.cooking(k)
		free[k]=G.rules.board.is_free(k) and not cooking
		if free[k]: available[id]=int(available.get(id,0))+1
		if int(G.board[k]["lock"])<2 and not cooking:
			if not targets.has(id): targets[id]=[]
			targets[id].append(k)
	var scored := {}
	for i in n_cells:
		if not free[i]: continue
		var id: String=ids[i]
		if not targets.has(id) or Data.next_id(id)=="": continue
		for j in targets[id]:
			if i==j: continue
			var locked := int(G.board[j]["lock"])==1
			if not locked and int(available.get(id,0))-int(reserve.get(id,0))<2: continue
			var score: float
			if scored.has(j): score=scored[j]
			else:
				score=0.0
				if locked: score+=1000
				if Data.type_of(id)=="gen": score+=500
				if useful(Data.next_id(id)): score+=200
				for n in MergeGrid.neighbors(j,G.COLS,n_cells):
					if int(G.board[n]["lock"])==2: score+=60
				score-=Data.lv(id)
				scored[j]=score
			if score>best: best=score; a=i; b=j
	if a<0: return false
	var id: String=G.rules.board.cell_id(a)
	var locked := int(G.board[b]["lock"])==1
	var result := str(command("drop", {"from": a, "to": b}).get("kind", ""))
	if result!="merge": return false
	record("merge","合成 "+Data.name_of(G.rules.board.cell_id(b)),"解锁藤蔓" if locked else "满足订单、升级生产器或整理棋盘",{"from":a,"to":b,"item":id,"result":G.rules.board.cell_id(b),"revealed":G.opened.duplicate(),"unlock_recorded":locked})
	if locked: record_unlock("main",b,id,G.rules.board.cell_id(b),G.COLS)
	return true

## 火种罐这类体力生产器点击不耗体力：有次数、棋盘留得出空位就点
func tap_energy_gen() -> bool:
	if G.rules.board.empty_count() < 2: return false
	for i in G.board.size():
		if not free_item(i) or Data.type_of(G.rules.board.cell_id(i)) != "egen" or G.rules.board.gen_left(i) == 0: continue
		var gen := G.rules.board.cell_id(i)
		var result := command("tap", {"cell": i})
		if result.has("error"): continue
		var id := str(result.get("id", ""))
		record("egen", "点火种罐 · " + Data.name_of(id), "体力生产器不耗体力", {"generator": gen, "item": id, "left": G.rules.board.gen_left(i)})
		return true
	return false

func produce() -> bool:
	if tap_energy_gen(): return true
	if G.energy<1 or G.rules.board.empty_count()<1: return false
	var missing := {}
	var used: Array=[]
	for raw in target:
		var id:=str(raw)
		var cell: int=G.rules.orders.board_has(id,used)
		if cell>=0: used.append(cell)
		else: missing[Data.chain(id)]=maxi(int(missing.get(Data.chain(id),0)),Data.lv(id))
	var best := 0.0
	var chosen := -1
	for i in G.board.size():
		if not free_item(i): continue
		var st:=Data.gen_stats(G.rules.board.cell_id(i))
		if st.is_empty() or G.rules.board.gen_left(i)==0: continue
		var score:=0.0
		for d in st.get("drops",[]):
			if missing.has(Data.chain(str(d["id"]))): score+=float(d["p"])*pow(2,Data.lv(str(d["id"]))-1)
		if score>best: best=score; chosen=i
	if chosen<0: return false
	set_boost_for(chosen, missing)
	var result := command("tap", {"cell": chosen})
	if result.has("error"): return false
	var id := str(result.get("id", ""))
	ph_gain("per_energy", G.rules.board.gen_cost())
	record("produce", "生产 " + Data.name_of(id), target_name, {"generator": G.rules.board.cell_id(chosen), "item": id})
	return true

## 双倍体力：解锁后，只要缺的目标物品比这台生产器的产物高，就开着（2 体力出高 1 级，省一半点击和第一层合成）
func set_boost_for(cell: int, missing: Dictionary) -> void:
	if not bool(cfg.get("use_boost", true)) or not G.rules.board.boost_open(): return
	var want := false
	if G.energy >= 2:
		for d in Data.gen_stats(G.rules.board.cell_id(cell)).get("drops", []):
			var id := str(d["id"])
			if int(missing.get(Data.chain(id), 0)) > Data.lv(id): want = true; break
	if want != G.boost: command("boost", {"on": want})

func make_room() -> bool:
	if G.rules.board.empty_count()>1: return false
	var best_store:=-1
	var store_value:=-1.0
	var worst:=-1
	var worst_value:=INF
	for i in G.board.size():
		if not free_item(i): continue
		var id: String=G.rules.board.cell_id(i)
		var kind:=Data.type_of(id)
		if target.has(id): continue
		var value:=OrderRoll.flames(id)
		if kind=="gen": value+=100000
		if not useful(id) and value>store_value and (kind=="item" or (kind=="gen" and Data.gen_stats(id).is_empty())):
			best_store=i; store_value=value
		if kind=="item" and not useful(id) and Data.lv(id)<=int(cfg.get("delete_max_level",10)) and value<worst_value:
			worst=i; worst_value=value
	if best_store>=0 and bool(cfg.get("use_storage",true)):
		if G.inv.size()>=G.inv_cap and bool(cfg.get("expand_storage",false)) and G.inv_cap<int(cfg.get("max_storage",20)) and G.amber>=G.rules.progression.storage_price():
			command("expand")
			record("storage","扩建储物洞","保护高价值物品，使用配置允许的琥珀预算")
			return true
		if G.inv.size()<G.inv_cap:
			var id: String=G.rules.board.cell_id(best_store)
			# Active generators carry cooldown state; leave them on board.
			if not G.board[best_store].has("gm"):
				var result := command("store", {"cell": best_store})
				if result.has("error"): return false
				record("storage","存入 "+Data.name_of(id),"棋盘拥挤，保留当前暂时不用的高价值物品",{"item":id})
				return true
	if worst>=0:
		var id: String=G.rules.board.cell_id(worst)
		var result := command("discard", {"cell": worst})
		if result.has("error"): return false
		command("discard_finish")
		record("delete","丢弃 "+Data.name_of(id),"储物洞无法再收纳，清理非目标产线低价值物品",{"item":id,"refund":Data.value_of(id)})
		return true
	return false

# ---------------------------------------------------------------- 占位活动

func ph_on(ev: Dictionary) -> bool:
	return bool(cfg.get("play_events",true)) and not G.tutorial_on and G.level>=int(ev["unlock_level"])

## 当前这一期的状态；换期时清零，并记下没买的付费档
func ph_sync(ev: Dictionary) -> Dictionary:
	var id:=str(ev["id"])
	var season:=int((G.now()-start)/(float(ev["season_days"])*86400.0))
	var st: Dictionary=ph_state.get(id,{})
	if st.is_empty() or int(st["season"])!=season:
		if not st.is_empty() and ev.has("paid"):
			record("event",str(ev["name"])+" 换期","零付费：付费档未购买",{"event":id,"season":st["season"],"earned":st["earned"],"plays":st["plays"],"claimed":st["claimed"],"paid_skipped":ev["paid"]})
		st={"season":season,"points":0,"earned":0,"plays":0,"claimed":0}
		ph_state[id]=st
	return st

func ph_gain(kind: String, n: int) -> void:
	for ev in ph_events:
		if not ph_on(ev): continue
		var per:=int((ev.get("points",{}) as Dictionary).get(kind,0))
		if per<=0: continue
		var st:=ph_sync(ev)
		st["points"]=int(st["points"])+per*n
		st["earned"]=int(st["earned"])+per*n

func ph_step(play_now: bool) -> bool:
	for ev in ph_events:
		if not ph_on(ev): continue
		var st:=ph_sync(ev)
		var ms: Array=ev.get("milestones",[])
		var k:=int(st["claimed"])
		var progress:=int(st["plays"]) if str(ev.get("milestone_on","points"))=="plays" else int(st["earned"])
		if k<ms.size() and progress>=int(ms[k][0]):
			st["claimed"]=k+1
			grant(ms[k][1])
			record_reward("ph_"+str(ev["id"]),str(ev["name"])+" 阶段奖励","累计进度达到 %d"%int(ms[k][0]),{"event":ev["id"],"stage":k+1,"rewards":ms[k][1],"received":reward_summary(ms[k][1])})
			return true
		var play: Dictionary=ev.get("play",{}) if play_now else {}
		if not play.is_empty() and int(st["points"])>=int(play["cost"]):
			st["points"]=int(st["points"])-int(play["cost"])
			st["plays"]=int(st["plays"])+1
			var table: Array=play["table"]
			var total:=0
			for row in table: total+=int(row[1])
			var roll:=randi()%maxi(1,total)
			var got: Array=table[0][0]
			for row in table:
				roll-=int(row[1])
				if roll<0: got=row[0]; break
			grant([got])
			record_reward("ph_"+str(ev["id"]),str(ev["name"])+" 抽奖","花活动积分玩一次",{"event":ev["id"],"rewards":[got],"received":reward_summary([got])})
			return true
	return false

## play=false 只做领奖、报名这类杂事；play=true 才花活动积分玩活动
func events_step(play: bool) -> bool:
	if not bool(cfg.get("play_events",true)) or G.tutorial_on: return false
	if ph_step(play): return true
	if DuelRace.unlocked():
		var duel:=DuelRace.state()
		var match_state: Dictionary=duel["match"]
		var milestones:=DuelRace.ready_milestones()
		if not milestones.is_empty():
			command("duel", {"action": "milestone", "milestone": int(milestones[0])})
			record_reward("duel_milestone","双人竞速累计胜利奖励","达到胜场里程碑",{"wins":milestones[0]})
			return true
		if not match_state.is_empty() and match_state["status"]!="running" and not match_state.get("claimed",false):
			var result: Dictionary=match_state.duplicate(true)
			command("duel", {"action": "claim"})
			record_reward("duel_match","双人竞速胜利" if result["status"]=="won" else "双人竞速落败","先达到配置目标积分的一方获胜",{"match":result,"wins":duel["wins"]})
			return true
		if (match_state.is_empty() or match_state.get("claimed",false)) and ActivitySchedule.scheduled("duel"):
			var joined := command("duel", {"action": "join"})
			if not joined.has("error"):
				record("event","参加双人竞速","完成主棋盘订单获得积分")
				return true
	if tiger_step(): return true
	if fossil_step(play): return true
	var race:=LocalRace.state()
	if not race.get("results",[]).is_empty():
		var r: Dictionary=race["results"][0]
		var result := command("race_claim", {"id": str(r["group"]["id"])})
		if result.has("error"): return false
		record_reward("banana","香蕉竞速结算","比赛结束，领取排名奖励",{"place":r["me"].get("place",0)})
		return true
	if race.get("current",{}).is_empty() and G.level>=int(LocalRace.rules().get("unlock_level",12)) and ActivitySchedule.scheduled("race"):
		var result := command("race_join")
		if result.has("error"): return false
		record("event","参加香蕉竞速","已解锁，主棋盘订单同步增加香蕉")
		return true
	var c:=MergeEvent.current()
	if not MergeEvent.available(c): return false
	var s:=MergeEvent.state(c)
	if bool(s["claimed"]): return false
	if not MergeEvent.claimable(c,s).is_empty():
		var result := command("activity", {"season": c["key"], "action": "claim"})
		record_reward("moon","月石里程碑奖励","解锁格子数达到阶段目标",result)
		return true
	var cells: Array=s["cells"]
	var lo:=int(s["view"])*int(c["board"]["cols"])
	var hi:=lo+int(c["board"]["cols"])*int(c["board"]["visible_rows"])
	# 火光岩画这类多产线活动（有画、颜料、画笔）才有收取和画笔；规则函数按名字动态调用，旧版活动规则里没有它们
	var multi: bool = c.has("mural") or c.has("brush")
	var me: Variant = MergeEvent
	# 收走活动棋盘上的奖励和合到顶的画（不占操作体力，先做）
	for i in range(lo,hi):
		if not multi: break
		if int(cells[i]["lock"])!=0 or str(cells[i]["id"])=="": continue
		var k:=str(me.kind(c,str(cells[i]["id"])))
		if k=="reward" or (k in ["light","mural"] and MergeEvent.next_id(c,str(cells[i]["id"]))==""):
			var got := command("activity", {"season": c["key"], "action": "collect", "cell": i})
			if got.has("error"): continue
			record_reward("moon","收取活动棋盘物品","奖励或合到顶的作品",got)
			return true
	if not play: return false
	# 画笔：颜料拖上去充能，有颜料就画
	if multi and s.has("brush"):
		var brush_at:=-1
		for i in range(lo,hi):
			if int(cells[i]["lock"])==0 and str(me.kind(c,str(cells[i]["id"])))=="brush": brush_at=i; break
		if brush_at>=0:
			if int(s["brush"]["charges"])<int(c["brush"].get("max_charges",8)):
				for i in range(lo,hi):
					if int(cells[i]["lock"])==0 and str(me.kind(c,str(cells[i]["id"])))=="paint":
						var fed := command("activity", {"season": c["key"], "action": "drop", "from": i, "to": brush_at})
						if fed.has("error"): break
						record("event","颜料充画笔","把挖出的颜料拖到画笔上",fed)
						return true
			if bool(me.can_brush(c,s,brush_at)):
				var drew := command("activity", {"season": c["key"], "action": "brush", "cell": brush_at})
				if not drew.has("error"):
					record("event","画笔作画","花一次颜料在旁边画出一幅",drew)
					return true
	var best:=-INF
	var a:=-1
	var b:=-1
	for i in range(lo,hi):
		if int(cells[i]["lock"])!=0 or str(cells[i]["id"])=="": continue
		if MergeEvent.next_id(c,str(cells[i]["id"]))=="": continue
		for j in range(lo,hi):
			if i==j or int(cells[j]["lock"])>=2 or cells[j]["id"]!=cells[i]["id"]: continue
			var score:=1000.0 if int(cells[j]["lock"])==1 else 0.0
			for k in MergeGrid.neighbors(j,int(c["board"]["cols"]),cells.size()):
				if int(cells[k]["lock"])==2: score+=20
			if score>best: best=score; a=i; b=j
	if a>=0:
		var locked:=int(cells[b]["lock"])==1
		var item:=str(cells[b]["id"])
		var result := command("activity", {"season": c["key"], "action": "drop", "from": a, "to": b})
		record("event","月石合成","优先合并锁定遗物，并揭开相邻覆盖",result)
		if locked and not result.has("error"):
			var after: Dictionary=MergeEvent.state(c)
			if int(after["cells"][b]["lock"])==0: record_unlock("moon",b,item,str(after["cells"][b]["id"]),int(c["board"]["cols"]))
		return true
	if int(s["points"])>=int(c["points"]["spawn_cost"]):
		var result := command("activity", {"season": c["key"], "action": "spawn"})
		if not result.has("error"):
			record("event","月石活动生产","使用订单获得的活动积分",result)
			return true
		# Recycle a completed highest-tier relic only when the event board is full.
		for i in range(lo,hi):
			if int(cells[i]["lock"])==0 and str(cells[i]["id"])!="" and (not multi or str(me.kind(c,str(cells[i]["id"]))) in ["light","mural"]) and MergeEvent.next_id(c,str(cells[i]["id"]))=="":
				command("activity", {"season": c["key"], "action": "recycle", "cell": i})
				record("event","整理月石棋盘","满级遗物无法继续合并，腾出空间")
				return true
	return false

## 剑齿虎：档期里开局；每过一关领一次礼包；一局结束后（逃脱或被追上）重开时会补发没领的礼包
func tiger_step() -> bool:
	if not TigerEscape.unlocked(): return false
	TigerEscape.tick()
	var m: Dictionary = TigerEscape.round_state()
	if not m.is_empty():
		for n in range(1, int(m["stage"]) + 1):
			if n in m["claimed"]: continue
			var got := command("tiger", {"action": "claim", "node": n})
			if got.has("error"): break
			record_reward("tiger", "剑齿虎第 %d 关礼包" % n, "已逃过这一关", {"node": n, "rewards": got.get("rewards", []), "received": reward_summary(got.get("rewards", []))})
			return true
	if not ActivitySchedule.scheduled("tiger"): return false
	if m.is_empty() or str(m["status"]) != "running":
		var action := "join" if m.is_empty() else "restart"
		var r := command("tiger", {"action": action})
		if r.has("error"): return false
		record("event", "参加逃离剑齿虎", "交订单攒积分逃离剑齿虎", {"previous": m.get("status", "")})
		return true
	return false

## 化石：一周档期轮到化石时交单攒铲子。挖法按真人：先顺着已露出的骨头往四周挖，没线索时随机挖
func fossil_step(play: bool) -> bool:
	if not FossilDig.unlocked() or FossilDig.state().is_empty(): return false
	for row in FossilDig.ready_rewards():
		var got := command("fossil", {"action": "claim", "value": int(row["bones"])})
		if got.has("error"): return false
		record_reward("fossil", "化石里程碑奖励", "挖出 %d 块骨头" % int(row["bones"]), {"rewards": got.get("rewards", []), "received": reward_summary(got.get("rewards", []))})
		return true
	if not FossilDig.window_current(): return false
	if FossilDig.cleared():
		if FossilDig.finished(): return false
		if not command("fossil", {"action": "next"}).has("error"):
			record("event", "化石下一层", "这一层骨头都挖出来了")
			return true
		return false
	if not play or int(FossilDig.state().get("shovels", 0)) < int(FossilDig.config()["dig_cost"]): return false
	var b: Dictionary = FossilDig.board()
	var n := int(b["n"])
	var hint: Array = []
	for p in b["pieces"]:
		if bool(p["found"]): continue
		var cells: Array = FossilDig.piece_cells(p, n)
		if not cells.any(func(c): return c in b["dug"]): continue
		for c in b["dug"]:
			if not c in cells: continue
			for nb in [c - n, c + n, c - 1 if c % n > 0 else -1, c + 1 if c % n < n - 1 else -1]:
				if nb >= 0 and nb < n * n and not nb in b["dug"] and not nb in hint: hint.append(nb)
	var pool: Array = hint
	if pool.is_empty():
		for c in n * n:
			if not c in b["dug"]: pool.append(c)
	if pool.is_empty(): return false
	var cell := int(pool[randi() % pool.size()])
	var r := command("fossil", {"action": "dig", "value": cell})
	if r.has("error"): return false
	record("event", "挖化石", "顺着露出的骨头挖" if not hint.is_empty() else "没有线索，随便挖一格", {"cell": cell, "found": r.get("found", []).size()})
	return true

## 免费小福利：每周礼包链的免费步、卡星兑换卡包、集齐卡册奖励、第一次免费补体力
func free_extras() -> bool:
	var gift: Dictionary = Replay.gift_view()
	if bool(gift.get("free_ready", false)):
		var got := command("gift", {"step": int(gift["step"])})
		if not got.has("error"):
			record_reward("gift", "礼包链免费步", "免费，直接领", {"rewards": got.get("rewards", []), "received": reward_summary(got.get("rewards", []))})
			return true
	if G.rules.progression.feature_unlocked(Data.CARD_LEVEL):
		var offers: Array = CardPacks.config()["star_exchange"].duplicate()
		offers.sort_custom(func(a, b): return int(a["cost"]) > int(b["cost"]))
		for offer in offers:
			if G.card_stars >= int(offer["cost"]):
				if command("card_star_exchange", {"cost": int(offer["cost"])}).has("error"): break
				record_reward("cards", "卡星兑换卡包", "卡星够换最好的一档", {"cost": offer["cost"], "pack": offer["pack"]})
				return true
		for album in Data.ALBUMS.size():
			if G.rules.progression.album_count(album) == Data.ALBUMS[album]["cards"].size() and not bool(Replay.meta.get("album:%d" % album, false)):
				if not command("album_claim", {"album": album}).has("error"):
					record_reward("album", "集齐卡册奖励", "卡册集齐", {"album": album})
					return true
	if G.energy < 1 and not bool(Replay.meta.get("free_energy", false)):
		if not command("energy").has("error"):
			record_reward("free_energy", "第一次免费补体力", "第一次补体力不花琥珀")
			return true
	return false

func wait_next() -> void:
	var seconds:=float(G.rules.clock.secs_to_midnight())
	var why:="等待次日免费补给"
	if G.energy<1:
		var regen:=float(G.rules.clock.energy_left()+G.REGEN_SEC*(clampi(int(cfg.get("wait_energy_batch",10)),1,G.MAX_ENERGY)-1))
		if regen<seconds: seconds=regen; why="体力耗尽，等待恢复"
	for i in G.board.size():
		var wait:=0
		if G.rules.orders.cooking(i): wait=G.rules.orders.cook_left(i)
		elif free_item(i) and not Data.gen_stats(G.rules.board.cell_id(i)).is_empty(): wait=G.rules.board.gen_wait(i)
		elif G.rules.board.is_merge_bubble(i): wait=G.rules.board.bubble_left(i)
		if wait>0 and wait<seconds: seconds=wait; why="等待制作、生产器冷却或气泡消失"
	seconds=minf(maxf(seconds,1),float(cfg["cycle_days"])*86400-(G.now()-start))
	# 真人没事干要等太久就下线；等体力这种算「卡体力」
	if not schedule.is_empty() and (seconds>float(schedule.get("quit_idle_minutes",5))*60 or seconds>=session_left()):
		lv_acc["stuck"]=int(lv_acc["stuck"])+1
		if G.energy<1: lv_acc["stuck_energy"]=int(lv_acc["stuck_energy"])+1
		record("stuck","没事可做："+why,"空等超过作息允许的时长，提前下线",{"wait_needed":seconds,"energy":G.energy,"session_left":session_left()})
		go_offline("卡住："+why)
		return
	var began:=G.now()-start
	tick(seconds,"idle")
	record("wait","快进 "+G.fmt_time(int(seconds)),why,{"seconds":seconds,"from":began})
	if G.now()-start-last_order_time>86400 and not warned_stall:
		warned_stall=true
		record("bottleneck","连续一天未完成订单","记录策略或配置阻塞，不赠送资源绕过",{"target":target,"board":G.board.duplicate(true),"inventory":G.inv.duplicate(),"orders":G.orders.duplicate(true)})

func prof_report() -> Dictionary:
	var out := {}
	for k in prof: out[k] = snappedf(float(prof[k]) / 1e6, 0.01)
	return out

func write_report() -> void:
	var tw := Time.get_ticks_usec()
	_write_report()
	prof["write_report"] = int(prof.get("write_report", 0)) + Time.get_ticks_usec() - tw

func _write_report() -> void:
	var report:={"schema":1,"config":cfg,"main_story_max_level":main_limit,"source_hashes":source_hashes,"production_counting":"level1_equivalent","resource_counting":"credited_gains_excluding_initial","production_lines":production_line_metrics(),"runs":summaries,"events":events,"wall_seconds":(Time.get_ticks_msec()-wall_start)/1000.0,"notes":["通过共享规则命令执行；不访问线上账号，不写入玩家日志。","各产线生产器折合一级份数：1 级计 1、2 级计 2、3 级计 4，之后每级翻倍（含低级部件），统计已解锁棋盘、储物洞和暂存区，不含锁定格及未购买气泡。","生产器最高等级统计当前已拥有的棋盘、储物洞和暂存区物品；琥珀、沙漏累计获得仅计本轮实际到账，排除初始资源，消耗不回减。","藤蔓解锁与触发合成记录在同一时间点，不额外消耗操作时间。","连续在线、零付费、跳过广告与引导手势；每个决策消耗配置的游戏内秒数。","时间快进会执行体力恢复、制作完成、跨日和活动结算。","到时长或动作上限即重开；不等同于通关。策略是可复现启发式，并非最优解。"]}
	var f:=FileAccess.open(output,FileAccess.WRITE)
	f.store_string(JSON.stringify(report))
	f.close()

func ensure_simulation() -> void:
	if _simulation_ready: return
	Replay.set_process(false)
	Replay.active = true
	Replay.worker = true
	Replay.authorized = true
	Replay.executing = false
	Replay.meta = G.replay_meta
	Replay.seq = int(Replay.meta.get("seq", 0))
	Replay.clock = int(G.simulation_time) if G.simulation_time >= 0 else int(G.now())
	Replay.pending = []
	Replay.inflight = {}
	_simulation_ready = true

func command(name: String, args: Dictionary = {}) -> Dictionary:
	ensure_simulation()
	var t0 := Time.get_ticks_usec()
	var result = Replay.perform(name, args)
	track_resources()
	prof["command"] = int(prof["command"]) + Time.get_ticks_usec() - t0
	if name in ["order", "craft", "rush", "build", "level", "tick", "tutorial_finish"]:
		target_dirty = true
	return result if result is Dictionary else {}
