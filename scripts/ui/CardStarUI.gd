class_name CardStarUI
extends RefCounted
## The same wallet and destination appear in the collection and card reveal.
const ENTRY_RECT := Rect2(552, 1320, 144, 142)

static func star(ci: CanvasItem, center: Vector2, radius: float = 28.0) -> void:
	var points := Art.star_pts(center, radius, radius * 0.47, 5, 18)
	Art.dilate(ci, points, 3.0, Color("6a3518"))
	ci.draw_colored_polygon(points, Color("ffd448"))
	ci.draw_polyline(Art.star_pts(center + Vector2(0, -1), radius * 0.75, radius * 0.35, 5, 18), Color("fff0a0"), 2.0, true)

static func button(p: PopupBase, initial: int = -1, live: bool = true) -> TButton:
	var hit := UI.hit(p.box, ENTRY_RECT, func(): G.main.open("card_star_shop"))
	hit.name = "card_star_wallet"
	hit.extra = func(ci, sz):
		Paint.round_btn(ci, Vector2(sz.x * 0.5, 51), 49, "orange", 24)
		star(ci, Vector2(sz.x * 0.5, 46), 30)
		Paint.button(ci, Rect2(10, 79, sz.x - 20, 36), "wood", 25)
	var amount := UI.lbl(hit, str(G.card_stars if initial < 0 else initial), Rect2(10, 78, 124, 38), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	amount.name = "balance"
	UI.lbl(hit, "星星兑换", Rect2(0, 116, 144, 28), 21, Color("fff0be"), HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	if live: Popups.live(p, G.changed, func(): amount.text = str(G.card_stars))
	return hit

static func set_balance(hit: TButton, amount: int) -> void:
	(hit.get_node("balance") as Label).text = str(amount)

static func pulse(hit: TButton) -> void:
	var tw := hit.create_tween()
	tw.tween_property(hit, "scale", Vector2(1.14, 1.14), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hit, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func shop() -> PopupBase:
	var p := PopupBase.new()
	p.name = "card_star_shop"
	Popups.frame(p, Rect2(40, 300, 640, 870), "星星兑换", Color("9f6430"))
	UI.box(p.box, Rect2(200, 361, 320, 68), func(ci, sz):
		Paint.button(ci, Rect2(Vector2.ZERO, sz), "wood", 35)
		star(ci, Vector2(46, 32), 23), false)
	var balance := UI.lbl(p.box, str(G.card_stars), Rect2(268, 367, 220, 52), 38, Color("fff1b0"), HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	balance.name = "star_shop_balance"
	UI.lbl(p.box, "重复卡按星级变成星星", Rect2(70, 440, 580, 36), 25, Color("805934"))
	var offers: Array = CardPacks.config()["star_exchange"]
	var buttons: Array[TButton] = []
	var deficits: Array[Label] = []
	for k in offers.size():
		var cost := int(offers[k]["cost"])
		var pack_id := str(offers[k]["pack"])
		var y := 500.0 + float(k) * 196.0
		UI.box(p.box, Rect2(66, y, 588, 178), func(ci, sz):
			var rect := Rect2(Vector2.ZERO, sz)
			var points := Art.rrect(rect, 20, 52, 0.4)
			ci.draw_colored_polygon(points, Color("e7cf9e"))
			Art.dashed(ci, Art.rrect(rect.grow(-7), 16, 53, 0.0), 7, 5, Color("b99765"), 2.0), false)
		UI.icon(p.box, pack_id, Vector2(146, y + 84), 130)
		UI.lbl(p.box, Data.name_of(pack_id), Rect2(222, y + 20, 252, 44), 31, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)
		UI.lbl(p.box, "每包 %d 张" % int(CardPacks.config()["cards_per_pack"]), Rect2(226, y + 68, 210, 34), 23, Color("805934"), HORIZONTAL_ALIGNMENT_LEFT)
		var highest: int = CardPacks.definition(pack_id)["weights"].size()
		while highest > 0 and float(CardPacks.definition(pack_id)["weights"][highest - 1]) == 0.0: highest -= 1
		UI.lbl(p.box, "最高 %d 星卡" % highest, Rect2(226, y + 108, 210, 34), 24, Color("a05a22"), HORIZONTAL_ALIGNMENT_LEFT)
		var buy := UI.btn(p.box, Rect2(480, y + 34, 148, 82), str(cost), "green", func():
			var result: Dictionary = Replay.perform("card_star_exchange", {"cost": cost})
			if result.has("error"):
				G.main.toast(str(result["error"]))
				return
			Sfx.play("coin")
			G.main.open("pack", {"id": result["pack"], "stash": result["stash"]}), 32)
		buy.name = "exchange_%d" % cost
		buy.extra = func(ci, _sz): star(ci, Vector2(25, 37), 14)
		buttons.append(buy)
		deficits.append(UI.lbl(p.box, "", Rect2(474, y + 122, 160, 30), 20, Color("9b6944")))
	var refresh := func():
		balance.text = str(G.card_stars)
		for k in offers.size():
			var cost := int(offers[k]["cost"])
			buttons[k].enabled = G.card_stars >= cost
			buttons[k].queue_redraw()
			deficits[k].text = "还差 %d 星" % (cost - G.card_stars) if G.card_stars < cost else ""
	refresh.call()
	Popups.live(p, G.changed, refresh)
	return p
