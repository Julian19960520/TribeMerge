extends PopupBase
## 外星补给面板：夜空里的飞碟用牵引光把一托盘物品「放」下来。
## 上：夜空 + 飞碟 + 折扣星章 + 倒计时；中：礼包物品一排（带件数，加赠的挂小签）；
## 下：原价划掉 → 现价，大按钮。飞碟离开后物品仍然显示，只是压暗并盖「已飞走」章。
## 面板不写「订单急需」之类的话（需求 #42），选品照旧优先补订单缺口。
const R := Rect2(40, 320, 640, 850)
const SKY := Rect2(66, 380, 588, 300)
const TRAY := Rect2(66, 694, 588, 186)
const SKY_TOP := Color("1d2f55")
const SKY_BOT := Color("3e6f86")
var offer: Dictionary
var buy_btn: TButton
var clock: Label
var saucer: DrawBox
var beam: DrawBox
var shade: DrawBox
var stamp: DrawBox
var _tick := 0.0
var _busy := false
var _gone := false
var _t := 0.0
var _tex: Texture2D

func _ready() -> void:
	offer = UfoOffer.state()["offer"].duplicate(true)
	_tex = load(str(UfoOffer.config()["icon"]))
	Popups.frame(self, R, "外星补给", Art.TEAL)
	UI.box(box, Rect2(Vector2.ZERO, Vector2(720, 1480)), _paint_back)
	beam = UI.box(box, Rect2(SKY.position.x, SKY.position.y + 150, SKY.size.x, 200), _paint_beam, false)
	saucer = UI.box(box, Rect2(230, 392, 260, 184), func(ci, sz):
		ci.draw_set_transform(sz * 0.5, sin(_t * 2.0) * 0.04, Vector2.ONE)
		ci.draw_texture_rect(_tex, Rect2(-sz * 0.5, sz), false)
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE), false)
	saucer.pivot_offset = saucer.size * 0.5
	# 折扣星章
	var original := int(UfoOffer.config()["original_price_cny"])
	var price := int(UfoOffer.config()["price_cny"])
	var off := int(round(price * 10.0 / original))
	var star := UI.box(box, Rect2(78, 400, 128, 128), func(ci, sz):
		Sprites.draw(ci, "ev_ufo_star", Rect2(Vector2.ZERO, sz)))
	star.rotation = -0.16
	star.pivot_offset = star.size * 0.5
	UI.lbl(star, "%d折" % off, Rect2(0, 30, 128, 52), 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	UI.lbl(star, "限时", Rect2(0, 78, 128, 24), 18, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 4, Art.INK)
	# 倒计时
	UI.box(box, Rect2(482, 398, 158, 48), func(ci, sz):
		Sprites.draw(ci, "ev_ufo_clock", Rect2(Vector2.ZERO, sz))
		Paint.glyph(ci, "clock", Vector2(26, sz.y * 0.5), 1.0, Color("ffd23f")))
	clock = UI.lbl(box, "", Rect2(526, 398, 108, 48), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 4, Color("0f1a24"))
	# 礼包物品
	_items()
	shade = UI.box(box, TRAY, func(ci, sz):
		ci.draw_colored_polygon(Art.rrect(Rect2(Vector2.ZERO, sz), 20, 741, 0.0), Color(0.18, 0.12, 0.08, 0.45)), false)
	shade.visible = false
	stamp = UI.box(box, Rect2(TRAY.get_center().x - 150, TRAY.get_center().y - 40, 300, 80), func(ci, sz):
		Sprites.draw(ci, "ev_ufo_stamp", Rect2(Vector2.ZERO, sz)))
	UI.lbl(stamp, "飞碟已飞走", Rect2(0, 4, 300, 72), 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	stamp.pivot_offset = stamp.size * 0.5
	stamp.rotation = -0.12
	stamp.visible = false
	# 价格对比
	var row_y := 892.0
	UI.lbl(box, "原价", Rect2(120, row_y + 6, 80, 60), 24, Color("8a7560"), HORIZONTAL_ALIGNMENT_RIGHT)
	UI.lbl(box, "¥%d" % original, Rect2(204, row_y, 120, 72), 40, Color("8a7560"))
	UI.box(box, Rect2(206, row_y + 10, 116, 52), func(ci, sz):
		Sprites.draw(ci, "ev_ufo_strike", Rect2(Vector2.ZERO, sz)))
	UI.box(box, Rect2(334, row_y + 14, 70, 44), func(ci, sz):
		Sprites.draw(ci, "ev_ufo_arrow", Rect2(Vector2.ZERO, sz)))
	UI.lbl(box, "¥%d" % price, Rect2(410, row_y - 8, 190, 88), 66, Color("ffb347"), HORIZONTAL_ALIGNMENT_LEFT, 12, Art.INK)
	buy_btn = UI.btn(box, Rect2(170, 984, 380, 94), "¥%d 购买" % price, "green", _buy, 42)
	buy_btn.title_font = false
	buy_btn.name = "ufo_buy"
	UI.lbl(box, "支付暂未开放", Rect2(160, 1086, 400, 30), 19, Color("9a8468"))
	_refresh()

## 夜空、远山、星星（飞碟和光束单独一层，好做飞走动画）
func _paint_back(ci: CanvasItem, _sz: Vector2) -> void:
	Sprites.draw(ci, "ev_ufo_sky", SKY)
	Paint.vgrad(ci, Rect2(SKY.position + Vector2(10, 14), SKY.size - Vector2(20, 22)), SKY_TOP, SKY_BOT)
	for k in 34:
		var p := SKY.position + Vector2(18 + Art.srnd(k * 3 + 1) * (SKY.size.x - 36), 14 + Art.srnd(k * 5 + 2) * 170)
		var r := 1.2 + Art.srnd(k + 11) * 2.0
		ci.draw_circle(p, r, Color(1, 0.97, 0.8, 0.55 + Art.srnd(k) * 0.45))
	for k in 3:
		var p := SKY.position + Vector2(90 + k * 210 + Art.srnd(k + 40) * 60, 40 + Art.srnd(k + 50) * 70)
		Sprites.draw(ci, "ev_spark4", Rect2(p - Vector2(9, 9), Vector2(18, 18)), Color(1, 0.95, 0.7, 0.9))
	# 月牙
	var m := SKY.position + Vector2(SKY.size.x - 70, 92)
	ci.draw_circle(m, 20, Color("fff1b7"))
	ci.draw_circle(m + Vector2(9, -6), 18, SKY_TOP.lerp(SKY_BOT, 0.3))
	# 远山 + 棕榈剪影（夜空圆角内缩一点，免得山脚戳出边框）
	ci.draw_set_transform(Vector2(SKY.position.x + 12, 0), 0, Vector2.ONE)
	Paint.hills(ci, SKY.end.y - 70, SKY.size.x - 24, 22, Color("2a4a52"), 723, SKY.end.y - 8)
	Paint.hills(ci, SKY.end.y - 40, SKY.size.x - 24, 14, Color("1e3a3f"), 724, SKY.end.y - 8)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	Paint.palm(ci, Vector2(SKY.position.x + 48, SKY.end.y - 22), 80, 725, Color("17302f"))
	Paint.palm(ci, Vector2(SKY.end.x - 60, SKY.end.y - 26), 64, 726, Color("17302f"))
	Sprites.draw(ci, "ev_ufo_sky_line", SKY)
	# 托盘
	Sprites.draw(ci, "ev_ufo_tray", TRAY)

func _paint_beam(ci: CanvasItem, sz: Vector2) -> void:
	var cx: float = sz.x * 0.5
	var top := 26.0
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - 36, top), Vector2(cx + 36, top), Vector2(sz.x - 20, sz.y), Vector2(20, sz.y)]),
		Color(0.78, 0.95, 0.5, 0.20 + 0.08 * pulse))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - 20, top), Vector2(cx + 20, top), Vector2(sz.x * 0.72, sz.y), Vector2(sz.x * 0.28, sz.y)]),
		Color(0.9, 1.0, 0.7, 0.16 + 0.06 * pulse))
	for k in 7:
		var u := fmod(_t * 0.35 + float(k) / 7.0, 1.0)
		var x := cx + (Art.srnd(k * 9 + 3) - 0.5) * (80 + 380 * u)
		ci.draw_circle(Vector2(x, top + u * (sz.y - top)), 2.5, Color(1, 1, 0.85, 0.7 * (1.0 - u)))

func _items() -> void:
	var rows := UfoOffer.grouped(UfoOffer.bundle(offer.get("items", [])))
	var bonus: Array = UfoOffer.config().get("bonus_items", [])
	var n := maxi(1, rows.size())
	var cell := minf(112.0, (TRAY.size.x - 40.0) / n)
	var tile := cell - 10.0
	var x0 := TRAY.get_center().x - cell * n * 0.5
	var cy := TRAY.position.y + 20 + tile * 0.5
	for k in rows.size():
		var id := str(rows[k][0])
		var cnt := int(rows[k][1])
		var is_bonus: bool = bonus.has(id) and not offer.get("items", []).has(id)
		var cx := x0 + cell * (k + 0.5)
		UI.box(box, Rect2(cx - tile * 0.5, cy - tile * 0.5, tile, tile), func(ci, sz):
			Sprites.draw(ci, "ev_ufo_tile_bonus" if is_bonus else "ev_ufo_tile_bone", Rect2(Vector2.ZERO, sz))
			Sprites.draw(ci, "ev_ell_shadow", Rect2(sz.x * 0.18, sz.y - 22, sz.x * 0.64, 12), Color(0, 0, 0, 0.12)))
		UI.icon(box, id, Vector2(cx, cy - 3), tile * 0.8)
		var h := UI.hit(box, Rect2(cx - tile * 0.5, cy - tile * 0.5, tile, tile), func(): G.main.open("item_info", id))
		h.sound = "tap"
		UI.lbl(box, "×%d" % cnt, Rect2(cx, cy + tile * 0.5 - 32, tile * 0.5 - 4, 30), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 6, Art.INK)
		# 下面一行小字：订单物品写名字，加赠的货币写到账多少
		var cap := Data.name_of(id)
		if Rewards.is_resource(id) and Data.value_of(id) > 0:
			cap = "%d%s" % [Data.value_of(id), {"energy": "体力", "amber": "琥珀", "shell": "不拿拿", "sand": "沙漏"}.get(Rewards.kind(id), "")]
		UI.lbl(box, cap, Rect2(cx - cell * 0.5, cy + tile * 0.5 + 4, cell, 28), 18, Color("6b3d1a") if is_bonus else Color("6b4a2a"))
		if is_bonus:
			var tg := UI.box(box, Rect2(cx - 30, cy - tile * 0.5 - 16, 60, 28), func(ci, sz):
				Sprites.draw(ci, "ev_ufo_bonus_tag", Rect2(Vector2.ZERO, sz)))
			tg.pivot_offset = tg.size * 0.5
			tg.rotation = -0.08
			UI.lbl(tg, "加赠", Rect2(0, 0, 60, 28), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 4, Art.MOSS_D, true)

func _process(delta: float) -> void:
	_t += delta
	if not _gone:
		saucer.position.y = 392 + sin(_t * 2.4) * 6.0
	saucer.queue_redraw()
	beam.queue_redraw()
	_tick += delta
	if _tick >= 1: _tick = 0; _refresh()

func _refresh() -> void:
	var left := maxi(0, int(ceil(float(offer.get("expires_at", 0)) - G.now())))
	var live := left > 0 and UfoOffer.active() and not offer.is_empty()
	clock.text = "%02d:%02d" % [left / 60, left % 60] if live else "已离开"
	buy_btn.enabled = live and not _busy
	buy_btn.text = "¥%d 购买" % int(UfoOffer.config()["price_cny"]) if live else "下次再来"
	buy_btn.queue_redraw()
	if not live and not _gone: _leave()

## 飞碟离开：飞碟往右上飞走、光束收起，托盘压暗盖章（物品仍然看得到）
func _leave() -> void:
	_gone = true
	shade.visible = true
	stamp.visible = true
	stamp.scale = Vector2(1.6, 1.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(saucer, "position", saucer.position + Vector2(260, -120), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(saucer, "scale", Vector2(0.4, 0.4), 0.8)
	tw.tween_property(saucer, "modulate:a", 0.0, 0.8)
	tw.tween_property(beam, "modulate:a", 0.0, 0.4)
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.25).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _buy() -> void:
	if _busy: return
	_busy = true; _refresh()
	var result := await UfoOffer.buy(str(offer.get("id", "")))
	if not is_instance_valid(self): return
	_busy = false
	if result.get("ok", false): close()
	else:
		G.main.toast(str(result.get("error", "购买失败")))
		_refresh()
