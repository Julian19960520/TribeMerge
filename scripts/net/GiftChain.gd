extends Node

signal updated

const DATA := "res://data/gift_chain.json"
const Payments := preload("res://scripts/net/Payments.gd")

var info := {}
var ok := false
var loading := false
var fetched_once := false
var busy := false

static func inst() -> Node:
	var g := (Engine.get_main_loop() as SceneTree).root.get_node("G")
	var n := g.get_node_or_null("GiftChain")
	if n == null:
		n = load("res://scripts/net/GiftChain.gd").new()
		n.name = "GiftChain"
		g.add_child(n)
	return n



func online() -> bool:
	return Replay.authorized

func fetch() -> void:
	_absorb(Replay.gift_view())
	updated.emit()

func _absorb(chain: Dictionary) -> void:
	info = chain
	ok = true
	fetched_once = true

func steps() -> Array:
	return info.get("steps", Data.ConfigFiles.shared(DATA)["steps"])

func head() -> int:
	return int(info.get("step", 0))

func total() -> int:
	return steps().size()

func visible_n() -> int:
	return int(info.get("visible", 3))

func done() -> bool:
	return ok and head() >= total()

func free_ready() -> bool:
	return ok and online() and bool(info.get("free_ready", false))

func ends_at() -> float:
	return float(info.get("ends_at", 0))

func step(i: int) -> Dictionary:
	var ss := steps()
	return ss[i] if i >= 0 and i < ss.size() else {}

static func is_paid(s: Dictionary) -> bool:
	return float(s.get("price", 0)) > 0.0

static func price_text(s: Dictionary) -> String:
	var t := str(s.get("price_str", ""))
	return t if t != "" else _yuan(float(s.get("price", 0)))

static func _yuan(p: float) -> String:
	return ("¥%d" % int(p)) if is_equal_approx(p, roundf(p)) else ("¥%.2f" % p)

# ---------------------------------------------------------------- 领 / 买（返回 {"ok", "rewards"}；奖励由调用方播动画入账）

func claim(i: int) -> Dictionary:
	var result: Dictionary = Replay.perform("gift", {"step": i})
	fetch()
	return result

## Paid steps go through the server; the grant advances the chain when it is still the head step.
func buy(index: int) -> Dictionary:
	if busy: return {"ok": false, "message": "正在处理"}
	busy = true
	var result: Dictionary = await Payments.buy("gift:%d" % index)
	busy = false
	fetch()
	return result
