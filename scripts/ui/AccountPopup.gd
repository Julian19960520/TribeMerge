extends RefCounted
## 设置 →「账号与数据」：账号 ID、绑定状态、最近同步、立即同步、账号转移码、换设备登录。
## 登录别的账号后弹出选择：用云端进度（推荐，默认）或保留本机进度；两边都有明显进度时额外提醒。

const R := Rect2(36, 150, 648, 1180)

static func open() -> PopupBase:
	var p := PopupBase.new()
	_build(p)
	G.main._attach_popup(p)
	return p

static func _build(p: PopupBase) -> void:
	var r := R
	Popups.frame(p, r, "账号与数据", Art.TEAL)
	if not G.server_mode():
		var offline := UI.lbl(p.box, "当前为本地试玩版\n进度自动保存在此浏览器\n云存档和换设备登录暂未开放", Rect2(72, 400, 576, 230), 28, Art.INK)
		offline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var x0 := r.position.x + 36
	var w := r.size.x - 72
	var y := r.position.y + 70
	var c = G.get_node("/root/Cloud")

	var info := UI.lbl(p.box, "", Rect2(x0, y, w, 150), 24, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var refresh := func():
		info.text = _status_text(c, {})
	refresh.call()
	_load_info(c, info)
	y += 160

	var sync := UI.btn(p.box, Rect2(x0, y, w, 70), "立即同步", "green", Callable(), 30)
	sync.pressed.connect(func():
		if not c.can_talk():
			G.main.toast("连不上服务器，请稍后再试" if c.kicked == "" else c._kick_text(c.kicked))
			return
		c.flush()
		await G.get_tree().create_timer(0.8).timeout
		if is_instance_valid(info):
			_load_info(c, info))
	y += 96

	Popups.section(p.box, "账号转移码", y, Color("8a5a30"), r.get_center().x)
	y += 50
	var code_lbl := UI.lbl(p.box, "", Rect2(x0, y, w, 90), 26, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
	code_lbl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var show_code := func():
		code_lbl.text = ("账号 ID：%s\n转移码：%s" % [c.account_id, c.transfer_code]) if c.transfer_code != "" \
			else "还没有转移码。换设备前先生成一个，记下「账号 ID + 转移码」。"
	show_code.call()
	y += 96
	var gen := UI.btn(p.box, Rect2(x0, y, w, 64), "重新生成转移码" if c.transfer_code != "" else "生成转移码", "orange", Callable(), 26)
	gen.pressed.connect(func():
		var code: String = await c.make_transfer_code()
		if code == "":
			G.main.toast("连不上服务器，请稍后再试")
			return
		show_code.call()
		gen.text = "重新生成转移码"
		G.main.toast("新转移码已生成，旧的作废"))
	y += 90

	Popups.section(p.box, "在这台设备登录其他账号", y, Color("8a5a30"), r.get_center().x)
	y += 50
	var acc_in := _line(p.box, Rect2(x0, y, w, 60), "账号 ID（TRB 开头）")
	y += 72
	var code_in := _line(p.box, Rect2(x0, y, w, 60), "转移码")
	y += 76
	var login := UI.btn(p.box, Rect2(x0, y, w, 64), "用转移码登录", "teal", Callable(), 26)
	login.pressed.connect(func():
		var res: Dictionary = await c.login_transfer(acc_in.text, code_in.text)
		_after_login(p, c, res))
	y += 92

	Popups.section(p.box, "登录渠道（开发用 mock）", y, Color("8a5a30"), r.get_center().x)
	y += 50
	var mock_in := _line(p.box, Rect2(x0, y, w, 60), "mock 用户名")
	y += 76
	var half := (w - 20) * 0.5
	var bind := UI.btn(p.box, Rect2(x0, y, half, 64), "绑定到本账号", "orange", Callable(), 24)
	bind.pressed.connect(func():
		if mock_in.text.strip_edges() == "":
			return
		var res: Dictionary = await c.bind_provider("mock", "mock:" + mock_in.text.strip_edges())
		G.main.toast("已绑定" if res.get("ok", false) else str(res.get("message", "绑定失败")))
		if is_instance_valid(info):
			_load_info(c, info))
	var mlogin := UI.btn(p.box, Rect2(x0 + half + 20, y, half, 64), "用它登录", "teal", Callable(), 24)
	mlogin.pressed.connect(func():
		if mock_in.text.strip_edges() == "":
			return
		var res: Dictionary = await c.login_provider("mock", "mock:" + mock_in.text.strip_edges())
		_after_login(p, c, res))

	var x := UI.hit(p.box, Rect2(r.end.x - 52, r.position.y - 24, 70, 70), p.close)
	x.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)

static func _status_text(c, info: Dictionary) -> String:
	var lines := []
	lines.append("账号 ID：%s" % (c.account_id if c.account_id != "" else G.player_id))
	if c.kicked != "":
		lines.append("状态：" + c._kick_text(c.kicked))
	elif not c.enabled:
		lines.append("状态：云服务已关闭（单机）")
	else:
		lines.append("状态：" + ("在线" if c.online else "离线，连上后自动同步"))
	var binds: Array = info.get("bindings", [])
	var has_code := bool(info.get("has_transfer_code", c.transfer_code != ""))
	lines.append("绑定：转移码 %s　mock %s" % ["✓" if has_code else "—", "✓" if binds.has("mock") else "—"])
	var t: float = float(c.last_sync)
	if info.get("last_sync_at") != null:
		t = float(info["last_sync_at"])
	lines.append("最近同步：%s" % (Time.get_datetime_string_from_unix_time(int(t) + 8 * 3600, true) if t > 0.0 else "还没有"))
	if not c.events.is_empty():
		lines.append("待结算：%d 件（交单 / 收取等）" % c.events.size())
	return "\n".join(lines)

static func _load_info(c, lbl: Label) -> void:
	var d: Dictionary = await c.account_info()
	if is_instance_valid(lbl):
		lbl.text = _status_text(c, d if d.get("ok", false) else {})

## 登录成功后让玩家选用哪边的进度
static func _after_login(p: PopupBase, c, res: Dictionary) -> void:
	if not res.get("ok", false):
		G.main.toast(str(res.get("message", "登录失败")))
		return
	if res.get("same", false):
		G.main.toast("已重新登录")
		p.close()
		return
	var cloud: Dictionary = res.get("cloud", {})
	var local: Dictionary = res.get("local", {})
	var q := PopupBase.new()
	var r := Rect2(60, 420, 600, 640)
	Popups.frame(q, r, "选择进度", Art.AMBER)
	var both: bool = c.has_progress(cloud) and c.has_progress(local)
	var txt := "云端账号 %s：等级 %d，已建 %d 件\n本机进度：等级 %d，已建 %d 件" % [
		str(res.get("account_id", "")), int(cloud.get("level", 1)), int(cloud.get("parts", 0)),
		int(local.get("level", 1)), int(local.get("parts", 0))]
	if both:
		txt += "\n\n两边都有进度！选「用云端进度」后，本机这份进度会被丢弃，找不回来。"
	var t := UI.lbl(q.box, txt, Rect2(r.position.x + 36, r.position.y + 70, r.size.x - 72, 280), 26, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var use := UI.btn(q.box, Rect2(r.position.x + 40, r.position.y + 380, r.size.x - 80, 90), "用云端进度（推荐）", "green", Callable(), 32)
	use.pressed.connect(func():
		q.close()
		p.close()
		await c.use_cloud_login())
	var keep := UI.btn(q.box, Rect2(r.position.x + 40, r.position.y + 496, r.size.x - 80, 80), "保留本机进度", "grey", Callable(), 28)
	keep.pressed.connect(func():
		q.close()
		await c.keep_local_login()
		G.main.toast("已保留本机进度"))
	G.main._attach_popup(q)

static func _line(parent: Node, r: Rect2, hint: String) -> LineEdit:
	UI.box(parent, r, func(ci, sz):
		var b := Art.rrect(Rect2(Vector2(1, 1), sz - Vector2(2, 2)), 12, 2, 0.15)
		ci.draw_colored_polygon(b, Color.WHITE)
		Art.outline(ci, b, 2.0, Color("c9a774")), false).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var e := LineEdit.new()
	e.position = r.position
	e.size = r.size
	e.placeholder_text = hint
	e.add_theme_font_size_override("font_size", 26)
	e.add_theme_color_override("font_color", Art.INK)
	e.add_theme_color_override("caret_color", Art.INK)
	e.add_theme_color_override("font_placeholder_color", Color("a09080"))
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 14
	empty.content_margin_right = 14
	for s in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(s, empty)
	if G.font_body:
		e.add_theme_font_override("font", G.font_body)
	parent.add_child(e)
	return e
