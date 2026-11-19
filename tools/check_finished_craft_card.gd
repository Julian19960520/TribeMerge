extends SceneTree
## 制作完成的订单卡不再留着原料点击区。
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _shown(card) -> int:
	var n := 0
	for hit in card._mat_hits:
		if hit.visible: n += 1
	return n

func run() -> void:
	await process_frame
	var script = load("res://scripts/ui/board/OrderCard.gd")
	var card = script.new()
	root.add_child(card)
	var order := {"who": 0, "kind": "craft", "phase": "need", "story": false, "dish": "trailpack", "mats": ["seed_4", "seed_3"], "items": ["seed_4", "seed_3"], "rw": {"shell": 1}, "uid": "craft-card"}
	card.refresh(0, order)
	check(_shown(card) == 2, "还没做完时原料还在")
	order["phase"] = "ready"
	card.refresh(0, order)
	check(_shown(card) == 0, "做完后原料点击区收起")
	order["phase"] = "finished"
	card.refresh(0, order)
	check(_shown(card) == 0, "手动领取前也不显示原料")
	print("%d failures" % failures)
	quit(1 if failures else 0)
