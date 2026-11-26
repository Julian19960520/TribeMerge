extends "res://scripts/domain/RuleModule.gd"
## Economy, shop purchases, player growth, pass tracks, buildings and card collections.

func feature_unlocked(required_level: int) -> bool:
	return state.gm_activities or state.level >= required_level

func unlock_all_features() -> void:
	var first = not state.gm_activities or state.tutorial_on
	state.gm_activities = true
	state.boost_gm = true
	state.tutorial_on = false
	state.seen_tutorial = true
	# GM 解锁时图鉴全部点亮：各产线的生产器和产物、菜、配方（奖励仍要在图鉴里点了领）
	for line in Data.LINES:
		for ch in [str(line["gen"])] + Data.products(line):
			if not Data.CHAINS.has(ch):
				continue
			for i in Data.CHAINS[ch]["items"].size():
				state.discovered["%s_%d" % [ch, i + 1]] = true
	for id in Data.DISHES:
		state.discovered[str(id)] = true
	for id in Data.CRAFT_IDS:
		state.discovered[str(id)] = true
	if first: context.orders.refill_orders()
	state.dirty()

func add_currency(kind: String, n: int) -> void:
	if n <= 0 or kind not in ["energy", "shell", "amber", "sand"]: return
	if kind in ["shell", "amber"]: context.record(kind, n)
	match kind:
		"energy": state.energy += n
		"shell": state.shells += n
		"amber": state.amber += n
		"sand": state.rush += n
	if kind == "energy" and state.energy >= state.MAX_ENERGY:
		state.energy_stamp = context.now()
	state.dirty()
	state.changed.emit()

func spend(kind: String, n: int) -> bool:
	if n < 0 or kind not in ["energy", "shell", "amber", "sand"]: return false
	if n == 0: return true
	match kind:
		"energy":
			if state.energy < n:
				return false
			if state.energy >= state.MAX_ENERGY:
				state.energy_stamp = context.now()
			state.energy -= n
		"shell":
			if state.shells < n:
				return false
			state.shells -= n
		"amber":
			if state.amber < n:
				return false
			state.amber -= n
			context.record("amber_spent", n)
		"sand":
			if state.rush < n:
				return false
			state.rush -= n
	state.dirty()
	state.changed.emit()
	return true

func energy_price() -> int:
	context.clock._check_day()
	# During the tutorial every refill costs the first-tier price, like the
	# reference game's flat 10 diamonds; those buys don't raise the day's price.
	return PriceBook.energy_price(0 if context.onboarding.active() else state.energy_buys)

func buy_energy() -> bool:
	context.clock._check_day()
	if not spend("amber", energy_price()):
		return false
	if not context.onboarding.active(): state.energy_buys += 1
	state.dirty()
	return true

func storage_price() -> int:
	var initial := int(Data.RULES.get("storage_initial", 5))
	var row := maxi(0, state.inv_cap / Data.STORAGE_COLS - initial / Data.STORAGE_COLS)
	return int(Data.RULES.get("storage_expand_price", 50)) + row * int(Data.RULES.get("storage_expand_step", 10))

func expand_storage() -> bool:
	if state._storage_busy: return false
	state._storage_busy = true
	var success = false
	if spend("amber", storage_price()):
		state.inv_cap += 1
		success = true
	state._storage_busy = false
	if success:
		state.dirty()
		state.changed.emit()
	return success

func claim_level(lv: int) -> Array:
	return Data.level_rewards(lv)

func shop_buy(key: String, id: String) -> Dictionary:
	if not PriceBook.ready(): return {"ok": false, "message": TextCatalog.source("notice.progressionrules.419ce98e5750")}
	if key.begins_with("deal_"): return {"ok":false,"message":TextCatalog.source("notice.progressionrules.88340e76cf90")}
	context.clock._check_day()
	var offer: Dictionary = {}
	var rows: Array = Data.daily_deals(state.level).duplicate()
	var hot: Array = context.shop.today()
	for k in hot.size():
		var d: Dictionary = hot[k].duplicate()
		d["key"] = "hot_%d" % k
		rows.append(d)
	for d in rows:
		if str(d["key"]) == key and str(d["id"]) == id:
			offer = d
			break
	if offer.is_empty():
		return {"ok": false, "message": TextCatalog.source("notice.progressionrules.1474fe39f598")}
	var book: Dictionary = state.deals_bought if key.begins_with("deal_") else state.hot_bought
	if int(book.get(key, 0)) >= int(offer["stock"]):
		return {"ok": false, "message": TextCatalog.source("notice.progressionrules.146d4fadcda9") if int(offer["price"]) == 0 else TextCatalog.source("notice.progressionrules.3e04d1952337")}
	if not spend("amber", int(offer["price"])):
		return {"ok": false, "error": "not_enough_amber"}
	book[key] = int(book.get(key, 0)) + 1
	state.dirty()
	state.changed.emit()
	return {"ok": true}

func has_free_daily() -> bool:
	for d in Data.daily_deals(state.level):
		if str(d.get("mode", "")) == "ad" or int(d["price"]) > 0 or state.pass_tier < int(d.get("min_tier",0)): continue
		if state.deals_day != context.clock.today() or int(state.deals_bought.get(d["key"],0)) < int(d["stock"]): return true
	return false

func refresh_hot() -> Dictionary:
	if state._hot_refresh_busy:
		return {"ok": false, "message": TextCatalog.source("notice.progressionrules.30fa38552623")}
	state._hot_refresh_busy = true
	context.clock._check_day()
	var previous: Array = context.shop.today().duplicate(true)
	var result: Dictionary
	if not spend("amber", int(Data.RULES["hot_refresh_price"])):
		result = {"ok": false, "message": TextCatalog.source("notice.boardrules.b874b509cd26")}
	else:
		state.hot_bought = {}
		state.hot_revision += 1
		context.shop.reroll_all(previous)
		result = {"ok": true}
	state._hot_refresh_busy = false
	if result.get("ok", false):
		state.dirty()
		state.changed.emit()
	return result

func xp_need() -> int:
	return Data.xp_need(state.level)

func add_xp(n: int) -> bool:
	context.record("xp", n)
	state.xp += n
	var up = false
	while state.xp >= xp_need():
		state.xp -= xp_need()
		state.level += 1
		up = true
		context.orders.refill_orders()
		state.orders_changed.emit()
	if up: _order_chest()
	if not state.tutorial_on:
		context.orders.assign_xp()
		state.orders_changed.emit()
	state.dirty()
	state.changed.emit()
	return up

## 升级时的「订单宝箱」：新订单还缺的材料（最多 ORDER_CHEST 件），每件降一级再送——玩家还得自己再合一次，
## 不会一升级就直接交单。要的是 1 级的不送；降一级后正好是哪张订单原样要的，就再往下降到没人要的那级，
## 每一级都有订单要就这件不送（这次升级可能一件都不送）；送出后会让哪张订单直接能交的那件也不送。
## 立刻放到棋盘上，放不下的进暂存区。界面先依次播放落到棋盘的动画，再弹升级面板。
const ORDER_CHEST := 3

func _order_chest() -> void:
	# 所有订单此刻原样缺的东西：降一级后正好是别的订单要的，也不送（那就等于直接给了订单物品）
	var lacking := {}
	for raw in context.orders.missing_order_items(99):
		lacking[str(raw)] = true
	# 每件先试低一级；那一级正好是哪张订单原样要的，就再往下找一级没人要的；都被要了这件就不送
	var help: Array = []
	for raw in context.orders.missing_order_items(ORDER_CHEST):
		var id := str(raw)
		if Data.lv(id) <= 1:
			continue
		var pick := ""
		for l in range(Data.lv(id) - 1, 0, -1):
			var gift := "%s_%d" % [Data.chain(id), l]
			if not lacking.has(gift) and not help.has(gift):
				pick = gift
				break
		if pick != "": help.append(pick)
	if help.is_empty(): return
	var placed: Array = []
	var stashed := 0
	for id in help:
		var ready_before := _ready_orders()
		var to: int = context.board.find_empty_near(state.board.size() / 2)
		if to >= 0:
			state.board[to]["id"] = str(id)
			if _ready_orders() > ready_before:
				state.board[to]["id"] = ""
				continue
			context.board.discover(str(id))
			placed.append({"to": to, "id": str(id)})
		else:
			state.stash.append(str(id))
			if _ready_orders() > ready_before:
				state.stash.pop_back()
				continue
			stashed += 1
	if placed.is_empty() and stashed == 0: return
	state.board_changed.emit()
	state.present("order_chest", {"items": placed, "stashed": stashed})

## 现在能直接交（或能开始制作）的订单张数
func _ready_orders() -> int:
	var n := 0
	for o in state.orders:
		if o is Dictionary and context.orders._order_filled(o): n += 1
	return n

func add_tokens(n: int) -> int:
	state.tokens += n
	var packs = 0
	while state.tokens - state.token_claimed >= state.TOKEN_STEP:
		state.token_claimed += state.TOKEN_STEP
		packs += 1
	state.dirty()
	state.changed.emit()
	return packs

func pass_reached() -> int:
	return int(_pass_cursor()["reached"])

func pass_prog_text() -> String:
	var c = _pass_cursor()
	return "%d/%d" % [int(c["into"]), int(c["need"])]

func pass_frac() -> float:
	var c = _pass_cursor()
	var need = int(c["need"])
	if need < 1:
		return 0.0
	return clampf(float(c["into"]) / float(need), 0.0, 1.0)

func pass_endless_ready() -> int:
	if state.pass_tier != 2:
		return 0
	var c = _pass_cursor()
	if int(c["reached"]) < Data.PASS_LEVELS.size():
		return 0
	var step = int(c["need"])
	if step < 1:
		return 0
	return maxi(0, int(int(c["extra"]) / float(step)) - state.pass_endless)

func _pass_cursor() -> Dictionary:
	var left = state.pass_pts
	var n = Data.PASS_LEVELS.size()
	for i in n:
		var need = Data.pass_need(i)
		if left < need:
			return {"reached": i, "into": left, "need": need, "extra": 0}
		left -= need
	if n == 0:
		return {"reached": 0, "into": 0, "need": 8, "extra": 0}
	var tail = Data.pass_need(n - 1)
	return {"reached": n, "into": tail, "need": tail, "extra": left}

func pass_got(prem: bool, lv: int) -> bool:
	return _pass_has(state.pass_prem if prem else state.pass_free, lv)

func pass_got_in(track: String, lv: int) -> bool:
	match track:
		"free": return _pass_has(state.pass_free, lv)
		"prem": return _pass_has(state.pass_prem, lv)
		"super": return _pass_has(state.pass_super, lv)
	return false

func pass_claimable() -> bool:
	var reached = pass_reached()
	for i in reached:
		var lv = i + 1
		if not _pass_has(state.pass_free, lv):
			return true
		if state.pass_tier >= 1 and not _pass_has(state.pass_prem, lv):
			return true
		if state.pass_tier >= 2 and not _pass_has(state.pass_super, lv):
			return true
	return pass_endless_ready() > 0

func claim_pass_free(lv: int) -> Array:
	context.clock.check_pass_season()
	if lv < 1 or lv > Data.PASS_LEVELS.size():
		return []
	if pass_reached() < lv or _pass_has(state.pass_free, lv):
		return []
	state.pass_free.append(lv)
	state.dirty()
	state.changed.emit()
	return Data.for_pass(state.level, Data.PASS_LEVELS[lv - 1]["free"])

func claim_pass_prem(lv: int) -> Array:
	context.clock.check_pass_season()
	if lv < 1 or lv > Data.PASS_LEVELS.size() or _pass_has(state.pass_prem, lv):
		return []
	if state.pass_tier < 1:
		state.present("notice", {"text": TextCatalog.source("notice.progressionrules.f691bdc992be")})
		return []
	if pass_reached() < lv:
		return []
	state.pass_prem.append(lv)
	state.dirty()
	state.changed.emit()
	return Data.for_pass(state.level, Data.PASS_LEVELS[lv - 1]["prem"])

func claim_pass_super(lv: int) -> Array:
	context.clock.check_pass_season()
	if lv < 1 or lv > Data.PASS_LEVELS.size() or _pass_has(state.pass_super, lv):
		return []
	if state.pass_tier < 2:
		state.present("notice", {"text": TextCatalog.source("notice.progressionrules.ba68c9b6e895")})
		return []
	if pass_reached() < lv:
		return []
	state.pass_super.append(lv)
	state.dirty()
	state.changed.emit()
	return Data.for_pass(state.level, Data.PASS_LEVELS[lv - 1].get("super", []))

func claim_pass_endless() -> Array:
	context.clock.check_pass_season()
	if state.pass_tier != 2:
		state.present("notice", {"text": TextCatalog.source("notice.progressionrules.ba0ee9227f7d")})
		return []
	if pass_endless_ready() <= 0:
		return []
	state.pass_endless += 1
	state.dirty()
	state.changed.emit()
	return [["chest_1", 1]]

func pass_cny(tier: String) -> float:
	var product := "pass:vip" if tier == "vip" else ("pass:upgrade" if state.pass_tier == 1 else "pass:super")
	return float(PriceBook.catalog.get("products", {}).get(product, {}).get("price_minor", 0)) / 100.0

func _pass_has(arr: Array, lv: int) -> bool:
	for x in arr:
		if int(x) == lv:
			return true
	return false

## 部落按 builds.json 的顺序一块地一块地建：前一块建完（且产线开放）才开下一块；
## 旧存档里已经动工的地块照样可以接着建。
func next_build_id() -> String:
	for b in Data.BUILDS:
		var id = str(b["id"])
		if build_can(id):
			return id
	return ""

func build_open(id: String) -> bool:
	var d = Data.build_def(id)
	if d.is_empty() or not feature_unlocked(Data.build_unlock(d)):
		return false
	return state.gm_activities or build_started(id) or _previous_build_done(id)

## 这块地是否已经动工（建过一件以上，或当前这件已经建了几次）
func build_started(id: String) -> bool:
	var d = Data.build_def(id)
	return int(state.builds.get(id, 0)) > int(d.get("initial", 0)) or build_step(id) > 0

func _previous_build_done(id: String) -> bool:
	var prev := {}
	for b in Data.BUILDS:
		if str(b["id"]) == id:
			break
		prev = b
	return prev.is_empty() or int(state.builds.get(str(prev["id"]), 0)) >= Data.build_stages(prev)

## 挡住这块地的前一块（没有就返回空）
func build_blocker(id: String) -> String:
	var prev := ""
	for b in Data.BUILDS:
		if str(b["id"]) == id:
			break
		prev = str(b["id"])
	return "" if prev == "" or _previous_build_done(id) else prev

func build_can(id: String) -> bool:
	var d = Data.build_def(id)
	return not d.is_empty() and build_open(id) and int(state.builds.get(id, 0)) < Data.build_stages(d)

## 当前这件部件（下标 = 已落成件数）已经建了几次（每件要建 steps 次才落成）；存在 builds["_steps"] 里
func build_step(id: String) -> int:
	var steps = state.builds.get("_steps", {})
	return int(steps.get(id, 0)) if steps is Dictionary else 0

## 后一件部件提前建了几次；存在 builds["_ahead"] 里
func build_ahead(id: String) -> int:
	var ahead = state.builds.get("_ahead", {})
	return int(ahead.get(id, 0)) if ahead is Dictionary else 0

## 第 idx 件部件已经建了几次
func part_step(id: String, idx: int) -> int:
	var parts = Data.build_parts(Data.build_def(id))
	var built = int(state.builds.get(id, 0))
	if idx < 0 or idx >= parts.size(): return 0
	if idx < built: return Data.part_steps(parts[idx])
	if idx == built: return mini(build_step(id), Data.part_steps(parts[idx]))
	if idx == built + 1: return build_ahead(id)
	return 0

## 这块地下一次建哪一件。最多同时开两件：后一件始终比前一件少建至少一次、也不会抢先落成，
## 所以两件交替往上长（图腾1、图腾2、大屋1、图腾3、大屋2…），落成顺序仍按 builds.json。
func build_target(id: String) -> int:
	var parts = Data.build_parts(Data.build_def(id))
	var built = int(state.builds.get(id, 0))
	if built < 0 or built >= parts.size(): return -1
	if built + 1 < parts.size():
		var ahead = build_ahead(id)
		if ahead + 1 < Data.part_steps(parts[built + 1]) and ahead + 1 < build_step(id):
			return built + 1
	return built

## 这块地一共要建多少次、已经建了多少次
func build_progress(id: String) -> Dictionary:
	var parts = Data.build_parts(Data.build_def(id))
	var total = 0
	var done = 0
	for k in parts.size():
		total += Data.part_steps(parts[k])
		done += part_step(id, k)
	return {"done": done, "total": total}

## 下一次要建的那件部件
func build_part(id: String) -> Dictionary:
	var parts = Data.build_parts(Data.build_def(id))
	var t = build_target(id)
	if t >= 0 and t < parts.size() and parts[t] is Dictionary:
		return parts[t]
	return {}

func build_cost(id: String) -> int:
	var part = build_part(id)
	if part.has("cost"):
		return maxi(0, int(part["cost"]))
	return 60 + int(state.builds.get(id, 0)) * 45

## 这次建完发的奖励：只有让部件落成的那一次才发
func build_rewards(id: String) -> Array:
	var part = build_part(id)
	if part_step(id, build_target(id)) + 1 < Data.part_steps(part):
		return []
	return build_piece_rewards(id)

## 下一次要建的那件部件落成时的奖励（界面预告用）
func build_piece_rewards(id: String) -> Array:
	var part = build_part(id)
	var out = []
	var all = part.get("rewards", [])
	if all is Array:
		for rw in all:
			if rw is Array and rw.size() >= 2 and str(rw[0]) != "":
				out.append([str(rw[0]), maxi(1, int(rw[1]))])
	return out

func do_build(id: String) -> Dictionary:
	if not build_can(id):
		return {}
	var t = build_target(id)
	var cost = build_cost(id)
	var rewards = build_rewards(id)
	if not spend("shell", cost):
		return {}
	var st = int(state.builds.get(id, 0))
	var need = Data.part_steps(build_part(id))
	var step = part_step(id, t) + 1
	var steps: Dictionary = state.builds.get("_steps", {}) if state.builds.get("_steps", {}) is Dictionary else {}
	var ahead: Dictionary = state.builds.get("_ahead", {}) if state.builds.get("_ahead", {}) is Dictionary else {}
	var finished = step >= need
	if t == st and finished:
		# 前一件落成：提前建的后一件顶上来当「当前这件」
		state.builds[id] = st + 1
		var moved = int(ahead.get(id, 0))
		ahead.erase(id)
		if moved > 0: steps[id] = moved
		else: steps.erase(id)
	elif t == st:
		steps[id] = step
	else:
		ahead[id] = step
	for pair in [["_steps", steps], ["_ahead", ahead]]:
		if (pair[1] as Dictionary).is_empty(): state.builds.erase(pair[0])
		else: state.builds[pair[0]] = pair[1]
	if finished: context.orders.refill_orders()
	state.dirty()
	state.changed.emit()
	return {"idx": t, "rewards": rewards, "finished": finished, "step": step if not finished else need, "steps": need}

func find_pack_source(pack_id: String = "", cell: int = -1, stash_index: int = -1) -> Dictionary:
	if cell >= 0:
		if cell < state.board.size() and context.board.is_free(cell) and Data.is_board_item(context.board.cell_id(cell)) and Data.type_of(context.board.cell_id(cell)) == "pack" and (pack_id == "" or context.board.cell_id(cell) == pack_id):
			return {"id": context.board.cell_id(cell), "cell": cell, "stash": -1}
		return {}
	if stash_index >= 0:
		if stash_index < state.stash.size() and Data.is_board_item(str(state.stash[stash_index])) and Data.type_of(str(state.stash[stash_index])) == "pack" and (pack_id == "" or str(state.stash[stash_index]) == pack_id):
			return {"id": str(state.stash[stash_index]), "cell": -1, "stash": stash_index}
		return {}
	var ids = [pack_id] if pack_id != "" else []
	if ids.is_empty():
		for tier in range(Data.max_lv("pack"), 0, -1): ids.append("pack_%d" % tier)
	for id in ids:
		if CardPacks.definition(str(id)).is_empty(): continue
		var index = state.stash.find(id)
		if index >= 0: return {"id": str(id), "cell": -1, "stash": index}
		var at = context.orders.board_has(str(id))
		if at >= 0: return {"id": str(id), "cell": at, "stash": -1}
	return {}

func consume_pack_source(source: Dictionary) -> void:
	if int(source["stash"]) >= 0: state.stash.remove_at(int(source["stash"]))
	else: state.board[int(source["cell"])]["id"] = ""

func open_pack(pack_id: String = "", cell: int = -1, stash_index: int = -1) -> Array:
	return open_pack_result(pack_id, cell, stash_index).get("cards", [])

func open_pack_result(pack_id: String = "", cell: int = -1, stash_index: int = -1) -> Dictionary:
	if state._pack_busy or not feature_unlocked(Data.CARD_LEVEL): return {"error": TextCatalog.source("notice.progressionrules.0cf982b1fe0e")}
	var source = find_pack_source(pack_id, cell, stash_index)
	if source.is_empty():
		state.present("notice", {"text": TextCatalog.source("notice.progressionrules.525b1fc2ed14")})
		return {"error": TextCatalog.source("notice.progressionrules.525b1fc2ed14")}
	state._pack_busy = true
	consume_pack_source(source)
	var result := draw_card_pack(str(source["id"]))
	if result.has("error"):
		var at = int(source["cell"])
		if at >= 0 and context.board._vacant(at): state.board[at]["id"] = source["id"]
		else: state.stash.append(source["id"])
	state._pack_busy = false
	state.dirty()
	state.board_changed.emit()
	state.changed.emit()
	return result

func roll_card_pack(pack_id: String = "pack_1") -> Array:
	return draw_card_pack(pack_id).get("cards", [])

func draw_card_pack(pack_id: String = "pack_1") -> Dictionary:
	if not feature_unlocked(Data.CARD_LEVEL):
		state.present("notice", {"text": TextCatalog.fill(TextCatalog.source("notice.progressionrules.de74876a0a22"), Data.CARD_LEVEL)})
		return {"error": TextCatalog.source("notice.progressionrules.0cf982b1fe0e")}
	if CardPacks.definition(pack_id).is_empty(): return {"error": TextCatalog.source("notice.progressionrules.55437ec117b8")}
	var out = []
	for i in int(CardPacks.config()["cards_per_pack"]):
		var selected = CardPacks.draw(pack_id, context.random_for("cards"))
		if selected.is_empty(): return {"error": TextCatalog.source("notice.progressionrules.eba10df6a3dc")}
		out.append(selected)
	return {"cards": out, "card_rewards": collect_cards(out)}

func collect_cards(entries: Array) -> Array:
	var rewards := []
	for entry in entries:
		var album := int(entry[0])
		var index := int(entry[1])
		var key := "%d_%d" % [album, index]
		var value := CardPacks.duplicate_value(album, index) if state.cards.has(key) else 0
		state.card_stars += value
		state.cards[key] = 1
		rewards.append({"album": album, "index": index, "stars": value})
	context.record("cards", entries.size())
	state.dirty()
	return rewards

func exchange_card_stars(cost: int) -> Dictionary:
	if not feature_unlocked(Data.CARD_LEVEL): return {"error": TextCatalog.source("notice.progressionrules.0cf982b1fe0e")}
	var offer := CardPacks.exchange_offer(cost)
	if offer.is_empty(): return {"error": TextCatalog.source("notice.progressionrules.8d53a4bbdbeb")}
	if state.card_stars < cost: return {"error": TextCatalog.source("notice.progressionrules.bf29777b97fd")}
	state.card_stars -= cost
	var pack_id := str(offer["pack"])
	# Keep the pack intact, even with a full board or an older pack in storage.
	state.stash.append(pack_id)
	state.dirty()
	state.changed.emit()
	return {"cost": cost, "pack": pack_id, "stash": state.stash.size() - 1}

func album_count(a: int) -> int:
	var n = 0
	for c in 9:
		if state.cards.has("%d_%d" % [a, c]):
			n += 1
	return n

func cards_total() -> int:
	var n = 0
	for a in Data.ALBUMS.size():
		n += album_count(a)
	return n

