class_name ActivityEntries
extends RefCounted
## The only mapping from business activity IDs to their board views.
const VIEWS := {
	"race": preload("res://scripts/ui/RaceEntry.gd"),
	"merge": preload("res://scripts/ui/MergeEventEntry.gd"),
	"seven": preload("res://scripts/ui/SevenDayEntry.gd"),
	"duel": preload("res://scripts/ui/DuelEntry.gd"),
	"tiger": preload("res://scripts/ui/TigerEscapeEntry.gd"),
	"fossil": preload("res://scripts/ui/FossilDigEntry.gd"),
}

static func create(parent: Control, entry_size: Vector2) -> Array:
	var entries := []
	for definition in ActivityRules.board_entries():
		var id: String = definition["id"]
		var view: Control = VIEWS[id].new()
		view.size = entry_size
		parent.add_child(view)
		view.visibility_changed.connect(func():
			view.process_mode = Node.PROCESS_MODE_INHERIT if view.is_visible_in_tree() else Node.PROCESS_MODE_DISABLED)
		entries.append({"id": id, "view": view, "visible": definition["visible"]})
	return entries
