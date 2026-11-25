class_name ActivityPoints
extends RefCounted
## 活动积分：篝火竞速、双人竞速、剑齿虎逃生共用的一份积分。
## - 交订单：按难度随机 ORDER_MIN~ORDER_MAX（简单单两三百，难单五六百）。
## - 合成：合出 MERGE_FROM 级及以上的物品，按等级给分，越高级越多，封顶 MERGE_MAX。
## 同一次得分同时记进每个进行中的新版活动（局里带 pv = VERSION）；老存档里还没打完的那一局仍按旧规则算，开新局才换。
## 量级标定见 tools/_cal_points.gd：Lv8~25 一张单约 350 分订单分 + 300 分合成分。

const VERSION := 2
const ORDER_MIN := 200
const ORDER_MAX := 600
## 同难度上下浮动
const ORDER_JITTER := 60.0
const MERGE_FROM := 7
const MERGE_BASE := 200
const MERGE_STEP := 100
const MERGE_MAX := 600
## 按等级出的简单单 / 难单火苗基准，各往外放宽这么多，当作难度 0 和 1
const EASY_SLACK := 0.7
const HARD_SLACK := 1.3

## 合出 id 这一下给多少分；不够格返回 0
static func merge_points(id: String) -> int:
	if not Data.is_board_item(id) or Data.is_dish(id) or Data.type_of(id) != "item":
		return 0
	var lv := Data.lv(id)
	if lv < MERGE_FROM:
		return 0
	return mini(MERGE_MAX, MERGE_BASE + MERGE_STEP * (lv - MERGE_FROM))

## 可配置的合成积分算法（供各活动按各自 JSON 规则复用）：
## rule 可区分 main（高概率主产物）与 sub（小概率副产物），也可直接平铺单套规则。
## 单套规则支持两种写法：
## 1) 阶梯公式：{"from": 5, "first_span": 2, "step_span": 3, "base": 1, "step": 1, "max": 0}
##    合出 from 级起给 base 分，前 first_span 个等级维持 base 分，之后每 step_span 级 +step 分（max > 0 时封顶）。
## 2) 逐级查表：{"table": [0, 1, 2, ...], "clamp_top": false}（索引 lv-1 对应合出 lv 级的分数）。
static func merge_score_by_rule(id: String, rule: Dictionary) -> int:
	if rule.is_empty() or not Data.is_board_item(id) or Data.is_dish(id) or Data.type_of(id) != "item":
		return 0
	var cfg: Dictionary = rule
	if rule.has("main") or rule.has("sub"):
		var key := "sub" if OrderRoll.is_sub(Data.chain(id)) else "main"
		var branch = rule.get(key, {})
		if not (branch is Dictionary) or (branch as Dictionary).is_empty():
			return 0
		cfg = branch
	return _eval_merge_tier(Data.lv(id), cfg)

static func _eval_merge_tier(lv: int, cfg: Dictionary) -> int:
	if lv <= 0 or cfg.is_empty():
		return 0
	if cfg.has("table") and cfg["table"] is Array:
		var tbl: Array = cfg["table"]
		if tbl.is_empty():
			return 0
		if lv <= tbl.size():
			return maxi(0, int(tbl[lv - 1]))
		return maxi(0, int(tbl.back())) if bool(cfg.get("clamp_top", false)) else 0
	var from_lv := int(cfg.get("from", 0))
	if from_lv <= 0 or lv < from_lv:
		return 0
	var base_pts := int(cfg.get("base", 1))
	var step_pts := int(cfg.get("step", 1))
	var first_span := maxi(1, int(cfg.get("first_span", 1)))
	var step_span := maxi(1, int(cfg.get("step_span", 1)))
	var pts := base_pts
	if lv >= from_lv + first_span:
		pts = base_pts + step_pts * (1 + int((lv - from_lv - first_span) / step_span))
	var max_pts := int(cfg.get("max", 0))
	if max_pts > 0:
		pts = mini(max_pts, pts)
	return maxi(0, pts)

## 订单理论消耗体力（火苗数）：烹饪单按材料 mats 算，普通单按 items 算。
static func order_flames(order: Dictionary) -> float:
	var items = order.get("items", [])
	if str(order.get("kind", "")) == "craft":
		items = order.get("mats", [])
	if not (items is Array) or (items as Array).is_empty():
		return 0.0
	return OrderRoll.total(items)

## 可配置的订单体力积分算法（供各活动按各自 JSON 规则复用）：
## rule: {"base": 1, "per_flame": 0.136, "min": 1, "max": 0}，max <= 0 表示不封顶。
static func order_energy_score(order: Dictionary, rule: Dictionary) -> int:
	var fl := order_flames(order)
	if fl <= 0.0:
		return 0
	var base := float(rule.get("base", 0.0))
	var per_flame := float(rule.get("per_flame", 0.136))
	var pts := int(round(base + fl * per_flame))
	var lo := int(rule.get("min", 1))
	var hi := int(rule.get("max", 0))
	if lo > 0:
		pts = maxi(lo, pts)
	if hi > 0:
		pts = mini(hi, pts)
	return maxi(0, pts)

## 订单难度 0~1：按订单要的火苗总数，落在当前等级简单单和难单的基准之间的位置
static func difficulty(order: Dictionary, level: int) -> float:
	var items = order.get("items", [])
	if str(order.get("kind", "")) == "craft":
		items = order.get("mats", [])
	if not (items is Array) or (items as Array).is_empty():
		return 0.5
	var easy := Data.tier_base(level, "easy") * EASY_SLACK
	var hard := Data.tier_base(level, "hard") * HARD_SLACK
	return clampf((OrderRoll.total(items) - easy) / maxf(1.0, hard - easy), 0.0, 1.0)

## 这张单给多少分（随机，走 activity_points 随机流，回放一致）
static func order_points(order: Dictionary) -> int:
	var d := difficulty(order, G.level)
	var jitter := G.random_for("activity_points").randf_range(-ORDER_JITTER, ORDER_JITTER)
	return clampi(int(snappedf(lerpf(ORDER_MIN, ORDER_MAX, d) + jitter, 10.0)), ORDER_MIN, ORDER_MAX)

## 记进每个进行中的新版活动，返回 [{"id": 活动 id, "n": 分数}]，界面按这个飞图标
static func grant(n: int) -> Array:
	var gains: Array = []
	if n <= 0:
		return gains
	if LocalRace.add_points(n): gains.append({"id": "race", "n": n})
	if DuelRace.add_points(n): gains.append({"id": "duel", "n": n})
	if TigerEscape.add_points(n): gains.append({"id": "tiger", "n": n})
	return gains
