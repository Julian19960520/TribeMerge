extends RefCounted
## Replay processes share rules with the client, but never initialize presentation.

static func enabled() -> bool:
	return not OS.has_feature("dedicated_server") and not "--replay-worker" in OS.get_cmdline_user_args()

static func in_view(control: Control) -> bool:
	if not control.is_visible_in_tree(): return false
	var visible_rect := control.get_global_rect()
	if not visible_rect.has_area(): return false
	var parent := control.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents:
			visible_rect = visible_rect.intersection(parent.get_global_rect())
			if not visible_rect.has_area(): return false
		parent = parent.get_parent()
	return true
