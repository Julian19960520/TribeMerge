class_name RewardPresenter
extends RefCounted
## Display committed rewards; this class never changes gameplay state.
static func present(rewards: Array, from: Callable = Callable(), delivery: Dictionary = {}) -> void:
	if not is_instance_valid(G.main): return
	var item_flies: Array = []
	var origin := int(delivery.get("board_origin", -1))
	for index in rewards.size():
		var reward = rewards[index]
		if not reward is Array or reward.size() < 2 or int(reward[1]) <= 0: continue
		var id := str(reward[0])
		var type := Rewards.kind(id)
		if type == "": continue
		var pos: Vector2 = from.call(index) if from.is_valid() else Vector2(360, 700)
		var physical: bool = reward.size() > 2 and str(reward[2]) in ["item", "physical"]
		if Data.is_numeric_resource(id): physical = false
		if physical and str(reward[2]) == "item" and origin < 0 and type in Rewards.RESOURCE_TYPES and Data.value_of(id) > 0: physical = false
		if not physical and (type in Rewards.RESOURCE_TYPES or type in ["xp", "token"]):
			var dest: Vector2 = G.main.topbar.get_global_transform() * Vector2(64, 82) if type == "xp" else G.main.topbar.target(type)
			G.main.fly(id, pos, dest, Callable(), 90)
		elif origin < 0:
			item_flies.append([id, pos])
	_fly_items(item_flies)

static func _fly_items(flies: Array) -> void:
	if flies.is_empty() or not is_instance_valid(G.main): return
	if G.main.screen == "home":
		var home: HomeScreen = G.main.home
		home.present_go(func():
			if not is_instance_valid(home): return
			home.arm_go(flies.size())
			for item in flies:
				G.main.fly(str(item[0]), item[1], home.go_center(), home.release_go, 90))
	else:
		for item in flies:
			G.main.fly(str(item[0]), item[1], G.main.board_screen.stash_pos(), Callable(), 90)
