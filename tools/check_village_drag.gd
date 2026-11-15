extends SceneTree
## 部落大地图：手指拖动、边界、对准下一处地块；新手引导和弹窗打开时不能拖。
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _press(home, at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	home._input(e)

func _move(home, at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	home._input(e)

func run() -> void:
	var TA = load("res://scripts/TribeArt.gd")
	var g = root.get_node("G")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 9
	g.builds["fire"] = 8
	g.builds["gather"] = 2
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.show_screen("home", true)
	main.close_all()
	await process_frame
	var home = main.home
	var world: Control = home._world
	check(world.size == TA.WORLD and world.get_parent().clip_contents, "部落在比屏幕大的地图层里，外面一层裁剪")
	home.focus_next(false)
	var target: Vector2 = TA.area_at(g.rules.progression.next_build_id())
	check((target + world.position).distance_to(home.VIEW_FOCUS) < 1.0, "镜头对准下一处要建的地块")
	var before: Vector2 = world.position
	var k: float = home._world_scale()
	_press(home, Vector2(360, 700), true)
	_move(home, Vector2(355, 695))
	check(world.position == before, "手指只动一点不算拖动（留给点击）")
	_move(home, Vector2(300, 600))
	_move(home, Vector2(260, 560))
	_press(home, Vector2(260, 560), false)
	var moved: Vector2 = world.position - before
	check(moved.distance_to(Vector2(-100, -140) * k) < 2.0, "拖动时地图跟着手指走")
	home._fling = Vector2.ZERO
	world.position = home._clamp_cam(Vector2(5000, 5000))
	check(world.position == Vector2.ZERO, "拖不出地图左上边界")
	world.position = home._clamp_cam(Vector2(-99999, -99999))
	check(world.position == home.size - TA.WORLD, "拖不出地图右下边界")
	main.open("settings")
	await process_frame
	var p0: Vector2 = world.position
	_press(home, Vector2(360, 700), true)
	_move(home, Vector2(200, 400))
	_press(home, Vector2(200, 400), false)
	check(world.position == p0, "弹窗打开时拖不动下面的地图")
	main.close_all()
	await process_frame
	# 新手引导的黑罩盖着时不能拖；引导期间没有黑罩时照样能拖
	var guide = main._guide
	var was: bool = guide.visible
	guide.visible = true
	_press(home, Vector2(360, 700), true)
	_move(home, Vector2(200, 400))
	_press(home, Vector2(200, 400), false)
	check(world.position == p0, "新手引导黑罩盖着时地图不动")
	guide.visible = false
	g.tutorial_on = true
	_press(home, Vector2(360, 700), true)
	_move(home, Vector2(420, 760))
	_press(home, Vector2(420, 760), false)
	check(world.position != p0, "新手引导期间没有黑罩时也能拖")
	home._fling = Vector2.ZERO
	guide.visible = was
	g.tutorial_on = false
	# 下一处地块在屏幕外时出现箭头，点一下镜头对过去
	world.position = home._clamp_cam(Vector2(-99999, 0))
	home._update_camera(0.016)
	check(home._arrow.visible, "下一处地块在屏幕外时显示箭头")
	home.focus_next(false)
	home._update_camera(0.016)
	check(not home._arrow.visible, "对准以后箭头消失")
	# 滚轮缩放：鼠标下面那块地不动
	var anchor := Vector2(360, 700)
	var wp0: Vector2 = (anchor - world.position) / world.scale.x
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = anchor
	home._input(wheel)
	check(world.scale.x > 1.05, "滚轮向上放大")
	var wp1: Vector2 = (anchor - world.position) / world.scale.x
	check(wp0.distance_to(wp1) < 1.0, "缩放时鼠标下面那块地不动")
	for i in 30: home._input(wheel)
	check(is_equal_approx(world.scale.x, home.ZOOM_MAX), "放大到上限为止")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for i in 60: home._input(wheel)
	check(is_equal_approx(world.scale.x, home._zoom_min()), "缩小到刚好铺满屏幕为止")
	check(world.position.x <= 0.0 and world.position.x + TA.WORLD.x * world.scale.x >= home.size.x - 0.5, "缩小后地图仍盖满屏幕")
	# 双指张开放大
	var z0: float = world.scale.x
	for idx in 2:
		var t := InputEventScreenTouch.new()
		t.index = idx; t.pressed = true; t.position = Vector2(300 + idx * 120, 700)
		home._input(t)
	for step in 5:
		var dr := InputEventScreenDrag.new()
		dr.index = 1; dr.position = Vector2(420 + step * 30, 700)
		home._input(dr)
	check(world.scale.x > z0 * 1.3, "双指张开放大")
	for idx in 2:
		var t := InputEventScreenTouch.new()
		t.index = idx; t.pressed = false; t.position = Vector2(300, 700)
		home._input(t)
	check(not home._pinching, "手指都松开后结束双指缩放")
	print("RESULT ", failures, " failures")
	quit(0 if failures == 0 else 1)
