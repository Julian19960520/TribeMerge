class_name LoginGift
extends RefCounted
## 七日签到：每天登录领下一格，按顺序领，漏签不清零；7 格领完从头再来。
## 状态 G.login_gift = {"count": 累计领了几次, "last": 最后一次领取的日期（东八区）}。
static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/login_gift.json")

static func state() -> Dictionary:
	return G.login_gift if not G.login_gift.is_empty() else initial_state()

static func initial_state() -> Dictionary:
	return {"count": 0, "last": ""}

static func days() -> Array:
	return config()["days"]

static func unlocked() -> bool:
	return G.rules.progression.feature_unlocked(Data.feature_level("login"))

static func visible() -> bool:
	return unlocked() and not G.tutorial_on

static func count() -> int:
	return int(state().get("count", 0))

static func claimed_today() -> bool:
	return str(state().get("last", "")) == str(G.rules.clock.today())

static func can_claim() -> bool:
	return unlocked() and not claimed_today()

## 这一轮里第几格（从 0 起）是今天要领 / 刚领的那格
static func today_index() -> int:
	var n := count()
	if claimed_today() and n > 0:
		return (n - 1) % days().size()
	return n % days().size()

## 第 k 格（从 0 起）在这一轮里是否已领
static func got(k: int) -> bool:
	var n := count()
	var size := days().size()
	if n <= 0: return false
	var done := n % size
	if done == 0 and claimed_today(): done = size
	return k < done

static func claim() -> Dictionary:
	if G.replay_input(): return Replay.perform("login_gift", {})
	if not unlocked(): return {"error": TextCatalog.fill(TextCatalog.source("ui.mergeevententry.b2377e256fd8"), Data.feature_level("login"))}
	if claimed_today(): return {"error": TextCatalog.source("notice.logingift.3072031ee45a")}
	var s := state()
	var rewards: Array = days()[int(s.get("count", 0)) % days().size()]
	s["count"] = int(s.get("count", 0)) + 1
	s["last"] = str(G.rules.clock.today())
	G.login_gift = s
	Rewards.settle(rewards)
	G.dirty()
	G.login_gift_changed.emit()
	return {"ok": true, "rewards": rewards}
