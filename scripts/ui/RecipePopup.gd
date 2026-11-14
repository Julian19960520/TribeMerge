extends RefCounted
## Recipe details expose stable rectangles for the first cooking lesson.
static func create(id: String) -> PopupBase:
	var key := id.trim_prefix("dish_")
	if not Data.DISHES.has(key): return null
	var d: Dictionary = Data.DISHES[key]
	var p := PopupBase.new()
	var rect := Rect2(58, 300, 604, 790)
	Popups.frame(p, rect, TextCatalog.source("ui.recipepopup.6db1b0abacb2"), Art.OCHRE)
	UI.icon(p.box, id, Vector2(360, 470), 156)
	UI.lbl(p.box, str(d["name"]), Rect2(100, 552, 520, 48), 34, Art.INK)
	Popups.section(p.box, TextCatalog.source("ui.recipepopup.a8ff5639f884"), 620)
	var mats: Array = d["mats"]
	for k in mats.size():
		var x := 360.0 + (k - (mats.size() - 1) * 0.5) * 132
		UI.icon(p.box, str(mats[k]), Vector2(x, 750), 94)
		UI.lbl(p.box, "×1", Rect2(x - 40, 798, 80, 34), 25, Art.INK)
	var seconds := int(d["secs"])
	UI.lbl(p.box, TextCatalog.source("ui.recipepopup.c18455486abf") % [seconds / 60, seconds % 60], Rect2(90, 914, 540, 60), 30, Art.INK)
	p.set_meta("recipe", rect)
	p.set_meta("recipe_mats", Rect2(100, 666, 520, 180))
	p.set_meta("recipe_time", Rect2(90, 882, 540, 110))
	p.set_meta("onboarding_close", Rect2(610, 276, 70, 70))
	return p
