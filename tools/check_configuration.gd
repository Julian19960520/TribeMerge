extends SceneTree
const Files := preload("res://scripts/config/config_files.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func rejects(changes: Dictionary, label: String) -> void:
	check(not Files.validate(changes) and not Files.last_errors.is_empty(), label)
func run() -> void:
	for node in root.get_children(): node.set_process(false)
	check(Files.validate(), "all gameplay configuration schemas and references")
	for error in Files.last_errors: print(error)
	check(Data.valid and Data.BOARD.size() == int(Data.RULES.cols) * int(Data.RULES.rows), "Data initialized through validated registry")
	var shared: Dictionary = Files.shared(Files.RULES)
	check(shared.is_read_only() and shared.order_cap_at.is_read_only(), "shared configuration is recursively immutable")
	var edited: Dictionary = Files.read(Files.RULES)
	edited.cols = 100
	check(int(shared.cols) != 100, "editor reads do not mutate the shared generation")
	var board: Dictionary = Files.read(Files.BOARD)
	board.cells.pop_back()
	rejects({Files.BOARD: board}, "mismatched board size is rejected")
	board = Files.read(Files.BOARD)
	board.cells[0] = "missing_99"
	rejects({Files.BOARD: board}, "unknown board item is rejected")
	var rules: Dictionary = Files.read(Files.RULES)
	rules.merge_resource_drops.main[0].chance = 1.5
	rejects({Files.RULES: rules}, "out-of-range drop chance is rejected")
	rules = Files.read(Files.RULES)
	rules.regen_sec = 0
	rejects({Files.RULES: rules}, "invalid timer is rejected")
	var chains: Array = Files.read(Files.CHAINS)
	chains.append(chains[0].duplicate(true))
	rejects({Files.CHAINS: chains}, "duplicate chain identifiers are rejected")
	var dishes: Array = Files.read(Files.DISHES)
	dishes[0].mats = ["missing_1"]
	rejects({Files.DISHES: dishes}, "unknown recipe ingredient is rejected")
	var packs: Dictionary = Files.read("res://data/card_packs.json")
	packs.packs[0].weights = [0, 0, 0, 0, 0]
	rejects({"res://data/card_packs.json": packs}, "empty weighted distribution is rejected")
	packs = Files.read("res://data/card_packs.json")
	packs.star_exchange[0].cost = -100
	rejects({"res://data/card_packs.json": packs}, "negative star prices are rejected")
	packs = Files.read("res://data/card_packs.json")
	packs.star_exchange[0].pack = "pack_99"
	rejects({"res://data/card_packs.json": packs}, "unknown exchange packs are rejected")
	packs = Files.read("res://data/card_packs.json")
	packs.duplicate_stars_by_rarity = [1, 2]
	rejects({"res://data/card_packs.json": packs}, "incomplete duplicate rarity values are rejected")
	var before := FileAccess.get_sha256(Files.BOARD)
	check(Files.write(Files.BOARD, board) == ERR_INVALID_DATA, "invalid editor write is refused")
	check(before == FileAccess.get_sha256(Files.BOARD), "refused write preserves the configuration file")
	rejects({Files.STORY: {}}, "missing current-format root fields are rejected")
	rules = Files.read(Files.RULES)
	rules.cols = {"invalid": true}
	rejects({Files.RULES: rules}, "wrong scalar types are rejected before use")
	rules = Files.read(Files.RULES)
	rules.merge_resource_drops.main[0].chance = {"invalid": true}
	rejects({Files.RULES: rules}, "wrong probability types are rejected without runtime errors")
	check(Files.write("res://data/../rules.json", rules) == ERR_INVALID_PARAMETER, "editor writes are restricted to registered canonical paths")
	var chest_descriptions_ok := true
	for grade in range(1, 6):
		for family in ["chest", "energybox", "premiumbox", "choice"]:
			var description: String = Data.describe("%s_%d" % [family, grade])
			chest_descriptions_ok = chest_descriptions_ok and description.contains("%d级" % grade)
			if family != "choice":
				var capacity: int = SpecialChests.count("%s_%d" % [family, grade])
				var capacity_text: String = ("获得%d件" if family == "premiumbox" else "取出%d件") % capacity
				chest_descriptions_ok = chest_descriptions_ok and description.contains(capacity_text)
	check(chest_descriptions_ok, "all graded chest descriptions match the current grade and capacity")
	var generation := Files.revision
	check(Data.refresh() and Files.revision == generation + 1 and Data.revision == Files.revision, "one refresh replaces and invalidates the complete generation")
	check(Data.line("food").id == "food" and Data.build_def("fire").id == "fire", "configuration indexes are available")
	quit(0 if failures == 0 else 1)
