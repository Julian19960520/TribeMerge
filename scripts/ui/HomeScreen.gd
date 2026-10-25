class_name HomeScreen
extends Control

var _spots_root: Control
var _event_lbl: Label

func _ready() -> void:
	size = Vector2(720, 1480)
	mouse_filter = MOUSE_FILTER_IGNORE
	UI.box(self, Rect2(0, 0, 720, 1480), func(ci, sz): Paint.village(ci, sz, G.builds))
	UI.box(self, Rect2(400, 920, 140, 140), func(ci, sz): Paint.mascot(ci, sz * 0.5, 84))
	_spots_root = Control.new()
	_spots_root.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_spots_root)
	_build_spots()

	var ev := UI.hit(self, Rect2(14, 160, 124, 150), func(): G.main.open("event"))
	ev.extra = func(ci, sz):
		var r := Rect2(6, 6, sz.x - 12, sz.y - 40)
		var b := Art.rrect(r, 18, 91, 1.0)
		Art.dilate(ci, b, 3.0, Art.INK)
		ci.draw_colored_polygon(b, Color("3c4f8a"))
		ci.draw_circle(Vector2(sz.x - 34, 30), 12, Color("fff1b8"))
		Paint.cards_icon(ci, Vector2(sz.x * 0.5, 66), 0.9)
		Paint.badge_num(ci, Vector2(sz.x - 12, 12))
	UI.lbl(ev, "丰收祭", Rect2(0, 92, 124, 30), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	_event_lbl = UI.lbl(ev, "", Rect2(0, 118, 124, 30), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	UI.lbl(ev, "!", Rect2(96, 0, 32, 26), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 4, Art.INK)

	var deal := UI.hit(self, Rect2(14, 326, 124, 150), func(): G.main.open("store"))
	deal.extra = func(ci, sz):
		var r := Rect2(6, 6, sz.x - 12, sz.y - 40)
		var b := Art.rrect(r, 18, 92, 1.0)
		Art.dilate(ci, b, 3.0, Art.INK)
		ci.draw_colored_polygon(b, Color("e7b45a"))
		Art.item(ci, "chest_1", Vector2(sz.x * 0.5, 62), 90)
	UI.lbl(deal, "每日特惠", Rect2(0, 92, 124, 30), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)

	var help := UI.btn(self, Rect2(30, 494, 84, 84), "?", "orange", func(): G.main.open("howto"), 44)
	help.is_round = true
	var gear := UI.btn(self, Rect2(626, 150, 80, 80), "", "teal", func(): G.main.open("settings"))
	gear.is_round = true
	gear.glyph = "gear"

	var build := UI.btn(self, Rect2(16, 1316, 124, 128), "", "wood", _open_next_build)
	build.extra = func(ci, sz): Paint.hammer(ci, sz * 0.5 + Vector2(0, -6), 1.1)
	UI.lbl(build, "建造", Rect2(0, 86, 124, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var bk := UI.btn(self, Rect2(150, 1330, 110, 112), "", "hide", func(): G.main.open("book"))
	bk.extra = func(ci, sz): Paint.book(ci, sz * 0.5 + Vector2(0, -10), 0.9)
	UI.lbl(bk, "图鉴", Rect2(0, 72, 110, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var cd := UI.btn(self, Rect2(270, 1330, 110, 112), "", "hide", func(): G.main.open("event"))
	cd.extra = func(ci, sz): Paint.cards_icon(ci, sz * 0.5 + Vector2(0, -10), 0.85)
	UI.lbl(cd, "卡册", Rect2(0, 72, 110, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var go := UI.btn(self, Rect2(398, 1310, 306, 136), "去合成", "green", func(): G.main.show_screen("board"), 54)
	go.extra = func(ci, sz):
		Art.item(ci, "berry_2", Vector2(sz.x - 34, 20), 56)
		Art.item(ci, "meat_4", Vector2(30, sz.y - 22), 50)

	G.changed.connect(_build_spots)

func _process(_d: float) -> void:
	if _event_lbl and Engine.get_process_frames() % 30 == 0:
		_event_lbl.text = G.fmt_time(G.event_left())

func _build_spots() -> void:
	for c in _spots_root.get_children():
		c.queue_free()
	for b in Data.BUILDS:
		var id: String = b["id"]
		var st: int = G.builds.get(id, 0)
		var p: Vector2 = Paint.SPOTS[id]
		var done: bool = st >= b["stages"]
		var bub := UI.hit(_spots_root, Rect2(p + Vector2(-46, -170 if id != "fire" else -150), Vector2(92, 108)), _open_build.bind(id))
		bub.visible = not done
		bub.extra = func(ci, sz):
			var c := Vector2(sz.x * 0.5, 44)
			var tail := Art.poly([c + Vector2(-12, 34), c + Vector2(12, 34), c + Vector2(0, 58)], 5)
			Art.dilate(ci, tail, 3.0, Art.INK)
			ci.draw_colored_polygon(tail, Art.BONE)
			var circ := Art.ell(c, Vector2(40, 40), 93, 0.03, 22)
			Art.dilate(ci, circ, 3.0, Art.INK)
			ci.draw_colored_polygon(circ, Art.BONE)
			ci.draw_colored_polygon(tail, Art.BONE)
			Paint.hammer(ci, c + Vector2(0, -2), 0.55)
			var t := float(st) / float(b["stages"])
			ci.draw_arc(c, 36, -PI * 0.5, -PI * 0.5 + TAU * t, 24, Art.MOSS, 6.0, true)
		UI.lbl(bub, "%d/%d" % [st, b["stages"]], Rect2(0, 76, 92, 30), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	for c in get_children():
		if c is DrawBox:
			c.queue_redraw()

func _open_build(id: String) -> void:
	G.main.open("build", id)

func _open_next_build() -> void:
	for b in Data.BUILDS:
		if int(G.builds.get(b["id"], 0)) < int(b["stages"]):
			G.main.open("build", b["id"])
			return
	G.main.toast("部落已经全部建好啦！")
