class_name DailyShop
extends RefCounted
static var ad_started := -1
static var ad_day := ""
static func offer(key: String) -> Dictionary:
	for d in Data.daily_deals(G.level):
		if str(d["key"]) == key: return d
	return {}
static func can_claim(d: Dictionary) -> bool:
	return not d.is_empty() and G.pass_tier >= int(d.get("min_tier",0)) and (G.deals_day != G.rules.clock.today() or int(G.deals_bought.get(d["key"],0)) < int(d["stock"]))
static func start_ad() -> bool:
	return false

static func cancel_ad() -> void:
	ad_started = -1
static func claim(key: String) -> Dictionary:
	if G.replay_input(): return Replay.perform("daily", {"key": key})
	G.rules.clock._check_day()
	var d := offer(key)
	if not can_claim(d): return {"error": "需要会员，或今日已经领取"}
	if str(d.get("mode", "")) == "ad": return {"error": "广告奖励需要平台验证"}
	if not G.rules.progression.spend(str(d.get("currency", "amber")), int(d["price"])): return {"error": "货币不足"}
	G.deals_bought[key] = int(G.deals_bought.get(key, 0)) + 1
	Rewards.settle(d["rewards"])
	return {"ok": true, "rewards": d["rewards"]}
