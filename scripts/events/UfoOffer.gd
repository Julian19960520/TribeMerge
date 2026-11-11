class_name UfoOffer
extends RefCounted
const Payments := preload("res://scripts/net/Payments.gd")
static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/ufo_offer.json")

static func state() -> Dictionary:
	return G.ufo_offer if not G.ufo_offer.is_empty() else initial_state()

static func initial_state() -> Dictionary:
	return {"next_at": G.now() + int(config()["first_delay_sec"]), "offer": {}}

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

## 礼包实际发放的全部物品。
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
	if G.tutorial_on or not bool(config()["enabled"]): return
	var s := state()
	if G.now() < float(s["next_at"]): return
	var items := candidate()
	if items.is_empty():
		s["offer"] = {}
		s["next_at"] = G.now() + int(config()["retry_sec"])
	else:
		s["offer"] = {"id": str(G.random_for("ufo").randi()), "items": items, "expires_at": G.now() + int(config()["duration_sec"]), "paid": false}
		s["next_at"] = G.now() + int(config()["interval_sec"])
	G.dirty()

static func tick() -> void:
	if G.tutorial_on or not bool(config()["enabled"]): return
	if G.now() >= float(state()["next_at"]): local_visit()



## Paid through the server; the grant delivers the shown items plus the bonus and marks the offer paid.
static func buy(offer_id: String) -> Dictionary:
	var offer: Dictionary = state()["offer"]
	if not active() or str(offer.get("id", "")) != offer_id: return {"ok": false, "error": "飞碟已经飞走了", "message": "飞碟已经飞走了"}
	var result: Dictionary = await Payments.buy("ufo", {"offer_id": offer_id, "items": offer.get("items", []).duplicate()})
	if not result.get("ok", false): result["error"] = str(result.get("message", "购买失败"))
	return result
