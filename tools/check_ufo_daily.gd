extends SceneTree
## Current race, daily-shop and UFO command boundaries; no local ad/payment simulations.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	var daily = load("res://scripts/events/DailyShop.gd")
	var ufo = load("res://scripts/events/UfoOffer.gd")
	var local = load("res://scripts/events/LocalRace.gd")
	g.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	g.simulation_time = 1793577600.0
	replay.active = true; replay.worker = true; replay.authorized = true; replay.executing = true
	replay.clock = int(g.simulation_time); replay.meta = {"allow_gm": true}; g.replay_meta = replay.meta
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true
	replay.advance(); replay.executing = false
	check(not replay.perform("race_join").get("ok", false), "race stays locked below the configured level")
	check(not replay.perform("gm").has("error") and g.gm_activities, "GM unlocks current activities through a command")
	var saved: Dictionary = replay.snapshot().duplicate(true)
	g.gm_activities = false
	check(replay.restore(saved) and g.gm_activities and g.level == 1, "GM unlock roundtrips without granting levels")
	check(replay.perform("race_join").get("ok", false), "GM unlock permits the shared banana race")
	g.orders = [g.order_identity({"who": 2, "items": ["fruit_14"], "rw": {}, "story": false})]
	g.board[0] = {"id": "fruit_14", "lock": 0}
	check(not replay.perform("order", {"cell": 0}).has("error") and float(g.local_race["current"]["group"]["members"][0]["score"]) > 0, "real order delivery advances race progress")
	for member in g.local_race["current"]["group"]["members"]:
		if not member["me"]: member["points"] = []
	g.simulation_time = float(g.local_race["current"]["group"]["end"]) + 1
	replay.perform("tick")
	var result: Dictionary = g.local_race["results"][0]
	var id := str(result["group"]["id"])
	var paid: Dictionary = replay.perform("race_claim", {"id": id})
	check(paid.get("ok", false) and not paid.get("rewards", []).is_empty() and not replay.perform("race_claim", {"id": id}).get("ok", false), "podium reward is settled exactly once")
	replay.perform("race_join")
	for member in g.local_race["current"]["group"]["members"]:
		if not member["me"]: member["points"] = [[1.0, float(g.local_race["current"]["group"]["target"])]]
	g.simulation_time += 10; replay.perform("tick")
	check(g.local_race["results"][0]["me"]["place"] == 5 and g.local_race["results"][0]["me"]["reward"].is_empty(), "banana race awards only the top three")
	g.pass_tier = 0; g.amber = 0; g.shells = 300; g.stash = []
	check(replay.perform("daily", {"key": "deal_member_1"}).has("error"), "non-member cannot claim member assets")
	var energy: int = g.energy
	check(not daily.start_ad() and replay.perform("daily", {"key": "deal_ad"}).has("error") and g.energy == energy, "unverified ad completion never grants local energy")
	daily.cancel_ad()
	check(replay.perform("daily", {"key": "deal_ad"}).has("error") and g.energy == energy, "cancelled ad cannot grant assets")
	check(replay.perform("daily", {"key": "deal_energybox"}).get("ok", false) and g.shells == 0 and g.stash == ["energybox_1"], "daily purchase spends three hundred currency for its physical chest")
	g.pass_tier = 1
	check(replay.perform("daily", {"key": "deal_member_1"}).get("ok", false) and g.amber == 100, "first member item grants its configured amount")
	check(replay.perform("daily", {"key": "deal_member_2"}).has("error") and g.amber == 100, "second member item requires the higher membership tier")
	g.pass_tier = 2
	check(replay.perform("daily", {"key": "deal_member_2"}).get("ok", false) and g.amber == 200, "second member item is independent and grants once")
	check(replay.perform("daily", {"key": "deal_member_1"}).has("error") and g.amber == 200, "member claim cannot be repeated")
	check(replay.perform("daily", {"key": "deal_2"}).get("ok", false) and not g.rules.progression.has_free_daily(), "free daily claims clear the indicator")
	g.deals_day = "2000-01-01"
	check(g.rules.progression.has_free_daily(), "a new day restores the free indicator")
	g.board = []
	for _cell in g.COLS * g.ROWS: g.board.append({"id": "", "lock": 0})
	g.board[0] = {"id": "fruit_3", "lock": 0}
	g.board[1] = {"id": "fruit_4", "lock": 3, "bubble": {"expires": g.now() + 60}}
	g.inv = []; g.stash = []
	g.orders = [g.order_identity({"who": 2, "rw": {}, "story": false, "items": ["fruit_3", "fruit_3", "fruit_4"]}), g.order_identity({"who": 3, "rw": {}, "story": false, "items": ["tool_3", "tool_4", "tool_5"]})]
	check(ufo.candidate() == ["fruit_3", "fruit_4", "tool_3"], "UFO candidates account for duplicates and ignore unpaid bubbles")
	g.ufo_offer = {"next_at": 0, "offer": {}}
	replay.perform("ufo")
	var offer: Dictionary = g.ufo_offer["offer"].duplicate(true)
	var deadline := float(offer["expires_at"])
	replay.perform("ufo")
	check(g.ufo_offer["offer"]["expires_at"] == deadline, "repeated visits do not extend the offer deadline")
	var before: Dictionary = g.business_snapshot().duplicate(true)
	check(ufo.buy(offer["id"]).has("error") and g.business_snapshot() == before, "UFO purchase requires verified payment and cannot deliver assets locally")
	g.ufo_offer["offer"]["expires_at"] = g.now() - 1
	check(not ufo.active() and ufo.buy(offer["id"]).has("error"), "expired offers remain unavailable")
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
