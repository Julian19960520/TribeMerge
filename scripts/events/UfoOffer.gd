class_name UfoOffer
extends RefCounted
static var _config: Dictionary = {}
static var busy := false
static var _retry_at := 0.0
static func config() -> Dictionary:
	if _config.is_empty(): _config = JSON.parse_string(FileAccess.get_file_as_string("res://data/ufo_offer.json"))
	return _config
static func state() -> Dictionary:
	if G.ufo_offer.is_empty():
		G.ufo_offer = {"next_at":0.0 if G.server_mode() else G.now()+int(config()["first_delay_sec"]),"offer":{},"deliveries":{}}
		G.dirty()
	return G.ufo_offer
static func candidate() -> Array:
	var owned := {}
	for cell in G.board:
		if int(cell.get("lock",0))==0 and not cell.get("ck") is Dictionary:
			var id := str(cell.get("id",""))
			owned[id] = int(owned.get(id,0))+1
	for item in G.inv + G.stash:
		var id := str(item.get("id","")) if item is Dictionary else str(item)
		owned[id] = int(owned.get(id,0))+1
	var ranked: Array = []
	var order_index := 0
	for order in G.orders:
		if str(order.get("kind",""))=="craft" and str(order.get("phase","need"))!="need": continue
		var ids: Array = order.get("mats",[]) if str(order.get("kind",""))=="craft" else order.get("items",[])
		if ids.is_empty(): continue
		var available: Dictionary = owned.duplicate()
		var missing: Array = []
		for value in ids:
			var id := str(value)
			if int(available.get(id,0))>0: available[id] = int(available[id])-1
			elif Data.CHAINS.has(Data.chain(id)) and Data.type_of(id)=="item": missing.append(id)
		if missing.is_empty(): continue
		var score := (1.0-float(missing.size())/ids.size())*1000.0 - missing.size()*10.0
		ranked.append({"score":score,"index":order_index,"items":missing})
		order_index += 1
	ranked.sort_custom(func(a,b):return float(a["score"])>float(b["score"]) if a["score"]!=b["score"] else int(a["index"])<int(b["index"]))
	var items: Array = []
	var maximum := int(config()["max_items"])
	for order in ranked:
		for id in order["items"]:
			if items.size()<maximum:items.append(str(id))
	if items.is_empty():return []
	var filler := "%s_%d" % [Data.chain(str(items[0])),maxi(1,Data.lv(str(items[0]))-1)]
	while items.size()<mini(maximum,int(config().get("min_items",1))):items.append(filler)
	return items

## 礼包实际发放的全部物品：订单缺口 + 固定加赠（bonus_items）。服务器 ufo_offer.bundle 同一规则。
static func bundle(items: Array) -> Array:
	var out: Array = []
	for id in items: out.append(str(id))
	for id in config().get("bonus_items", []): out.append(str(id))
	return out
## 面板展示用：相同物品合并成 [id, 件数]，保持首次出现顺序
static func grouped(ids: Array) -> Array:
	var rows: Array = []
	for id in ids:
		var hit := false
		for r in rows:
			if r[0] == str(id):
				r[1] = int(r[1]) + 1
				hit = true
				break
		if not hit: rows.append([str(id), 1])
	return rows
static func active() -> bool:
	var o: Dictionary = state()["offer"]
	return not o.is_empty() and not bool(o.get("paid",false)) and G.now()<float(o["expires_at"])
static func remaining() -> int:
	return maxi(0,int(ceil(float(state()["offer"].get("expires_at",0))-G.now())))
static func local_visit() -> void:
	if G.replay_input(): Replay.perform("ufo"); return
	var s := state()
	if G.now()<float(s["next_at"]): return
	var items := candidate()
	if items.is_empty():
		s["offer"] = {}
		s["next_at"] = G.now()+int(config()["retry_sec"])
	else:
		s["offer"] = {"id":str(G.random_for("ufo").randi()) if Replay.active else Crypto.new().generate_random_bytes(12).hex_encode(),"items":items,"expires_at":G.now()+int(config()["duration_sec"]),"paid":false}
		s["next_at"] = G.now()+int(config()["interval_sec"])
	G.save_game()
static func tick() -> void:
	if busy or G.tutorial_on or G.now() < _retry_at or not bool(config()["enabled"]): return
	var s := state()
	_deliver()
	if G.now()<float(s["next_at"]): return
	if G.server_mode():
		busy = true
		_retry_at = G.now()+int(config()["retry_sec"])
		var cloud = G._cloud()
		if cloud.can_talk():
			await cloud._upload()
			await cloud.act("/v1/ufo/visit",{"received":G.ufo_receipts})
		busy = false
	else: local_visit()
static func open_panel() -> void:
	if busy or not active(): return
	if not G.server_mode():
		if Replay.active:
			Replay.perform("ufo_refresh")
			G.main.open("ufo")
			return
		var items := candidate()
		if items.is_empty():
			state()["offer"]={}
			G.save_game()
			return
		state()["offer"]["items"]=items
		G.save_game()
	else:
		busy = true
		await G._cloud()._upload()
		var result: Dictionary = await G._cloud().act("/v1/ufo/visit", {"received":G.ufo_receipts,"refresh":true})
		busy = false
		if not result.get("ok",false) or not active(): return
	G.main.open("ufo")
static func buy(offer_id: String) -> Dictionary:
	if Replay.active: return {"error": "购买需要联网验证，支付渠道尚未接通"}
	if busy: return {"error":""}
	var o: Dictionary = state()["offer"]
	if not active() or str(o["id"])!=offer_id: return {"error":"飞碟已离开，下次再见"}
	# Never silently change the reviewed bundle during purchase.
	if candidate()!=o["items"]: return {"error":"订单需求已变化，请重新打开礼包"}
	busy=true
	if G.server_mode():
		var cloud = G._cloud()
		await cloud._upload()
		var order: Dictionary = await cloud.act("/v1/ufo/order",{"offer":offer_id})
		if not order.get("ok",false):
			busy=false
			return {"error":str(order.get("message","购买失败"))}
		var paid: Dictionary = await cloud.act("/v1/payments/mock/%s/pay" % str(order["order_id"]))
		if not paid.get("ok",false) or str(paid.get("status",""))!="paid":
			busy=false
			return {"error":str(paid.get("message","支付未完成"))}
	else:
		if not bool(config().get("demo_purchase",false)):
			busy=false
			return {"error":"支付尚未接通"}
		o["paid"]=true
		state()["deliveries"]["demo_"+offer_id]=bundle(o["items"])
	_deliver()
	G.save_game()
	busy=false
	return {"ok":true}
static func _deliver() -> void:
	var deliveries: Dictionary = state().get("deliveries",{})
	for receipt in deliveries:
		if G.ufo_receipts.has(str(receipt)): continue
		var rewards: Array = []
		for id in deliveries[receipt]: rewards.append([str(id),1,"physical"])
		G.ufo_receipts.append(str(receipt))
		Rewards.grant(rewards,Callable(),true)
		G.save_game()
	if G.ufo_receipts.size()>256: G.ufo_receipts=G.ufo_receipts.slice(-256)
	if not G.server_mode(): deliveries.clear()
