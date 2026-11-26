class_name ActivityRules
extends RefCounted
## Business registration only. Entry artwork and factories live in the UI registry.
static var _registry: Array = []
static var _timed: Array = []
static var _entries: Array = []

static func registry() -> Array:
	if _registry.is_empty():
		_registry = [
			{"id": "seven", "field": "seven_day", "initial": SevenDay.initial_state,
				"order": func(_o): SevenDay.record("orders", 1), "visible": func(): return G.rules.progression.feature_unlocked(Data.feature_level("seven")), "entry_order": 2},
			{"id": "login", "field": "login_gift", "initial": LoginGift.initial_state, "visible": LoginGift.visible, "entry_order": 6},
			{"id": "merge", "initialize": _initialize_merge, "order": MergeEvent.on_order,
				"visible": func(): return MergeEvent.available(MergeEvent.current()), "entry_order": 1},
			{"id": "duel", "initialize": DuelRace.initialize,
				"tick": DuelRace.tick, "tick_order": 1, "order": DuelRace.on_order, "visible": DuelRace.visible, "entry_order": 3},
			{"id": "tiger", "field": "tiger_escape", "initial": func(): return {"rounds": 0, "round": {}},
				"tick": TigerEscape.tick, "tick_order": 0, "order": TigerEscape.on_order, "visible": TigerEscape.visible, "entry_order": 4},
			{"id": "fossil", "initialize": FossilDig.initialize, "order": FossilDig.on_order,
				"visible": FossilDig.visible, "entry_order": 5},
			{"id": "ufo", "field": "ufo_offer", "initial": UfoOffer.initial_state},
			{"id": "race", "field": "local_race", "initial": func(): return {"current": {}, "results": []},
				"tick": LocalRace.tick, "tick_order": 2, "order": func(o): LocalRace.order(o.get("items", [])),
				"visible": _race_visible, "entry_order": 0},
		]
		for definition in _registry:
			if definition.has("tick"): _timed.append(definition)
			if definition.has("entry_order"): _entries.append(definition)
			definition.make_read_only()
		_timed.sort_custom(func(a, b): return int(a["tick_order"]) < int(b["tick_order"]))
		_entries.sort_custom(func(a, b): return int(a["entry_order"]) < int(b["entry_order"]))
		_timed.make_read_only()
		_entries.make_read_only()
		_registry.make_read_only()
	return _registry

static func _initialize_merge() -> void:
	var current := MergeEvent.current()
	if MergeEvent.available(current) and not G.merge_events.has(str(current["key"])):
		G.merge_events[str(current["key"])] = MergeEvent.fresh(current)

static func initialize() -> void:
	for definition in registry():
		if definition.has("initial") and G.get(definition["field"]).is_empty():
			G.set(definition["field"], definition["initial"].call())
		if definition.has("initialize"): definition["initialize"].call()

static func tick() -> void:
	registry()
	for definition in _timed: definition["tick"].call()

static func on_order(order: Dictionary) -> void:
	for definition in registry():
		if definition.has("order"): definition["order"].call(order)
	var gains: Array = ActivityPoints.grant(ActivityPoints.order_points(order))
	var duel_pts := DuelRace.order_score(order)
	if DuelRace.add_duel_points(duel_pts): gains.append({"id": "duel", "n": duel_pts})
	if not gains.is_empty(): G.present("activity_points", {"source": "order", "gains": gains})

## 合成：合出高级物品给活动积分，界面从这一格冒分飞进活动入口。
static func on_merge(id: String, cell: int) -> void:
	var gains: Array = ActivityPoints.grant(ActivityPoints.merge_points(id))
	var duel_pts := DuelRace.merge_score(id)
	if DuelRace.add_duel_points(duel_pts): gains.append({"id": "duel", "n": duel_pts})
	if not gains.is_empty(): G.present("activity_points", {"source": "merge", "cell": cell, "gains": gains})

static func board_entries() -> Array:
	registry()
	return _entries

## 篝火竞速：在档期里，或者上一局还没比完/没领奖时显示。
static func _race_visible() -> bool:
	if not G.rules.progression.feature_unlocked(int(LocalRace.rules().get("unlock_level", 12))): return false
	return ActivitySchedule.scheduled("race") or LocalRace.busy()
