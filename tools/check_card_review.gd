extends SceneTree
## 开卡结果：重复卡收走标题和星星；有新卡时查看并逐张放大，没有新卡时确定。
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	await process_frame
	var presentation = load("res://scripts/ui/CardRewardPresentation.gd")
	if presentation == null or not presentation.has_method("popup"):
		check(false, "开卡结果脚本没加载")
		print("%d failures" % failures)
		quit(1)
		return
	var g = root.get_node("G")
	g.card_stars = 4
	var dup = presentation.popup({"card_rewards": [{"album": 0, "index": 0, "stars": 2}]})
	root.add_child(dup)
	check(dup.box.get_node("receive_cards").text == "确定", "没有新卡时底部按钮是确定")
	await create_timer(1.6).timeout
	check(not dup.box.get_node("received_card_0").visible and not dup.box.get_node("card_album_0").visible and not dup.box.get_node("card_badge_0").visible, "重复卡收成星星后，顶部标题和底部星星一起消失")
	dup.free()
	var review = presentation.popup({"card_rewards": [{"album": 0, "index": 0, "stars": 0}, {"album": 0, "index": 1, "stars": 0}]})
	root.add_child(review)
	var view = review.box.get_node("receive_cards")
	check(view.text == "查看", "有新卡时底部按钮是查看")
	view.pressed.emit()
	await create_timer(0.4).timeout
	var first: Control = review.box.get_node("received_card_0")
	var second: Control = review.box.get_node("received_card_1")
	check(first.visible and not second.visible and first.scale.is_equal_approx(Vector2.ONE * 1.7) and absf(first.get_rect().get_center().x - 360.0) < 2.0 and view.text == "下一张", "查看把第一张新卡放大到正中，底部变成下一张")
	view.pressed.emit()
	await create_timer(0.4).timeout
	check(second.visible and not first.visible and view.text == "确定", "再点翻到下一张，按钮变成确定")
	view.pressed.emit()
	check(review._closing, "确定关掉翻卡")
	print("%d failures" % failures)
	quit(1 if failures else 0)
