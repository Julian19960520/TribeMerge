extends RefCounted
## Deterministic gameplay commands shared by the client and validation workers.
## This module has no storage, transport, scene or animation responsibilities.
var runtime: Node
## Only used while recovering the previous local version's verified journal.
var legacy_album_rewards := false
var meta: Dictionary:
	get: return runtime.meta
	set(value): runtime.meta = value

func _init(owner: Node) -> void:
	runtime = owner

func advance() -> void:
	ActivityRules.initialize()
	G.rules.clock._check_day()
	G.rules.board._tick_bubbles()
	if G.energy < G.MAX_ENERGY: G.rules.clock._regen()
	G.rules.orders._tick_cooks()
	ActivityRules.tick()
	# Tutorial effects are rules, never values supplied by the interface.
	if G.tutorial_on and G.rules.orders.board_has("basket_5") >= 0:
		if G.energy < 1 and not meta.get("tutorial_energy", false):
			G.energy = 5
			meta["tutorial_energy"] = true
		if not meta.get("seed_order", false):
			G.orders.insert(0, G.order_identity({"who": 1, "items": ["seed_1"], "rw": {"xp": 1, "shell": 50}, "story": true, "say": "草籽能种出新的果树，你学得真快！"}))
			meta["seed_order"] = true

func grant(rw: Array, delivery: Dictionary = {}) -> void:
	Rewards.settle(rw, delivery)

func dispatch(name: String, a: Dictionary):
	var i := int(a.get("cell", -1))
	match name:
		"tick": return {}
		"drop":
			var r := G.try_drop(int(a.get("from", -1)), int(a.get("to", -1)))
			return {"kind": r} if r != "" else {"error": "不能移动或合成"}
		"tap": return tap(i)
		"stash": return stash(int(a.get("index", -1)))
		"store":
			if not valid_cell(i) or G.rules.orders.cooking(i) or G.inv.size() >= G.inv_cap or Data.type_of(G.rules.board.cell_id(i)) == "egen" or G.rules.board.is_merge_bubble(i) or Data.is_dish(G.rules.board.cell_id(i)): return {"error": "无法存入"}
			if not G.rules.board.store_cell(i): return {"error": "无法存入"}
			return {}
		"inventory":
			var index := int(a.get("index", -1))
			var to := G.rules.board.find_empty_near(0)
			if index < 0 or index >= G.inv.size() or to < 0: return {"error": "无法取出"}
			G.rules.board.take_inventory(index, to)
			return {"to": to}
		"discard":
			if not valid_cell(i) or G.rules.orders.cooking(i) or G.rules.board.is_merge_bubble(i) or Data.type_of(G.rules.board.cell_id(i)) in ["gen", "egen"] or Data.is_dish(G.rules.board.cell_id(i)): return {"error": "不能丢弃"}
			settle_trash()
			meta["trash"] = {"cell": i, "id": G.rules.board.cell_id(i), "chest": G.board[i].get("chest", []).duplicate()}
			G.board[i]["id"] = ""; G.board[i].erase("chest")
			return {}
		"discard_finish": settle_trash(); return {}
		"undo":
			var t: Dictionary = meta.get("trash", {})
			if t.is_empty() or G.rules.board.cell_id(int(t["cell"])) != "": return {"error": "无法撤销"}
			G.board[int(t["cell"])]["id"] = t["id"]
			if not t.get("chest", []).is_empty(): G.board[int(t["cell"])]["chest"] = t["chest"].duplicate()
			meta.erase("trash"); return {}
		"order":
			if i < 0 or i >= G.orders.size() or not G.rules.orders.order_ready(G.orders[i]): return {"error": "订单尚未完成"}
			var o: Dictionary = G.orders[i].duplicate(true)
			var rw := Rewards.for_order(o)
			var cells := G.complete_order(i)
			grant(rw)
			return {"cells": cells, "rewards": rw, "who": int(o["who"]), "say": str(o.get("say", ""))}
		"craft":
			if i < 0 or i >= G.orders.size(): return {"error": "订单不存在"}
			var r := G.begin_craft(i)
			return {"flights": r} if not r.is_empty() else {"error": "材料不足"}
		"rush":
			if not valid_cell(i) or not G.rules.orders.cooking(i): return {"error": "未在制作"}
			return {"used": G.rush_cook(i)}
		"boost": G.set_boost(bool(a.get("on", false))); return {}
		"energy":
			if not G.buy_energy(): return {"error": "琥珀不足"}
			G.rules.progression.add_currency("energy", 100); return {"ok": true}
		"expand": return {"ok": G.expand_storage()}
		"build":
			var r: Dictionary = G.do_build(str(a.get("id", "")))
			if r.is_empty(): return {"error": "无法建造"}
			grant(r.get("rewards", [])); return r
		"book":
			var n: int = G.claim_book(str(a.get("id", "")))
			if n <= 0: return {"error": "尚未发现或已领取"}
			G.rules.progression.add_currency("energy", n); return {"energy": n}
		"level":
			var lv := int(a.get("level", 0))
			var key := "level:%d" % lv
			if lv < 2 or lv > G.level or meta.has(key): return {"error": "等级奖励不可领取"}
			meta[key] = true; var rw := Data.level_rewards(lv); grant(rw); return {"rewards": rw}
		"pack": return pack(a)
		"album_claim": return claim_album(int(a.get("album", -1)))
		"shop_view": return {"list": G.rules.shop.today()}
		"shop":
			var r: Dictionary = G.shop_buy(str(a.get("key", "")), str(a.get("id", "")))
			if not r.get("ok", false): return r
			G.rules.board.stash_push(str(a["id"])); return r
		"hot_refresh": return G.refresh_hot()
		"shell_refresh": return G.refresh_shell()
		"bubble_buy":
			if not G.rules.board.is_merge_bubble(i): return {"error": "气泡不存在"}
			return G.buy_bubble(i)
		"bubble_reward":
			if i < 0 or i >= G.board.size() or int(G.board[i].get("lock", 2)) == 2: return {"error": "未解锁"}
			var rw := G.Layout.parse_reward(G.board[i].get("rw", null))
			if rw.is_empty(): return {"error": "已领取"}
			G.board[i].erase("rw"); grant([rw]); return {"rewards": [rw]}
		"pass":
			var track := str(a.get("track", "")); var lv := int(a.get("level", 0)); var rw: Array = []
			if track == "free": rw = G.claim_pass_free(lv)
			elif track == "prem": rw = G.claim_pass_prem(lv)
			elif track == "super": rw = G.claim_pass_super(lv)
			elif track == "endless": rw = G.claim_pass_endless()
			if rw.is_empty(): return {"error": "不可领取"}
			grant(rw); return {"rewards": rw}
		"daily":
			if str(a.get("key", "")) == "deal_ad": return {"error": "广告奖励需要平台验证"}
			return DailyShop.claim(str(a.get("key", "")))
		"seven": return SevenDay.claim(str(a.get("id", "")), bool(a.get("stage", false)))
		"choice": return ChoiceChest.choose(i, G.rules.board.cell_id(i) if valid_cell(i) else "", int(a.get("option", -1)))
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
		"duel": return DuelRace.act(str(a.get("action", "")), int(a.get("milestone", 0)))
		"tiger": return TigerEscape.act(str(a.get("action", "")), int(a.get("node", 0)))
		"fossil": return FossilDig.act(str(a.get("action", "")), int(a.get("value", -1)))
		"race_join": return LocalRace.join()
		"race_claim":
			var r := LocalRace.claim(str(a.get("id", ""))); if r.get("ok", false): grant(r.get("rewards", []))
			return r
		"offer": return {"ok": Offers.open_window(str(a.get("kind", "")))}
		"ufo": UfoOffer.local_visit(); return {}
		"reset":
			var id := G.player_id
			var allow_gm := bool(meta.get("allow_gm", false))
			G.new_game()
			G.player_id = id
			meta = {"allow_gm": allow_gm}
			advance()
			return {}
		"gm":
			return gm(a)
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
			if int(G.builds.get("fire", 0)) < 2 or G.rules.orders.board_has("seed_1") >= 0 or not meta.get("seed_order", false): return {"error": "引导尚未完成"}
			G.tutorial_on = false; G.seen_tutorial = true; G.rules.orders.refill_orders(); return {}
		_: return {"error": "不支持的操作"}

func valid_cell(i: int) -> bool:
	return i >= 0 and i < G.board.size() and int(G.board[i].get("lock", 2)) == 0 and G.rules.board.cell_id(i) != ""

func settle_trash() -> void:
	var t: Dictionary = meta.get("trash", {})
	if not t.is_empty():
		var id := str(t["id"])
		if Data.type_of(id) == "item": G.rules.progression.add_currency("shell", maxi(0, Data.value_of(id)))
	meta.erase("trash")

func tap(i: int) -> Dictionary:
	if not valid_cell(i) or G.rules.orders.cooking(i): return {"error": "请选择可用物品"}
	var id := G.rules.board.cell_id(i)
	var t := Data.type_of(id)
	if t in ["gen", "egen"]:
		if Data.gen_stats(id).is_empty() or G.rules.board.gen_left(i) == 0: return {"error": "生产器尚未就绪"}
		var to := G.rules.board.find_empty_near(i)
		# Tutorial landing positions are fixed rules.
		if G.tutorial_on and i == 31:
			for candidate in [24, 32]:
				if G.rules.board._vacant(candidate): to = candidate; break
		if to < 0: return {"error": "棋盘已满"}
		if t == "gen" and not G.rules.progression.spend("energy", G.rules.board.gen_cost()): return {"error": "体力不足"}
		G.rules.board.gen_use(i)
		var out := G.rules.board.roll_produce(id)
		if t == "gen": out = G.rules.board.boost_drop(out)
		if G.tutorial_on and id == "basket_5" and not meta.get("seed_produced", false): out = "seed_1"; meta["seed_produced"] = true
		G.rules.board.discover(out); G.board[to]["id"] = out
		return {"kind": "produce", "id": out, "to": to}
	if t in ["energy", "shell", "amber", "sand"]:
		var n := Data.value_of(id)
		if n <= 0: return {"error": "需要合成后收取"}
		G.board[i]["id"] = ""; G.rules.progression.add_currency(t, n); return {"kind": "collect", "id": id, "amount": n}
	if t == "chest":
		return G.dispense_chest(i)
	return {"error": "该物品不能直接使用"}

func stash(index: int) -> Dictionary:
	if index < 0 or index >= G.stash.size(): return {"error": "物品不存在"}
	var id := str(G.stash[index]); var t := Data.type_of(id)
	if t == "pack": return {"error": "请打开卡包"}
	if t in ["energy", "shell", "amber", "sand"] and Data.value_of(id) > 0:
		G.stash.remove_at(index); G.rules.progression.add_currency(t, Data.value_of(id)); return {}
	var to := G.rules.board.find_empty_near(0)
	if to < 0: return {"error": "棋盘已满"}
	G.stash.remove_at(index); G.board[to]["id"] = id; G.rules.board.discover(id); return {"to": to, "id": id}

func pack(args: Dictionary = {}) -> Dictionary:
	if not G.rules.progression.feature_unlocked(Data.CARD_LEVEL): return {"error": "典藏卡尚未解锁"}
	var source := G.rules.progression.find_pack_source(str(args.get("id", "")), int(args.get("cell", -1)), int(args.get("stash", -1)))
	if source.is_empty(): return {"error": "没有卡包"}
	G.rules.progression.consume_pack_source(source)
	var complete_before := []
	if legacy_album_rewards:
		for album in Data.ALBUMS.size():
			if G.rules.progression.album_count(album) == 9: complete_before.append(album)
	var cards: Array = G.rules.progression.roll_card_pack(str(source["id"]))
	if cards.is_empty(): return {"error": "卡包无法打开"}
	if legacy_album_rewards: grant_album_rewards(complete_before)
	return {"cards": cards}

func claim_album(album: int) -> Dictionary:
	if not G.rules.progression.feature_unlocked(Data.CARD_LEVEL): return {"error": "典藏卡尚未解锁"}
	if album < 0 or album >= Data.ALBUMS.size(): return {"error": "卡册不存在"}
	var key := "album:%d" % album
	if bool(meta.get(key, false)): return {"error": "奖励已领取"}
	if G.rules.progression.album_count(album) != Data.ALBUMS[album]["cards"].size(): return {"error": "尚未集齐卡册"}
	var rewards: Array = Data.ConfigFiles.shared("res://data/replay_economy.json")["album_reward"]
	meta[key] = true
	grant(rewards)
	return {"rewards": rewards}

func grant_album_rewards(complete_before: Array) -> void:
	var economy: Dictionary = Data.ConfigFiles.shared("res://data/replay_economy.json")
	for album in Data.ALBUMS.size():
		var key := "album:%d" % album
		if G.rules.progression.album_count(album) == 9 and not album in complete_before and not meta.get(key, false):
			meta[key] = true
			grant(economy["album_reward"])

func gm(args: Dictionary) -> Dictionary:
	if not meta.get("allow_gm", false): return {"error": "当前环境未开放 GM"}
	var action := str(args.get("action", "unlock"))
	if action == "unlock":
		G.rules.progression.unlock_all_features()
		ActivityRules.initialize()
		return {}
	if action != "card": return {"error": "未知 GM 操作"}
	if not G.rules.progression.feature_unlocked(Data.CARD_LEVEL): return {"error": "请先解锁卡册"}
	var selected_album := int(args.get("album", -1))
	if selected_album < -1 or selected_album >= Data.ALBUMS.size(): return {"error": "卡册不存在"}
	var pool := []
	var missing := []
	var complete_before := []
	for album in Data.ALBUMS.size():
		if legacy_album_rewards and G.rules.progression.album_count(album) == 9: complete_before.append(album)
		if selected_album >= 0 and album != selected_album: continue
		for index in Data.ALBUMS[album]["cards"].size():
			var entry := [album, index]
			pool.append(entry)
			if not G.cards.has("%d_%d" % [album, index]): missing.append(entry)
	if pool.is_empty(): return {"error": "没有可获取的卡片"}
	var candidates: Array = missing if not missing.is_empty() else pool
	var rng: RandomNumberGenerator = G.random_for("gm_cards")
	var entry: Array = candidates[int(rng.randi() % candidates.size())]
	G.rules.progression.collect_cards([entry])
	if legacy_album_rewards: grant_album_rewards(complete_before)
	return {"cards": [entry]}

func gift_view() -> Dictionary:
	var c: Dictionary = Data.ConfigFiles.shared("res://data/gift_chain.json")
	var days := maxi(1, int(c.get("cycle_days", 7)))
	var day := floori((G.now() + 28800) / 86400.0)
	var cycle := floori(float(day - 4 - int(c.get("anchor_weekday", 0))) / days)
	var step := int(meta.get("gift_step", 0)) if int(meta.get("gift_cycle", -1)) == cycle else 0
	var rows: Array = c["steps"]
	return {"cycle": cycle, "step": step, "ends_at": (4 + (cycle+1)*days)*86400-28800,
		"visible": c.get("visible", 3), "total": rows.size(), "steps": rows,
		"free_ready": step < rows.size() and float(rows[step]["price"]) == 0, "done": step >= rows.size()}
