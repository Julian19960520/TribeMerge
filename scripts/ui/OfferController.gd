class_name OfferController
extends Node
## Local presentation policy for limited offers; gameplay changes go through commands.
var _clock := 0.0

static func inst() -> Node:
	var main: Node = G.main
	var node := main.get_node_or_null("OfferController")
	if node == null:
		node = OfferController.new()
		node.name = "OfferController"
		main.add_child.call_deferred(node)
	return node

static func open_energy() -> void:
	if Offers.open_window("energy") and Offers.any_left("energy") and is_instance_valid(G.main):
		G.main.open("energy_offer")

func _process(delta: float) -> void:
	_clock += delta
	if _clock < 1.0: return
	_clock = 0.0
	if not Replay.authorized or not is_instance_valid(G.main) or not bool(Offers.cfg("spree").get("auto_popup", true)): return
	if Offers.can_open("spree"): Offers.open_window("spree")
	var start := float(Offers.state("spree").get("start", 0))
	if not Offers.active("spree") or float(G.settings.get("spree_popped", 0)) == start or not Offers.any_left("spree"): return
	if G.main.popup_layer.get_child_count() > 0 or not G.main.screen in ["home", "board"]: return
	G.settings["spree_popped"] = start
	G.save_game()
	G.main.open("spree")
