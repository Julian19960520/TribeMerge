extends SceneTree
## 新手阶段提示截图：体力用完、升级弹窗（订单宝箱）、暂存区、火种罐、首次免费补体力（不碰真实存档）。
## Godot --path . --script tools/onboarding_shot.gd -- --save=user://onboarding_shot/s.json --cloud-off --cloud-state=user://onboarding_shot/c.json --out=DIR
var _started := false
var out := "."
var g
var main
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false
func _shot(n: String) -> void:
	await create_timer(0.6).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/ob_" + n + ".png")
	print("shot ", n)
func _run() -> void:
	g = root.get_node("G")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 4
	g.energy = 0
	g.orders = []
	g.rules.orders.refill_orders()
	g.tips_seen = {"howto": true, "stash": true, "craft": true, "craft_cook": true, "craft_ready": true, "build": true, "unlock_4": true}
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board", true)
	await create_timer(1.5).timeout
	main.tips.energy_out()
	await _shot("energy_tip")
	main.tips._close()
	await _shot("energy_free")
	main.close_all()
	main.open("levelup")
	await _shot("levelup")
	main.close_all()
	g.tips_seen.erase("stash")
	g.stash = ["emberpot_1", "basket_1"]
	g.changed.emit()
	await create_timer(1.0).timeout
	await _shot("stash_tip")
	main.tips._close()
	for i in g.board.size():
		if int(g.board[i]["lock"]) == 0:
			g.board[i]["id"] = "emberpot_1"
			break
	g.board_changed.emit()
	await create_timer(1.0).timeout
	await _shot("egen_tip")
	print("DONE")
	quit(0)
