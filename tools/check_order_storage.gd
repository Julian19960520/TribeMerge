extends SceneTree
## 订单是否满足要算上储物洞，交付时从洞里扣掉。
var failures := 0
var g
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	g = root.get_node("G")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	for i in g.board.size():
		g.board[i] = {"id": "", "lock": 0}
	g.inv = ["seed_3", "seed_3"]
	g.inv_chests = {}
	var order: Dictionary = g.order_identity({"who": 0, "items": ["seed_3", "seed_3"], "rw": {"shell": 1}, "story": false})
	g.orders = [order]
	check(g.rules.orders.order_ready(order), "两件都在储物洞时订单算满足")
	g.board[4]["id"] = "seed_3"
	g.inv = ["seed_3"]
	check(g.rules.orders.order_ready(order) and g.rules.orders.order_cells(order) == [4], "棋盘和储物洞各一件时，棋盘那格算进订单")
	var cells: Array = g.rules.orders.complete_order(0, false)
	check(cells == [4] and g.board[4]["id"] == "" and g.inv.is_empty(), "交付同时清掉棋盘和储物洞里的物品")
	g.orders = [g.order_identity({"who": 0, "items": ["seed_4"], "rw": {"shell": 1}, "story": false})]
	g.board[1]["id"] = "seed_4"
	g.inv = ["seed_4"]
	check(g.rules.orders.order_cells(g.orders[0]) == [1], "棋盘上已有的物品优先，不先扣储物洞")
	g.rules.orders.complete_order(0, false)
	check(g.board[1]["id"] == "" and g.inv == ["seed_4"], "优先交付棋盘上的那一件")
	print("%d failures" % failures)
	quit(1 if failures else 0)
