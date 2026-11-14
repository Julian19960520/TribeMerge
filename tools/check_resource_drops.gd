extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	var data = load("res://scripts/Data.gd")
	check(data.resource_drop("main", 0.0, 8, "fruit_2") == "shell_2" and data.resource_drop("main", 0.049999, 8, "fruit_2") == "shell_2", "production merges directly drop level-two coins over the five-percent interval")
	check(data.resource_drop("main", 0.05, 8, "fruit_2") == "sand_1" and data.resource_drop("main", 0.054999, 8, "fruit_2") == "sand_1", "sand retains its separate half-percent interval")
	check(data.resource_drop("main", 0.0555, 8, "fruit_2") == "amber_1", "amber keeps its rare probability")
	check(data.resource_drop("main", 0.056, 8, "fruit_2") == "", "outside the configured probability intervals produces nothing")
	for id in ["shell_2", "sand_2", "amber_2", "fire_2", "basket_3", "chest_1", "pack_1", "choice_1", "energybox_1", "salad"]:
		check(data.resource_drop("main", 0, 40, id) == "", "%s cannot generate extra resources" % id)
	var original_rules: Dictionary = data.RULES
	data.RULES = original_rules.duplicate(true)
	data.RULES["merge_resource_lines"] = ["food"]
	check(data.resource_drop("main", 0, 8, "tool_2") == "" and data.resource_drop("main", 0, 8, "fruit_2") == "shell_2", "source-line allowlist is configurable")
	data.RULES = original_rules
	check(data.resource_drop("event", 0, 1) == "amber_1", "activity-board drops keep their independent configuration")
	print("RESULT ", failures, " failures")
	quit(0 if failures == 0 else 1)
