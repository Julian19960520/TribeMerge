extends RefCounted
const Core := preload("res://scripts/sprites/ui_core.gd")

static func paint(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("f3e6cc"))
	for side in 2:
		var o := Vector2(side * 600, 0)
		var live := side == 0
		var y := 20.0
		for st in ["green", "orange", "grey"]:
			var r := Rect2(o + Vector2(20, y), Vector2(300 if st == "green" else 180, 96 if st == "green" else 60))
			if live: Core.live_button(ci, r, st)
			else: Paint.button(ci, r, st)
			y += r.size.y + 24
		if live: Core.live_round_btn(ci, o + Vector2(420, 70), 44, "teal")
		else: Paint.round_btn(ci, o + Vector2(420, 70), 44, "teal")
		var pr := Rect2(o + Vector2(20, 300), Vector2(540, 420))
		if live: Core.live_panel(ci, pr)
		else: Paint.panel(ci, pr)
		var br := Rect2(o + Vector2(60, 270), Vector2(460, 90))
		if live: Core.live_banner(ci, br, Art.TEAL)
		else: Paint.banner(ci, br, Art.TEAL)
		var bar := Rect2(o + Vector2(40, 760), Vector2(400, 30))
		if live: Core.live_bar(ci, bar, 0.6, Art.MOSS)
		else: Paint.bar(ci, bar, 0.6, Art.MOSS)
		var bar2 := Rect2(o + Vector2(40, 810), Vector2(300, 12))
		if live: Core.live_bar(ci, bar2, 0.4, Art.FIRE)
		else: Paint.bar(ci, bar2, 0.4, Art.FIRE)
		var pill := Rect2(o + Vector2(40, 850), Vector2(200, 44))
		if live: Core.live_pill(ci, pill)
		else: Paint.pill(ci, pill)
		for k in 4:
			var c := o + Vector2(300 + k * 60, 870)
			match k:
				0: (Core.live_close_btn(ci, c, 26) if live else Paint.close_btn(ci, c, 26))
				1: (Core.live_check_mark(ci, c, 1.2) if live else Paint.check_mark(ci, c, 1.2))
				2: (Core.live_plus_badge(ci, c) if live else Paint.plus_badge(ci, c))
				3: (Core.live_badge_num(ci, c, 7, 12) if live else Paint.badge_num(ci, c, 7, 12))
		if live: Core.live_level_badge(ci, o + Vector2(120, 1000), 130)
		else: Paint.level_badge(ci, o + Vector2(120, 1000), 130)
		var sp := Rect2(o + Vector2(260, 960), Vector2(300, 110))
		if live: Core.live_speech(ci, sp, true)
		else: Paint.speech(ci, sp, true)
		if live: Core.live_cell_bracket(ci, Rect2(o + Vector2(60, 1120), Vector2(90, 90)))
		else: Paint.cell_bracket(ci, Rect2(o + Vector2(60, 1120), Vector2(90, 90)))
