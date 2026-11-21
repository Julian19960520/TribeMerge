class_name ProdData
extends RefCounted
## 预览界面用的产线视图。数据本身在 Data.LINES / Data.CHAINS，这里只换成预览需要的形状：
## 每条产线 = 生产器链 G + 主力产物链 M + 第一条其余产物链 S（没有时为空）。

static var LINES: Array = _build()

static func _build() -> Array:
	var out := []
	for l in Data.LINES:
		var g: Dictionary = Data.CHAINS[l["gen"]]
		var main := Data.primary(l)
		var subs := Data.secondaries(l)
		var sub := str(subs[0]) if not subs.is_empty() else ""
		out.append({
			"id": l["id"], "name": l["name"], "gen": g["name"], "gen_id": l["gen"], "idle": _leading_idle(l["gen"], g["items"].size()),
			"main_name": Data.CHAINS[main]["name"], "sub_name": Data.CHAINS[sub]["name"] if sub != "" else "",
			"main_id": main, "sub_id": sub,
			"G": g["items"], "M": Data.CHAINS[main]["items"], "S": Data.CHAINS[sub]["items"] if sub != "" else [],
		})
	return out

static func _leading_idle(gen_id: String, n: int) -> int:
	var idle := 0
	for lv in range(1, n + 1):
		if not Data.gen_stats("%s_%d" % [gen_id, lv]).is_empty():
			break
		idle = lv
	return idle

static func line(id: String) -> Dictionary:
	for l in LINES:
		if l["id"] == id:
			return l
	return {}

## 生产器第 lv 级的产出参数；不可生产时返回空字典。
static func gen_stats(l: Dictionary, lv: int) -> Dictionary:
	return Data.gen_stats("%s_%d" % [l["gen_id"], lv])
