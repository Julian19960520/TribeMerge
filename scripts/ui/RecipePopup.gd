extends RefCounted
## 配方详情：上面是菜（台座 + 光晕），中间一排材料格（棋盘上已经有的打勾），下面一条制作时间。
## 新手做菜那一课会按 recipe / recipe_mats / recipe_time 几块区域逐个点亮讲解，区域位置要跟着版面。
const SLOT := 116.0
const GAP := 18.0

static func create(id: String) -> PopupBase:
	var key := id.trim_prefix("dish_")
	if not Data.DISHES.has(key): return null
	var d: Dictionary = Data.DISHES[key]
	var p := PopupBase.new()
	var rect := Rect2(58, 300, 604, 740)
	Popups.frame(p, rect, TextCatalog.source("ui.recipepopup.6db1b0abacb2"), Art.OCHRE)
	var mats: Array = d["mats"]
	var row_w := float(mats.size()) * SLOT + float(maxi(mats.size() - 1, 0)) * GAP
	var mats_rect := Rect2(360.0 - row_w * 0.5 - 18.0, 682, row_w + 36.0, SLOT + 36.0)
	var time_rect := Rect2(130, 900, 460, 76)
	# 底层：菜的光晕台座、材料托盘、时间条底
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		var dc := Vector2(360, 468)
		for k in 3:
			ci.draw_circle(dc, 98.0 - k * 18.0, Color(1, 0.86, 0.45, 0.12 + 0.06 * k))
		Sprites.at(ci, "pop_spot_shadow", dc + Vector2(0, 66), 2.2, 0.0, Color(0.35, 0.2, 0.08, 0.28))
		Sprites.draw(ci, "pop_inner14", mats_rect, Color("f1e0bd"))
		for k in mats.size():
			var slot := _slot_rect(k, mats.size())
			Sprites.draw(ci, "pop_inner14", slot, Color("fff8e8"))
		Sprites.draw(ci, "pop_inner14", time_rect, Color("f1e0bd"))
		_clock(ci, time_rect.position + Vector2(48, time_rect.size.y * 0.5), 22.0), false)
	UI.icon(p.box, id, Vector2(360, 462), 164)
	UI.lbl(p.box, str(d["name"]), Rect2(100, 560, 520, 48), 36, Art.INK)
	Popups.section(p.box, TextCatalog.source("ui.recipepopup.a8ff5639f884"), 626)
	for k in mats.size():
		var mat := str(mats[k])
		var slot := _slot_rect(k, mats.size())
		UI.icon(p.box, mat, slot.get_center(), 96)
		var hit := UI.hit(p.box, slot, func(): G.main.open("item_info", mat))
		hit.sound = "pop"
	# 棋盘上已经有的材料打勾（随棋盘变化）
	var checks := UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		var used := []
		for k in mats.size():
			var cell := G.rules.orders.board_has(str(mats[k]), used)
			if cell < 0: continue
			used.append(cell)
			var slot := _slot_rect(k, mats.size())
			Paint.check_mark(ci, slot.end - Vector2(20, 20), 0.8), false)
	Popups.live(checks, G.board_changed, checks.queue_redraw)
	var seconds := int(d["secs"])
	var tl := UI.lbl(p.box, TextCatalog.source("ui.recipepopup.c18455486abf") % [seconds / 60, seconds % 60], Rect2(time_rect.position.x + 84, time_rect.position.y, time_rect.size.x - 100, time_rect.size.y), 28, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.set_meta("recipe", rect)
	p.set_meta("recipe_mats", mats_rect.grow(6))
	p.set_meta("recipe_time", time_rect.grow(8))
	p.set_meta("onboarding_close", Rect2(610, 276, 70, 70))
	return p

static func _slot_rect(k: int, n: int) -> Rect2:
	var row_w := float(n) * SLOT + float(maxi(n - 1, 0)) * GAP
	return Rect2(360.0 - row_w * 0.5 + float(k) * (SLOT + GAP), 700, SLOT, SLOT)

## 时间条左边的闹钟（和订单卡上做菜时那只同一种画法）
static func _clock(ci: CanvasItem, c: Vector2, r: float) -> void:
	for sx in [-1.0, 1.0]:
		var bell := c + Vector2(sx * r * 0.62, -r * 0.86)
		ci.draw_circle(bell, 6.5, Art.INK)
		ci.draw_circle(bell, 4.5, Color("f08a2c"))
	ci.draw_circle(c, r + 3.0, Art.INK)
	ci.draw_circle(c, r, Color("f08a2c"))
	ci.draw_circle(c, r - 5.0, Art.BONE)
	for k in 4:
		var dir := Vector2.UP.rotated(PI * 0.5 * k)
		ci.draw_line(c + dir * (r - 9.0), c + dir * (r - 6.5), Art.INK, 2.4, true)
	ci.draw_line(c, c + Vector2(0, -(r - 8.0)), Art.INK, 3.0, true)
	ci.draw_line(c, c + Vector2(r - 10.0, 0).rotated(0.5), Art.INK, 3.0, true)
	ci.draw_circle(c, 3.0, Art.INK)
