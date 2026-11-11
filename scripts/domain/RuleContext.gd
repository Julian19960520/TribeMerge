extends RefCounted
## One service graph per game instance. Clocks and random streams are injectable.
const BoardService := preload("res://scripts/domain/BoardRules.gd")
const OrdersService := preload("res://scripts/domain/OrderRules.gd")
const ProgressionService := preload("res://scripts/domain/ProgressionRules.gd")
const ClockService := preload("res://scripts/domain/ClockRules.gd")
const layout := preload("res://scripts/config/board_layout.gd")
const roll := preload("res://scripts/OrderRoll.gd")
const ShopService := preload("res://scripts/domain/ShopRules.gd")
var shop: ShopService
var state: Node
var board: BoardService
var orders: OrdersService
var progression: ProgressionService
var clock: ClockService
var _now: Callable
var _random: Callable
var _clock_ready: Callable
var _effects: Dictionary

func _init(game: Node, now_source: Callable, random_source: Callable, clock_ready_source: Callable, effects: Dictionary) -> void:
	_effects = effects
	state = game
	_now = now_source
	_random = random_source
	_clock_ready = clock_ready_source
	board = BoardService.new(self)
	orders = OrdersService.new(self)
	progression = ProgressionService.new(self)
	clock = ClockService.new(self)
	shop = ShopService.new(self)

func now() -> float:
	return _now.call()

func random_for(key: String) -> RandomNumberGenerator:
	return _random.call(key)

func clock_ready() -> bool:
	return _clock_ready.call()

func record(metric: String, amount: int) -> void:
	_effects["record"].call(metric, amount)

func login() -> void:
	_effects["login"].call()

func on_order(order: Dictionary) -> void:
	_effects["order"].call(order)

func settle(rewards: Array, delivery: Dictionary = {}) -> Dictionary:
	return _effects["settle"].call(rewards, delivery)

func meta() -> Dictionary:
	return _effects["meta"].call()
