extends SceneTree
const Files := preload("res://scripts/config/config_files.gd")
const SPECIAL := "res://data/special_chests.json"
const CHOICES := "res://data/choice_chests.json"
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func rejects(path: String, value: Variant, label: String) -> void:
	check(not Files.validate({path: value}) and not Files.last_errors.is_empty(), label)
func run() -> void:
	check(Files.refresh(), "all current chest grades validate")
	for error in Files.last_errors: print(error)
	var current: Dictionary = Files.shared(SPECIAL)
	var counts_ok: bool = current.orderbox.levels.size() == 10
	for family in ["chest", "energybox", "premiumbox"]: counts_ok = counts_ok and current[family].levels.size() == 5
	check(counts_ok and Files.shared(CHOICES).size() == 5, "current chest families have every required grade")
	var changed: Dictionary = Files.read(SPECIAL)
	changed.premiumbox = changed.premiumbox.levels[0].duplicate(true)
	rejects(SPECIAL, changed, "flat legacy premium chest definition is rejected")
	changed = Files.read(SPECIAL)
	changed.premiumbox.count = 8
	rejects(SPECIAL, changed, "legacy root fields cannot coexist with grade definitions")
	changed = Files.read(SPECIAL)
	changed.premiumbox.levels.pop_back()
	rejects(SPECIAL, changed, "missing premium grade is rejected")
	changed = Files.read(SPECIAL)
	changed.premiumbox.levels[1].count = changed.premiumbox.levels[0].count
	rejects(SPECIAL, changed, "higher grades must increase chest capacity")
	changed = Files.read(SPECIAL)
	changed.premiumbox.levels[0].tier_weights = [0, 0, 0, 0, 0, 0]
	rejects(SPECIAL, changed, "empty premium tier distribution is rejected")
	changed = Files.read(SPECIAL)
	changed.premiumbox.levels[0].resource_weights = {"sand": 1}
	rejects(SPECIAL, changed, "premium pools reject unrelated resource chains")
	changed = Files.read(SPECIAL)
	changed.premiumbox.levels[0].guaranteed_resources = ["sand"]
	rejects(SPECIAL, changed, "guaranteed resource must belong to the premium pool")
	changed = Files.read(SPECIAL)
	changed.energybox.levels[0]["items"][0] = "fire_99"
	rejects(SPECIAL, changed, "unknown energy chest tier is rejected")
	changed = Files.read(SPECIAL)
	changed.energybox.levels[0]["items"][0] = "amber_2"
	rejects(SPECIAL, changed, "energy chests reject nonenergy contents")
	changed = Files.read(SPECIAL)
	changed.chest.levels[0].gen_tier = 99
	rejects(SPECIAL, changed, "wicker producer grades are bounded by every production line")
	changed = Files.read(SPECIAL)
	changed.chest.levels[0].gen_chance = 1.5
	rejects(SPECIAL, changed, "wicker producer probability is bounded")
	var choices: Dictionary = Files.read(CHOICES)
	choices.erase("choice_5")
	rejects(CHOICES, choices, "missing choice chest grade is rejected")
	choices = Files.read(CHOICES)
	choices.choice_5.choices[0] = "missing_1"
	rejects(CHOICES, choices, "choice grades reject unknown reward items")
	choices = Files.read(CHOICES)
	choices.choice_5.choices[1] = choices.choice_5.choices[0]
	rejects(CHOICES, choices, "choice chest options must be distinct")
	quit(0 if failures == 0 else 1)
