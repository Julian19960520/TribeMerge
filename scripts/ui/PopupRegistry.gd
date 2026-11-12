class_name PopupRegistry
extends RefCounted
## Feature factories and access conditions; Main only presents the returned view.
const PassPopupScript := preload("res://scripts/ui/PassPopup.gd")
static func create(name: String, arg = null) -> PopupBase:
	if name in ["album", "pack", "event", "card", "card_star_shop", "card_received"] and not G.rules.progression.feature_unlocked(Data.CARD_LEVEL):
		G.main.toast("典藏卡在 %d 级解锁" % Data.CARD_LEVEL)
		return null
	var p: PopupBase
	match name:
		"choice_chest":
			p = preload("res://scripts/ui/ChoiceChestPopup.gd").new()
			p.cell = int(arg)
			p.box_id = G.rules.board.cell_id(int(arg))
		"ufo":
			p = preload("res://scripts/ui/UfoPopup.gd").new()
		"daily_ad":
			p = preload("res://scripts/ui/DailyAdPopup.gd").new()
		"tiger": p = preload("res://scripts/ui/TigerEscapePopup.gd").new()
		"fossil": p = preload("res://scripts/ui/FossilDigPopup.gd").new()
		"duel": p = preload("res://scripts/ui/DuelPopup.gd").new()
		"seven_day":
			p = preload("res://scripts/ui/SevenDayPopup.gd").new()
		"merge_event":
			p = preload("res://scripts/ui/MergeEventPopup.gd").new()
			if arg is String: p.period_key = arg
		"energy":
			p = ShopPopups.energy()
			# 仅生产器体力不足触发后续礼包；购买成功补足体力则不打扰。
			if arg == "exhausted":
				p.closed.connect(func():
					if is_instance_valid(G.main) and G.rules.progression.feature_unlocked(16) and G.energy < G.rules.board.gen_cost() and Offers.wants_energy():
						OfferController.open_energy(), CONNECT_ONE_SHOT)
		"energy_amber": p = ShopPopups.energy()
		"energy_offer": p = preload("res://scripts/ui/EnergyOfferPopup.gd").new()
		"spree": p = preload("res://scripts/ui/SpreePopup.gd").new()
		"howto": p = ShopPopups.howto()
		"store": p = ShopPopups.store()
		"settings": p = SettingsPopups.settings()
		"build": p = ProgressionPopups.build(arg)
		"book": p = ItemPopups.book(0 if arg == null else arg)
		"inventory": p = ItemPopups.inventory()
		"item_info": p = ItemPopups.item_info(arg)
		"levelup": p = RewardPopups.levelup()
		"board_reward": p = RewardPopups.board_reward(arg if arg is Array else [])
		"event": p = CollectionPopups.event()
		"pass": p = PassPopupScript.screen()
		"pass_buy": p = PassPopupScript.buy()
		"album": p = CollectionPopups.album(arg)
		"card": p = CollectionPopups.card(int(arg.get("album", -1)), int(arg.get("index", -1)))
		"pack": p = CollectionPopups.pack(arg if arg is Dictionary else {})
		"card_star_shop": p = CardStarUI.shop()
		"card_received": p = CardRewardPresentation.popup(arg if arg is Dictionary else {})
		"level": p = RewardPopups.level_info()
		_: return null
	return p
