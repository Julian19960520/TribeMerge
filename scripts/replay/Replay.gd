extends Node
## One reducer for local input and headless server replay. Only commands are uploaded.
const PROTOCOL := 1
const ENGINE := "4.6.3"
var active := false
var executing := false
var worker := false
var clock := 0
var seq := 0
var base := 0
var authorized := false
var pending: Array = []
var inflight: Dictionary = {}
var meta: Dictionary = {}
var _timer := 0.0
var _rules := ""

func _ready() -> void:
	worker = "--replay-worker" in OS.get_cmdline_user_args()
	active = worker or get_tree().get_script() == null or "--replay-test" in OS.get_cmdline_user_args()
	if not active: return
	var saved: Dictionary = G.replay_local
	base = int(saved.get("base", 0))
	pending = saved.get("pending", [])
	inflight = saved.get("inflight", {})
	authorized = bool(saved.get("authorized", false))
	# G loads these fields before the Replay autoload is ready.
	meta = G.replay_meta
	seq = int(meta.get("seq", 0))
	clock = int(meta.get("at", 0))
	if not worker and not Cloud.enabled:
		meta["allow_gm"] = true
		authorized = true
		if G.random_seed == "": G.random_seed = Crypto.new().generate_random_bytes(32).hex_encode()
	if not worker: G.save_game()

func journal() -> Dictionary:
	return {"base": base, "pending": pending, "inflight": inflight, "authorized": authorized}

func rules_hash() -> String:
	if _rules == "":
		var parts := ["replay-v1-rules-20261109.1-godot-" + ENGINE]
		for dir in ["res://data"]: _rule_files(dir, parts)
		parts.sort()
		_rules = "\n".join(parts).sha256_text()
	return _rules

func _rule_files(dir: String, parts: Array) -> void:
	for name in DirAccess.get_files_at(dir):
		if (dir == "res://data" and name.ends_with(".json")) or name.ends_with(".gd"):
			var path := dir.path_join(name)
			parts.append(path + ":" + FileAccess.get_sha256(path))
	for name in DirAccess.get_directories_at(dir): _rule_files(dir.path_join(name), parts)

func snapshot() -> Dictionary:
	G.replay_meta = meta
	meta["seq"] = seq
	meta["at"] = clock
	var s := G.save_dict().duplicate(true)
	for k in ["settings", "replay_local", "tiger_escape_seen"]: s.erase(k)
	return normalize(s)

func normalize(value):
	if value is Dictionary:
		var out := {}
		var keys: Array = value.keys()
		keys.sort()
		for k in keys: out[str(k)] = normalize(value[k])
		return out
	if value is Array:
		var out := []
		for v in value: out.append(normalize(v))
		return out
	if value is float:
		return int(value) if value == floor(value) else snappedf(value, 0.000001)
	return value

func digest() -> String:
	return JSON.stringify(snapshot()).sha256_text()

func restore(s: Dictionary) -> void:
	var settings: Dictionary = G.settings.duplicate(true)
	executing = true
	meta = s.get("replay_meta", {}).duplicate(true)
	seq = int(meta.get("seq", 0))
	clock = int(meta.get("at", 0))
	G.load_snapshot(s, false)
	G.settings = settings
	G.replay_meta = meta
	executing = false

func _process(delta: float) -> void:
	if not active or worker or not authorized or executing: return
	_timer += delta
	if _timer >= 1.0:
		_timer = 0.0
		perform("tick")

func perform(name: String, args: Dictionary = {}, at := -1):
	if not active: return {"error": "未启用操作重放"}
	if executing: return {"error": "操作正在处理"}
	if not worker and not authorized: return {"error": "首次进入需要联网取得存档"}
	var before := snapshot()
	var old_clock := clock
	clock = maxi(clock, int(Cloud.server_now()) if at < 0 else at)
	executing = true
	advance()
	var result = dispatch.call(name, args)
	executing = false
	if result is Dictionary and (result.has("error") or result.get("ok", true) == false):
		restore(before)
		return result
	# Idle time produces no log entries unless a timer actually changes state.
	if name == "tick":
		clock = old_clock
		if snapshot() == before: return result
		clock = maxi(old_clock, int(Cloud.server_now()) if at < 0 else at)
	seq += 1
	meta["seq"] = seq
	meta["at"] = clock
	# Use the same canonical numeric values between commands on both sides,
	# including when a server checkpoint splits an offline sequence.
	var canonical: Dictionary = JSON.parse_string(JSON.stringify(snapshot()))
	G.load_snapshot(canonical, false)
	meta = G.replay_meta
	if not worker:
		pending.append({"seq": seq, "at": clock, "name": name, "args": args.duplicate(true), "hash": digest()})
		G.save_game() # Snapshot and log are one atomic file, before animations.
	G.board_changed.emit()
	G.orders_changed.emit()
	G.changed.emit()
	G.merge_event_changed.emit()
	return result

func advance() -> void:
	G._check_day()
	G._tick_bubbles()
	if G.energy < G.MAX_ENERGY: G._regen()
	G._tick_cooks()
	TigerEscape.tick()
	DuelRace.tick()
	LocalRace.tick()
	SevenDay.login()
	DuelRace.state()
	TigerEscape.state()
	UfoOffer.state()
	var c := MergeEvent.current()
	if MergeEvent.available(c): MergeEvent.state(c)
	# Tutorial effects are rules, never values supplied by the interface.
	if G.tutorial_on and G.board_has("basket_5") >= 0:
		if G.energy < 1 and not meta.get("tutorial_energy", false):
			G.energy = 5
			meta["tutorial_energy"] = true
		if not meta.get("seed_order", false):
			G.orders.insert(0, {"who": 1, "items": ["seed_1"], "rw": {"xp": 1, "shell": 50}, "story": true, "say": "草籽能种出新的果树，你学得真快！"})
			meta["seed_order"] = true

func order_rewards(o: Dictionary) -> Array:
	var rw: Dictionary = o.get("rw", {})
	var out := []
	for pair in [["shell", "shell_2"], ["xp", "xp_1"], ["token", "token_1"]]:
		if int(rw.get(pair[0], 0)) > 0: out.append([pair[1], int(rw[pair[0]])])
	if rw.get("rewards") is Array and not rw["rewards"].is_empty(): out.append_array(Rewards.items(rw["rewards"]))
	elif int(rw.get("pack", 0)) > 0: out.append(["pack_1", int(rw["pack"])])
	return out

func grant(rw: Array, delivery: Dictionary = {}) -> void:
	Rewards.grant(rw, Callable(), false, true, delivery)

func dispatch(name: String, a: Dictionary):
	var i := int(a.get("cell", -1))
	match name:
		"tick": return {}
		"drop":
			var r := G.try_drop(int(a.get("from", -1)), int(a.get("to", -1)))
			return {"kind": r} if r != "" else {"error": "不能移动或合成"}
		"tap": return await tap(i)
		"stash": return await stash(int(a.get("index", -1)))
		"store":
			if not valid_cell(i) or G.cooking(i) or G.inv.size() >= G.inv_cap or Data.type_of(G.cell_id(i)) == "egen" or G.is_merge_bubble(i) or Data.is_dish(G.cell_id(i)): return {"error": "无法存入"}
			G.inv.append(G.cell_id(i)); G.board[i] = {"id": "", "lock": 0}
			return {}
		"inventory":
			var index := int(a.get("index", -1))
			var to := G.find_empty_near(0)
			if index < 0 or index >= G.inv.size() or to < 0: return {"error": "无法取出"}
			G.board[to]["id"] = G.inv.pop_at(index); G.discover(G.cell_id(to))
			return {"to": to}
		"discard":
			if not valid_cell(i) or G.cooking(i) or G.is_merge_bubble(i) or Data.type_of(G.cell_id(i)) in ["gen", "egen"] or Data.is_dish(G.cell_id(i)): return {"error": "不能丢弃"}
			settle_trash()
			meta["trash"] = {"cell": i, "id": G.cell_id(i)}; G.board[i]["id"] = ""
			return {}
		"discard_finish": settle_trash(); return {}
		"undo":
			var t: Dictionary = meta.get("trash", {})
			if t.is_empty() or G.cell_id(int(t["cell"])) != "": return {"error": "无法撤销"}
			G.board[int(t["cell"])]["id"] = t["id"]; meta.erase("trash"); return {}
		"order":
			if i < 0 or i >= G.orders.size() or not G.order_ready(G.orders[i]): return {"error": "订单尚未完成"}
			var o: Dictionary = G.orders[i].duplicate(true)
			var rw := order_rewards(o)
			var cells := G.complete_order(i)
			LocalRace.order(o.get("items", []))
			grant(rw)
			return {"cells": cells, "rewards": rw}
		"craft":
			if i < 0 or i >= G.orders.size(): return {"error": "订单不存在"}
			var r := G.begin_craft(i)
			return {"flights": r} if not r.is_empty() else {"error": "材料不足"}
		"rush":
			if not valid_cell(i) or not G.cooking(i): return {"error": "未在制作"}
			return {"used": G.rush_cook(i)}
		"boost": G.set_boost(bool(a.get("on", false))); return {}
		"energy":
			if not await G.buy_energy(): return {"error": "琥珀不足"}
			G.add_currency("energy", 100); return {"ok": true}
		"expand": return {"ok": await G.expand_storage()}
		"build":
			var r: Dictionary = await G.do_build(str(a.get("id", "")))
			if r.is_empty(): return {"error": "无法建造"}
			grant(r.get("rewards", [])); return r
		"book":
			var n: int = await G.claim_book(str(a.get("id", "")))
			if n <= 0: return {"error": "尚未发现或已领取"}
			G.add_currency("energy", n); return {"energy": n}
		"level":
			var lv := int(a.get("level", 0))
			var key := "level:%d" % lv
			if lv < 2 or lv > G.level or meta.has(key): return {"error": "等级奖励不可领取"}
			meta[key] = true; var rw := Data.level_rewards(lv); grant(rw); return {"rewards": rw}
		"pack": return await pack()
		"shop_view": return {"list": G.HotDeals.today()}
		"shop":
			var r: Dictionary = await G.shop_buy(str(a.get("key", "")), str(a.get("id", "")), 0, false)
			if not r.get("ok", false): return r
			G.stash_push(str(a["id"])); return r
		"hot_refresh": return await G.refresh_hot()
		"shell_refresh": return await G.refresh_shell()
		"bubble_buy":
			if not G.is_merge_bubble(i): return {"error": "气泡不存在"}
			return await G.buy_bubble(i)
		"bubble_reward":
			if i < 0 or i >= G.board.size() or int(G.board[i].get("lock", 2)) == 2: return {"error": "未解锁"}
			var rw := G.Layout.parse_reward(G.board[i].get("rw", null))
			if rw.is_empty(): return {"error": "已领取"}
			G.board[i].erase("rw"); grant([rw]); return {"rewards": [rw]}
		"pass":
			var track := str(a.get("track", "")); var lv := int(a.get("level", 0)); var rw: Array = []
			if track == "free": rw = await G.claim_pass_free(lv)
			elif track == "prem": rw = await G.claim_pass_prem(lv)
			elif track == "super": rw = await G.claim_pass_super(lv)
			elif track == "endless": rw = await G.claim_pass_endless()
			if rw.is_empty(): return {"error": "不可领取"}
			grant(rw); return {"rewards": rw}
		"daily":
			if str(a.get("key", "")) == "deal_ad": return {"error": "广告奖励需要平台验证"}
			return await DailyShop.claim(str(a.get("key", "")))
		"seven": return await SevenDay.claim(str(a.get("id", "")), bool(a.get("stage", false)))
		"choice": return await ChoiceChest.choose(i, G.cell_id(i) if valid_cell(i) else "", int(a.get("option", -1)))
		"activity":
			var c := MergeEvent.definition(str(a.get("season", "")))
			if not MergeEvent.available(c) or (str(a.get("action", "")) != "claim" and not MergeEvent.active(c)): return {"error": "活动尚未开放"}
			var state := MergeEvent.state(c)
			var roll := -1.0
			if str(a.get("action", "")) == "drop":
				var from := int(a.get("from", -1)); var to := int(a.get("to", -1))
				if MergeGrid.drop_kind(state["cells"], from, to, func(id): return MergeEvent.next_id(c, id)) == "merge":
					roll = G.random_for("activity:" + str(c["key"])).randf()
			var r := MergeEvent.local_action(c, state, str(a.get("action", "")), a, roll)
			if r.has("error"): return r
			for id in r.get("drops", []): grant([[id, 1, "physical"]])
			grant(r.get("rewards", [])); return r
		"duel": return await DuelRace.act(str(a.get("action", "")), int(a.get("milestone", 0)))
		"tiger": return await TigerEscape.act(str(a.get("action", "")), int(a.get("node", 0)))
		"race_join": return LocalRace.join()
		"race_claim":
			var r := LocalRace.claim(str(a.get("id", ""))); if r.get("ok", false): grant(r.get("rewards", []))
			return r
		"offer": return {"ok": await Offers.open_window(str(a.get("kind", "")))}
		"ufo": UfoOffer.local_visit(); return {}
		"reset":
			var id := G.player_id; G.new_game(); G.player_id = id; meta = {"allow_gm": meta.get("allow_gm", false)}; return {}
		"gm":
			if not meta.get("allow_gm", false): return {"error": "当前环境未开放 GM"}
			G.boost_gm = true; G.gm_activities = true; return {}
		"gift":
			var view := gift_view()
			var step := int(a.get("step", -1))
			if step != int(view["step"]) or step >= view["steps"].size() or float(view["steps"][step]["price"]) > 0: return {"error": "礼包不可领取"}
			meta["gift_cycle"] = view["cycle"]; meta["gift_step"] = step + 1
			var rw: Array = view["steps"][step]["rewards"]; grant(rw); return {"ok": true, "rewards": rw}
		"ufo_refresh":
			if UfoOffer.active(): UfoOffer.state()["offer"]["items"] = UfoOffer.candidate()
			return {}
		"tutorial_finish":
			if int(G.builds.get("fire", 0)) < 2 or G.board_has("seed_1") >= 0 or not meta.get("seed_order", false): return {"error": "引导尚未完成"}
			G.tutorial_on = false; G.seen_tutorial = true; G.refill_orders(); return {}
		_: return {"error": "不支持的操作"}

func valid_cell(i: int) -> bool:
	return i >= 0 and i < G.board.size() and int(G.board[i].get("lock", 2)) == 0 and G.cell_id(i) != ""

func settle_trash() -> void:
	var t: Dictionary = meta.get("trash", {})
	if not t.is_empty():
		var id := str(t["id"])
		if Data.type_of(id) == "item": G.add_currency("shell", maxi(0, Data.value_of(id)))
	meta.erase("trash")

func tap(i: int) -> Dictionary:
	if not valid_cell(i) or G.cooking(i): return {"error": "请选择可用物品"}
	var id := G.cell_id(i)
	var t := Data.type_of(id)
	if t in ["gen", "egen"]:
		if Data.gen_stats(id).is_empty() or G.gen_left(i) == 0: return {"error": "生产器尚未就绪"}
		var to := G.find_empty_near(i)
		# Tutorial landing positions are fixed rules.
		if G.tutorial_on and i == 31:
			for candidate in [24, 32]:
				if G._vacant(candidate): to = candidate; break
		if to < 0: return {"error": "棋盘已满"}
		if t == "gen" and not G.spend("energy", G.gen_cost()): return {"error": "体力不足"}
		G.gen_use(i)
		var out := G.roll_produce(id)
		if t == "gen": out = G.boost_drop(out)
		if G.tutorial_on and id == "basket_5" and not meta.get("seed_produced", false): out = "seed_1"; meta["seed_produced"] = true
		G.discover(out); G.board[to]["id"] = out
		return {"kind": "produce", "id": out, "to": to}
	if t in ["energy", "shell", "amber", "sand"]:
		var n := Data.value_of(id)
		if n <= 0: return {"error": "需要合成后收取"}
		G.board[i]["id"] = ""; G.add_currency(t, n); return {"kind": "collect"}
	if t == "chest":
		var ids: Array = await G.open_chest(id)
		G.board[i]["id"] = ""; grant(Rewards.items(ids), {"board_origin": i}); return {"kind": "chest", "items": ids}
	return {"error": "该物品不能直接使用"}

func stash(index: int) -> Dictionary:
	if index < 0 or index >= G.stash.size(): return {"error": "物品不存在"}
	var id := str(G.stash[index]); var t := Data.type_of(id)
	if t == "pack": return {"error": "请打开卡包"}
	if t in ["energy", "shell", "amber", "sand"] and Data.value_of(id) > 0:
		G.stash.remove_at(index); G.add_currency(t, Data.value_of(id)); return {}
	if t == "chest":
		var ids: Array = await G.open_chest(id)
		G.stash.remove_at(index); grant(Rewards.items(ids), {"board_origin": 0}); return {"items": ids}
	var to := G.find_empty_near(0)
	if to < 0: return {"error": "棋盘已满"}
	G.stash.remove_at(index); G.board[to]["id"] = id; G.discover(id); return {"to": to, "id": id}

func pack() -> Dictionary:
	if G.level < Data.CARD_LEVEL: return {"error": "典藏卡尚未解锁"}
	var board_index := G.board_has("pack_1")
	var stash_index := G.stash.find("pack_1")
	if board_index < 0 and stash_index < 0: return {"error": "没有卡包"}
	if stash_index >= 0: G.stash.remove_at(stash_index)
	else: G.board[board_index]["id"] = ""
	var complete_before := []
	for album in Data.ALBUMS.size():
		if G.album_count(album) == 9: complete_before.append(album)
	var cards: Array = await G.open_pack()
	var economy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/replay_economy.json"))
	for album in Data.ALBUMS.size():
		var key := "album:%d" % album
		if G.album_count(album) == 9 and not album in complete_before and not meta.get(key, false):
			meta[key] = true
			grant(economy["album_reward"])
	return {"cards": cards}

func connect_session(why: String) -> void:
	Cloud._busy = true
	var r: Array = await Cloud._call("POST", "/v2/session", {})
	Cloud._busy = false
	if r[0] != 200:
		Cloud._offline("boot")
		return
	var d: Dictionary = r[1]
	if str(d.get("rules", "")) != rules_hash():
		Cloud._say("游戏规则版本不一致，暂时保留本地进度")
		Cloud._offline("boot")
		return
	if authorized and not inflight.is_empty() and why != "login":
		Cloud._after_boot()
		await upload()
		return
	if not authorized or pending.is_empty() or why == "login" or int(d["version"]) != base:
		accept(d, true)
	Cloud._after_boot()
	if not pending.is_empty(): upload()

func accept(d: Dictionary, replace: bool) -> void:
	base = int(d["version"])
	authorized = true
	if replace:
		var raw := Marshalls.base64_to_raw(str(d["data"])).decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		var s = JSON.parse_string(raw.get_string_from_utf8())
		if not s is Dictionary: return
		restore(s)
		pending = []; inflight = {}
		G.loaded_save = true
		G.board_changed.emit()
		G.orders_changed.emit()
		G.changed.emit()
		G.merge_event_changed.emit()
		G.seven_day_changed.emit()
		Cloud.restored.emit()
	G.save_game()
	Cloud.last_sync = Cloud.server_now()
	Cloud._save_state()

func upload() -> void:
	if Cloud._busy or not Cloud.can_talk() or not authorized or pending.is_empty(): return
	if inflight.is_empty():
		var ops := []
		for entry in pending.slice(0, 256):
			var op: Dictionary = entry.duplicate(true); op.erase("hash"); ops.append(op)
		inflight = {"base": base, "rules": rules_hash(), "hash": str(pending[ops.size()-1]["hash"]),
			"batch": Crypto.new().generate_random_bytes(16).hex_encode(), "ops": ops}
		G.save_game()
	Cloud._busy = true
	Cloud._last_up = Cloud._ticks()
	var r: Array = await Cloud._call("POST", "/v2/sync", inflight)
	Cloud._busy = false
	if r[0] != 200:
		Cloud._offline("upload")
		return
	var d: Dictionary = r[1]
	if d.get("reset", false):
		accept(d, true)
		Cloud._say(str(d.get("reason", "进度校验不一致")) + "，已恢复服务器存档")
	else:
		var ack := int(d["seq"])
		pending = pending.filter(func(op): return int(op["seq"]) > ack)
		inflight = {}
		accept(d, false)
	Cloud.online = true
	Cloud.uploads += 1
	Cloud.synced.emit("replay", true)
	if not pending.is_empty(): upload.call_deferred()

func gift_view() -> Dictionary:
	var c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gift_chain.json"))
	var days := maxi(1, int(c.get("cycle_days", 7)))
	var day := floori((G.now() + 28800) / 86400.0)
	var cycle := floori(float(day - 4 - int(c.get("anchor_weekday", 0))) / days)
	var step := int(meta.get("gift_step", 0)) if int(meta.get("gift_cycle", -1)) == cycle else 0
	var rows: Array = c["steps"]
	return {"cycle": cycle, "step": step, "ends_at": (4 + (cycle+1)*days)*86400-28800,
		"visible": c.get("visible", 3), "total": rows.size(), "steps": rows,
		"free_ready": step < rows.size() and float(rows[step]["price"]) == 0, "done": step >= rows.size()}
