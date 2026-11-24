class_name CardRewardPresentation
extends RefCounted
## Receipts describe committed acquisitions; tweens never change gameplay state.

static func popup(result: Dictionary) -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.82
	UI.title(p.box, TextCatalog.source("ui.cardrewardpresentation.0f4ceca75ab3"), Rect2(70, 250, 580, 80), 44, Color.WHITE)
	fill(p, result.get("card_rewards", []))
	return p

static func fill(p: PopupBase, rewards: Array) -> void:
	p.on_tap = Callable()
	var total := 0
	for reward in rewards: total += int(reward["stars"])
	var display := {"balance": G.card_stars - total}
	var wallet := CardStarUI.button(p, int(display["balance"]), false)
	wallet.enabled = false
	var end_time := 0.65
	var cards: Array = []
	var albums: Array = []
	var badges: Array = []
	var fresh: Array = []
	for k in rewards.size():
		var reward: Dictionary = rewards[k]
		var album := int(reward["album"])
		var index := int(reward["index"])
		var amount := int(reward["stars"])
		var x := 360.0 - float(rewards.size() - 1) * 135.0 + float(k) * 270.0
		var rect := Rect2(x - 115, 520, 230, 320)
		var card := UI.hit(p.box, rect, func(): pass)
		card.name = "received_card_%d" % k
		card.set_meta("card", [album, index])
		card.extra = func(ci, sz): Paint.card(ci, Rect2(Vector2(6, 12), sz - Vector2(12, 18)), album, index, true)
		UI.lbl(card, CardArtwork.card_name(album, index), Rect2(20, 252, 190, 50), 24, Color("5a3a1e"))
		var heading := UI.lbl(p.box, CardArtwork.title(album), Rect2(rect.position.x - 8, 466, 246, 40), 23, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
		heading.name = "card_album_%d" % k
		var badge := UI.lbl(p.box, TextCatalog.source("ui.cardrewardpresentation.6f346e51c6f0") if amount > 0 else TextCatalog.source("ui.cardrewardpresentation.59867734cd78"), Rect2(rect.position.x, 870, 230, 48), 30, Color("ffd957") if amount > 0 else Color("b9ef9a"), HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
		badge.name = "card_badge_%d" % k
		cards.append(card)
		albums.append(heading)
		badges.append(badge)
		if amount == 0: fresh.append(k)
		card.pivot_offset = rect.size * 0.5
		card.scale = Vector2(0, 1)
		var tw := card.create_tween()
		card.set_meta("intro", tw)
		tw.tween_interval(0.15 + float(k) * 0.2)
		tw.tween_property(card, "scale", Vector2(1.1, 1.1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.1)
		if amount > 0:
			card.enabled = false
			var delay := 1.0 + float(k) * 0.22
			var convert := p.create_tween()
			convert.tween_interval(delay)
			convert.tween_property(card, "modulate", Color(1.8, 1.5, 0.7, 1), 0.13)
			convert.tween_property(card, "scale", Vector2(0, 0.7), 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			convert.tween_callback(func():
				card.hide()
				heading.hide()
				badge.hide()
				_emit_stars(p, rect.get_center(), amount, wallet, display))
			end_time = maxf(end_time, delay + 1.35 + float(amount - 1) * 0.07)
	var state := {"page": -1, "fresh": fresh, "cards": cards, "albums": albums, "badges": badges, "button": null}
	var close := UI.btn(p.box, Rect2(210, 1080, 300, 104), TextCatalog.source("ui.cardrewardpresentation.db8db0530432") if not fresh.is_empty() else TextCatalog.source("ui.cardrewardpresentation.fac2a67ad878"), "green", func(): _advance(p, state), 44)
	close.name = "receive_cards"
	state["button"] = close
	close.enabled = false
	close.modulate.a = 0.0
	var finish := p.create_tween()
	finish.tween_interval(end_time)
	finish.tween_callback(func():
		close.enabled = true
		wallet.enabled = true
		CardStarUI.set_balance(wallet, G.card_stars)
		close.queue_redraw()
		Popups.live(p, G.changed, func(): CardStarUI.set_balance(wallet, G.card_stars)))
	finish.tween_property(close, "modulate:a", 1.0, 0.15)

## 有新卡时先放大到中间。翻看时底部是下一张，最后一张是确定。
static func _advance(p: PopupBase, state: Dictionary) -> void:
	var fresh: Array = state["fresh"]
	var button: TButton = state["button"]
	var page := int(state["page"])
	if fresh.is_empty() or (page >= 0 and page >= fresh.size() - 1):
		p.close()
		return
	page += 1
	state["page"] = page
	_focus(state, int(fresh[page]))
	button.text = TextCatalog.resolve(TextCatalog.source("ui.cardrewardpresentation.fac2a67ad878") if page >= fresh.size() - 1 else TextCatalog.source("ui.cardrewardpresentation.dcd4eb027369"))
	button.queue_redraw()

static func _focus(state: Dictionary, index: int) -> void:
	var cards: Array = state["cards"]
	var albums: Array = state["albums"]
	var badges: Array = state["badges"]
	for k in cards.size():
		if k == index: continue
		(cards[k] as Control).hide()
		(albums[k] as Control).hide()
		(badges[k] as Control).hide()
	var card: Control = cards[index]
	if card.has_meta("intro") and (card.get_meta("intro") as Tween).is_valid():
		(card.get_meta("intro") as Tween).kill()
	# 放大后卡册名和“新卡！”会压在卡面上，收起来；底部换成这张卡的台词
	(albums[index] as Control).hide()
	(badges[index] as Control).hide()
	card.show()
	card.enabled = false
	card.pivot_offset = card.size * 0.5
	var dest := Vector2(360, 645) - card.size * 0.5
	var line: Label = state.get("line")
	if line == null:
		line = UI.lbl(card.get_parent(), "", Rect2(60, 930, 600, 130), 32, Color("fff3d6"), HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
		line.name = "card_line"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state["line"] = line
	var reward_key: Array = card.get_meta("card")
	line.text = UI.resource_text(CardArtwork.caption(int(reward_key[0]), int(reward_key[1])))
	line.modulate.a = 0.0
	line.create_tween().tween_property(line, "modulate:a", 1.0, 0.25).set_delay(0.18)
	var tw := card.create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "position", dest, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE * 1.7, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func _emit_stars(p: PopupBase, origin: Vector2, amount: int, wallet: TButton, display: Dictionary) -> void:
	Sfx.play("merge", 1.5)
	for k in amount:
		var offset := Vector2((float(k) - float(amount - 1) * 0.5) * 48.0, -absf(float(k) - float(amount - 1) * 0.5) * 15.0)
		var from := origin + offset
		var spark := UI.box(p.box, Rect2(origin - Vector2(36, 36), Vector2(72, 72)), func(ci, sz):
			ci.draw_circle(sz * 0.5, 35, Color(1, 0.8, 0.2, 0.16))
			CardStarUI.star(ci, sz * 0.5, 28), false)
		spark.name = "converted_star"
		spark.pivot_offset = spark.size * 0.5
		spark.scale = Vector2.ZERO
		var tw := spark.create_tween()
		tw.tween_property(spark, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(spark, "position", from - spark.size * 0.5, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.16 + float(k) * 0.07)
		var to := CardStarUI.ENTRY_RECT.position + Vector2(72, 46)
		var mid := from.lerp(to, 0.45) + Vector2(80, -100)
		tw.tween_method(func(t: float):
			spark.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t) - spark.size * 0.5
			spark.scale = Vector2.ONE * (1.0 - 0.5 * t), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			display["balance"] += 1
			CardStarUI.set_balance(wallet, int(display["balance"]))
			CardStarUI.pulse(wallet)
			Sfx.play("coin", 1.2)
			spark.queue_free())
