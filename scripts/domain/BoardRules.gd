extends "res://scripts/domain/RuleModule.gd"
## Grid, inventory, generators, bubbles, item tools and physical loot rules.

func _init_board() -> void:
	state.board = []
	for i in state.COLS * state.ROWS:
		state.board.append({"id": "", "lock": 0})
	var cells: Array = Data.BOARD
	for row in state.ROWS:
		for col in state.COLS:
			var at = idx(col, row)
			var n = row * state.COLS + col
			var id = str(cells[n]) if n < cells.size() else ""
			if Data.is_board_item(id):
				state.board[at]["id"] = id
			state.board[at]["lock"] = context.layout.lock_of(Data.LOCKS, n, col, row, state.COLS, state.ROWS)
			var rw = context.layout.reward_of(Data.REWARDS, n)
			if not rw.is_empty():
				state.board[at]["rw"] = rw
	for k in state.board:
		if k["id"] != "" and k["lock"] == 0:
			discover(k["id"])

func is_merge_bubble(i: int) -> bool:
	return i >= 0 and i < state.board.size() and int(state.board[i].get("lock", 0)) == 3 and state.board[i].get("bubble") is Dictionary

func bubble_left(i: int) -> int:
	return maxi(0, int(ceil(float(state.board[i]["bubble"].get("expires", 0)) - context.now()))) if is_merge_bubble(i) else 0

func _maybe_spawn_bubble(id: String, near: int) -> void:
	# 引导固定了每一步用到的格子，完成后才开始出现随机额外物品。只有高级普通物品才有（Data.bubble_ok）。
	if state.tutorial_on or not Data.bubble_ok(id) or find_empty_near(near) < 0:
		return
	var offer: Dictionary
	var rule = Data.bubble_rule()
	if context.random_for("bubbles").randf() >= float(rule.get("chance", 0.1)):
		return
	offer = {"uid": "%s-%s" % [int(context.now()), context.random_for("bubbles").randi()], "item": id,
		"expires": context.now() + float(rule.get("seconds", 60)), "price": Data.bubble_price(id)}
	if state.tutorial_on or offer.is_empty() or float(offer.get("expires", 0)) <= context.now():
		return
	var at = find_empty_near(near)
	if at < 0:
		return
	state.board[at] = {"id": id, "lock": 3, "bubble": offer}
	state.dirty()
	state.board_changed.emit()
	state.present("board_spawn", {"origin": near, "to": at, "id": id})

func _tick_bubbles() -> void:
	var expired = false
	for i in state.board.size():
		if not is_merge_bubble(i):
			continue
		if bubble_left(i) == 0 and not state._bubble_busy.has(str(state.board[i]["bubble"].get("uid", ""))):
			state.board[i] = {"id": "shell_3", "lock": 0}
			discover("shell_3")
			expired = true
	if expired:
		state.dirty()
		state.board_changed.emit()

func buy_bubble(i: int) -> Dictionary:
	if not is_merge_bubble(i) or bubble_left(i) <= 0:
		_tick_bubbles()
		return {"ok": false, "message": "泡泡已经消失了"}
	var offer: Dictionary = state.board[i]["bubble"]
	var uid = str(offer.get("uid", ""))
	if state._bubble_busy.has(uid):
		return {"ok": false, "message": "正在购买"}
	state._bubble_busy[uid] = true
	var result: Dictionary
	result = {"ok": context.progression.spend("amber", int(offer.get("price", Data.bubble_price(str(state.board[i]["id"]))))), "message": "琥珀不够了！"}
	state._bubble_busy.erase(uid)
	if result.get("ok", false):
		state.board[i]["lock"] = 0
		state.board[i].erase("bubble")
		discover(str(state.board[i]["id"]))
		state.dirty()
		state.board_changed.emit()
		state.changed.emit()
	else:
		_tick_bubbles()
	return result

func stash_push(id: String) -> void:
	if Data.is_numeric_resource(id):
		context.settle([[id, 1]])
		return
	state.stash.append(id)
	state.dirty()
	state.changed.emit()

func stash_claim_index() -> int:
	for i in range(state.stash.size() - 1, -1, -1):
		if context.progression.feature_unlocked(Data.CARD_LEVEL) or Data.type_of(str(state.stash[i])) != "pack":
			return i
	return -1

func idx(c: int, r: int) -> int:
	return r * state.COLS + c

func cell_id(i: int) -> String:
	return state.board[i]["id"]

func is_free(i: int) -> bool:
	return state.board[i]["lock"] == 0

func _vacant(i: int) -> bool:
	var c: Dictionary = state.board[i]
	return c["id"] == "" and int(c["lock"]) == 0 and typeof(c.get("ck")) != TYPE_DICTIONARY

func empty_count() -> int:
	var n = 0
	for i in state.board.size():
		if _vacant(i):
			n += 1
	return n

func find_empty_near(i: int) -> int:
	return MergeGrid.nearest_empty(state.board, state.COLS, i)

func place(i: int, id: String) -> void:
	if Data.is_numeric_resource(id):
		context.settle([[id, 1]])
		return
	state.board[i]["id"] = id
	discover(id)
	state.dirty()

func book_prize(id: String) -> bool:
	return id != "" and state.discovered.has(id) and not state.book_claimed.has(id)

func book_prize_count() -> int:
	var n = 0
	for line in Data.LINES:
		for key in ["gen", "main", "sub"]:
			var ch = str(line[key])
			if not Data.CHAINS.has(ch):
				continue
			var items: Array = Data.CHAINS[ch]["items"]
			for i in items.size():
				if book_prize("%s_%d" % [ch, i + 1]):
					n += 1
	for id in Data.DISHES:
		if book_prize(str(id)):
			n += 1
	return n

func claim_book(id: String) -> int:
	if not book_prize(id):
		return 0
	state.book_claimed[id] = true
	state.dirty()
	state.changed.emit()
	return maxi(1, Data.lv(id))

func discover(id: String) -> bool:
	if Data.is_numeric_resource(id): return false
	if id == "" or state.discovered.has(id):
		return false
	if Data.is_dish(id):
		state.discovered[id] = true
		return true
	var ch = Data.chain(id)
	for l in range(1, Data.lv(id) + 1):
		state.discovered["%s_%d" % [ch, l]] = true
	return true

func unlock_around(i: int) -> Array:
	return MergeGrid.reveal_neighbors(state.board, i, state.COLS)

func try_drop(a: int, b: int) -> String:
	state.opened = []
	if a < 0 or b < 0 or a >= state.board.size() or b >= state.board.size() or a == b: return ""
	if state._chest_busy.has(a) or state._chest_busy.has(b): return ""
	if Data.type_of(cell_id(a)) in ["upgrade", "scissors"] and cell_id(b) != "":
		return _use_item_tool(a, b)
	if is_merge_bubble(a) or is_merge_bubble(b): return _drop_bubble(a, b)
	if context.orders.cooking(a) or context.orders.cooking(b): return _drop_cook(a, b)
	var result = MergeGrid.drop_kind(state.board, a, b, Data.next_id)
	if result == "": return ""
	if result != "merge": _swap_item_state(a, b)
	MergeGrid.apply_drop(state.board, a, b, result, Data.next_id)
	if result == "merge":
		context.record("merges", 1)
		var nx = str(state.board[b]["id"])
		state.board[a].erase("gm")
		state.board[b].erase("gm")
		discover(nx)
		state.opened = unlock_around(b)
		_maybe_spawn_bubble(nx, b)
		_merge_coin(nx, b)
	state.dirty()
	state.board_changed.emit()
	return result

func tool_drop_kind(a: int, b: int) -> String:
	if a < 0 or b < 0 or a >= state.board.size() or b >= state.board.size() or a == b: return ""
	if not is_free(a) or not is_free(b) or context.orders.cooking(a) or context.orders.cooking(b) or state._chest_busy.has(b): return ""
	var target = cell_id(b)
	if not Data.is_board_item(target) or state.board[b].has("chest"): return ""
	var kind = Data.type_of(cell_id(a))
	if kind == "upgrade" and Data.next_id(target) != "": return "upgrade"
	if kind == "scissors" and not Data.is_dish(target) and Data.lv(target) > 1: return "split"
	return ""

func _use_item_tool(a: int, b: int) -> String:
	var action = tool_drop_kind(a, b)
	if action == "": return ""
	var target = cell_id(b)
	state.board[a]["id"] = ""
	state.board[a].erase("gm")
	state.board[b].erase("gm")
	if action == "upgrade":
		state.board[b]["id"] = Data.next_id(target)
	else:
		var lower = "%s_%d" % [Data.chain(target), Data.lv(target) - 1]
		state.board[a]["id"] = lower
		state.board[b]["id"] = lower
	discover(cell_id(b))
	state.dirty()
	state.board_changed.emit()
	return action

func _drop_cook(a: int, b: int) -> String:
	if int(state.board[a]["lock"]) != 0 or int(state.board[b]["lock"]) != 0:
		return ""
	if not context.orders.cooking(a) and str(state.board[a]["id"]) == "":
		return ""
	var onto_empty = str(state.board[b]["id"]) == "" and not context.orders.cooking(b)
	var ida: String = state.board[a]["id"]
	var idb: String = state.board[b]["id"]
	var cka = state.board[a].get("ck")
	var ckb = state.board[b].get("ck")
	state.board[a]["id"] = idb
	state.board[b]["id"] = ida
	if typeof(cka) == TYPE_DICTIONARY:
		state.board[b]["ck"] = cka
	else:
		state.board[b].erase("ck")
	if typeof(ckb) == TYPE_DICTIONARY:
		state.board[a]["ck"] = ckb
	else:
		state.board[a].erase("ck")
	_swap_item_state(a, b)
	_sync_cook_cells()
	state.dirty()
	state.board_changed.emit()
	return "move" if onto_empty else "swap"

func _sync_cook_cells() -> void:
	var at = {}
	for i in state.board.size():
		var ck = state.board[i].get("ck")
		if typeof(ck) == TYPE_DICTIONARY:
			at[str(ck.get("uid", ""))] = i
	for o in state.orders:
		if str(o.get("kind", "")) != "craft" or str(o.get("phase", "")) != "cook":
			continue
		var uid = str(o.get("uid", ""))
		if at.has(uid):
			o["cell"] = int(at[uid])

func _swap_item_state(a: int, b: int) -> void:
	for key in ["gm", "chest"]:
		var va = state.board[a].get(key)
		var vb = state.board[b].get(key)
		state.board[a].erase(key)
		state.board[b].erase(key)
		if va != null: state.board[b][key] = va
		if vb != null: state.board[a][key] = vb

func gen_left(i: int) -> int:
	var id: String = state.board[i]["id"]
	var st = Data.gen_stats(id)
	if not st.has("charges"):
		return -1
	var cap: int = st["charges"]
	var gm = state.board[i].get("gm")
	if typeof(gm) != TYPE_DICTIONARY or str(gm.get("g", "")) != id:
		return cap
	var used = int(gm["u"])
	if used >= cap and context.now() - float(gm["t"]) >= float(st["refill"]) * 60.0:
		state.board[i].erase("gm")
		return cap
	return maxi(cap - used, 0)

func gen_wait(i: int) -> int:
	if gen_left(i) != 0:
		return 0
	var st = Data.gen_stats(state.board[i]["id"])
	return maxi(1, int(float(st["refill"]) * 60.0 - (context.now() - float(state.board[i]["gm"]["t"]))))

func boost_on() -> bool:
	return state.boost and boost_open()

func boost_open() -> bool:
	return state.boost_gm or context.progression.feature_unlocked(Data.BOOST_LEVEL)

func gen_cost() -> int:
	return 2 if boost_on() else 1

func set_boost(on: bool) -> void:
	state.boost = on and boost_open()
	state.dirty()
	state.changed.emit()
	state.board_changed.emit()

func boost_drop(id: String) -> String:
	if not boost_on() or Data.is_dish(id):
		return id
	var nxt = Data.next_id(id)
	return nxt if nxt != "" else id

func gen_use(i: int) -> void:
	var left = gen_left(i)
	if left < 0:
		return
	var id: String = state.board[i]["id"]
	state.board[i]["gm"] = {"g": id, "u": int(Data.gen_stats(id)["charges"]) - left + 1, "t": context.now()}
	state.dirty()

func _pick(dist: Array) -> int:
	var r = context.random_for("orders").randf() * 100.0
	for k in dist.size():
		r -= float(dist[k])
		if r < 0.0:
			return k
	return dist.size() - 1

func roll_produce(gen_id: String) -> String:
	var st = Data.gen_stats(gen_id)
	var drops: Array = st["drops"]
	var total = 0.0
	for d in drops:
		total += float(d["p"])
	var r = context.random_for("energy_produce" if Data.type_of(gen_id) == "egen" else "produce:" + gen_id).randf() * total
	for d in drops:
		r -= float(d["p"])
		if r < 0.0:
			return str(d["id"])
	return str(drops.back()["id"])

func open_chest(box_id: String = "chest_1") -> Array:
	return SpecialChests.contents(box_id, state)

func dispense_chest(i: int) -> Dictionary:
	if i < 0 or i >= state.board.size() or not is_free(i) or Data.type_of(cell_id(i)) != "chest":
		return {"error": "宝箱已不在原位置"}
	if state._chest_busy.has(i): return {"error": "宝箱正在打开"}
	var id = cell_id(i)
	if SpecialChests.is_order(id) and SpecialChests.needs(state).is_empty(): return {"error": "当前订单已备齐，完成订单后再开启"}
	var items: Array = state.board[i].get("chest", [])
	if items.is_empty():
		if find_empty_near(i) < 0: return {"error": "棋盘满了，先腾出一个空格"}
		state._chest_busy[i] = true
		items = open_chest(id)
		state._chest_busy.erase(i)
		if items.is_empty(): return {"error": "宝箱暂时无法打开"}
		if cell_id(i) != id or not is_free(i): return {"error": "宝箱已不在原位置"}
		state.board[i]["chest"] = items.duplicate()
		items = state.board[i]["chest"]
	var to = i if items.size() == 1 else find_empty_near(i)
	if to < 0:
		state.dirty()
		return {"error": "棋盘满了，先腾出一个空格"}
	var out = SpecialChests.order_drop(id, state) if str(items[0]) == SpecialChests.ORDER_SLOT else str(items[0])
	if out == "": return {"error": "当前订单没有缺少的物品"}
	items.pop_front()
	if items.is_empty():
		state.board[i]["id"] = ""
		state.board[i].erase("chest")
	state.board[to]["id"] = out
	discover(out)
	state.dirty()
	state.board_changed.emit()
	return {"kind": "chest", "id": out, "to": to, "remaining": items.size()}

func store_cell(i: int) -> bool:
	if i < 0 or i >= state.board.size() or not is_free(i) or not can_move(i) or context.orders.cooking(i) or state.inv.size() >= state.inv_cap or Data.is_dish(cell_id(i)) or Data.type_of(cell_id(i)) == "egen": return false
	var slot = str(state.inv.size())
	state.inv_chests.erase(slot)
	if state.board[i].has("chest"): state.inv_chests[slot] = state.board[i]["chest"].duplicate()
	state.inv.append(cell_id(i))
	state.board[i]["id"] = ""
	state.board[i].erase("chest")
	return true

func take_inventory(index: int, to: int) -> bool:
	if index < 0 or index >= state.inv.size() or to < 0 or to >= state.board.size() or not _vacant(to): return false
	var contents = state.inv_chests.get(str(index))
	var shifted = {}
	for key in state.inv_chests:
		var slot = int(key)
		if slot != index: shifted[str(slot - 1 if slot > index else slot)] = state.inv_chests[key]
	state.inv_chests = shifted
	state.board[to]["id"] = str(state.inv.pop_at(index))
	state.board[to].erase("chest")
	if contents is Array: state.board[to]["chest"] = contents.duplicate()
	discover(cell_id(to))
	return true

func _merge_coin(merged: String, origin: int) -> void:
	var to = find_empty_near(origin) if not state.tutorial_on else -1
	var roll = context.random_for("merge_drops").randf()
	if to < 0: return
	var id = Data.resource_drop("main", roll, state.level, merged)
	if id == "": return
	context.settle([[id, 1, "physical"]], {"board_origin": origin})

func can_move(i: int) -> bool:
	if i < 0 or i >= state.board.size(): return false
	if Data.is_numeric_resource(cell_id(i)): return false
	if state._chest_busy.has(i): return false
	if is_merge_bubble(i):
		return bubble_left(i) > 0 and not state._bubble_busy.has(str(state.board[i]["bubble"].get("uid", "")))
	return is_free(i) and (cell_id(i) != "" or context.orders.cooking(i))

func _drop_bubble(a: int, b: int) -> String:
	if not can_move(a) or (not is_free(b) and not can_move(b)): return ""
	var onto_empty = _vacant(b)
	for key in ["id", "lock", "bubble", "gm", "ck", "chest"]:
		var va = state.board[a].get(key)
		var vb = state.board[b].get(key)
		state.board[a].erase(key)
		state.board[b].erase(key)
		if va != null: state.board[b][key] = va
		if vb != null: state.board[a][key] = vb
	_sync_cook_cells()
	state.dirty()
	state.board_changed.emit()
	return "move" if onto_empty else "swap"

