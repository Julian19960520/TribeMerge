extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1

func run() -> void:
	var game = root.get_node("G")
	var replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	var catalog = load("res://scripts/localization/TextCatalog.gd")
	var ui = load("res://scripts/ui/UI.gd")
	var doc: Dictionary = catalog.document()
	var basket_copy := str(doc["entries"]["names.chains.ee1624377a03"]["zh_CN"])
	var claim_copy := str(doc["entries"]["ui.duelpopup.844ab9477225"]["zh_CN"])
	check(doc["stats"]["unique_texts"] == doc["entries"].size(), "catalogue count matches deduplicated entries")
	var hydrated := true
	for document in Data.ConfigFiles.documents().values():
		hydrated = hydrated and not JSON.stringify(document).contains("§")
	check(hydrated, "all gameplay config references hydrate before validation")
	var canonical := Data.name_of("basket_4")
	check(canonical == "初果灌木", "canonical item names preserve published gameplay values")
	check(catalog.resolve("§names.chains.ee1624377a03§") == basket_copy, "direct references display the editable default Chinese")
	check(catalog.hydrate(catalog.references([canonical, {"name": canonical, "count": 4}])) == [canonical, {"name": canonical, "count": 4}], "config editor roundtrip preserves canonical data and numbers")
	var before: Dictionary = game.business_snapshot().duplicate(true)
	var rules: String = replay.rules_hash()
	catalog.source("ui.duelpopup.844ab9477225")
	catalog._document["entries"]["ui.duelpopup.844ab9477225"]["en_US"] = "Collect"
	catalog._document["entries"]["names.chains.ee1624377a03"]["en_US"] = "Basket"
	catalog._document["entries"]["ui.boardscreen.89a087698f45"]["en_US"] = "${0} (Level ${1})"
	catalog._document["entries"]["ui.itempopups.bcfcbb40fe43"]["en_US"] = "${0} / rank ${1}"
	catalog.set_locale("en_US")
	check(catalog.text("ui.duelpopup.844ab9477225") == "Collect" and catalog.resolve("领取") == "Collect", "exact keys and legacy literals use the selected locale")
	check(catalog.resolve("初果灌木 (Lv.4)") == "Basket (Level 4)", "formatted legacy text translates both template and item argument")
	check(catalog.text("ui.itempopups.bcfcbb40fe43", [canonical, 4]) == "Basket / rank 4", "new keyed format API translates string arguments and retains numeric types")
	var host := Control.new(); root.add_child(host)
	var label = ui.lbl(host, "领取", Rect2(0, 0, 100, 30))
	var button = ui.btn(host, Rect2(0, 40, 100, 30), "领取", "green", Callable())
	check(label.text == "Collect" and button.text == "Collect", "real label and custom button display paths use the catalogue")
	catalog._cache.clear(); catalog._rendered.clear()
	check(button.text == "Collect", "custom buttons retain their display value after transient translation caches expire")
	check(catalog.source("names.chains.ee1624377a03") == canonical and Data.name_of("basket_4") == canonical and game.business_snapshot() == before and replay.rules_hash() == rules, "locale changes preserve canonical names, player state and replay identity")
	catalog._document["entries"]["ui.duelpopup.844ab9477225"]["zh_CN"] = "领取奖励"
	catalog.set_locale("untranslated_locale")
	check(catalog.resolve("领取") == "领取奖励", "missing translations fall back to the editable Chinese copy")
	check(catalog.resolve(catalog.resolve("领取")) == "领取奖励", "nested rendering boundaries do not translate edited copy twice")
	catalog.set_locale("zh_CN")
	check(catalog.resolve("§ui.duelpopup.844ab9477225§") == "领取奖励" and catalog.source("ui.duelpopup.844ab9477225") == "领取奖励", "a catalogue key reads the current Chinese copy")
	for entry in catalog._document["entries"].values(): entry["en_US"] = "TEST " + str(entry["zh_CN"])
	catalog.set_locale("en_US")
	check(catalog.text("ui.duelpopup.844ab9477225") == "TEST 领取奖励" and catalog.resolve("初果灌木 (Lv.4)").ends_with("(Lv.4)"), "the complete catalogue can load a translated locale and compile all legacy display templates")
	catalog.set_locale("zh_CN")
	catalog.reload()
	check(catalog.resolve("领取") == claim_copy and catalog.locale() == "zh_CN", "reloading restores the editable on-disk catalogue")
	host.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
