class_name ActivitySchedule
extends RefCounted
## 活动档期：短局 / 1～2天 / 一周 / 一个月，每档同一时间只开一个活动，按 data/activity_schedule.json 轮换。
## 只用规则时间 G.now() 计算，客户端与服务端重放结果一致；GM 全开活动时所有活动都算在档期内。

## 只给单个活动的玩法检查用：打开后所有活动都算在档期里。正式规则永远不打开。
static var bypass := false

static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/activity_schedule.json")

static func _start() -> float:
	return float(Time.get_unix_time_from_datetime_string(str(config().get("start_utc", "2026-11-02T00:00:00"))))

## 活动所在的档；不在任何档里返回空。
static func slot_of(activity: String) -> Dictionary:
	for slot in config().get("slots", []):
		for row in slot.get("rotation", []):
			if str(row["activity"]) == activity: return slot
	return {}

## 某档在 at 时刻的这一期：{"slot", "index", "starts", "ends", "activity", "key"}。
static func window(slot: Dictionary, at := -1.0) -> Dictionary:
	if slot.is_empty(): return {}
	if at < 0: at = G.now()
	var period := maxf(1.0, float(slot.get("period_hours", 24))) * 3600.0
	var start := _start()
	var index := int(floor((at - start) / period))
	var rotation: Array = slot.get("rotation", [])
	if rotation.is_empty(): return {}
	var row: Dictionary = rotation[posmod(index, rotation.size())]
	return {"slot": str(slot["id"]), "index": index, "starts": start + index * period, "ends": start + (index + 1) * period,
		"activity": str(row["activity"]), "key": "%s:%d" % [slot["id"], index]}

## 活动当前是否在自己的档期里（可以开新局、可以获得进度）。不在档里的活动总是开放。
static func scheduled(activity: String, at := -1.0) -> bool:
	if G.gm_activities or bypass: return true
	var slot := slot_of(activity)
	if slot.is_empty(): return true
	return str(window(slot, at).get("activity", "")) == activity

## 活动当前这一期的标识；不在档期里返回空字符串。
static func window_key(activity: String, at := -1.0) -> String:
	var slot := slot_of(activity)
	if slot.is_empty(): return "always"
	var w := window(slot, at)
	return str(w["key"]) if str(w.get("activity", "")) == activity or bypass else ""

## 本档这一期还剩多少秒（给入口倒计时用）。
static func seconds_left(activity: String) -> int:
	var slot := slot_of(activity)
	if slot.is_empty(): return 0
	return maxi(0, int(float(window(slot)["ends"]) - G.now()))

## 档期以外开新局时的提示。
static func closed_message(activity: String) -> String:
	var slot := slot_of(activity)
	var current := str(window(slot).get("activity", ""))
	return TextCatalog.source("notice.activityschedule.69c0e50ab97d") % str(slot.get("name", "")) if current != activity else ""
