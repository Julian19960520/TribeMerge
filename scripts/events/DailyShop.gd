class_name DailyShop
extends RefCounted
static var busy := false
static var ad_started := -1
static var ad_day := ""
static func offer(key: String) -> Dictionary:
	for d in Data.daily_deals(G.level):
		if str(d["key"]) == key: return d
	return {}
## 体力宝箱开出的东西（deal_energybox 的 opens，服务器 daily_shop.energy_chest_items 同一份）
static func energy_chest_items() -> Array:
	var out: Array = []
	for id in offer("deal_energybox").get("opens", ["fire_4", "fire_4", "fire_4"]): out.append(str(id))
	return out
static func can_claim(d: Dictionary) -> bool:
	return not d.is_empty() and G.pass_tier >= int(d.get("min_tier",0)) and (G.deals_day != G.today() or int(G.deals_bought.get(d["key"],0)) < int(d["stock"]))
static func start_ad() -> bool:
	if busy or not can_claim(offer("deal_ad")): return false
	if G.server_mode():
		var r: Dictionary = await G._cloud().act("/v1/daily/ad/start")
		if not r.get("ok",false):
			G.main.toast(str(r.get("message","广告暂不可用")))
			return false
	ad_started = Time.get_ticks_msec()
	ad_day = G.today()
	return true
static func cancel_ad() -> void:
	ad_started = -1
static func claim(key: String, origin := Vector2(360,740)) -> Dictionary:
	if G.replay_input(): return await Replay.perform("daily", {"key": key})
	if busy: return {"ok":false}
	G._check_day()
	var d := offer(key)
	if not can_claim(d): return {"ok":false,"message":"需要会员，或今日已经领取"}
	var ad := str(d.get("mode","")) == "ad"
	if ad and (ad_started < 0 or Time.get_ticks_msec()-ad_started < 5000 or ad_day != G.today()): return {"ok":false,"message":"请完整观看广告"}
	busy = true
	var rw: Array = d["rewards"]
	if G.server_mode():
		var r: Dictionary = await G._cloud().act("/v1/daily/claim",{"key":key},rw)
		if not r.get("ok",false):
			busy = false
			return r
	else:
		if not G.spend(str(d.get("currency","amber")),int(d["price"])):
			busy=false
			return {"ok":false,"message":"贝币不足"}
		G.deals_bought[key]=int(G.deals_bought.get(key,0))+1
	if ad: cancel_ad()
	Rewards.grant(rw,func(_k):return origin)
	G.save_game()
	G.changed.emit()
	busy=false
	return {"ok":true}
