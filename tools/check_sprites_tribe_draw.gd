extends RefCounted
const T := preload("res://scripts/sprites/tribe.gd")

static func _full() -> Dictionary:
	var full := {}
	var k := 0
	for b in Data.BUILDS:
		# 各区域建到不同阶段，地基也能看到
		full[str(b["id"])] = k % (Data.build_stages(b) + 1)
		k += 1
	full["fire"] = Data.build_stages(Data.build_def("fire"))
	return full

## 原来 TribeArt.village 的画法
static func live_village(ci: CanvasItem, builds: Dictionary, level: int) -> void:
	for b in Data.BUILDS:
		var id := str(b.get("id", ""))
		var parts := Data.build_parts(b)
		var st := clampi(int(builds.get(id, 0)), 0, parts.size())
		var open := level >= Data.build_unlock(b)
		T.live_plot(ci, TribeArt.area_at(id), id, open)
		var order: Array = range(st)
		order.sort_custom(func(a, c): return TribeArt.part_at(id, a).y < TribeArt.part_at(id, c).y)
		if open and st < parts.size():
			T.live_found(ci, TribeArt.part_at(id, st), st)
		for k in order:
			T.live_part(ci, str(parts[k].get("id", "")), TribeArt.part_at(id, k), TribeArt.VS)

static func village(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("8fbf50"))
	var builds := _full()
	live_village(ci, builds, 10)
	ci.draw_rect(Rect2(718, 0, 4, 1480), Color.BLACK)
	# 右半边：贴图版（同 TribeArt.village，整体右移 720）
	var off := Vector2(720, 0)
	for b in Data.BUILDS:
		var id := str(b.get("id", ""))
		var parts := Data.build_parts(b)
		var st := clampi(int(builds.get(id, 0)), 0, parts.size())
		var open := 10 >= Data.build_unlock(b)
		var at := TribeArt.area_at(id) + off
		Sprites.draw(ci, TribeArt.plot_key(id, open), Rect2(at + TribeArt.PLOT_BOX.position, TribeArt.PLOT_BOX.size))
		var order: Array = range(st)
		order.sort_custom(func(a, c): return TribeArt.part_at(id, a).y < TribeArt.part_at(id, c).y)
		if open and st < parts.size():
			var gp := TribeArt.part_at(id, st) + off
			Sprites.draw(ci, "tribe_found_%d" % st, Rect2(gp + TribeArt.FOUND_BOX.position, TribeArt.FOUND_BOX.size))
		for k in order:
			TribeArt.part(ci, str(parts[k].get("id", "")), TribeArt.part_at(id, k) + off, TribeArt.VS)

static func parts(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("f3e6cc"))
	ci.draw_rect(Rect2(698, 0, 4, sz.y), Color.BLACK)
	for side in 2:
		var o := Vector2(side * 700, 0)
		var live := side == 0
		# 弹窗图标：正常 / 置灰
		var kinds := ["campfire", "chiefhut", "totem", "sacredfire", "smokehouse", "wheel"]
		for i in kinds.size():
			var r := Rect2(o + Vector2(10 + i * 112, 10), Vector2(104, 120))
			ci.draw_rect(r, Color("ecd9b3"))
			var r2 := Rect2(o + Vector2(10 + i * 112, 140), Vector2(104, 120))
			ci.draw_rect(r2, Color("dcc9a2"))
			if live:
				_live_icon(ci, kinds[i], r, false)
				_live_icon(ci, kinds[i], r2, true)
			else:
				TribeArt.icon(ci, kinds[i], r, false)
				TribeArt.icon(ci, kinds[i], r2, true)
		# 建造中的剪影（挤压）和弹出时的拉伸
		var at := o + Vector2(90, 400)
		var fc := Color(1, 0.97, 0.88, 0.5)
		if live:
			T.flat = fc
			T.live_part(ci, "kilndome", at, TribeArt.VS, Vector2(1.0, 0.5))
			T.flat = Color(0, 0, 0, 0)
			T.live_part(ci, "kilndome", at + Vector2(140, 0), TribeArt.VS, Vector2(0.88, 1.22))
			ci.draw_set_transform(at + Vector2(300, -40), -0.4, Vector2.ONE * 0.9)
			T.live_hammer(ci, Vector2.ZERO)
		else:
			TribeArt.part(ci, "kilndome", at, TribeArt.VS, Vector2(1.0, 0.5), "_flat", fc)
			TribeArt.part(ci, "kilndome", at + Vector2(140, 0), TribeArt.VS, Vector2(0.88, 1.22))
			ci.draw_set_transform(at + Vector2(300, -40), -0.4, Vector2.ONE * 0.9)
			Sprites.draw(ci, "tribe_hammer", T.HAMMER_BOX)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var bc := o + Vector2(500, 380)
		if live:
			Art.dashed(ci, Art.ell(bc, Vector2(36, 13), 5, 0.0, 18, 0.0, 0.0), 7, 6, Color(1, 1, 1, 0.9), 2.5)
			ci.draw_colored_polygon(Art.ell(bc + Vector2(80, 0), Vector2(20, 16), 7, 0.1, 12), Color(0.93, 0.85, 0.7, 0.75))
			ci.draw_colored_polygon(Art.star_pts(bc + Vector2(140, 0), 9, 9 * 0.42, 4, 3), Color(1, 0.9, 0.4))
		else:
			Sprites.draw(ci, "tribe_build_ring", Rect2(bc - Vector2(40, 17), Vector2(80, 34)))
			Sprites.at(ci, "tribe_dust", bc + Vector2(80, 0), 20.0 / T.DUST_R, 0.0, Color(0.93, 0.85, 0.7, 0.75))
			Sprites.at(ci, "tribe_star", bc + Vector2(140, 0), 9.0 / T.STAR_R, 0.0, Color(1, 0.9, 0.4))
		# 小人
		for role in 10:
			var feet := o + Vector2(40 + role * 66, 560)
			if live:
				T.live_walker(ci, role, feet)
			else:
				var box := T.walker_box(role)
				Sprites.draw(ci, "tribe_walker_%d" % role, Rect2(feet + box.position, box.size))
		# 气泡
		var anchor := o + Vector2(200, 700)
		var br := Rect2(anchor + Vector2(-130, -14 - 70), Vector2(300, 70))
		if live:
			var tail := Art.poly([Vector2(anchor.x - 9, br.end.y - 2), Vector2(anchor.x + 9, br.end.y - 2), anchor + Vector2(2, -2)], 3, 0.2)
			var b := Art.rrect(br, 14, 9, 0.4)
			Art.dilate(ci, b, 3.0, Art.INK)
			Art.dilate(ci, tail, 3.0, Art.INK)
			ci.draw_colored_polygon(b, Color(1, 0.99, 0.95))
			ci.draw_colored_polygon(tail, Color(1, 0.99, 0.95))
		else:
			Sprites.draw(ci, "tribe_bubble", br)
			Sprites.draw(ci, "tribe_bubble_tail", Rect2(anchor + T.TAIL_BOX.position, T.TAIL_BOX.size))
		# 木牌、通行证卡、奖杯
		for k in 2:
			var tp := o + Vector2(20 + k * 170, 740)
			if live:
				T.live_tag_base(ci, tp, T.TAG_SIZE, "stone", k == 0)
				ci.draw_colored_polygon(Art.rrect(Rect2(tp + Vector2(48, 33), Vector2(50, 9)), 4.5, 3, 0.2), Art.MOSS)
			else:
				Sprites.draw(ci, T.tag_key("stone", k == 0), Rect2(tp, T.TAG_SIZE))
				Sprites.draw(ci, "tribe_tag_fill", Rect2(tp + Vector2(48, 33), Vector2(50, 9)), Art.MOSS)
		for k in 2:
			var pp := o + Vector2(20 + k * 150, 820)
			if live:
				T.live_pass_base(ci, pp, T.PASS_SIZE, k == 1)
				T.live_pass_fill(ci, Rect2(pp + Vector2(22, 76), Vector2(48, 11)))
			else:
				Sprites.draw(ci, "tribe_pass_prem" if k == 1 else "tribe_pass", Rect2(pp, T.PASS_SIZE))
				Sprites.draw(ci, "tribe_pass_fill", Rect2(pp + Vector2(22, 76), Vector2(48, 11)))
		var tc := o + Vector2(400, 880)
		if live: T.live_trophy(ci, tc)
		else: Sprites.draw(ci, "tribe_trophy", Rect2(tc + T.TROPHY_BOX.position, T.TROPHY_BOX.size))
		# 转场帘木杆（截一段）和皮章
		var pole := o + Vector2(-20, 1010)
		if live: T.live_wipe_pole(ci, pole)
		else: Sprites.draw(ci, "tribe_wipe_pole", Rect2(pole, Vector2(760, 30)))
		var bdg := o + Vector2(350, 1250)
		if live: T.live_wipe_badge(ci, bdg, 0)
		else: Sprites.draw(ci, "tribe_wipe_badge", Rect2(bdg + T.BADGE_BOX.position, T.BADGE_BOX.size))

## 原来 TribeArt.icon 的画法
static func _live_icon(ci: CanvasItem, kind: String, r: Rect2, dim: bool) -> void:
	var h := float(TribeArt._HEIGHT.get(kind, 80))
	var w := float(TribeArt._WIDTH.get(kind, 100))
	var s := minf(minf(r.size.y * 0.8 / h, r.size.x * 0.86 / w), 1.5)
	T.rim = not dim
	if dim:
		T.flat = Color("8f7a5e")
	T.live_part(ci, kind, Vector2(r.get_center().x, r.end.y - r.size.y * 0.1), s)
	T.flat = Color(0, 0, 0, 0)
	T.rim = false
