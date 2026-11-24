class_name BoardMotion
extends RefCounted
## 主棋盘和活动棋盘共用的一套手感：拖放滑入、生产器飞出、落地回弹、晃动、合成爆点，
## 以及"手快时直接收尾"。两边只管各自怎么画格子和物品，时长、缓动、轨迹都在这里。
##
## 动画只是表现：逻辑在操作那一刻已经落定，飞行中的格子用 hid 计数藏起来，
## 落地（或被 settle 提前收尾）时回调 landed(entry)。

const MergeBurst := preload("res://scripts/ui/board/BoardMergeBurst.gd")

## 以主棋盘 96 像素格子为基准；其他尺寸的棋盘按 unit 缩放距离。
const BASE_CELL := 96.0
const ITEM_RATIO := 84.0 / 96.0
const MOVE_DUR := 0.26
const FLY_DUR := 0.28
const FLY_ARC := 80.0
const POP_DUR := 0.35
const SHAKE_DUR := 0.35
const BURST_DUR := 0.6
const DRAG_LIFT := Vector2(0, -14)
const DRAG_SCALE := 1.15
const DRAG_START := 10.0

## 拖放、交换、合成：带 back 缓动滑到格子。字段 id/from/to/t/dur，其余由调用方附带。
var moves: Array = []
## 生产器出货、奖励掉落：减速飞出、上抛、由小变大。字段 id/from/to/t/delay。
var flights: Array = []
var pops: Dictionary = {}
var shakes: Dictionary = {}
var bursts: Array = []
## 格子 → 还有几件东西正往这里飞；有计数的格子不画静止物品。
var hid: Dictionary = {}
## landed(entry: Dictionary)：滑入或飞入结束（含 settle 提前收尾）。entry["kind"] 是 "move" 或 "fly"。
var landed: Callable

func slide(id: String, from: Vector2, to: int, dur := MOVE_DUR, extra := {}) -> Dictionary:
	conceal(to)
	var m := {"kind": "move", "id": id, "from": from, "to": to, "t": 0.0, "dur": dur, "delay": 0.0}
	m.merge(extra, true)
	moves.append(m)
	return m

func fly(id: String, from: Vector2, to: int, delay := 0.0, extra := {}) -> Dictionary:
	conceal(to)
	var f := {"kind": "fly", "id": id, "from": from, "to": to, "t": 0.0, "delay": delay}
	f.merge(extra, true)
	flights.append(f)
	return f

func conceal(i: int) -> void:
	hid[i] = int(hid.get(i, 0)) + 1

func unhide(i: int) -> void:
	var n := int(hid.get(i, 0)) - 1
	if n <= 0: hid.erase(i)
	else: hid[i] = n

func pop(i: int) -> void:
	pops[i] = 0.0

func shake(i: int) -> void:
	shakes[i] = 0.0

func burst(center: Vector2) -> void:
	bursts.append({"p": center, "t": 0.0, "seed": randi() % 1000})

func busy() -> bool:
	return not (moves.is_empty() and flights.is_empty() and pops.is_empty() and shakes.is_empty() and bursts.is_empty())

func clear() -> void:
	moves.clear()
	flights.clear()
	pops.clear()
	shakes.clear()
	bursts.clear()
	hid.clear()

## 玩家手快，格子上的滑入、飞入还没播完就要拿或放：直接收尾。
func settle(i: int) -> void:
	if i < 0: return
	for list in [moves, flights]:
		for e in list.duplicate():
			if int(e["to"]) == i:
				list.erase(e)
				_finish(e)

func tick(delta: float) -> void:
	for list in [moves, flights]:
		for e in list:
			if float(e["delay"]) > 0.0:
				e["delay"] = maxf(float(e["delay"]) - delta, 0.0)
				continue
			e["t"] = float(e["t"]) + delta / float(e.get("dur", FLY_DUR))
		for e in list.duplicate():
			if float(e["t"]) >= 1.0:
				list.erase(e)
				_finish(e)
	for d in [pops, shakes]:
		for k in d.keys():
			d[k] = float(d[k]) + delta
			if float(d[k]) > (POP_DUR if d == pops else SHAKE_DUR): d.erase(k)
	for b in bursts: b["t"] = float(b["t"]) + delta
	var left := bursts.filter(func(b): return float(b["t"]) < BURST_DUR)
	bursts.clear()
	bursts.append_array(left)

func _finish(e: Dictionary) -> void:
	unhide(int(e["to"]))
	if landed.is_valid(): landed.call(e)

# ---------------------------------------------------------------- 轨迹

static func ease_back(t: float) -> float:
	return MergeGrid.ease_back(t)

## 还在等 delay 的飞行不画。
static func waiting(e: Dictionary) -> bool:
	return float(e.get("delay", 0.0)) > 0.0

static func move_pos(m: Dictionary, to: Vector2) -> Vector2:
	return (m["from"] as Vector2).lerp(to, ease_back(clampf(float(m["t"]), 0.0, 1.0)))

## 刚松手时还是拖着的大小，滑到一半回到原大。
static func move_scale(m: Dictionary) -> float:
	return lerpf(DRAG_SCALE, 1.0, clampf(float(m["t"]) * 1.5, 0.0, 1.0))

static func fly_pos(f: Dictionary, to: Vector2, unit := 1.0) -> Vector2:
	var t := clampf(float(f["t"]), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - t, 3.0)
	return (f["from"] as Vector2).lerp(to, e) + Vector2(0, -FLY_ARC * unit * sin(PI * t))

static func fly_scale(f: Dictionary) -> float:
	var t := clampf(float(f["t"]), 0.0, 1.0)
	return 0.7 + 0.3 * (1.0 - pow(1.0 - t, 3.0))

## 静止格子上的回弹缩放与晃动偏移。
func pop_scale(i: int) -> float:
	if not pops.has(i): return 1.0
	var t := float(pops[i]) / POP_DUR
	return 1.0 + 0.28 * sin(PI * t) * (1.0 - t * 0.5)

func shake_offset(i: int, unit := 1.0) -> Vector2:
	if not shakes.has(i): return Vector2.ZERO
	var t := float(shakes[i])
	return Vector2(sin(t * 60.0) * 6.0 * unit * (1.0 - t / SHAKE_DUR), 0)

func draw_bursts(ci: CanvasItem, unit := 1.0) -> void:
	for b in bursts:
		MergeBurst.paint(ci, b["p"], float(b["t"]) / BURST_DUR, float(b["seed"]), false, 1.0, unit)

## 选中框：轻轻呼吸。
static func draw_selection(ci: CanvasItem, center: Vector2, cell: float, t: float, color := Color(0, 0, 0, 0)) -> void:
	var sz := Vector2(cell, cell) * (1.0 + 0.04 * sin(t * 6.0))
	var r := Rect2(center - sz * 0.5, sz).grow(-4)
	if color.a > 0.0: Paint.cell_bracket(ci, r, color)
	else: Paint.cell_bracket(ci, r)
