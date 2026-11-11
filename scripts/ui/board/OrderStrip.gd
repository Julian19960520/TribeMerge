class_name OrderStrip
extends Control
## Order identity is independent of completion state and display position.
signal craft_requested(index: int)
signal delivery_requested(index: int)
var cards_by_index: Array[Control] = []
var right_edge := 274.0
var refresh_count := 0
var created_count := 0
var _cards: Dictionary = {}

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func refresh() -> void:
	refresh_count += 1
	var wanted := {}
	var sorted: Array[int] = []
	var gaps: Array[int] = []
	cards_by_index.resize(G.orders.size())
	for index in G.orders.size():
		var order: Dictionary = G.orders[index]
		var key := _identity(order)
		wanted[key] = true
		var card: OrderCard = _cards.get(key)
		if card == null:
			card = OrderCard.new()
			card.craft_requested.connect(func(_oi): _request(key, true))
			card.delivery_requested.connect(func(_oi): _request(key, false))
			_cards[key] = card
			add_child(card)
			created_count += 1
		card.refresh(index, order)
		cards_by_index[index] = card
		sorted.append(index)
		gaps.append(OrderCard.missing(order))
	for key in _cards.keys():
		if wanted.has(key): continue
		var card: Control = _cards[key]
		_cards.erase(key)
		remove_child(card)
		card.queue_free()
	sorted.sort_custom(func(a: int, b: int) -> bool:
		var xp_a := int(G.orders[a]["rw"].get("xp", 0)) > 0
		var xp_b := int(G.orders[b]["rw"].get("xp", 0)) > 0
		if xp_a != xp_b: return xp_a
		if (gaps[a] == 0) != (gaps[b] == 0): return gaps[a] == 0
		return a < b if gaps[a] == gaps[b] else gaps[a] < gaps[b])
	var x := 272.0
	for index in sorted:
		var card := cards_by_index[index]
		card.position = Vector2(x, 44)
		x += card.size.x + 4.0
	right_edge = x + 2.0

static func _identity(order: Dictionary) -> String:
	return str(order["uid"])

func _request(key: String, crafting: bool) -> void:
	# A prior click may have removed/reordered an order before the deferred render.
	for index in G.orders.size():
		if _identity(G.orders[index]) != key: continue
		if crafting: craft_requested.emit(index)
		else: delivery_requested.emit(index)
		return
