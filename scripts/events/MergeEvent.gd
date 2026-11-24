class_name MergeEvent
extends RefCounted
## Seasonal board controller. Its item IDs never enter the main board/inventory.

static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/merge_events.json")

static func current(at := -1.0) -> Dictionary:
	if at < 0: at = G.now()
	for raw in config().get("seasons", []):
		if not bool(raw.get("enabled", true)): continue
		var start := float(Time.get_unix_time_from_datetime_string(str(raw["start_utc"])))
		var period := float(raw.get("repeat_days", 0)) * 86400.0
		var duration := float(raw.get("duration_days", 7)) * 86400.0
		if at < start: continue
		var index := int((at - start) / period) if period > 0 else 0
		var begins := start + index * period
		if at >= begins + duration: continue
		var c: Dictionary = raw.duplicate(true)
		c["key"] = "%s:%d" % [c["id"], index]
		c["at"] = at
		c["ends_at"] = begins + duration
		return c
	return {}

static func definition(key: String) -> Dictionary:
	for raw in config().get("seasons", []):
		if str(raw["id"]) == key.get_slice(":", 0):
			var c: Dictionary = raw.duplicate(true)
			c["key"] = key
			c["ends_at"] = float(Time.get_unix_time_from_datetime_string(str(c["start_utc"]))) + int(key.get_slice(":", 1)) * float(c.get("repeat_days", 0)) * 86400 + float(c.get("duration_days", 7)) * 86400
			return c
	return {}

## 赛季开放、等级够，且这一季落在「一周」档期里轮到月石遗迹。
static func available(c: Dictionary) -> bool:
	if c.is_empty() or not (G.gm_activities or G.level >= int(c.get("unlock_level", 1))): return false
	return ActivitySchedule.scheduled("merge", float(c.get("at", G.now())))

static func active(c: Dictionary) -> bool:
	return available(c) and str(current().get("key", "")) == str(c.get("key", ""))

static func fresh(c: Dictionary) -> Dictionary:
	var b: Dictionary = c["board"]
	var cols := int(b["cols"])
	var rows := int(b["total_rows"])
	var cells: Array = []
	for row in rows:
		for col in cols:
			if row == rows - 1:
				cells.append({"id": "", "lock": 0})
				continue
			var tier := locked_tier(b, rows - 2 - row, col)
			cells.append({"id": str(c["chain"][clampi(tier - 1, 0, c["chain"].size() - 2)]["id"]), "lock": 2})
	var out := {"rules_version": 3, "cells": cells, "points": 0, "earned": 0, "spent": 0, "discovered": {}, "min_view": rows - int(b["visible_rows"]), "view": rows - int(b["visible_rows"]), "claimed": false, "got": [], "orders": 0}
	# 三条线的活动：埋好颜料、底排放画笔。
	for sp in b.get("specials", []):
		var depth := int(sp["depth"])
		if depth >= 0 and depth < rows - 1: cells[(rows - 2 - depth) * cols + int(sp["col"])]["id"] = str(sp["id"])
	if c.has("brush"):
		cells[(rows - 1) * cols + clampi(int(b.get("brush_col", cols / 2)), 0, cols - 1)]["id"] = str(c["brush"]["id"])
		out["rules_version"] = 5
		out["brush"] = {"charges": 0, "fed": 0, "load": []}
		out["queue"] = []
		out["made"] = 0
		out["codex"] = {}
	return out

## 老存档补字段：气泡队列、合成过的最高级、生产器待产清单、图鉴领取记录。
static func _upgrade(c: Dictionary, s: Dictionary) -> void:
	if s.is_empty() or int(s.get("rules_version", 0)) >= 5 or not c.has("brush"): return
	if not s.has("queue"): s["queue"] = []
	if not s.has("codex"): s["codex"] = {}
	if not s.has("made"): s["made"] = unlocked_tier(c, s)
	var brush: Dictionary = s.get("brush", {"charges": 0, "fed": 0})
	if not brush.has("load"):
		brush["load"] = _batch(c, brush_index(c, s)).slice(0, int(brush.get("charges", 0)))
		brush["charges"] = brush["load"].size()
	s["brush"] = brush
	s["rules_version"] = 5

## Locked item tier at a depth (0 = row right above the open bottom row). Deeper layers hold higher relics.
## Shared integer hash keeps client and worker boards identical.
static func locked_tier(b: Dictionary, depth: int, col: int) -> int:
	var seed := int(b.get("seed", 0))
	var layers: Array = b["layers"]
	var tiers: Array = layers[-1]["tiers"]
	var acc := 0
	for layer in layers:
		acc += int(layer["rows"])
		if depth < acc:
			tiers = layer["tiers"]
			break
	return int(tiers[((depth * 131 + col * 71 + seed * 17) % 97) % tiers.size()])

static func state(c: Dictionary) -> Dictionary:
	var key := str(c.get("key", ""))
	if key == "": return {}
	return G.merge_events.get(key, {})

static func next_id(c: Dictionary, id: String) -> String:
	for chain in [c["chain"], c.get("mural", [])]:
		for k in chain.size() - 1:
			if str(chain[k]["id"]) == id: return str(chain[k + 1]["id"])
	# 卡包碎片：最高级的两片合成一个能打开的卡包。
	var shards: Array = c.get("shards", [])
	for k in shards.size():
		if str(shards[k]["id"]) == id: return str(shards[k + 1]["id"]) if k + 1 < shards.size() else str(c.get("shard_result", ""))
	# 体力、琥珀、箱子等主游戏物品：和主棋盘一样按各自产线合成。
	if kind(c, id) == "reward": return Data.next_id(id)
	return ""

## 活动棋盘上的物品属于哪一类：light（产线一）、mural（特殊物品）、shard（卡包碎片）、brush（生产器）、paint（宝石）、reward（主游戏的资源或箱子）。
static func kind(c: Dictionary, id: String) -> String:
	if id == "": return ""
	for row in c["chain"]:
		if str(row["id"]) == id: return "light"
	for row in c.get("mural", []):
		if str(row["id"]) == id: return "mural"
	for row in c.get("shards", []):
		if str(row["id"]) == id: return "shard"
	if c.has("brush") and id == str(c["brush"]["id"]): return "brush"
	for row in c.get("paints", []):
		if str(row["id"]) == id: return "paint"
	return "reward" if Data.is_board_item(id) else ""

## 资源（体力、贝币、琥珀、沙漏）在活动棋盘上选中后点击领取；箱子类显示成气泡，点一下收进主棋盘暂存区。
static func is_bubble(c: Dictionary, id: String) -> bool:
	return kind(c, id) == "reward" and not Data.type_of(id) in Rewards.RESOURCE_TYPES

static func item(c: Dictionary, id: String) -> Dictionary:
	for row in c["chain"]:
		if str(row["id"]) == id: return row
	for row in c.get("mural", []) + c.get("shards", []) + c.get("paints", []):
		if str(row["id"]) == id: return row
	if c.has("brush") and id == str(c["brush"]["id"]): return brush_level(c, state(c))
	return {}

## 生产器当前等级那一档配置（名字、图标、产出清单）：喂一颗宝石升一级，满级后再喂就按满级重新装填。
static func brush_level(c: Dictionary, s: Dictionary) -> Dictionary:
	var levels: Array = c.get("brush", {}).get("levels", [])
	if levels.is_empty(): return {}
	return levels[brush_index(c, s)]

static func brush_index(c: Dictionary, s: Dictionary) -> int:
	var levels: Array = c.get("brush", {}).get("levels", [])
	return clampi(int(s.get("brush", {}).get("fed", 0)), 0, maxi(0, levels.size() - 1))

## 某一级生产器一次装填的产出：按配置各行轮流排开（特殊物品、体力、钻石、碎片穿插着出）。
static func _batch(c: Dictionary, level: int) -> Array:
	var levels: Array = c.get("brush", {}).get("levels", [])
	if levels.is_empty(): return []
	var rows: Array = levels[clampi(level, 0, levels.size() - 1)].get("batch", [])
	var left: Array = []
	for rw in rows: left.append(int(rw[1]))
	var out: Array = []
	var more := true
	while more:
		more = false
		for k in rows.size():
			if int(left[k]) <= 0: continue
			out.append(str(rows[k][0]))
			left[k] = int(left[k]) - 1
			more = true
	return out

## 这一下点生产器能不能产出（还有存货、旁边有空格）。
static func can_brush(c: Dictionary, s: Dictionary, at: int) -> bool:
	if s.is_empty() or not s.has("brush") or int(s["brush"]["charges"]) <= 0: return false
	var cells: Array = s["cells"]
	var cols := int(c["board"]["cols"])
	var lo := int(s["view"]) * cols
	var hi := lo + int(c["board"]["visible_rows"]) * cols
	if at < lo or at >= hi or kind(c, str(cells[at]["id"])) != "brush": return false
	return MergeGrid.nearest_empty(cells, cols, at, func(k): return k >= lo and k < hi) >= 0

static func _row_of(c: Dictionary, id: String) -> Dictionary:
	for row in c["chain"] + c.get("mural", []):
		if str(row["id"]) == id: return row
	return {}

## 把物品摆到 origin 附近的可见空格，放不下的进洞口暂存，有空位再自动出来。
static func _place(c: Dictionary, s: Dictionary, ids: Array, origin: int, lo: int, hi: int) -> Array:
	var placed: Array = []
	var cells: Array = s["cells"]
	for id in ids:
		var to := MergeGrid.nearest_empty(cells, int(c["board"]["cols"]), origin, func(k): return k >= lo and k < hi)
		if to < 0:
			s["queue"].append(str(id))
			continue
		cells[to]["id"] = str(id)
		cells[to]["lock"] = 0
		if kind(c, str(id)) in ["light", "mural", "shard"]: s["discovered"][str(id)] = true
		placed.append({"to": to, "id": str(id), "from": origin})
	return placed

## 气泡里还剩几件（订单奖励、推进时收起来的物品、摆不下的掉落）+ 老积分还能换几件。
static func supply(c: Dictionary, s: Dictionary) -> int:
	if s.is_empty(): return 0
	return s.get("queue", []).size() + int(s["points"]) / maxi(1, int(c["points"]["spawn_cost"]))

## 气泡下一件发射出来的物品。
static func next_supply(c: Dictionary, s: Dictionary) -> String:
	var q: Array = s.get("queue", [])
	if not q.is_empty(): return str(q[0])
	return str(c["chain"][int(c["points"]["spawn_tier"]) - 1]["id"])

## 订单奖励：按难度（最高物品等级 + 多出来的件数）给若干个某一级的活动物品。
static func order_bundle(c: Dictionary, order: Dictionary) -> Dictionary:
	var score := 1
	var ids: Array = order.get("items", [])
	for id in ids: score = maxi(score, Data.lv(str(id)))
	score += maxi(0, ids.size() - 1)
	var out := {}
	for row in c["points"].get("order_bundles", []):
		if score >= int(row["score"]): out = row
	return out

static func _expand(rows: Array) -> Array:
	var out: Array = []
	for rw in rows:
		for _k in int(rw[1]): out.append(str(rw[0]))
	return out

static func order_points(c: Dictionary, order: Dictionary) -> int:
	var score := 1
	var ids: Array = order.get("items", [])
	for id in ids: score = maxi(score, Data.lv(str(id)))
	score += maxi(0, ids.size() - 1)
	var p: Dictionary = c["points"]
	var tier := 0
	for threshold in p["order_thresholds"]:
		if score >= int(threshold): tier += 1
	return clampi(int(p["order_rewards"][mini(tier, p["order_rewards"].size() - 1)]), 1, 3)

static func on_order(order: Dictionary) -> int:
	var c := current()
	if not available(c): return 0
	var s := state(c)
	_upgrade(c, s)
	s["orders"] = int(s["orders"]) + 1
	if c["points"].has("order_bundles"):
		var bundle := order_bundle(c, order)
		var count := int(bundle.get("count", 0))
		var id := str(c["chain"][clampi(int(bundle.get("tier", 1)) - 1, 0, c["chain"].size() - 1)]["id"])
		for _k in count: s["queue"].append(id)
		s["earned"] = int(s["earned"]) + count
		_changed()
		return count
	var n := order_points(c, order)
	s["points"] = int(s["points"]) + n
	s["earned"] = int(s["earned"]) + n
	_changed()
	return n

## GM 调试：给当期活动直接加积分（只经 Replay 的 gm 动作调用）。
static func gm_points(n: int) -> int:
	var c := current()
	var s := state(c)
	if not available(c) or s.is_empty(): return 0
	s["points"] = int(s["points"]) + n
	s["earned"] = int(s["earned"]) + n
	_changed()
	return n

static func _changed() -> void:
	G.dirty()
	G.merge_event_changed.emit()

static func remaining(s: Dictionary) -> int:
	var n := 0
	for cell in s["cells"]:
		if int(cell["lock"]) != 0: n += 1
	return n

static func complete(c: Dictionary, s: Dictionary) -> bool:
	return progress(c, s) >= goal_total(c)

## Goal size: covered cells for unlock_all, chain length for discover_all.
static func goal_total(c: Dictionary) -> int:
	if str(c["board"].get("goal", "unlock_all")) == "discover_all": return c["chain"].size()
	return int(c["board"]["cols"]) * (int(c["board"]["total_rows"]) - 1)

static func progress(c: Dictionary, s: Dictionary) -> int:
	if str(c["board"].get("goal", "unlock_all")) == "discover_all":
		var n := 0
		for row in c["chain"]:
			if s["discovered"].has(str(row["id"])): n += 1
		return n
	return goal_total(c) - remaining(s)

## Progress milestones; the last one is the completion reward. Old configs with a bare `rewards` list get one milestone.
static func milestones(c: Dictionary) -> Array:
	return c["milestones"]

static func got(_c: Dictionary, s: Dictionary) -> Array:
	return s["got"]

## Indexes of reached but unclaimed milestones.
static func claimable(c: Dictionary, s: Dictionary) -> Array:
	var out: Array = []
	var have := got(c, s)
	var p := progress(c, s)
	var ms := milestones(c)
	for k in ms.size():
		if p >= mini(int(ms[k]["at"]), goal_total(c)) and not have.has(k): out.append(k)
	return out

static func claim_rewards(c: Dictionary, indexes: Array) -> Array:
	var out: Array = []
	var ms := milestones(c)
	for k in indexes:
		for rw in ms[int(k)]["rewards"]: out.append((rw as Array).duplicate())
	return out

static func unlocked_tier(c: Dictionary, s: Dictionary) -> int:
	var tier := 0
	for k in c["chain"].size():
		if s["discovered"].has(str(c["chain"][k]["id"])): tier = k + 1
	return tier

static func advance_target(c: Dictionary, s: Dictionary) -> int:
	var rows := 0
	var by_merge: bool = c["board"].has("advance_on_merge")
	var tier := int(s.get("made", 0)) if by_merge else unlocked_tier(c, s)
	for stage in c["board"].get("advance_on_merge" if by_merge else "advance_by_tier", []):
		if tier >= int(stage["tier"]): rows += maxi(0, int(stage["rows"]))
	return maxi(0, int(c["board"]["total_rows"]) - int(c["board"]["visible_rows"]) - rows)

## 首次合成出指定等级时推进：底下移出视野的物品（锁着的也算）全部收进气泡，生产器挪到新视野里的空格。
static func _advance_on_merge(c: Dictionary, s: Dictionary) -> int:
	var target := advance_target(c, s)
	var view := int(s["view"])
	if view <= target: return 0
	var cols := int(c["board"]["cols"])
	var rows := int(c["board"]["visible_rows"])
	var cells: Array = s["cells"]
	var stashed: Array = []
	var brushes := 0
	for k in range((target + rows) * cols, (view + rows) * cols):
		var id := str(cells[k]["id"])
		if kind(c, id) == "brush": brushes += 1
		elif id != "": stashed.append(id)
		cells[k] = {"id": "", "lock": 0}
	s["view"] = target
	s["min_view"] = target
	var lo := target * cols
	var hi := lo + rows * cols
	for _k in brushes:
		var to := MergeGrid.nearest_empty(cells, cols, hi - cols / 2 - 1, func(k): return k >= lo and k < hi)
		if to >= 0: cells[to]["id"] = str(c["brush"]["id"])
		else: stashed.push_front(str(c["brush"]["id"]))
	stashed.append_array(s["queue"])
	s["queue"] = stashed
	return stashed.size()

static func _advance(c: Dictionary, s: Dictionary) -> void:
	if c["board"].has("advance_on_merge"):
		_advance_on_merge(c, s)
		return
	var cols := int(c["board"]["cols"])
	var rows := int(c["board"]["visible_rows"])
	var cells: Array = s["cells"]
	var target := advance_target(c, s)
	while int(s["view"]) > target:
		var view := int(s["view"])
		var shifted := false
		# Preserve every outgoing item, and never strand an uncleared lower cell.
		for step in range(mini(view - target, int(c["board"]["reveal_rows"])), 0, -1):
			var next_view := view - step
			var next_end := (next_view + rows) * cols
			var outgoing: Array = []
			var slots: Array = []
			var clear := true
			for k in range(next_end, (view + rows) * cols):
				if int(cells[k]["lock"]) != 0: clear = false
				if str(cells[k]["id"]) != "": outgoing.append(k)
			for k in range(next_view * cols, next_end):
				if int(cells[k]["lock"]) == 0 and str(cells[k]["id"]) == "": slots.append(k)
			# Keep room to place and merge a fresh pair after the camera advances.
			if not clear or outgoing.size() + 2 > slots.size(): continue
			slots.reverse()
			for k in outgoing.size():
				cells[slots[k]]["id"] = cells[outgoing[k]]["id"]
				cells[outgoing[k]]["id"] = ""
			s["min_view"] = next_view
			s["view"] = next_view
			shifted = true
			break
		if not shifted: break

## Returns an error string or a result with animation cell indices.
static func local_action(c: Dictionary, s: Dictionary, action: String, args: Dictionary = {}, drop_roll := -1.0) -> Dictionary:
	_upgrade(c, s)
	var cells: Array = s["cells"]
	var cols := int(c["board"]["cols"])
	var view := int(s["view"])
	if not action in ["claim", "codex"] and int(args.get("view", view)) != view: return {"error": TextCatalog.source("notice.mergeevent.1690899b5094")}
	var lo := view * cols
	var hi := lo + int(c["board"]["visible_rows"]) * cols
	var result := {}
	if not action in ["claim", "codex"] and bool(s["claimed"]): return {"error": TextCatalog.source("notice.mergeevent.382e6cd7a7d1")}
	s["view"] = view
	var queued_before: int = s.get("queue", []).size()
	if action == "spawn":
		# 气泡：先发射排队的物品，排空了再用老积分换一级物品。
		var cost := int(c["points"]["spawn_cost"])
		var waiting: Array = s.get("queue", [])
		if waiting.is_empty() and int(s["points"]) < cost: return {"error": TextCatalog.source("notice.mergeevent.61192eec0f98")}
		var to := MergeGrid.nearest_empty(cells, cols, hi - cols + cols / 2, func(k): return k >= lo and k < hi)
		if to < 0: return {"error": TextCatalog.source("notice.mergeevent.634a45c3f2c5")}
		var id := next_supply(c, s)
		if not waiting.is_empty():
			waiting.pop_front()
		else:
			s["points"] = int(s["points"]) - cost
			s["spent"] = int(s["spent"]) + cost
		cells[to]["id"] = id
		if kind(c, id) in ["light", "mural", "shard"]: s["discovered"][id] = true
		result = {"kind": "spawn", "to": to, "id": id}
	elif action == "drop":
		var a := int(args.get("from", -1))
		var b := int(args.get("to", -1))
		if a < lo or a >= hi or b < lo or b >= hi: return {"error": ""}
		if int(cells[b]["lock"]) == 2: return {"error": TextCatalog.source("notice.mergeevent.6609aa98c87b")}
		# 宝石拖到生产器上：升一级并装满这一级的产出（满级后按满级重新装填）。
		if kind(c, str(cells[a]["id"])) == "paint" and kind(c, str(cells[b]["id"])) == "brush" and int(cells[a]["lock"]) == 0 and int(cells[b]["lock"]) == 0:
			var brush: Dictionary = s["brush"]
			if int(brush["charges"]) > 0: return {"error": TextCatalog.source("notice.mergeevent.4fd1a3eda0b7")}
			var before := brush_index(c, s)
			var paint := str(cells[a]["id"])
			brush["fed"] = int(brush["fed"]) + 1
			brush["load"] = _batch(c, brush_index(c, s))
			brush["charges"] = brush["load"].size()
			cells[a]["id"] = ""
			result = {"kind": "feed", "from": a, "to": b, "id": paint, "charges": int(brush["charges"]), "level_up": brush_index(c, s) > before, "level": brush_index(c, s) + 1}
		else:
			var next := func(id): return next_id(c, id)
			var how := MergeGrid.drop_kind(cells, a, b, next)
			if how == "": return {"error": TextCatalog.source("notice.mergeevent.7100074c0c36") if int(cells[b]["lock"]) != 0 else ""}
			var locked := int(cells[b]["lock"]) != 0
			var id := str(cells[a]["id"])
			var under := str(cells[b]["id"])
			MergeGrid.apply_drop(cells, a, b, how, next)
			var revealed := MergeGrid.reveal_neighbors(cells, b, cols) if how == "merge" else []
			# 颜料、画笔这类特殊物品揭开后直接可用，不用再配对解锁。
			for k in revealed:
				if not kind(c, str(cells[k]["id"])) in ["light", "mural"]: cells[k]["lock"] = 0
			s["discovered"][str(cells[b]["id"])] = true
			if locked: s["discovered"][under] = true
			result = {"kind": how, "from": a, "to": b, "id": id, "under": under, "unlocked": locked, "revealed": revealed}
			if how == "merge" and kind(c, str(cells[b]["id"])) == "light" and s.has("made"):
				var tier := 1
				for k in c["chain"].size():
					if str(c["chain"][k]["id"]) == str(cells[b]["id"]): tier = k + 1
				if tier > int(s["made"]):
					s["made"] = tier
					result["first_tier"] = tier
			if how == "merge" and c.has("mural"):
				# 三条线的活动：奖励都留在活动棋盘上，不直接进主棋盘。
				var row := _row_of(c, str(cells[b]["id"]))
				var made := _expand(row.get("drops", []) + row.get("rewards", []))
				result["placed"] = _place(c, s, made, b, lo, hi)
				result["queued"] = made.size() - result["placed"].size()
			elif how == "merge":
				var drop := Data.resource_drop("event", drop_roll if drop_roll >= 0 else G.rng.randf(), G.level)
				if drop != "": result["drops"] = [drop]
	elif action == "brush":
		var at := int(args.get("cell", -1))
		if at < lo or at >= hi or kind(c, str(cells[at]["id"])) != "brush" or int(cells[at]["lock"]) != 0: return {"error": ""}
		if int(s["brush"]["charges"]) <= 0: return {"error": TextCatalog.source("notice.mergeevent.5eb3bdaef09b")}
		var to := MergeGrid.nearest_empty(cells, cols, at, func(k): return k >= lo and k < hi)
		if to < 0: return {"error": TextCatalog.source("notice.mergeevent.c898da2e69e9")}
		var load: Array = s["brush"]["load"]
		var id := str(load.pop_front())
		s["brush"]["charges"] = load.size()
		cells[to]["id"] = id
		if kind(c, id) in ["light", "mural", "shard"]: s["discovered"][id] = true
		result = {"kind": "brush", "from": at, "to": to, "id": id, "charges": int(s["brush"]["charges"])}
	elif action == "collect":
		var at := int(args.get("cell", -1))
		if at < lo or at >= hi or int(cells[at]["lock"]) != 0: return {"error": ""}
		var id := str(cells[at]["id"])
		var k := kind(c, id)
		if k == "reward":
			result = {"kind": "collect", "cell": at, "id": id, "bubble": is_bubble(c, id), "rewards": [[id, 1, "item"]]}
		elif k in ["light", "mural"] and next_id(c, id) == "":
			result = {"kind": "hang", "cell": at, "id": id}
		else: return {"error": ""}
		cells[at]["id"] = ""
	elif action == "recycle":
		var at := int(args.get("cell", -1))
		if at < lo or at >= hi or int(cells[at]["lock"]) != 0 or str(cells[at]["id"]) == "" or kind(c, str(cells[at]["id"])) == "brush": return {"error": TextCatalog.source("notice.mergeevent.ddc20351115f")}
		cells[at]["id"] = ""
		result = {"kind": "recycle"}
	elif action == "claim":
		var ready := claimable(c, s)
		if ready.is_empty(): return {"error": TextCatalog.source("notice.mergeevent.9c400b890514")}
		var have := got(c, s).duplicate()
		have.append_array(ready)
		s["got"] = have
		if have.has(milestones(c).size() - 1): s["claimed"] = true
		result = {"kind": "claim", "milestones": ready, "rewards": claim_rewards(c, ready)}
	elif action == "codex":
		var id := str(args.get("id", ""))
		if not codex_ready(c, s, id): return {"error": ""}
		s["codex"][id] = true
		result = {"kind": "codex", "id": id, "rewards": c.get("codex_reward", []).duplicate(true)}
	else: return {"error": TextCatalog.source("notice.duelrace.f242d2db4cea")}
	if action in ["drop", "spawn", "recycle", "brush", "collect"]:
		_advance(c, s)
		result["advance_rows"] = view - int(s["view"])
		var stashed: int = s.get("queue", []).size() - queued_before
		if result["advance_rows"] > 0 and stashed > 0: result["stashed"] = stashed
	return result

# ---------------------------------------------------------------- 图鉴：活动物品、生产器、特殊物品三条线

## 图鉴每一页：[{title, ids}]；生产器各级用 "brush#等级" 当编号。
static func codex_lines(c: Dictionary) -> Array:
	var out: Array = []
	var light: Array = []
	for row in c["chain"]: light.append(str(row["id"]))
	out.append({"key": "light", "title": str(c.get("chain_title", TextCatalog.source("notice.mergeevent.f892078afded"))), "ids": light})
	if c.has("brush"):
		var gens: Array = []
		for k in c["brush"]["levels"].size(): gens.append("brush#%d" % (k + 1))
		out.append({"key": "brush", "title": TextCatalog.source("developer.lines_editor.bb7813711819"), "ids": gens})
	if c.has("mural"):
		var murals: Array = []
		for row in c["mural"]: murals.append(str(row["id"]))
		out.append({"key": "mural", "title": TextCatalog.source("notice.mergeevent.9f9003edc0bc"), "ids": murals})
	return out

## 图鉴格子的名字和图标（生产器按等级取）。
static func codex_entry(c: Dictionary, id: String) -> Dictionary:
	if id.begins_with("brush#"):
		return c["brush"]["levels"][clampi(int(id.get_slice("#", 1)) - 1, 0, c["brush"]["levels"].size() - 1)]
	return item(c, id)

static func codex_unlocked(c: Dictionary, s: Dictionary, id: String) -> bool:
	if s.is_empty(): return false
	if id.begins_with("brush#"): return c.has("brush") and int(id.get_slice("#", 1)) <= brush_index(c, s) + 1
	return s["discovered"].has(id)

static func codex_ready(c: Dictionary, s: Dictionary, id: String) -> bool:
	if not s.has("codex") or s["codex"].has(id) or c.get("codex_reward", []).is_empty(): return false
	for line in codex_lines(c):
		if (line["ids"] as Array).has(id): return codex_unlocked(c, s, id)
	return false

static func codex_pending(c: Dictionary, s: Dictionary) -> int:
	var n := 0
	for line in codex_lines(c):
		for id in line["ids"]:
			if codex_ready(c, s, str(id)): n += 1
	return n

static func act(c: Dictionary, action: String, args: Dictionary = {}) -> Dictionary:
	var input := args.duplicate()
	input["season"] = str(c["key"])
	input["action"] = action
	return Replay.perform("activity", input)
