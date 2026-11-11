extends Control
## 产线设计预览：一页一条产线，点物品放大。
## 运行「产线预览.bat」打开；加参数 --prod-shots 会把每页截图存到 shots/ 后退出。

const W := 1640
const H := 1000
const CARD := Vector2(96, 122)
const GAP := 4.0
const LV_COLS := [Color("d6ecb0"), Color("8cc63f"), Color("4fa39a"), Color("2f6fa8"), Color("8a4fb0")]
const BG := Color("2a1a0f")
const PANEL := Color("f6e7c8")
const PANEL_D := Color("ead3a6")

var tab := 0
var sel := {"kind": "G", "lv": 1}
var hits := []
var tab_rects := []

func _ready() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(W, H)
	## 屏幕放不下 1640×1000 时整体等比缩小，否则右边的概率表会被裁掉
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen).size
	var fit := minf(float(usable.x - 16) / float(W), float(usable.y - 48) / float(H))
	if fit < 1.0 and not OS.get_cmdline_user_args().has("--prod-shots"):
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		win.content_scale_size = Vector2i(W, H)
		win.size = Vector2i(int(float(W) * fit), int(float(H) * fit))
	win.move_to_center()
	win.title = "产线设计预览"
	size = Vector2(W, H)
	G.boil_tick.connect(queue_redraw)
	if OS.get_cmdline_user_args().has("--prod-shots"):
		_shots.call_deferred()

func _shots() -> void:
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(0.6).timeout
	for i in ProdData.LINES.size():
		tab = i
		var l: Dictionary = ProdData.LINES[i]
		sel = {"kind": "G", "lv": (l["G"] as Array).size()}
		queue_redraw()
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("prod_%s.png" % l["id"]))
	get_tree().quit()

func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = e.position
	for i in tab_rects.size():
		if (tab_rects[i] as Rect2).has_point(p):
			tab = i
			sel = {"kind": "G", "lv": 1}
			queue_redraw()
			return
	for h in hits:
		if (h["r"] as Rect2).has_point(p):
			sel = {"kind": h["kind"], "lv": h["lv"]}
			queue_redraw()
			return

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode == KEY_RIGHT or e.keycode == KEY_TAB:
			tab = (tab + 1) % ProdData.LINES.size()
		elif e.keycode == KEY_LEFT:
			tab = (tab + ProdData.LINES.size() - 1) % ProdData.LINES.size()
		else:
			return
		sel = {"kind": "G", "lv": 1}
		queue_redraw()

# ---------------------------------------------------------------- 绘制

func _txt(t: String, pos: Vector2, fs: int, col: Color = Art.INK, title: bool = false, w: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(G.font_title if title else G.font_body, pos, t, align, w, fs, col)

func _panel(r: Rect2, col: Color = PANEL, seed: int = 0) -> void:
	var pts := Art.rrect(r, 14, seed, 0.7)
	Art.dilate(self, pts, 3.0, Art.INK)
	draw_colored_polygon(pts, col)

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), BG)
	hits.clear()
	tab_rects.clear()
	var l: Dictionary = ProdData.LINES[tab]
	_draw_tabs()
	var lid: String = l["id"]
	var ng: int = (l["G"] as Array).size()
	var nm: int = (l["M"] as Array).size()
	var ns: int = (l["S"] as Array).size()
	var title := "%s线 · 生产器「%s」" % [l["name"], l["gen"]]
	_txt(title, Vector2(22, 100), 30, Color("ffd23f"), true)
	## 副标题紧跟在标题后面，标题长时自动右移，不压字
	var sub_x: float = maxf(400.0, 22.0 + G.font_title.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 24.0)
	var idle_n := int(l["idle"])
	var gen_hint := "生产器 %d 级" % ng
	if idle_n > 0:
		gen_hint += "（1-%d 级不可生产）" % idle_n
	_txt("%s   主产物「%s」%d 级   副产物「%s」%d 级" % [gen_hint, l["main_name"], nm, l["sub_name"], ns],
		Vector2(sub_x, 98), 18, Color("fff1c4"))

	var click_hint := "合成升级，每一级都能点击生产"
	if idle_n > 0:
		click_hint = "合成升级，%d 级起可点击生产" % (idle_n + 1)
	_section("生产器", click_hint, 128, Color("ffb347"))
	_row(l, "G", 150)
	_table(l, Rect2(944, 122, 680, 190))
	_section("主产物", "高概率产出 · %s" % l["main_name"], 318, Color("a5d65a"))
	_row(l, "M", 340)
	_section("副产物", "低概率产出 · %s" % l["sub_name"], 476, Color("7fd3f0"))
	_row(l, "S", 498)
	_detail(l, Rect2(20, 640, 640, 344))
	_notes(l, Rect2(676, 640, 944, 344))

func _draw_tabs() -> void:
	_txt("合合部落 · 产线设计预览", Vector2(22, 40), 28, Color("fff1c4"), true)
	var x := 430.0
	for i in ProdData.LINES.size():
		var l: Dictionary = ProdData.LINES[i]
		var r := Rect2(x, 12, 150, 42)
		tab_rects.append(r)
		var on := i == tab
		var pts := Art.rrect(r, 12, 400 + i, 0.6)
		Art.dilate(self, pts, 2.5, Art.INK)
		draw_colored_polygon(pts, Color("eaa53c") if on else Color("6e3b17"))
		_txt(l["name"], Vector2(r.position.x, r.position.y + 30), 22, Art.INK if on else Color("f6e7c8"), true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		x += 158.0

func _section(name: String, hint: String, y: float, col: Color) -> void:
	_txt(name, Vector2(22, y + 14), 22, col, true)
	_txt(hint, Vector2(110, y + 13), 16, Color(1, 0.95, 0.85, 0.7))

func _row(l: Dictionary, kind: String, y: float) -> void:
	var names: Array = l[kind]
	for i in names.size():
		var lv := i + 1
		var r := Rect2(20 + float(i) * (CARD.x + GAP), y, CARD.x, CARD.y)
		hits.append({"r": r, "kind": kind, "lv": lv})
		var idle: bool = kind == "G" and ProdData.gen_stats(l, lv).is_empty()
		var on: bool = sel["kind"] == kind and sel["lv"] == lv
		var pts := Art.rrect(r, 12, i * 3 + kind.unicode_at(0), 0.5)
		if on:
			Art.dilate(self, pts, 6.0, Color("ffd23f"))
		Art.dilate(self, pts, 2.0, Art.INK)
		draw_colored_polygon(pts, Color("cdbb98") if idle else PANEL)
		ProdArt.draw(self, l["id"], kind, lv, r.position + Vector2(CARD.x * 0.5, 52), 70)
		if idle:
			draw_colored_polygon(pts, Color(0.25, 0.18, 0.12, 0.22))
			var tag := Rect2(r.position.x + 30, r.position.y + 5, 60, 18)
			draw_rect(tag, Color("8a2f1d"))
			_txt("不可生产", Vector2(tag.position.x, tag.position.y + 14), 13, Color("fff1c4"), false, tag.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var tier := clampi((lv - 1) / 3, 0, 4)
		draw_circle(r.position + Vector2(14, 14), 11, Art.INK)
		draw_circle(r.position + Vector2(14, 14), 9, LV_COLS[tier])
		_txt(str(lv), Vector2(r.position.x + 3, r.position.y + 20), 14, Art.INK if tier < 2 else Color.WHITE, false, 22, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(names[i], Vector2(r.position.x, r.end.y - 9), 15, Art.INK, false, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func _bar(r: Rect2, dist: Array) -> void:
	var x := r.position.x
	for i in dist.size():
		var w := r.size.x * float(dist[i]) / 100.0
		if w <= 0.0:
			continue
		var seg := Rect2(x, r.position.y, w, r.size.y)
		draw_rect(seg, LV_COLS[i])
		if w >= 26.0:
			_txt("%d%%" % dist[i], Vector2(seg.position.x, seg.position.y + r.size.y - 4), 12, Art.INK if i < 2 else Color.WHITE, false, w, HORIZONTAL_ALIGNMENT_CENTER)
		x += w
	draw_rect(r, Art.INK, false, 1.5)

func _table(l: Dictionary, r: Rect2) -> void:
	_panel(r, PANEL, 77)
	var x0 := r.position.x + 12
	var y := r.position.y + 22
	_txt("等级", Vector2(x0, y), 14, Art.LEATHER_D)
	_txt("产出（物品和概率）", Vector2(x0 + 46, y), 14, Art.LEATHER_D)
	_txt("满储 / 回满", Vector2(x0 + 548, y), 14, Art.LEATHER_D)
	var ng: int = (l["G"] as Array).size()
	var rows := 0
	for lv in range(1, ng + 1):
		var st := ProdData.gen_stats(l, lv)
		if st.is_empty():
			continue
		var yy := r.position.y + 32 + float(rows) * 22.0
		if sel["kind"] == "G" and sel["lv"] == lv:
			draw_rect(Rect2(r.position.x + 4, yy - 1, r.size.x - 8, 21), Color(1, 0.82, 0.25, 0.45))
		_txt("%d级" % lv, Vector2(x0, yy + 15), 15, Art.INK)
		var bits: PackedStringArray = []
		for d in st["drops"]:
			bits.append("%s %d" % [str(d["id"]), int(d["p"])])
		_txt(" ".join(bits), Vector2(x0 + 46, yy + 15), 14, Art.INK, false, 490)
		var cd := "%d次 / %d分" % [st["charges"], st["refill"]] if st.has("charges") else "无冷却"
		_txt(cd, Vector2(x0 + 548, yy + 15), 15, Art.INK)
		rows += 1

func _detail(l: Dictionary, r: Rect2) -> void:
	_panel(r, PANEL, 91)
	var kind: String = sel["kind"]
	var lv: int = sel["lv"]
	var names: Array = l[kind]
	lv = clampi(lv, 1, names.size())
	draw_circle(r.position + Vector2(170, 180), 140, PANEL_D)
	ProdArt.draw(self, l["id"], kind, lv, r.position + Vector2(170, 170), 230)
	var tx := r.position.x + 330
	var kn := {"G": "生产器 · " + String(l["gen"]), "M": "主产物 · " + String(l["main_name"]), "S": "副产物 · " + String(l["sub_name"])}
	_txt(names[lv - 1], Vector2(tx, r.position.y + 56), 34, Art.INK, true)
	_txt(kn[kind], Vector2(tx, r.position.y + 90), 17, Art.LEATHER_D)
	_txt("第 %d 级 / 共 %d 级" % [lv, names.size()], Vector2(tx, r.position.y + 118), 17, Art.LEATHER_D)
	var y := r.position.y + 156
	var lines := []
	if lv > 1:
		lines.append("由 2 个「%s」合成" % names[lv - 2])
	if lv < names.size():
		lines.append("2 个合成「%s」" % names[lv])
	else:
		lines.append("已是最高级")
	if kind == "G":
		var st := ProdData.gen_stats(l, lv)
		if st.is_empty():
			lines.append("还不能生产，只占格子")
		else:
			for d in st["drops"]:
				lines.append("%s  %d" % [Data.name_of(str(d["id"])), int(d["p"])])
			if st.has("charges"):
				lines.append("满储 %d 次，%d 分钟回满" % [st["charges"], st["refill"]])
	for t in lines:
		_txt(t, Vector2(tx, y), 17, Art.INK)
		y += 28
	_txt("点任意物品放大 · ←/→ 切换产线", Vector2(r.position.x + 20, r.end.y - 14), 14, Color(Art.INK, 0.5))

func _notes(l: Dictionary, r: Rect2) -> void:
	_panel(r, PANEL, 93)
	var x := r.position.x + 24
	var y := r.position.y + 40
	_txt("这条线怎么玩", Vector2(x, y), 22, Art.LEATHER_D, true)
	y += 34
	var idle: int = l["idle"]
	var ng: int = (l["G"] as Array).size()
	var first := {}
	var last := {}
	for lv in range(1, ng + 1):
		var st := ProdData.gen_stats(l, lv)
		if st.is_empty():
			continue
		if first.is_empty():
			first = st
		last = st
	var tips := []
	if idle > 0:
		tips.append("「%s」1-%d 级没配产物，只能合成，放在棋盘上会占格子。" % [l["gen"], idle])
	if first.is_empty():
		tips.append("还没有配能生产的等级。")
	else:
		tips.append("配了产物的等级可以点击：每次消耗 1 火种，按概率产出列表里的一件。")
		if first.has("charges"):
			tips.append("满储次数从 %d 次到 %d 次，回满时间从 %d 分钟到 %d 分钟。" % [first["charges"], last["charges"], first["refill"], last["refill"]])
		else:
			tips.append("没有冷却，能不能继续生产只看火种够不够。")
	tips.append("最高级「%s」是这条线的终极追求，每升一级外形都会更华丽。" % (l["G"] as Array)[ng - 1])
	for t in tips:
		draw_circle(Vector2(x + 6, y - 6), 4, Art.OCHRE)
		_txt(t, Vector2(x + 20, y), 17, Art.INK)
		y += 30
	y += 12
	_txt("色块说明", Vector2(x, y), 16, Art.LEATHER_D)
	for i in 5:
		var bx := x + 90 + float(i) * 96
		draw_rect(Rect2(bx, y - 14, 18, 16), LV_COLS[i])
		draw_rect(Rect2(bx, y - 14, 18, 16), Art.INK, false, 1.2)
		_txt("%d级" % (i + 1), Vector2(bx + 24, y), 15, Art.INK)
