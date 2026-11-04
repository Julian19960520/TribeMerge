@tool
extends RefCounted
## 初始棋盘的锁和奖励。锁：0 开放，1 藤蔓，2 巨石。
## locks 和 cells 一一对应。没写、或比格子短的部分用默认：
## 只有正中和它右边一格开放，其余都是巨石。
## rewards 是「格子下标 -> [物品 id, 数量]」。石头裂开时弹出全屏面板领取。

static func lock_at(col: int, row: int, cols: int, rows: int) -> int:
	var cx := cols / 2
	var cy := rows / 2
	if (col == cx and row == cy) or (col == cx + 1 and row == cy):
		return 0
	return 2

static func lock_of(locks: Array, n: int, col: int, row: int, cols: int, rows: int) -> int:
	if n >= 0 and n < locks.size():
		return clampi(int(locks[n]), 0, 2)
	return lock_at(col, row, cols, rows)

## 把 locks 补到能写下标 n，空出来的格子填默认锁。
static func ensure(locks: Array, n: int, cols: int, rows: int) -> void:
	if cols < 1:
		cols = 1
	var cap := cols * maxi(rows, 1)
	if n >= cap:
		n = cap - 1
	if n < 0:
		return
	while locks.size() <= n:
		var i := locks.size()
		locks.append(lock_at(i % cols, int(i / cols), cols, rows))

## 一格的奖励。[物品 id, 数量]。空、数量不够、没有物品时返回空数组。
static func parse_reward(raw) -> Array:
	if not (raw is Array) or raw.size() < 2:
		return []
	var id := str(raw[0]).strip_edges()
	if id == "":
		return []
	var n := int(raw[1])
	if n < 1:
		return []
	return [id, n]

## rewards 可以是「下标 -> [id, 数量]」，也可以是和格子对齐的数组。
static func rewards_map(raw) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw:
			var key := str(k).strip_edges()
			if not key.is_valid_int():
				continue
			var rw := parse_reward(raw[k])
			if rw.is_empty():
				continue
			out[str(int(key))] = rw
	elif raw is Array:
		for i in raw.size():
			var rw := parse_reward(raw[i])
			if not rw.is_empty():
				out[str(i)] = rw
	return out

static func reward_of(rewards, n: int) -> Array:
	if not (rewards is Dictionary):
		return []
	if rewards.has(str(n)):
		return parse_reward(rewards[str(n)])
	if rewards.has(n):
		return parse_reward(rewards[n])
	return []

## 保存前收齐 rewards。没有奖励就拿掉这个字段。
static func normalize_rewards(board: Dictionary, cols: int, rows: int) -> bool:
	if cols < 1 or rows < 1:
		return false
	var need := cols * rows
	if not board.has("rewards"):
		return false
	var raw = board["rewards"]
	var mapped := rewards_map(raw)
	var sorted := {}
	var keys: Array = mapped.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in keys:
		var i := int(k)
		if i < 0 or i >= need:
			continue
		sorted[str(i)] = mapped[k]
	if sorted.is_empty():
		board.erase("rewards")
		return true
	if raw is Dictionary and JSON.stringify(raw) == JSON.stringify(sorted):
		return false
	board["rewards"] = sorted
	return true

## 保存前收齐 locks。和默认完全一样就拿掉，文件里只留改过的。
static func normalize(board: Dictionary, cols: int, rows: int) -> bool:
	if cols < 1 or rows < 1:
		return false
	if not (board.get("locks") is Array):
		if board.has("locks"):
			board.erase("locks")
			return true
		return false
	var need := cols * rows
	var locks: Array = board["locks"]
	if locks.is_empty():
		board.erase("locks")
		return true
	var changed := false
	while locks.size() < need:
		var i := locks.size()
		locks.append(lock_at(i % cols, int(i / cols), cols, rows))
		changed = true
	if locks.size() > need:
		board["locks"] = locks.slice(0, need)
		locks = board["locks"]
		changed = true
	for i in locks.size():
		var v := clampi(int(locks[i]), 0, 2)
		if int(locks[i]) != v:
			changed = true
		locks[i] = v
	for i in locks.size():
		if int(locks[i]) != lock_at(i % cols, int(i / cols), cols, rows):
			return changed
	board.erase("locks")
	return true
