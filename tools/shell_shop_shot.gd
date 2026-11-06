extends SceneTree
## 集市「贝币小摊」截图 + 本地购买检查（不连服务器）。不碰真实存档：存档 / 云 / 排行 / 热卖都指向 user://shell_shot/。
## Godot --path . --script tools/shell_shop_shot.gd -- --save=user://shell_shot/s.json --cloud-off --rank-state=user://shell_shot/r.json --cloud-state=user://shell_shot/c.json --hot-file=user://shell_shot/h.json --out=DIR

## Popups 依赖自动加载的 G，不能在脚本顶部 preload（SceneTree 脚本先于自动加载编译），进场后再 load
var PopupsS

var _started := false
var out := "."
var fails: Array = []

func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _shot(name: String) -> void:
	var path := out + "/shell_shop_" + name + ".png"
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)

func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)

func _scroller(p: Node) -> Node:
	for c in p.find_children("*", "", true, false):
		if c.has_method("jump_to"):
			return c
	return null

func _open_store(main) -> Node:
	var p = main.open("store")
	await create_timer(0.6).timeout
	var sc = _scroller(p)
	if sc != null:
		sc.jump_to(1280.0)
	await create_timer(0.6).timeout
	return p

func _run() -> void:
	var g := root.get_node("G")
	g.set_process(false)
	root.get_node("Cloud").set_process(false)
	if root.has_node("Rank"):
		root.get_node("Rank").set_process(false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 6
	g.shells = 70
	g.shell_bought = {}
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	PopupsS = load("res://scripts/ui/Popups.gd")
	await create_timer(0.3).timeout
	_check(Data.STORE_SHELL.size() == 6, "store_shell.json 读到 6 件")
	for d in Data.STORE_SHELL:
		_check(typeof(d["price"]) == TYPE_INT and typeof(d["stock"]) == TYPE_INT, "%s 价格 / 库存是整数（%s）" % [d["id"], str(d["price"])])
		_check(float(d["price"]) > OrderRoll.flames(d["id"]) * OrderRoll.PAY_PER_FLAME, "%s 贝币价 %d > 交单所得 %.1f" % [d["id"], d["price"], OrderRoll.flames(d["id"]) * OrderRoll.PAY_PER_FLAME])
	var p = await _open_store(main)
	_shot("fresh")
	# 本地（--cloud-off）购买：扣贝币、记已购、放进暂存
	var stash0: int = g.stash.size()
	var ok: bool = await PopupsS._buy_offer("fruit_2", PopupsS._shell_offer("shell_0"), Vector2(360, 900))
	_check(ok and g.shells == 62 and int(g.shell_bought.get("shell_0", 0)) == 1 and g.stash.size() == stash0 + 1, "买樱桃：贝币 70→%d，已购 %s" % [g.shells, str(g.shell_bought)])
	g.shells = 30
	ok = await PopupsS._buy_offer("seed_1", PopupsS._shell_offer("shell_3"), Vector2(360, 900))
	_check(not ok and g.shells == 30, "贝币 30 买不起 52 的草籽")
	for _i in 2:
		await PopupsS._buy_offer("tool_2", PopupsS._shell_offer("shell_1"), Vector2(360, 900))
	g.shells = 30
	await PopupsS._buy_offer("tool_2", PopupsS._shell_offer("shell_1"), Vector2(360, 900))
	_check(PopupsS._shell_offer("shell_1").is_empty(), "石片买满 3 件后售罄")
	# 换轮清零
	g.shell_period = "0"
	g.check_shell_period()
	_check(g.shell_bought.is_empty(), "换轮后已购清零")
	g.shell_bought = {"shell_1": 3, "shell_0": 1}
	g.shell_period = g.shell_period_now()
	p.close()
	await create_timer(0.4).timeout
	await _open_store(main)
	await create_timer(1.2).timeout
	_shot("after_buy")
	print("RESULT: ", "PASS" if fails.is_empty() else "FAIL " + str(fails))
	quit(0 if fails.is_empty() else 1)
