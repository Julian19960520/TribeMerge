class_name Offers
extends RefCounted

const DATA := "res://data/offers.json"
const Payments := preload("res://scripts/net/Payments.gd")



static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/offers.json")

static func cfg(kind: String) -> Dictionary:
	var c = config().get(kind, {})
	return c if c is Dictionary else {}

static func tiers(kind: String) -> Array:
	var t = cfg(kind).get("tiers", [])
	return t if t is Array else []

static func tier(kind: String, k: int) -> Dictionary:
	var ts := tiers(kind)
	return ts[k] if k >= 0 and k < ts.size() else {}

static func state(kind: String) -> Dictionary:
	var s = G.offers.get(kind, {})
	return s if s is Dictionary else {}

static func unlocked(kind: String) -> bool:
	return not G.tutorial_on and G.rules.progression.feature_unlocked(int(cfg(kind).get("min_level", 999)))

static func active(kind: String) -> bool:
	var s := state(kind)
	return not s.is_empty() and G.now() >= float(s.get("start", 0)) and G.now() < float(s.get("end", 0))

static func can_open(kind: String) -> bool:
	return unlocked(kind) and not active(kind) and G.now() >= float(state(kind).get("next_at", 0))

static func remaining(kind: String) -> int:
	return maxi(0, int(ceil(float(state(kind).get("end", 0)) - G.now()))) if active(kind) else 0

static func bought(kind: String, k: int) -> int:
	var b = state(kind).get("bought", {})
	return int(b.get(str(k), 0)) if b is Dictionary else 0

static func left(kind: String, k: int) -> int:
	return maxi(0, int(tier(kind, k).get("limit", 0)) - bought(kind, k))

static func any_left(kind: String) -> bool:
	for k in tiers(kind).size():
		if left(kind, k) > 0: return true
	return false

static func price_text(kind: String, k: int) -> String:
	return "¥%d" % int(tier(kind, k).get("price_cny", 0))

static func value(rewards: Array) -> float:
	var total := 0.0
	for rw in rewards:
		var id := str(rw[0])
		var n := int(rw[1])
		match Rewards.kind(id):
			"amber": total += n
			"energy": total += n * 0.4
			"shell": total += n * 0.1
			"sand": total += n * 5.0
			"chest": total += 15.0 * n
			"pack": total += 20.0 * n
			_:
				if Data.type_of(id) == "gen": total += 10.0 * pow(2.0, Data.lv(id) - 1) * n
	return total

# ---------------------------------------------------------------- 开期

static func open_window(kind: String) -> bool:
	if G.replay_input(): return bool(Replay.perform("offer", {"kind": kind}).get("ok", false))
	if active(kind): return true
	if not can_open(kind): return false
	var c := cfg(kind)
	var start := G.now()
	var end := start + int(c["duration_sec"])
	G.offers[kind] = {"start": start, "end": end, "next_at": end + int(c["cooldown_sec"]), "bought": {}}
	G.dirty()
	return true

static func wants_energy() -> bool:
	return unlocked("energy") and ((active("energy") and any_left("energy")) or can_open("energy"))



## Paid through the server (scripts/net/Payments.gd); the grant records the purchase in the window.
static func buy(kind: String, k: int) -> Dictionary:
	if not active(kind): return {"ok": false, "error": "closed", "message": "本期礼包已结束"}
	if left(kind, k) <= 0: return {"ok": false, "error": "limit_reached", "message": "本期已买完"}
	return await Payments.buy("offer:%s:%d" % [kind, k])
