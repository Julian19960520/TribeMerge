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
	G.rules.starter.tick()
	G.rules.clock._check_day()
	G.rules.board._tick_bubbles()
	if G.energy < G.MAX_ENERGY: G.rules.clock._regen()
	G.rules.orders._tick_cooks()
	ActivityRules.tick()
	G.rules.onboarding.advance()

func grant(rw: Array, delivery: Dictionary = {}) -> void:
	Rewards.settle(rw, delivery)

func dispatch(name: String, a: Dictionary):
	var result: Dictionary = _dispatch(name, a)
	if not result.has("error"):
		G.rules.onboarding.observe(name, a, result)
	return result

func _dispatch(name: String, a: Dictionary):
	var i := int(a.get("cell", -1))
	match name:
		"tick": return {}
		"drop":
			var r := G.try_drop(int(a.get("from", -1)), int(a.get("to", -1)))
			return {"kind": r} if r != "" else {"error": TextCatalog.source("notice.reducer.863a17402e36")}
		"tap": return tap(i)
		"stash": return stash(int(a.get("index", -1)))
		"store":
			if not valid_cell(i) or G.rules.orders.cooking(i) or G.inv.size() >= G.inv_cap or Data.type_of(G.rules.board.cell_id(i)) == "egen" or G.rules.board.is_merge_bubble(i) or Data.is_dish(G.rules.board.cell_id(i)): return {"error": TextCatalog.source("notice.reducer.15bb521bca65")}
			if not G.rules.board.store_cell(i): return {"error": TextCatalog.source("notice.reducer.15bb521bca65")}
			return {}
		"inventory":
			var index := int(a.get("index", -1))
			var to := G.rules.board.find_empty_near(0)
			if index < 0 or index >= G.inv.size() or to < 0: return {"error": TextCatalog.source("notice.reducer.4c562c5a325b")}
			G.rules.board.take_inventory(index, to)
			return {"to": to}
		"discard":
			if not valid_cell(i) or G.rules.orders.cooking(i) or G.rules.board.is_merge_bubble(i) or Data.type_of(G.rules.board.cell_id(i)) in ["gen", "egen"] or Data.is_dish(G.rules.board.cell_id(i)): return {"error": TextCatalog.source("notice.reducer.fef1d59e3fde")}
			settle_trash()
			var sell_id := G.rules.board.cell_id(i)
			var sell_n := int(G.rules.onboarding.config().get("sell_energy", {}).get(str(Data.lv(sell_id)), 0)) if Data.type_of(sell_id) == "item" else 0
			if sell_n > 0:
				G.board[i]["id"] = ""
				G.rules.progression.add_currency("energy", sell_n)
				return {"sold": true, "energy": sell_n}
			meta["trash"] = {"cell": i, "id": G.rules.board.cell_id(i), "chest": G.board[i].get("chest", []).duplicate()}
			G.board[i]["id"] = ""; G.board[i].erase("chest")
			return {}
		"discard_finish": settle_trash(); return {}
		"undo":
			var t: Dictionary = meta.get("trash", {})
			if t.is_empty() or G.rules.board.cell_id(int(t["cell"])) != "": return {"error": TextCatalog.source("notice.reducer.0901e1ab6cca")}
			G.board[int(t["cell"])]["id"] = t["id"]
			if not t.get("chest", []).is_empty(): G.board[int(t["cell"])]["chest"] = t["chest"].duplicate()
			meta.erase("trash"); return {}
		"order":
			if i < 0 or i >= G.orders.size() or not G.rules.orders.order_ready(G.orders[i]): return {"error": TextCatalog.source("notice.reducer.c725f5672f44")}
			var o: Dictionary = G.orders[i].duplicate(true)
			var rw := Rewards.for_order(o)
			var cells: Array = G.rules.orders.complete_order(i, false)
			grant(rw)
			if not G.tutorial_on: G.rules.orders.refill_orders()
			return {"cells": cells, "rewards": rw, "who": int(o["who"]), "say": str(o.get("say", ""))}
		"craft":
			if i < 0 or i >= G.orders.size(): return {"error": TextCatalog.source("notice.reducer.3fa37b852448")}
			var r := G.begin_craft(i)
			return {"flights": r} if not r.is_empty() else {"error": TextCatalog.source("notice.reducer.2381e67fca10")}
		"rush":
			if not valid_cell(i) or not G.rules.orders.cooking(i): return {"error": TextCatalog.source("notice.reducer.488309ef578d")}
			return {"used": G.rush_cook(i)}
		"boost":
			var mult := int(a["mult"]) if a.has("mult") else (2 if bool(a.get("on", false)) else 1)
			G.set_boost_mult(mult)
			return {}
		"energy":
			# 第一次补体力免费，之后才花琥珀。
			if not meta.get("free_energy", false):
				meta["free_energy"] = true
				G.rules.progression.add_currency("energy", PriceBook.energy_amount()); return {"ok": true, "free": true}
			if not G.buy_energy(): return {"error": TextCatalog.source("notice.boardrules.b874b509cd26")}
			G.rules.progression.add_currency("energy", PriceBook.energy_amount()); return {"ok": true}
		"expand": return {"ok": G.expand_storage()}
		"build":
			var r: Dictionary = G.do_build(str(a.get("id", "")))
			if r.is_empty(): return {"error": TextCatalog.source("notice.reducer.298d1765f84e")}
			grant(r.get("rewards", [])); return r
		"book":
			var n: int = G.claim_book(str(a.get("id", "")))
			if n <= 0: return {"error": TextCatalog.source("notice.reducer.4a2819815587")}
			G.rules.progression.add_currency("energy", n); return {"energy": n}
		"level":
			var lv := int(a.get("level", 0))
			var key := "level:%d" % lv
			if lv < 2 or lv > G.level or meta.has(key): return {"error": TextCatalog.source("notice.reducer.93d1ab460f9b")}
			# 订单宝箱在升级那一刻就发了（ProgressionRules._order_chest），这里只发等级奖励。
			meta[key] = true
			if lv == int(G.rules.starter.config().get("reward_level", -1)): G.rules.starter.grant()
			var rw := Data.level_rewards(lv)
			grant(rw)
			return {"rewards": rw}
		"pack": return pack(a)
		"card_star_exchange": return G.rules.progression.exchange_card_stars(int(a.get("cost", 0)))
		"album_claim": return claim_album(int(a.get("album", -1)))
		"shop_view": return {"list": G.rules.shop.today()}
		"shop":
			var r: Dictionary = G.shop_buy(str(a.get("key", "")), str(a.get("id", "")))
			if not r.get("ok", false): return r
			G.rules.board.stash_push(str(a["id"])); return r
		"resource_buy":
			for row in PriceBook.catalog.get("resource_products", []):
				if str(row["product"]) != str(a.get("product", "")): continue
				if not G.rules.progression.spend("amber", int(row["price"])): return {"error": TextCatalog.source("notice.boardrules.b874b509cd26")}
				grant(row["rewards"])
				return {"ok": true, "rewards": row["rewards"]}
			return {"error": "unknown_product"}
		"hot_refresh": return G.refresh_hot()
		"shell_refresh": return G.refresh_shell()
		"bubble_buy":
			if not G.rules.board.is_merge_bubble(i): return {"error": TextCatalog.source("notice.boardrules.9d09918e4686")}
			return G.buy_bubble(i)
		"bubble_reward":
			if i < 0 or i >= G.board.size() or int(G.board[i].get("lock", 2)) == 2: return {"error": TextCatalog.source("notice.reducer.273bae9c314f")}
			var rw := G.Layout.parse_reward(G.board[i].get("rw", null))
			if rw.is_empty(): return {"error": TextCatalog.source("notice.sevenday.426e458a4124")}
			G.board[i].erase("rw"); grant([rw]); return {"rewards": [rw]}
		"pass":
			var track := str(a.get("track", "")); var lv := int(a.get("level", 0)); var rw: Array = []
			if track == "free": rw = G.claim_pass_free(lv)
			elif track == "prem": rw = G.claim_pass_prem(lv)
			elif track == "super": rw = G.claim_pass_super(lv)
			elif track == "endless": rw = G.claim_pass_endless()
			if rw.is_empty(): return {"error": TextCatalog.source("notice.reducer.2256aff70004")}
			grant(rw); return {"rewards": rw}
		"daily":
			if str(a.get("key", "")) == "deal_ad": return {"error": TextCatalog.source("notice.dailyshop.b5b1db41e829")}
			return DailyShop.claim(str(a.get("key", "")))
		"seven": return SevenDay.claim(str(a.get("id", "")), bool(a.get("stage", false)))
		"choice": return ChoiceChest.choose(i, G.rules.board.cell_id(i) if valid_cell(i) else "", int(a.get("option", -1)))
		"activity":
			var c := MergeEvent.definition(str(a.get("season", "")))
			if not MergeEvent.available(c) or (str(a.get("action", "")) != "claim" and not MergeEvent.active(c)): return {"error": TextCatalog.source("notice.reducer.3c11c47b13f7")}
			var state := MergeEvent.state(c)
			var roll := -1.0
			if str(a.get("action", "")) == "drop":
				var from := int(a.get("from", -1)); var to := int(a.get("to", -1))
				if MergeGrid.drop_kind(state["cells"], from, to, func(id): return MergeEvent.next_id(c, id)) == "merge":
					roll = G.random_for("activity:" + str(c["key"])).randf()
			elif str(a.get("action", "")) == "brush" and MergeEvent.can_brush(c, state, int(a.get("cell", -1))):
				roll = G.random_for("activity_brush:" + str(c["key"])).randf()
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
			if step != int(view["step"]) or step >= view["steps"].size() or float(view["steps"][step]["price"]) > 0: return {"error": TextCatalog.source("notice.reducer.651ae13947c0")}
			meta["gift_cycle"] = view["cycle"]; meta["gift_step"] = step + 1
			var rw: Array = view["steps"][step]["rewards"]; grant(rw); return {"ok": true, "rewards": rw}
		"grant": return apply_grant(str(a.get("id", "")), a.get("content", {}))
		"ufo_refresh":
			if UfoOffer.active(): UfoOffer.state()["offer"]["items"] = UfoOffer.candidate()
			return {}
		"onboarding_rescue": return G.rules.onboarding.claim_rescue()
		"onboarding_next": return G.rules.onboarding.acknowledge(str(a.get("step", "")))
		"tutorial_finish":
			if G.rules.onboarding.active(): return {"error": TextCatalog.source("notice.reducer.8d9d2b110d04")}
			# 引导到第一次建设完、两张教学订单都交掉为止；之后的生产器升级由一次性提示带。
			if int(G.builds.get("fire", 0)) < 2: return {"error": TextCatalog.source("notice.reducer.83438aeb7d21")}
			for o in G.orders:
				if int(o.get("tutorial", 0)) > 0: return {"error": TextCatalog.source("notice.reducer.83438aeb7d21")}
			G.tutorial_on = false; G.seen_tutorial = true; G.rules.orders.refill_orders(); return {}
		_: return {"error": TextCatalog.source("notice.reducer.7ae48a0c4f7e")}

## Server-issued paid content (scripts/net/Payments.gd). The grant id is recorded in
## replay_meta.grants, so a grant applies once per save however often it is delivered.
func apply_grant(id: String, content) -> Dictionary:
	if not id.begins_with("gr_") or not content is Dictionary: return {"error": TextCatalog.source("notice.reducer.b0b344e7f5e7")}
	var applied: Dictionary = meta.get("grants", {})
	if applied.has(id): return {"error": TextCatalog.source("notice.reducer.b92c02b8354b"), "duplicate": true}
	var cost := int(content.get("cost_amber", 0))
	if cost < 0 or (cost > 0 and not G.rules.progression.spend("amber", cost)): return {"error": "not_enough_amber"}
	var energy_purchase: Dictionary = content.get("energy_purchase", {})
	G.rules.clock._check_day()
	if str(energy_purchase.get("day", "")) == G.rules.clock.today(): G.energy_buys = maxi(G.energy_buys, int(energy_purchase.get("count", 0)))
	var shop: Dictionary = content.get("shop", {})
	if not shop.is_empty() and int(shop.get("revision", -1)) == G.hot_revision:
		var key := str(shop.get("key", ""))
		G.hot_bought[key] = int(G.hot_bought.get(key, 0)) + 1
	var amber := int(content.get("amber", 0))
	if amber > 0: G.rules.progression.add_currency("amber", amber)
	var pass_info = content.get("pass", {})
	if pass_info is Dictionary and int(pass_info.get("tier", 0)) > 0:
		G.rules.clock.check_pass_season()
		G.pass_tier = maxi(G.pass_tier, clampi(int(pass_info["tier"]), 0, 2))
	var rewards: Array = content.get("rewards", []) if content.get("rewards", []) is Array else []
	grant(rewards)
	var offer = content.get("offer", {})
	if offer is Dictionary and G.offers.get(str(offer.get("kind", ""))) is Dictionary:
		var window: Dictionary = G.offers[str(offer["kind"])]
		var bought: Dictionary = window.get("bought", {})
		var key := str(int(offer.get("tier", 0)))
		bought[key] = int(bought.get(key, 0)) + 1
		window["bought"] = bought
	var ufo := str(content.get("ufo", ""))
	if ufo != "" and G.ufo_offer.get("offer") is Dictionary and str(G.ufo_offer["offer"].get("id", "")) == ufo:
		G.ufo_offer["offer"]["paid"] = true
	var gift = content.get("gift", {})
	if gift is Dictionary and gift.has("step"):
		var view := gift_view()
		if int(gift.get("cycle", -1)) == int(view["cycle"]) and int(gift["step"]) == int(view["step"]):
			meta["gift_cycle"] = view["cycle"]; meta["gift_step"] = int(gift["step"]) + 1
	applied[id] = runtime.clock
	meta["grants"] = applied
	G.dirty()
	G.changed.emit()
	return {"ok": true, "id": id, "amber": amber, "rewards": rewards}

func valid_cell(i: int) -> bool:
	return i >= 0 and i < G.board.size() and int(G.board[i].get("lock", 2)) == 0 and (G.rules.board.cell_id(i) != "" or G.rules.orders.cooking(i))

func settle_trash() -> void:
	var t: Dictionary = meta.get("trash", {})
	if not t.is_empty():
		var id := str(t["id"])
		if Data.type_of(id) == "item": G.rules.progression.add_currency("shell", maxi(0, Data.value_of(id)))
	meta.erase("trash")

func tap(i: int) -> Dictionary:
	if not valid_cell(i): return {"error": TextCatalog.source("notice.reducer.c28c94015176")}
	if G.rules.orders.cooking(i): return G.rules.orders.collect_craft(i)
	var id := G.rules.board.cell_id(i)
	var t := Data.type_of(id)
	if t in ["gen", "egen"]:
		if Data.gen_stats(id).is_empty() or G.rules.board.gen_left(i) == 0: return {"error": TextCatalog.source("notice.reducer.adb84d88ec3d")}
		var to := G.rules.board.find_empty_near(i)
		if to < 0: return {"error": TextCatalog.source("notice.reducer.cf76442736ea")}
		if t == "gen" and not G.rules.progression.spend("energy", G.rules.board.gen_cost()): return {"error": TextCatalog.source("notice.reducer.2eea6537a85c")}
		G.rules.board.gen_use(i)
		var out := G.rules.onboarding.scripted_drop(id)
		if out == "": out = G.rules.board.roll_produce(id)
		if t == "gen": out = G.rules.board.boost_drop(out)
		G.rules.board.discover(out); G.board[to]["id"] = out
		return {"kind": "produce", "id": out, "to": to}
	if t in ["energy", "shell", "amber", "sand"]:
		var n := Data.value_of(id)
		if n <= 0: return {"error": TextCatalog.source("notice.reducer.49704ea9064a")}
		G.board[i]["id"] = ""; G.rules.progression.add_currency(t, n); return {"kind": "collect", "id": id, "amount": n}
	if t == "chest":
		return G.dispense_chest(i)
	return {"error": TextCatalog.source("notice.reducer.2e2a7ba66972")}

func stash(index: int) -> Dictionary:
	if index < 0 or index >= G.stash.size(): return {"error": TextCatalog.source("notice.reducer.c8a1a9fa6fae")}
	# 卡册没开时，暂存区里的卡包（老存档里早领到的）取出来就是藤编宝箱
	var id := Rewards.before_cards(str(G.stash[index])); var t := Data.type_of(id)
	if t == "pack": return {"error": TextCatalog.source("notice.reducer.1f220c65a234")}
	if t in ["energy", "shell", "amber", "sand"] and Data.value_of(id) > 0:
		G.stash.remove_at(index); G.rules.progression.add_currency(t, Data.value_of(id)); return {}
	var to := G.rules.board.find_empty_near(0)
	if to < 0: return {"error": TextCatalog.source("notice.reducer.cf76442736ea")}
	G.stash.remove_at(index); G.board[to]["id"] = id; G.rules.board.discover(id); return {"to": to, "id": id}

func pack(args: Dictionary = {}) -> Dictionary:
	if not G.rules.progression.feature_unlocked(Data.CARD_LEVEL): return {"error": TextCatalog.source("notice.progressionrules.0cf982b1fe0e")}
	var source := G.rules.progression.find_pack_source(str(args.get("id", "")), int(args.get("cell", -1)), int(args.get("stash", -1)))
	if source.is_empty(): return {"error": TextCatalog.source("notice.reducer.fe21817d4c29")}
	G.rules.progression.consume_pack_source(source)
	var complete_before := []
	if legacy_album_rewards:
		for album in Data.ALBUMS.size():
			if G.rules.progression.album_count(album) == 9: complete_before.append(album)
	var result: Dictionary = G.rules.progression.draw_card_pack(str(source["id"]))
	if result.has("error"): return result
	if legacy_album_rewards: grant_album_rewards(complete_before)
	return result

func claim_album(album: int) -> Dictionary:
	if not G.rules.progression.feature_unlocked(Data.CARD_LEVEL): return {"error": TextCatalog.source("notice.progressionrules.0cf982b1fe0e")}
	if album < 0 or album >= Data.ALBUMS.size(): return {"error": TextCatalog.source("notice.reducer.131c409c2fcd")}
	var key := "album:%d" % album
	if bool(meta.get(key, false)): return {"error": TextCatalog.source("notice.reducer.583d60e4570b")}
	if G.rules.progression.album_count(album) != Data.ALBUMS[album]["cards"].size(): return {"error": TextCatalog.source("notice.reducer.943f4ff65b4c")}
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
	if not meta.get("allow_gm", false): return {"error": TextCatalog.source("notice.reducer.9fb5160ef90e")}
	var action := str(args.get("action", "unlock"))
	if action == "unlock":
		G.rules.progression.unlock_all_features()
		ActivityRules.initialize()
		return {}
	if action != "card": return {"error": TextCatalog.source("notice.reducer.749653a39991")}
	if not G.rules.progression.feature_unlocked(Data.CARD_LEVEL): return {"error": TextCatalog.source("notice.reducer.0d7677cd4279")}
	var selected_album := int(args.get("album", -1))
	if selected_album < -1 or selected_album >= Data.ALBUMS.size(): return {"error": TextCatalog.source("notice.reducer.131c409c2fcd")}
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
	if pool.is_empty(): return {"error": TextCatalog.source("notice.reducer.ef55cc5b0180")}
	var candidates: Array = missing if not missing.is_empty() else pool
	var rng: RandomNumberGenerator = G.random_for("gm_cards")
	var entry: Array = candidates[int(rng.randi() % candidates.size())]
	var rewards: Array = G.rules.progression.collect_cards([entry])
	if legacy_album_rewards: grant_album_rewards(complete_before)
	return {"cards": [entry], "card_rewards": rewards}

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
