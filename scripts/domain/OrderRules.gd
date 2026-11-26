extends "res://scripts/domain/RuleModule.gd"
## Order generation, material matching, cooking and delivery rules.

func _trim_orders() -> void:
	while state.orders.size() > Data.order_total(state.level):
		var remove = -1
		for i in range(state.orders.size()-1, -1, -1):
			var o: Dictionary = state.orders[i]
			if not o.get("story",false) and str(o.get("phase","need")) not in ["cook","ready"]:
				remove=i
				break
		if remove<0:
			for i in range(state.orders.size()-1,-1,-1):
				if state.orders[i].get("story",false):
					remove=i
					state.pending_orders.push_front(state.orders[i])
					break
		if remove<0: break # Active crafts retain their slots until delivery.
		state.orders.remove_at(remove)

## 还没开始做、但材料现在根本弄不到的做饭单（老存档里可能有）换掉，免得卡着
func _drop_unsourced_crafts() -> void:
	if state.gm_activities: return
	var allowed := sourced_chains()
	if allowed.is_empty(): return
	for i in range(state.orders.size() - 1, -1, -1):
		var o = state.orders[i]
		if not (o is Dictionary) or str(o.get("kind", "")) != "craft" or str(o.get("phase", "need")) != "need":
			continue
		for m in o.get("mats", []):
			if not allowed.has(Data.chain(str(m))):
				state.orders.remove_at(i)
				break

## 新手引导用固定的教学单；引导结束后不再发手配剧情单，全部按当前等级和产线随机出单（含制作单）。
func refill_orders() -> void:
	if state.tutorial_on:
		context.onboarding.refill()
		return
	_trim_orders()
	_drop_unsourced_crafts()
	_ensure_craft_order(false)
	_add_random_batch()
	assign_xp()
	state.dirty()
	state.orders_changed.emit()

## 每张单生成时按档位定好固定经验 xp_value（简单 1、难 2，剧情单按配置），之后不变。
## 每一级只「开放」刚好够升级那么多经验的订单（rw.xp = xp_value，按订单栏从左到右），其余订单经验先关闭；
## 同一级里已开放的保持开放，后补的订单只填剩余额度；升级后全部重新分配，已在场的单优先亮出经验。
## 还差 1 点时优先开放 1 经验的单，找不到才开放 2 经验的单，多出的经验结转到下一级。
## 引导期间的教学单经验是固定的，不参与分配。
func assign_xp() -> void:
	if state.tutorial_on: return
	# A checkpoint from the previous XP table can already be full; keep one
	# starred order so its next delivery settles the carried experience.
	var need: int = maxi(1, context.progression.xp_need() - state.xp)
	var reset: bool = int(context.meta().get("order_xp_level", state.level)) != state.level
	context.meta()["order_xp_level"] = state.level
	var open_rows: Array = []
	for o in state.orders:
		if not (o is Dictionary) or int(o.get("tutorial", 0)) > 0: continue
		order_xp_value(o)
		if reset:
			o["rw"].erase("xp")
			o["xp_level"] = 0
		elif not o.has("xp_level"):
			# Existing saves retain the experience already shown on their cards.
			o["xp_level"] = state.level
		if int(o["xp_level"]) == state.level: need -= int(o["rw"].get("xp", 0))
		else: open_rows.append(o)
	while need > 0 and not open_rows.is_empty():
		var pick: Dictionary = open_rows[0]
		if need == 1:
			for o in open_rows:
				if int(o["xp_value"]) == 1:
					pick = o
					break
		open_rows.erase(pick)
		pick["rw"]["xp"] = int(pick["xp_value"])
		pick["xp_level"] = state.level
		need -= int(pick["xp_value"])
	for o in open_rows:
		o["rw"].erase("xp")
		o["xp_level"] = state.level

## 订单固定的经验值；旧存档里没有的按订单难度补上并写回。
func order_xp_value(o: Dictionary) -> int:
	if not o.has("rw") or not (o["rw"] is Dictionary): o["rw"] = {}
	if o.has("xp_value"): return int(o["xp_value"])
	var value := 1
	if bool(o.get("story", false)):
		var list := Data.story_orders(int(o.get("story_level", state.level)))
		var si := int(o.get("si", -1))
		value = int(list[si].get("xp", 1)) if si >= 0 and si < list.size() else maxi(1, int(o["rw"].get("xp", 1)))
	else:
		var tier := str(o.get("tier", ""))
		if tier == "":
			var items: Array = o.get("mats", o.get("items", []))
			tier = Data.tier_of_value(state.level, context.roll.total(items))
			o["tier"] = tier
		value = Data.tier_xp(tier)
	o["xp_value"] = maxi(1, value)
	return int(o["xp_value"])

func _is_random_order(o: Dictionary) -> bool:
	return not bool(o.get("story", false)) and str(o.get("kind", "")) != "craft"

func _random_left() -> int:
	var n = 0
	for o in state.orders:
		if o is Dictionary and _is_random_order(o):
			n += 1
	return n

func _random_slots_taken() -> Dictionary:
	var taken = {}
	for o in state.orders:
		if o is Dictionary and _is_random_order(o) and o.has("slot"):
			taken[int(o["slot"])] = true
	return taken

func random_cap() -> int:
	return _random_left() + maxi(0, Data.order_total(state.level) - state.orders.size())

func craft_level() -> int:
	return maxi(1, int(Data.RULES.get("craft_level", 3)))

func _slot_target(slot: int) -> int:
	return Data.random_slot_target(state.level, slot)

func _add_random_batch(at: int = -1) -> void:
	var n = random_cap()
	if n == 0:
		return
	var taken = _random_slots_taken()
	var have = _random_left()
	var avoid: Array = []
	for o in state.orders:
		if o is Dictionary and _is_random_order(o) and o.get("items") is Array:
			for id in o["items"]:
				avoid.append(str(id))
	var slot = 0
	while have < n and slot < n:
		if taken.has(slot):
			slot += 1
			continue
		var made: Dictionary
		var tier := ""
		if Data.random_curve_count() <= 0:
			made = _spice(_make_order_free(avoid))
		elif not Data.ORDER_TIERS.is_empty():
			tier = _roll_tier()
			var target := Data.tier_target(state.level, tier, context.random_for("orders"))
			made = _make_order(target, avoid)
			if made.is_empty():
				made = _spice(_make_order_free(avoid))
			made["diff"] = target
		else:
			made = _make_order(_slot_target(slot), avoid)
			if made.is_empty():
				made = _spice(_make_order_free(avoid))
		if tier != "":
			made["tier"] = tier
			made["xp_value"] = Data.tier_xp(tier)
			var coins: int = int(context.roll.shell_of(made.get("items", []))) if Data.ORDER_COINS.has("k") else Data.order_coins(state.level, tier, context.random_for("orders"))
			if coins > 0 and made.get("rw") is Dictionary: made["rw"]["shell"] = coins
		made["slot"] = slot
		if made.get("items") is Array:
			for id in made["items"]:
				avoid.append(str(id))
		_insert_random(made, at)
		at = -1
		taken[slot] = true
		have += 1
		slot += 1

## 新随机单的档位：场上简单单不够 MIN_EASY 张时必出简单单，否则按等级的难单占比抽。
func _roll_tier() -> String:
	var easy := 0
	for o in state.orders:
		if o is Dictionary and _is_random_order(o) and str(o.get("tier", "")) == "easy": easy += 1
	if easy < Data.MIN_EASY: return "easy"
	return "hard" if context.random_for("orders").randf() < Data.hard_share(state.level) else "easy"

func _insert_random(made: Dictionary, at: int) -> void:
	made["xp_level"] = 0
	state.order_identity(made)
	if at >= 0 and at <= state.orders.size():
		state.orders.insert(at, made)
		return
	var slot = int(made.get("slot", 0))
	for i in state.orders.size():
		var o = state.orders[i]
		if o is Dictionary and _is_random_order(o) and int(o.get("slot", 99)) > slot:
			state.orders.insert(i, made)
			return
	var tail = state.orders.size()
	for i in state.orders.size():
		if str(state.orders[i].get("kind", "")) == "craft":
			tail = i
			break
	state.orders.insert(tail, made)

func _ensure_story() -> bool:
	var old = str(state.orders)
	refill_orders()
	return old != str(state.orders)

func _make_order(target: int = -1, avoid: Array = []) -> Dictionary:
	if Data.random_curve_count() <= 0:
		return _spice(_make_order_free(avoid))
	var bounds = Data.random_bounds(state.level)
	var t = target
	if t < 1:
		t = bounds.x if bounds.x >= bounds.y else context.random_for("orders").randi_range(bounds.x, bounds.y)
	var plan := vine_plan()
	var made: Dictionary = context.roll.make(state.level, float(t), context.random_for("orders"), avoid, {} if state.gm_activities else sourced_chains(), plan["keys"], plan["outputs"])
	if made.is_empty():
		made = _make_order_free(avoid)
	made["xp_level"] = 0
	return _spice(made)

func vine_plan() -> Dictionary:
	var keys := {}
	for cell in state.board:
		var id := str(cell.get("id", ""))
		if int(cell.get("lock", 2)) == 1 and Data.type_of(id) == "item" and Data.next_id(id) != "": keys[id] = true
	var outputs := {}
	for id in keys:
		var out := str(id)
		while keys.has(out) and Data.next_id(out) != "": out = Data.next_id(out)
		outputs[out] = true
	return {"keys": keys, "outputs": outputs}

func vine_output(id: String) -> String:
	var keys: Dictionary = vine_plan()["keys"]
	var out := id
	while keys.has(out) and Data.next_id(out) != "": out = Data.next_id(out)
	return out

func _spice(made: Dictionary) -> Dictionary:
	if made.is_empty() or not (made.get("rw") is Dictionary):
		return made
	if context.random_for("orders").randf() < 0.25 and context.progression.feature_unlocked(Data.CARD_LEVEL):
		made["rw"]["pack"] = 1
	if context.random_for("orders").randf() < 0.5:
		made["rw"]["token"] = context.random_for("orders").randi_range(1, 3) * (made.get("items", []) as Array).size()
	return made

func _make_order_free(avoid: Array = []) -> Dictionary:
	var r = context.random_for("orders").randf()
	var n = 1 if state.level < 2 or r < 0.45 else (2 if r < 0.85 else 3)
	var items = []
	var shell = 0
	var top: int = 2 + state.level / 2
	var open = Data.unlocked_lines(state.level)
	var allowed: Dictionary = {} if state.gm_activities else sourced_chains()
	for i in n:
		var placed := false
		for attempt in 8:
			var ln: Dictionary = open[context.random_for("orders").randi() % open.size()]
			var id := ""
			var add := 0
			var subs := Data.secondaries(ln)
			# 只有一种其余产物时不多抽随机数，老存档回放的随机序列保持不变
			var sub := "" if subs.is_empty() else str(subs[0]) if subs.size() == 1 else str(subs[context.random_for("orders").randi() % subs.size()])
			if state.level >= 2 and sub != "" and Data.product_open(state.level, sub) and _sourced(sub, allowed) and context.random_for("orders").randf() < 0.15:
				var sl = context.random_for("orders").randi_range(1, mini(3, 1 + state.level / 3))
				id = "%s_%d" % [sub, sl]
				add = 12 * int(pow(2, sl - 1)) + context.random_for("orders").randi_range(0, 4)
			else:
				var ch: String = Data.primary(ln)
				if not Data.product_open(state.level, ch) or not _sourced(ch, allowed):
					continue
				var l = context.random_for("orders").randi_range(1 if state.level < 2 else 2, mini(top, Data.max_lv(ch)))
				id = "%s_%d" % [ch, l]
				add = 3 * int(pow(2, l - 1)) + context.random_for("orders").randi_range(0, 4)
			if id == "":
				continue
			if (items.has(id) or avoid.has(id)) and attempt < 7:
				continue
			items.append(id)
			shell += add
			placed = true
			break
		if not placed:
			break
	if Data.ORDER_COINS.has("k") and not items.is_empty():
		shell = context.roll.shell_of(items)
	var rw = {"shell": shell}
	var plan := vine_plan()
	for id in items:
		if plan["keys"].has(str(id)):
			var safe: Dictionary = context.roll.make(state.level, context.roll.total(items), context.random_for("orders"), items, allowed, plan["keys"], plan["outputs"])
			if not safe.is_empty(): return safe
			break
	return {"who": context.random_for("orders").randi() % Data.PEOPLE.size(), "items": items, "rw": rw, "story": false, "xp_level": 0}

func _craft_count() -> int:
	var n = 0
	for o in state.orders:
		if str(o.get("kind", "")) == "craft":
			n += 1
	return n

## 玩家眼下真能弄到的物品链：手里（棋盘上没被封住的格子、暂存区、仓库）的生产器现在能掉出来的链。
## 订单只要这些链上的东西：小草篓还没升到会掉种子的等级时，就不会出要种子的单。GM 全开时不限制。
func sourced_chains() -> Dictionary:
	var out := {}
	var ids: Array = []
	for c in state.board:
		if int(c.get("lock", 0)) == 0: ids.append(str(c.get("id", "")))
	ids.append_array(state.stash)
	ids.append_array(state.inv)
	for id in ids:
		var sid := str(id)
		if sid == "" or not Data.is_known(sid) or Data.type_of(sid) != "gen":
			continue
		for d in Data.gen_stats(sid).get("drops", []):
			out[Data.chain(str(d["id"]))] = true
	return out

func _sourced(chain_id: String, allowed: Dictionary) -> bool:
	return allowed.is_empty() or allowed.has(chain_id)

func _pick_dish(avoid: Array = []) -> Dictionary:
	var pool: Array = []
	var allowed: Dictionary = {} if state.gm_activities else sourced_chains()
	for d in (Data.DISHES.values() if state.gm_activities else Data.dishes_for(state.level)):
		if not state.gm_activities and int(d.get("order_max_level", 0)) > 0 and state.level > int(d["order_max_level"]): continue
		if str(d["id"]) in avoid:
			continue
		var ok := true
		for m in d["mats"]:
			if not _sourced(Data.chain(str(m)), allowed): ok = false
		if ok:
			pool.append(d)
	if pool.is_empty():
		return {}
	for d in pool:
		if not state.discovered.has(str(d["id"])):
			return d
	var recent = pool.slice(maxi(0, pool.size() - 8))
	return recent[context.random_for("orders").randi() % recent.size()]

func _craft_order(d: Dictionary) -> Dictionary:
	if d.is_empty():
		return {}
	var mats: Array = (d["mats"] as Array).duplicate()
	var shell = 4
	for id in mats:
		shell += 4 * int(pow(2.0, float(Data.lv(str(id)) - 1)))
	var coins: int = int(context.roll.shell_of(mats)) if Data.ORDER_COINS.has("k") else Data.order_coins(state.level, "craft", context.random_for("orders"))
	if coins > 0: shell = coins
	var rw = {"shell": shell}
	if context.random_for("orders").randf() < 0.4:
		rw["token"] = context.random_for("orders").randi_range(1, 3)
	var secs := Data.craft_secs(state.level, str(d["id"]))
	var units := Data.craft_sand_units(state.level, secs)
	if units > 0: rw["sand"] = units
	else:
		var sand = Data.craft_sand(str(d["id"]), secs)
		if sand != "": rw["rewards"] = [sand]
	return {
		"who": context.random_for("orders").randi() % Data.PEOPLE.size(),
		"kind": "craft",
		"xp_level": 0,
		"tier": Data.tier_of_value(state.level, context.roll.total(mats)),
		"dish": str(d["id"]),
		"mats": mats,
		"items": mats.duplicate(),
		"secs": secs,
		"rw": rw,
		"story": false,
		"phase": "need",
		"cell": -1,
		"t0": 0.0,
		"uid": state.next_order_uid(),
	}

func _ensure_craft_order(replace: bool, avoid: String = "") -> void:
	if not context.progression.feature_unlocked(craft_level()):
		return
	while _craft_count() < maxi(Data.craft_cap(state.level), 1 if state.gm_activities else 0) and state.orders.size() < Data.order_total(state.level):
		var skip: Array = [avoid] if avoid != "" else []
		for o in state.orders:
			if str(o.get("kind", "")) == "craft":
				skip.append(str(o.get("dish", "")))
		var made = _craft_order(_pick_dish(skip))
		if made.is_empty():
			return
		if replace:
			replace = false
			for i in range(state.orders.size() - 1, -1, -1):
				if not bool(state.orders[i].get("story", false)) and str(state.orders[i].get("kind", "")) != "craft":
					state.orders[i] = made
					state.dirty()
					return
		state.orders.append(made)
		state.dirty()

func _add_story_orders(skip: Array = [], after: int = -1) -> void:
	var at = 0
	for o in state.orders:
		if o["story"]:
			at += 1
	## 只和场上的剧情单比重复；和随机单撞了也照发，不然这一级的声望会不够
	var listed: Array = state.orders.filter(func(o): return o is Dictionary and bool(o.get("story", false)))
	var protected = 0
	for o in state.orders:
		if str(o.get("kind", "")) == "craft" and str(o.get("phase", "need")) in ["cook", "ready"]: protected += 1
	var room = maxi(0, Data.order_total(state.level) - listed.size() - protected)
	while room > 0 and not state.pending_orders.is_empty():
		var row: Dictionary = state.pending_orders.pop_front()
		state.orders.insert(at, row)
		listed.append(row)
		at += 1
		room -= 1
	var list = Data.story_orders(state.level)
	for si in list.size():
		if room <= 0:
			break
		if si <= after or state.story_done.has("%d:%d" % [state.level, si]):
			continue
		var s: Dictionary = list[si]
		var items: Array = s["items"]
		if _story_listed(items, skip) or _story_listed(items, listed):
			continue
		room -= 1
		var rw = {"xp": int(s["xp"]), "shell": int(s["shell"])}
		if s.has("token"):
			rw["token"] = int(s["token"])
		if s.get("rewards") is Array and not (s["rewards"] as Array).is_empty():
			rw["rewards"] = (s["rewards"] as Array).duplicate()
		elif int(s.get("pack", 0)) > 0:
			var packs: Array = []
			for _i in int(s["pack"]):
				packs.append("pack_1")
			rw["rewards"] = packs
		var row = {"who": int(s["who"]), "items": items.duplicate(), "rw": rw, "story": true, "si": si, "story_level": state.level, "xp_level": 0, "xp_value": maxi(1, int(s["xp"]))}
		state.order_identity(row)
		if str(s.get("say", "")) != "":
			row["say"] = str(s["say"])
		state.orders.insert(at, row)
		at += 1
	_trim_orders()

func _story_listed(items: Array, rows: Array) -> bool:
	for row in rows:
		var got: Array = row["items"] if row is Dictionary else row
		if got.size() != items.size():
			continue
		var same = true
		for i in items.size():
			if str(got[i]) != str(items[i]):
				same = false
				break
		if same:
			return true
	return false

func board_has(id: String, exclude: Array = []) -> int:
	for k in state.board.size():
		if state.board[k]["id"] == id and state.board[k]["lock"] == 0 and not (k in exclude):
			return k
	return -1

func inv_has(id: String, exclude: Array = []) -> int:
	for k in state.inv.size():
		if str(state.inv[k]) == id and not (k in exclude):
			return k
	return -1

## 棋盘空闲格优先，不够再算储物洞。命中后把位置记进对应的已用列表。
func claim_supply(id: String, boards: Array, slots: Array) -> Dictionary:
	var cell := board_has(id, boards)
	if cell >= 0:
		boards.append(cell)
		return {"board": cell}
	var slot := inv_has(id, slots)
	if slot >= 0:
		slots.append(slot)
		return {"inv": slot}
	return {}

func _match_sources(ids: Array) -> Array:
	var boards: Array = []
	var slots: Array = []
	var out: Array = []
	for id in ids:
		var got := claim_supply(str(id), boards, slots)
		if got.is_empty():
			return []
		out.append(got)
	return out

func _board_of(sources: Array) -> Array:
	var cells: Array = []
	for source in sources:
		if source.has("board"):
			cells.append(int(source["board"]))
	return cells

func _vacant_cell() -> int:
	for i in state.board.size():
		if context.board._vacant(i):
			return i
	return -1

func order_cells(o: Dictionary) -> Array:
	if str(o.get("kind", "")) == "craft" and str(o.get("phase", "need")) == "cook":
		return []
	return _board_of(_match_sources(_order_need_ids(o)))

func order_ready(o: Dictionary) -> bool:
	if str(o.get("kind", "")) == "craft":
		return str(o.get("phase", "")) == "ready" and not _match_sources(_order_need_ids(o)).is_empty()
	var items: Array = o["items"]
	return _match_sources(items).size() == items.size()

## 棋盘上该格是否为带经验的制作订单已完成的产物
func cell_has_craft_xp(i: int) -> bool:
	if i < 0 or i >= state.board.size():
		return false
	var c: Dictionary = state.board[i]
	var ck = c.get("ck")
	if typeof(ck) == TYPE_DICTIONARY:
		var uid := str(ck.get("uid", ""))
		for o in state.orders:
			if not (o is Dictionary) or str(o.get("kind", "")) != "craft" or str(o.get("uid", "")) != uid:
				continue
			var rw = o.get("rw")
			if rw is Dictionary and int(rw.get("xp", 0)) > 0:
				return true
		return false
	if int(c.get("lock", 2)) != 0 or str(c.get("id", "")) == "":
		return false
	for o in state.orders:
		if not (o is Dictionary) or str(o.get("kind", "")) != "craft":
			continue
		if str(o.get("phase", "")) != "ready":
			continue
		var rw = o.get("rw")
		if not (rw is Dictionary) or int(rw.get("xp", 0)) <= 0:
			continue
		if i in order_cells(o):
			return true
	return false

func craft_mats_ready(o: Dictionary) -> bool:
	if str(o.get("kind", "")) != "craft" or str(o.get("phase", "need")) != "need":
		return false
	var mats: Array = o.get("mats", [])
	var sources := _match_sources(mats)
	if mats.is_empty() or sources.size() != mats.size():
		return false
	return not _board_of(sources).is_empty() or _vacant_cell() >= 0

func wanted_ids() -> Dictionary:
	var d = {}
	for o in state.orders:
		if str(o.get("kind", "")) == "craft":
			var phase = str(o.get("phase", "need"))
			if phase == "ready":
				d[str(o.get("dish", ""))] = true
			elif phase == "need":
				for id in o.get("mats", []):
					d[str(id)] = true
			continue
		for id in o["items"]:
			d[id] = true
	return d

## 升级时的「订单宝箱」：当前订单还缺、棋盘、暂存区和储物洞里都没有的物品，按订单顺序最多 cap 件。
## 菜品要靠制作，不直接送；制作单送的是还缺的材料。
func missing_order_items(cap: int = 3) -> Array:
	var have = {}
	for c in state.board:
		if int(c.get("lock", 2)) == 0 and str(c.get("id", "")) != "":
			have[str(c["id"])] = int(have.get(str(c["id"]), 0)) + 1
	for s in state.stash:
		have[str(s)] = int(have.get(str(s), 0)) + 1
	for s in state.inv:
		have[str(s)] = int(have.get(str(s), 0)) + 1
	var out: Array = []
	for o in state.orders:
		var ids: Array = []
		if str(o.get("kind", "")) == "craft":
			if str(o.get("phase", "need")) == "need": ids = o.get("mats", [])
		else:
			ids = o.get("items", [])
		for raw in ids:
			var id = str(raw)
			if int(have.get(id, 0)) > 0:
				have[id] = int(have[id]) - 1
				continue
			if Data.is_dish(id) or not Data.is_board_item(id) or Data.type_of(id) != "item": continue
			out.append(id)
			if out.size() >= cap: return out
	return out

## 好运爆发用：没有一张能马上交，且每张都还缺一件比手头同链（不超过要的那级）最高的高 gap 级以上的物品。
## 制作中的单不算；手上一张单都没有也不算。
func all_orders_hard(gap: int) -> bool:
	var owned := {}
	var note := func(raw) -> void:
		var id := str(raw)
		if id == "" or Data.is_dish(id) or not Data.is_board_item(id):
			return
		var ch := Data.chain(id)
		if not owned.has(ch):
			owned[ch] = []
		owned[ch].append(Data.lv(id))
	for c in state.board:
		if int(c.get("lock", 2)) == 0:
			note.call(c.get("id", ""))
	for s in state.inv:
		note.call(s)
	for s in state.stash:
		note.call(s)
	var counted := 0
	for o in state.orders:
		if not (o is Dictionary):
			continue
		if str(o.get("kind", "")) == "craft" and str(o.get("phase", "need")) == "cook":
			continue
		if _order_filled(o):
			return false
		counted += 1
		var hard := false
		for raw in _order_need_ids(o):
			var id := str(raw)
			if Data.is_dish(id) or not Data.is_board_item(id) or Data.type_of(id) != "item":
				continue
			var best := 0
			for l in owned.get(Data.chain(id), []):
				if int(l) <= Data.lv(id):
					best = maxi(best, int(l))
			if Data.lv(id) - best >= gap:
				hard = true
				break
		if not hard:
			return false
	return counted > 0

func order_cell_tone() -> PackedInt32Array:
	var tone = PackedInt32Array()
	tone.resize(state.board.size())
	var claimed: Array = []
	for o in state.orders:
		if not _order_filled(o):
			continue
		for k in order_cells(o):
			var i = int(k)
			if i < 0 or i >= tone.size():
				continue
			tone[i] = 2
			if not (i in claimed):
				claimed.append(i)
	for o in state.orders:
		if _order_filled(o):
			continue
		for k in _take_partial(o, claimed):
			tone[int(k)] = 1
	return tone

func _order_filled(o: Dictionary) -> bool:
	if str(o.get("kind", "")) == "craft":
		var phase = str(o.get("phase", "need"))
		if phase == "cook":
			return false
		if phase == "ready":
			return order_ready(o)
		return craft_mats_ready(o)
	return order_ready(o)

func _order_need_ids(o: Dictionary) -> Array:
	if str(o.get("kind", "")) == "craft":
		var phase = str(o.get("phase", "need"))
		if phase == "need":
			return o.get("mats", [])
		if phase == "ready":
			var dish = str(o.get("dish", ""))
			return [dish] if dish != "" else []
		return []
	var items = o.get("items", [])
	return items if items is Array else []

func _take_partial(o: Dictionary, claimed: Array) -> Array:
	var got: Array = []
	for id in _order_need_ids(o):
		var sid = str(id)
		if sid == "":
			continue
		var k = board_has(sid, claimed)
		if k < 0:
			continue
		claimed.append(k)
		got.append(k)
	return got

func cooking(i: int) -> bool:
	return i >= 0 and i < state.board.size() and typeof(state.board[i].get("ck")) == TYPE_DICTIONARY

func cook_left(i: int) -> int:
	if not cooking(i):
		return 0
	var ck: Dictionary = state.board[i]["ck"]
	var left = float(ck["t0"]) + float(ck["secs"]) - context.now()
	return maxi(0, int(ceil(left)))

func rush_cook(i: int) -> int:
	if not cooking(i) or state.rush < 1:
		return 0
	var n = mini(state.rush, rush_need(i))
	state.rush -= n
	var ck: Dictionary = state.board[i]["ck"]
	ck["t0"] = float(ck["t0"]) - float(n * Data.rush_sec())
	var uid = str(ck.get("uid", ""))
	for o in state.orders:
		if str(o.get("kind", "")) == "craft" and str(o.get("uid", "")) == uid:
			o["t0"] = float(ck["t0"])
	_tick_cooks()
	state.dirty()
	state.changed.emit()
	state.board_changed.emit()
	return n

func rush_need(i: int) -> int:
	return maxi(1, int(ceil(float(cook_left(i)) / float(Data.rush_sec()))))

func _gather_anchor(cells: Array) -> int:
	var sx = 0.0
	var sy = 0.0
	for k in cells:
		sx += float(int(k) % state.COLS)
		sy += float(int(k) / state.COLS)
	sx /= float(cells.size())
	sy /= float(cells.size())
	var best: int = int(cells[0])
	var bd = 1e9
	for k in cells:
		var d = Vector2(int(k) % state.COLS, int(k) / state.COLS).distance_squared_to(Vector2(sx, sy))
		if d < bd:
			bd = d
			best = int(k)
	return best

func begin_craft(oi: int) -> Array:
	_sync_craft_times()
	if oi < 0 or oi >= state.orders.size():
		return []
	var o: Dictionary = state.orders[oi]
	if not craft_mats_ready(o):
		return []
	var sources := _match_sources(o.get("mats", []))
	var cells := _board_of(sources)
	var anchor := _gather_anchor(cells) if not cells.is_empty() else _vacant_cell()
	if anchor < 0:
		return []
	var flights = []
	var mats: Array = []
	var slots: Array = []
	for source in sources:
		if source.has("inv"):
			slots.append(int(source["inv"]))
	slots.sort()
	var stored := {}
	for n in range(slots.size() - 1, -1, -1):
		stored[slots[n]] = context.board.remove_inventory(slots[n])
	for source in sources:
		if source.has("board"):
			var k := int(source["board"])
			var id := str(state.board[k]["id"])
			mats.append(id)
			flights.append({"from": k, "to": anchor, "id": id, "delay": float(flights.size()) * 0.05})
			state.board[k]["id"] = ""
			state.board[k].erase("gm")
			state.board[k].erase("ck")
		else:
			mats.append(str(stored[int(source["inv"])]))
	if flights.is_empty():
		flights.append({"to": anchor})
	var fly = 0.36 + 0.05 * float(maxi(cells.size() - 1, 0))
	var t0 = context.now() + fly
	state.board[anchor]["ck"] = {
		"dish": str(o["dish"]),
		"t0": t0,
		"secs": int(o["secs"]),
		"uid": str(o["uid"]),
		"mats": mats,
	}
	o["phase"] = "cook"
	o["cell"] = anchor
	o["t0"] = t0
	state.dirty()
	state.board_changed.emit()
	state.orders_changed.emit()
	return flights

func _sync_craft_times() -> void:
	var changed := false
	for collection in [state.orders, state.pending_orders]:
		for o in collection:
			if not o is Dictionary or str(o.get("kind", "")) != "craft": continue
			var id := str(o.get("dish", "")).trim_prefix("dish_")
			if not Data.DISHES.has(id): continue
			var target := Data.craft_secs(state.level, id)
			var phase := str(o.get("phase", "need"))
			if phase == "need":
				if not o.has("secs") or int(o["secs"]) > target:
					o["secs"] = target
					changed = true
			elif phase == "cook":
				var cell := int(o.get("cell", -1))
				if cell < 0 or cell >= state.board.size(): continue
				var ck: Variant = state.board[cell].get("ck")
				if not ck is Dictionary or str(ck.get("uid", "")) != str(o.get("uid", "")) or bool(ck.get("finished", false)): continue
				# Preserve the original start and any acceleration already applied.
				target = mini(target, mini(int(o.get("secs", target)), int(ck.get("secs", target))))
				if int(o.get("secs", target)) > target or int(ck.get("secs", target)) > target:
					o["secs"] = target
					ck["secs"] = target
					changed = true
	if changed:
		state.dirty()
		state.orders_changed.emit()

func _tick_cooks() -> void:
	_sync_craft_times()
	if state.board.is_empty():
		return
	var done: Array = []
	for i in state.board.size():
		var ck = state.board[i].get("ck")
		if typeof(ck) != TYPE_DICTIONARY:
			continue
		if context.now() < float(ck["t0"]) + float(ck["secs"]):
			continue
		done.append(i)
	if done.is_empty():
		return
	for slot in done:
		var at = int(slot)
		var ck: Dictionary = state.board[at]["ck"]
		if bool(ck.get("finished", false)): continue
		var manual := false
		for o in state.orders:
			if str(o.get("uid", "")) == str(ck.get("uid", "")) and bool(o.get("manual_collect", false)):
				o["phase"] = "finished"
				manual = true
		if manual:
			ck["finished"] = true
			continue
		var dish = str(ck["dish"])
		var uid = str(ck.get("uid", ""))
		state.board[at]["id"] = dish
		state.board[at].erase("ck")
		context.board.discover(dish)
		for o in state.orders:
			if str(o.get("kind", "")) == "craft" and str(o.get("uid", "")) == uid:
				o["phase"] = "ready"
				o["cell"] = at
		state.cooked_pop.append(at)
	state.dirty()
	state.board_changed.emit()
	state.orders_changed.emit()
	state.present("craft_complete", {"cells": done.duplicate()})

func complete_order(oi: int, refill_after: bool = true) -> Array:
	var o: Dictionary = state.orders[oi]
	var craft = str(o.get("kind", "")) == "craft"
	if craft and str(o.get("phase", "")) != "ready":
		return []
	var need: Array = _order_need_ids(o)
	var sources := _match_sources(need)
	if sources.size() != need.size():
		return []
	var cells := _board_of(sources)
	state.order_delivered.emit((o["items"] as Array).duplicate())
	var slots: Array = []
	for source in sources:
		if source.has("inv"):
			slots.append(int(source["inv"]))
	for k in cells:
		state.board[k]["id"] = ""
		state.board[k].erase("ck")
	slots.sort()
	for n in range(slots.size() - 1, -1, -1):
		context.board.remove_inventory(slots[n])
	if o.get("story",false) and o.has("si"):
		state.story_done["%d:%d" % [int(o.get("story_level",state.level)),int(o["si"])]] = true
	context.onboarding.delivered(o)
	state.orders.remove_at(oi)
	# The delivered card must not take a slot in the new level's XP allocation.
	context.on_order(o)
	if not state.tutorial_on and refill_after: refill_orders()
	context.clock.check_pass_season()
	var pass_gain := Data.order_pass_points(o)
	state.pass_pts += pass_gain + (1 if state.pass_tier >= 2 else 0)  # 大长老：每单额外 +1 笑脸
	state.dirty()
	state.board_changed.emit()
	state.orders_changed.emit()
	state.changed.emit()
	return cells


## Completed tutorial dishes stay on their equipment until the player takes them.
func collect_craft(i: int) -> Dictionary:
	if not cooking(i) or cook_left(i) > 0: return {"error": TextCatalog.source("notice.orderrules.301a6df8b1ab")}
	var ck: Dictionary = state.board[i]["ck"]
	var dish := str(ck["dish"])
	for o in state.orders:
		if str(o.get("uid", "")) == str(ck.get("uid", "")): o["phase"] = "ready"
	state.board[i]["id"] = dish
	state.board[i].erase("ck")
	context.board.discover(dish)
	state.board_changed.emit()
	state.orders_changed.emit()
	return {"kind": "dish", "id": dish, "to": i}
