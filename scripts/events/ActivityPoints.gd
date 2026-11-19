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
