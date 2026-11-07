extends Node
## Policy chooses actions; G, Rewards and event controllers execute the actual game rules.
var cfg: Dictionary
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
	main_limit=int(cfg.get("main_story_max_level",0))
	if main_limit<=0 and not Data.STORY.is_empty(): main_limit=int(Data.STORY.keys().max())
	wall_start = Time.get_ticks_msec()
	for n in int(cfg.get("runs", 1)):
		run_id = n + 1
		await play()
		if finish_reason == "invariant_failed": return 1
	stream.close()
	write_report()
	print("SIMULATION_RESULT ", JSON.stringify({"runs": summaries, "events": events.size(), "wall_seconds": (Time.get_ticks_msec()-wall_start)/1000.0, "report": ProjectSettings.globalize_path(output)}))
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
	for v in G.builds.values(): parts += int(v)
	var moon := 0
	var c := MergeEvent.current()
	if MergeEvent.available(c): moon = MergeEvent.progress(c, MergeEvent.state(c))
	var state: Dictionary={"level": G.level, "xp": G.xp, "energy": G.energy, "coins": G.shells, "gems": G.amber, "empty": G.empty_count(), "storage": G.inv.size(), "stash": G.stash.size(), "parts": parts, "moon": moon, "cards": G.cards_total(), "duel_wins": int(DuelRace.state()["wins"]), "orders": G.orders.size()}
	state.merge(production_line_totals())
	state.merge(production_line_levels())
	state.merge({"sand":G.rush,"amber_earned":int(resource_earned.get("amber",0)),"sand_earned":int(resource_earned.get("sand",0))})
	return state

func record(cat: String, title: String, _reason: String, detail: Dictionary = {}, reward_source: String = "") -> void:
	var after := snap()
	var delta := {}
	for key in after:
		if after[key] != before.get(key, after[key]): delta[key] = after[key] - before[key]
	var e := {"run": run_id, "seq": events.size()+1, "time": snappedf(G.now()-start, 0.01), "category": cat, "title": title, "state": after, "delta": delta, "detail": detail}
	if reward_source!="": e["reward_source"]=reward_source
	events.append(e)
	stream.store_line(JSON.stringify(e))
	totals[cat] = int(totals.get(cat, 0)) + 1
	before = after

func record_reward(source: String, title: String, reason: String, detail: Dictionary = {}) -> void:
	record("reward",title,reason,detail,source)

func record_unlock(board_id: String, cell: int, item: String, result: String, cols: int) -> void:
	var merge_seq:=int(events[-1]["seq"])
	var item_name:=Data.name_of(item) if board_id=="main" else str(MergeEvent.item(MergeEvent.current(),item).get("name",item))
	var result_name:=Data.name_of(result) if board_id=="main" else str(MergeEvent.item(MergeEvent.current(),result).get("name",result))
	record("unlock",("主棋盘" if board_id=="main" else "月石棋盘")+" · 解锁藤蔓","与藤蔓格内的同级物品合成，格子解除锁定",{"board":board_id,"cell":cell,"row":int(cell/cols)+1,"col":cell%cols+1,"item":item,"item_name":item_name,"result":result,"result_name":result_name,"lock_before":1,"lock_after":0,"merge_seq":merge_seq})

func target_level_reached() -> bool:
	var limit:=int(cfg.get("stop_level",40))
	return limit>0 and G.level>=limit

func observe_level() -> void:
	if G.level!=observed_level:
		record("level", "升到 %d 级" % G.level, "订单或建造奖励达到升级条件", {"from": observed_level, "to": G.level})
		observed_level=G.level

func tick(seconds: float) -> void:
	G.simulation_time += seconds
	G._regen()
	G._tick_cooks()
	G._tick_bubbles()
	G._check_day()
	SevenDay.login()
	if bool(cfg.get("play_events", true)):
		LocalRace.tick()
		DuelRace.tick()

func play() -> void:
	start = float(Time.get_unix_time_from_datetime_string(str(cfg["start_utc"])))
	G.simulation_time = start
	G.rng.seed = int(cfg["seed"]) + run_id - 1
	seed(int(cfg["seed"]) + run_id - 1)
	resource_tracking=false
	G.new_game()
	begin_resource_tracking()
	SevenDay.login()
	claimed_levels = {}
	totals = {}
	target = []
	last_target = ""
	action_count = 0
	observed_level = 1
	last_order_time = 0
	warned_stall = false
	finish_reason = "duration_limit"
	main_finished=false
	target_dirty=true
	before = snap()
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
		if await upgrade_tribe(): pass
		elif await rewards(): pass
		elif finish_tutorial(): pass
		elif submit_orders(): pass
		else:
			choose_target()
			if retrieve(): pass
			elif merge_main(): pass
			elif await events_step(): pass
			elif produce(): pass
			elif await make_room(): pass
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
		tick(minf(float(cfg["action_seconds"]),maxf(0,float(cfg["cycle_days"])*86400-(G.now()-start))))
		if action_count % 1000 == 0:
			print("SIM_PROGRESS run=", run_id, " actions=", action_count, " day=", snappedf((G.now()-start)/86400,0.01), " level=",G.level)
			await get_tree().process_frame
	if finish_reason!="target_level" and action_count >= int(cfg["max_actions"]): finish_reason = "action_limit"
	record("end", "本轮结束", {"duration_limit":"达到配置的模拟时长", "action_limit":"达到动作上限", "target_level":"达到目标等级", "invariant_failed":"状态校验失败"}[finish_reason], {"reason":finish_reason})
	var summary := {"run":run_id,"seed":int(cfg["seed"])+run_id-1,"duration":G.now()-start,"actions":action_count,"state":snap(),"counts":totals.duplicate(),"finish_reason":finish_reason,"resource_initial":resource_initial.duplicate()}
	summaries.append(summary)
	var state_file := FileAccess.open(output.get_basename()+"-run%d-save.json"%run_id,FileAccess.WRITE)
	state_file.store_string(JSON.stringify(G.save_dict()))
	state_file.close()
	stream.flush()
	write_report()

func valid_state() -> bool:
	return G.energy >= 0 and G.shells >= 0 and G.amber >= 0 and G.inv.size() <= G.inv_cap and G.board.size() == G.COLS*G.ROWS and G.orders.size() <= Data.order_total(G.level)

func grant(rw: Array) -> void:
	Rewards.grant(rw, Callable(), false)

func reward_summary(rewards: Array) -> String:
	var parts:=PackedStringArray()
	var labels:={"energy":"体力","shell":"贝币","amber":"琥珀","sand":"沙漏","xp":"经验","token":"祭典积分"}
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
			var rw: Array=await G.claim_level(lv)
			grant(rw)
			record_reward("level", "领取 %d 级奖励" % lv, "达到等级，领取一次",{"level":lv,"rewards":rw.duplicate(true),"received":reward_summary(rw)})
			return true
	for id in G.discovered:
		if G.book_prize(id):
			var amount: int = await G.claim_book(id)
			G.add_currency("energy", amount)
			record_reward("book", "图鉴 · " + Data.name_of(id), "发现新物品", {"energy":amount})
			return true
	for day in SevenDay.config()["days"]:
		for task in day["tasks"]:
			if SevenDay.done(task) and not SevenDay.got(task):
				await SevenDay.claim(str(task["id"]))
				record_reward("seven_day_task", "七日任务奖励", "任务已完成", {"task":task})
				return true
	for stage in SevenDay.config()["milestones"]:
		if SevenDay.stage_ready(stage):
			await SevenDay.claim(str(stage["id"]),true)
			record_reward("seven_day_stage", "七日里程碑", "累计任务积分达标", {"stage":stage})
			return true
	for lv in range(1,G.pass_reached()+1):
		if not G.pass_got(false,lv):
			var rw: Array = await G.claim_pass_free(lv)
			if not rw.is_empty():
				grant(rw)
				record_reward("pass", "通行证免费奖励", "已达到第 %d 档"%lv)
				return true
	for deal in Data.daily_deals(G.level):
		if int(deal.get("price",0)) == 0 and str(deal.get("mode","")) != "ad" and DailyShop.can_claim(deal):
			var claimed: Dictionary=await DailyShop.claim(str(deal["key"]))
			if not claimed.get("ok",false): continue
			record_reward("daily", "领取每日免费补给", "今日尚未领取", {"key":deal["key"]})
			return true
	for i in G.board.size():
		if int(G.board[i]["lock"]) != 0: continue
		if G.board[i].has("rw"):
			var rw: Array = G.board[i]["rw"]
			G.board[i].erase("rw")
			grant([rw])
			record_reward("land", "领取开地奖励", "覆盖已经揭开", {"cell":i,"rewards":rw})
			return true
		var id: String = G.cell_id(i)
		if id == "" or G.cooking(i): continue
		var kind := Data.type_of(id)
		if kind in Rewards.RESOURCE_TYPES and Data.value_of(id)>0:
			# Prefer merging resources; collect when needed, full, or at maximum tier.
			var urgent: bool = (kind=="energy" and G.energy < 10) or G.empty_count()<2 or Data.next_id(id)==""
			if urgent:
				G.board[i]["id"] = ""
				G.add_currency(kind,Data.value_of(id))
				record_reward("resource_"+kind, "收取 "+Data.name_of(id), "需要资源或腾出棋盘格子", {"item":id})
				return true
		if kind == "pack" and G.level>=Data.CARD_LEVEL:
			G.board[i]["id"] = ""
			await G.open_pack()
			record_reward("cards", "打开典藏卡包", "典藏卡已解锁")
			return true
		if not ChoiceChest.definition(id).is_empty():
			var choices: Array = ChoiceChest.definition(id)["choices"]
			var option := 0
			for j in choices.size():
				if useful(str(choices[j])): option=j; break
			await ChoiceChest.choose(i,id,option)
			record_reward("choice_chest", "打开自选宝箱", "优先选择当前订单产线", {"item":choices[option]})
			return true
		if kind == "chest":
			var got: Array = await G.open_chest(id)
			G.board[i]["id"] = ""
			Rewards.grant(Rewards.items(got),Callable(),false,true,{"board_origin":i})
			record_reward("chest", "打开宝箱", "获取资源与生产器", {"items":got})
			return true
	var si: int = G.stash_claim_index()
	if si>=0:
		var id := str(G.stash[si])
		var k := Data.type_of(id)
		if k == "pack":
			G.stash.remove_at(si)
			await G.open_pack()
			record_reward("cards", "领取暂存卡包", "8 级后开启")
			return true
		if k in Rewards.RESOURCE_TYPES and Data.value_of(id)>0:
			G.stash.remove_at(si)
			grant([[id,1,"item"]])
			record_reward("stash", "收取暂存资源", "无需占用棋盘", {"item":id})
			return true
		if G.empty_count()>1:
			G.stash.remove_at(si)
			G.place(G.find_empty_near(31),id)
			record("stash", "取出 "+Data.name_of(id), "棋盘有空位", {"item":id})
			return true
	return false

func submit_orders() -> bool:
	choose_target()
	for i in G.orders.size():
		var o: Dictionary = G.orders[i]
		if main_finished and bool(o.get("story",false)): continue
		if target_story and not bool(o.get("story",false)) and (o.get("items",[]) as Array).any(func(id):return useful(str(id))): continue
		if G.order_ready(o):
			var rw: Dictionary = o["rw"].duplicate(true)
			var detail := o.duplicate(true)
			G.complete_order(i)
			if bool(cfg.get("play_events",true)): LocalRace.order(detail["items"])
			var rws := []
			for p in [["shell","shell_2"],["xp","xp_1"],["token","token_1"]]:
				if int(rw.get(p[0],0))>0: rws.append([p[1],int(rw[p[0]])])
			if rw.get("rewards") is Array: rws.append_array(Rewards.items(rw["rewards"]))
			elif int(rw.get("pack",0))>0: rws.append(["pack_1",int(rw["pack"])])
			grant(rws)
			record("order", ("主线" if detail.get("story",false) else "副线")+"订单完成", "所需物品已齐全",detail)
			last_order_time = G.now()-start
			warned_stall = false
			return true
		if G.craft_mats_ready(o):
			G.begin_craft(i)
			record("craft", "开始制作料理", "材料齐全，等待制作完成",o.duplicate(true))
			return true
	return false

func upgrade_tribe() -> bool:
	var b: String = G.next_build_id()
	if b!="" and G.shells>=G.build_cost(b):
		var cost: int=G.build_cost(b)
		var result: Dictionary = await G.do_build(b)
		if result.is_empty(): return false
		grant(result.get("rewards",[]))
		record("build", "升级部落 · "+str(Data.build_def(b).get("name",b)), "贝币足够，独立推进部落", {"building":b,"stage":G.builds[b],"cost":cost,"rewards":result.get("rewards",[])})
		return true
	return false

func finish_tutorial() -> bool:
	if G.tutorial_on and int(G.builds.get("fire",0))>=2:
		var pending := false
		for o in G.orders:
			if o.has("tutorial"): pending=true
		if not pending:
			G.tutorial_on=false
			G.seen_tutorial=true
			target_dirty=true
			var guide:=Guide.new()
			guide._ensure_seed_order()
			guide._grant_normal_orders()
			guide.free()
			record("milestone","新手阶段完成","教学订单与首次部落升级完成，进入正式订单")
			return true
	return false

func free_item(i: int) -> bool:
	return G.is_free(i) and G.cell_id(i)!="" and not G.cooking(i)

func choose_target() -> void:
	if not target_dirty and action_count%50!=0: return
	target_dirty=false
	var best := INF
	target=[]
	target_name=""
	target_story=false
	for o in G.orders:
		if main_finished and bool(o.get("story",false)): continue
		var ids: Array = G._order_need_ids(o)
		if ids.is_empty(): continue
		var cost := 0.0
		var reachable := true
		for raw in ids:
			var id := str(raw)
			if G.board_has(id)>=0 or G.inv.has(id): continue
			var ch := Data.chain(id)
			var prob := production_rate(ch)
			var mass := 0.0
			for j in G.board.size():
				if free_item(j) and Data.chain(G.cell_id(j))==ch and Data.lv(G.cell_id(j))<Data.lv(id): mass+=pow(2,Data.lv(G.cell_id(j))-1)
			if prob<=0 and mass<pow(2,Data.lv(id)-1): reachable=false
			cost += maxf(0,pow(2,Data.lv(id)-1)-mass)/maxf(prob,0.01)
		if bool(o.get("story",false)) and bool(cfg.get("story_first",true)): cost-=100000
		if not reachable: cost+=1000000
		if cost<best:
			best=cost
			target=ids.duplicate()
			target_story=bool(o.get("story",false))
			target_name=("主线" if o.get("story",false) else "副线")+" · "+"、".join(PackedStringArray(ids.map(func(id):return Data.name_of(str(id)))))
	var signature := str(target)
	if signature!=last_target:
		last_target=signature
		record("decision","目标："+target_name,"优先可完成的主线；主线暂不可生产时转向副线",{"items":target})

func useful(id: String) -> bool:
	for raw in target:
		if Data.chain(str(raw))==Data.chain(id) and Data.lv(id)<=Data.lv(str(raw)): return true
	return false

func production_rate(ch: String) -> float:
	var rate := 0.0
	for i in G.board.size():
		if not free_item(i): continue
		var st := Data.gen_stats(G.cell_id(i))
		var r := 0.0
		for d in st.get("drops",[]):
			if Data.chain(str(d["id"]))==ch: r+=float(d["p"])*pow(2,Data.lv(str(d["id"]))-1)/100.0
		rate=maxf(rate,r)
	return rate

func retrieve() -> bool:
	if G.empty_count()<1: return false
	for j in G.inv.size():
		var id := str(G.inv[j])
		var spare := 0
		for cell in G.board.size():
			if free_item(cell) and G.cell_id(cell)==id: spare+=1
		spare-=target.count(id)
		var can_merge := spare>0 and Data.next_id(id)!=""
		if (target.has(id) and G.board_has(id)<0) or can_merge:
			G.inv.remove_at(j)
			G.place(G.find_empty_near(31),id)
			record("storage","取回 "+Data.name_of(id),"订单需要或可继续合成",{"item":id})
			return true
	return false

func merge_main() -> bool:
	var best := -INF
	var a := -1
	var b := -1
	var reserve := {}
	for id in target: reserve[id]=int(reserve.get(id,0))+1
	for i in G.board.size():
		if not free_item(i): continue
		var id: String=G.cell_id(i)
		if Data.next_id(id)=="": continue
		var available := 0
		for j in G.board.size():
			if free_item(j) and G.cell_id(j)==id: available+=1
		for j in G.board.size():
			if i==j or G.cell_id(j)!=id or int(G.board[j]["lock"])>=2 or G.cooking(j): continue
			var locked := int(G.board[j]["lock"])==1
			if not locked and available-int(reserve.get(id,0))<2: continue
			var score := 0.0
			if locked: score+=1000
			if Data.type_of(id)=="gen": score+=500
			if useful(Data.next_id(id)): score+=200
			for n in MergeGrid.neighbors(j,G.COLS,G.board.size()):
				if int(G.board[n]["lock"])==2: score+=60
			score-=Data.lv(id)
			if score>best: best=score; a=i; b=j
	if a<0: return false
	var id: String=G.cell_id(a)
	var locked := int(G.board[b]["lock"])==1
	var result: String=G.try_drop(a,b)
	if result!="merge": return false
	record("merge","合成 "+Data.name_of(G.cell_id(b)),"解锁藤蔓" if locked else "满足订单、升级生产器或整理棋盘",{"from":a,"to":b,"item":id,"result":G.cell_id(b),"revealed":G.opened.duplicate(),"unlock_recorded":locked})
	if locked: record_unlock("main",b,id,G.cell_id(b),G.COLS)
	return true

func produce() -> bool:
	if G.energy<1 or G.empty_count()<1: return false
	var missing := {}
	var used: Array=[]
	for raw in target:
		var id:=str(raw)
		var cell: int=G.board_has(id,used)
		if cell>=0: used.append(cell)
		else: missing[Data.chain(id)]=true
	var best := 0.0
	var chosen := -1
	for i in G.board.size():
		if not free_item(i): continue
		var st:=Data.gen_stats(G.cell_id(i))
		if st.is_empty() or G.gen_left(i)==0: continue
		var score:=0.0
		for d in st.get("drops",[]):
			if missing.has(Data.chain(str(d["id"]))): score+=float(d["p"])*pow(2,Data.lv(str(d["id"]))-1)
		if score>best: best=score; chosen=i
	if chosen<0: return false
	var id: String=G.roll_produce(G.cell_id(chosen))
	G.spend("energy",1)
	G.gen_use(chosen)
	G.place(G.find_empty_near(chosen),id)
	record("produce","生产 "+Data.name_of(id),target_name,{"generator":G.cell_id(chosen),"item":id})
	return true

func make_room() -> bool:
	if G.empty_count()>1: return false
	var best_store:=-1
	var store_value:=-1.0
	var worst:=-1
	var worst_value:=INF
	for i in G.board.size():
		if not free_item(i): continue
		var id: String=G.cell_id(i)
		var kind:=Data.type_of(id)
		if target.has(id): continue
		var value:=OrderRoll.flames(id)
		if kind=="gen": value+=100000
		if not useful(id) and value>store_value and (kind=="item" or (kind=="gen" and Data.gen_stats(id).is_empty())):
			best_store=i; store_value=value
		if kind=="item" and not useful(id) and Data.lv(id)<=int(cfg.get("delete_max_level",10)) and value<worst_value:
			worst=i; worst_value=value
	if best_store>=0 and bool(cfg.get("use_storage",true)):
		if G.inv.size()>=G.inv_cap and bool(cfg.get("expand_storage",false)) and G.inv_cap<int(cfg.get("max_storage",20)) and G.amber>=G.storage_price():
			await G.expand_storage()
			record("storage","扩建储物洞","保护高价值物品，使用配置允许的琥珀预算")
			return true
		if G.inv.size()<G.inv_cap:
			var id: String=G.cell_id(best_store)
			# Active generators carry cooldown state; leave them on board.
			if not G.board[best_store].has("gm"):
				G.inv.append(id)
				G.board[best_store]["id"]=""
				record("storage","存入 "+Data.name_of(id),"棋盘拥挤，保留当前暂时不用的高价值物品",{"item":id})
				return true
	if worst>=0:
		var id: String=G.cell_id(worst)
		G.board[worst]["id"]=""
		G.add_currency("shell",Data.value_of(id))
		record("delete","丢弃 "+Data.name_of(id),"储物洞无法再收纳，清理非目标产线低价值物品",{"item":id,"refund":Data.value_of(id)})
		return true
	return false

func events_step() -> bool:
	if not bool(cfg.get("play_events",true)) or G.tutorial_on: return false
	if DuelRace.unlocked():
		var duel:=DuelRace.state()
		var match_state: Dictionary=duel["match"]
		var milestones:=DuelRace.ready_milestones()
		if not milestones.is_empty():
			await DuelRace.act("milestone",int(milestones[0]))
			record_reward("duel_milestone","双人竞速累计胜利奖励","达到胜场里程碑",{"wins":milestones[0]})
			return true
		if not match_state.is_empty() and match_state["status"]!="running" and not match_state.get("claimed",false):
			var result: Dictionary=match_state.duplicate(true)
			await DuelRace.act("claim")
			record_reward("duel_match","双人竞速胜利" if result["status"]=="won" else "双人竞速落败","先达到配置目标积分的一方获胜",{"match":result,"wins":duel["wins"]})
			return true
		if match_state.is_empty() or match_state.get("claimed",false):
			await DuelRace.act("join")
			record("event","参加双人竞速","完成主棋盘订单获得积分")
			return true
	var race:=LocalRace.state()
	if not race.get("results",[]).is_empty():
		var r: Dictionary=race["results"][0]
		var result: Dictionary=LocalRace.claim(str(r["group"]["id"]))
		grant(result.get("rewards",[]))
		record_reward("banana","香蕉竞速结算","比赛结束，领取排名奖励",{"place":r["me"].get("place",0)})
		return true
	if race.get("current",{}).is_empty() and G.level>=int(LocalRace.rules().get("unlock_level",12)):
		LocalRace.join()
		record("event","参加香蕉竞速","已解锁，主棋盘订单同步增加香蕉")
		return true
	var c:=MergeEvent.current()
	if not MergeEvent.available(c): return false
	var s:=MergeEvent.state(c)
	if bool(s["claimed"]): return false
	if not MergeEvent.claimable(c,s).is_empty():
		var result: Dictionary=await MergeEvent.act(c,"claim")
		record_reward("moon","月石里程碑奖励","解锁格子数达到阶段目标",result)
		return true
	var cells: Array=s["cells"]
	var lo:=int(s["view"])*int(c["board"]["cols"])
	var hi:=lo+int(c["board"]["cols"])*int(c["board"]["visible_rows"])
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
		var result: Dictionary=await MergeEvent.act(c,"drop",{"from":a,"to":b})
		record("event","月石合成","优先合并锁定遗物，并揭开相邻覆盖",result)
		if locked and not result.has("error"):
			var after: Dictionary=MergeEvent.state(c)
			if int(after["cells"][b]["lock"])==0: record_unlock("moon",b,item,str(after["cells"][b]["id"]),int(c["board"]["cols"]))
		return true
	if int(s["points"])>=int(c["points"]["spawn_cost"]):
		var result: Dictionary=await MergeEvent.act(c,"spawn")
		if not result.has("error"):
			record("event","月石活动生产","使用订单获得的活动积分",result)
			return true
		# Recycle a completed highest-tier relic only when the event board is full.
		for i in range(lo,hi):
			if int(cells[i]["lock"])==0 and str(cells[i]["id"])!="" and MergeEvent.next_id(c,str(cells[i]["id"]))=="":
				await MergeEvent.act(c,"recycle",{"cell":i})
				record("event","整理月石棋盘","满级遗物无法继续合并，腾出空间")
				return true
	return false

func wait_next() -> void:
	var seconds:=float(G.secs_to_midnight())
	var why:="等待次日免费补给"
	if G.energy<1:
		var regen:=float(G.energy_left()+G.REGEN_SEC*(clampi(int(cfg.get("wait_energy_batch",10)),1,G.MAX_ENERGY)-1))
		if regen<seconds: seconds=regen; why="体力耗尽，等待恢复"
	for i in G.board.size():
		var wait:=0
		if G.cooking(i): wait=G.cook_left(i)
		elif free_item(i) and not Data.gen_stats(G.cell_id(i)).is_empty(): wait=G.gen_wait(i)
		elif G.is_merge_bubble(i): wait=G.bubble_left(i)
		if wait>0 and wait<seconds: seconds=wait; why="等待制作、生产器冷却或气泡消失"
	seconds=minf(maxf(seconds,1),float(cfg["cycle_days"])*86400-(G.now()-start))
	var began:=G.now()-start
	tick(seconds)
	record("wait","快进 "+G.fmt_time(int(seconds)),why,{"seconds":seconds,"from":began})
	if G.now()-start-last_order_time>86400 and not warned_stall:
		warned_stall=true
		record("bottleneck","连续一天未完成订单","记录策略或配置阻塞，不赠送资源绕过",{"target":target,"board":G.board.duplicate(true),"inventory":G.inv.duplicate(),"orders":G.orders.duplicate(true)})

func write_report() -> void:
	var hashes:={}
	for file in DirAccess.get_files_at("res://data"):
		if file.ends_with(".json"): hashes[file]=FileAccess.get_sha256("res://data/"+file)
	var report:={"schema":1,"config":cfg,"main_story_max_level":main_limit,"source_hashes":hashes,"production_counting":"level1_equivalent","resource_counting":"credited_gains_excluding_initial","production_lines":production_line_metrics(),"runs":summaries,"events":events,"wall_seconds":(Time.get_ticks_msec()-wall_start)/1000.0,"notes":["直接调用本地游戏规则；不访问线上账号。","各产线生产器折合一级份数：1 级计 1、2 级计 2、3 级计 4，之后每级翻倍（含低级部件），统计已解锁棋盘、储物洞和暂存区，不含锁定格及未购买气泡。","生产器最高等级统计当前已拥有的棋盘、储物洞和暂存区物品；琥珀、沙漏累计获得仅计本轮实际到账，排除初始资源，消耗不回减。","藤蔓解锁与触发合成记录在同一时间点，不额外消耗操作时间。","连续在线、零付费、跳过广告与引导手势；每个决策消耗配置的游戏内秒数。","时间快进会执行体力恢复、制作完成、跨日和活动结算。","到时长或动作上限即重开；不等同于通关。策略是可复现启发式，并非最优解。"]}
	var f:=FileAccess.open(output,FileAccess.WRITE)
	f.store_string(JSON.stringify(report))
	f.close()
