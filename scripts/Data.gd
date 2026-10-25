class_name Data
extends RefCounted
## 所有静态配置。新增物品：在 CHAINS 里加一条链，并在 Art.item() 里加对应绘制函数。

const CHAINS := {
	"berry": {"name": "野果", "type": "item", "items": ["草籽", "野莓", "莓果串", "叶包浆果", "浆果篮"]},
	"stone": {"name": "石器", "type": "item", "items": ["碎石", "燧石", "石片", "石刀", "石斧"]},
	"meat": {"name": "兽肉", "type": "item", "items": ["兽骨", "生肉", "烤肉串", "烤兽腿", "烤全兽"]},
	"fish": {"name": "河鱼", "type": "item", "items": ["小鱼", "河鲈", "鱼串", "烤鱼"]},
	"basket": {"name": "采集篮", "type": "gen", "items": ["草绳", "小草篓", "藤篮", "大藤筐"],
		"out": [["berry"], ["berry"], ["berry", "stone"], ["berry", "stone"]]},
	"hunt": {"name": "狩猎器具", "type": "gen", "items": ["木棍", "石矛", "弓与箭", "兽骨号角"],
		"out": [["meat"], ["meat"], ["meat", "fish"], ["meat", "fish"]]},
	"fire": {"name": "火种", "type": "energy", "items": ["火星", "火苗", "篝火"], "value": [5, 15, 40]},
	"shell": {"name": "贝币", "type": "shell", "items": ["贝壳", "贝壳串", "贝壳堆"], "value": [5, 15, 50]},
	"amber": {"name": "琥珀", "type": "amber", "items": ["琥珀粒", "琥珀块", "虫珀"], "value": [1, 3, 10]},
	"chest": {"name": "藤编宝箱", "type": "chest", "items": ["藤编宝箱"]},
	"pack": {"name": "兽皮卡包", "type": "pack", "items": ["兽皮卡包"]},
}

const ORDER_CHAINS := ["berry", "stone", "meat", "fish"]

const PEOPLE := ["老酋长 巴图", "巫医 月禾", "猎手 阿石", "小不点 果果"]

const BUILDS := [
	{"id": "fire", "name": "篝火广场", "stages": 7},
	{"id": "hut", "name": "酋长大屋", "stages": 6},
	{"id": "totem", "name": "部落图腾", "stages": 5},
	{"id": "rack", "name": "晾肉架", "stages": 5},
	{"id": "tower", "name": "瞭望塔", "stages": 6},
]

const ALBUMS := [
	{"name": "猛犸迁徙", "cards": ["雪原足迹", "长牙首领", "幼崽", "河边饮水", "围猎", "风雪夜", "长鼻嬉戏", "迁徙路", "猛犸之歌"]},
	{"name": "林中狩猎", "cards": ["鹿影", "潜行", "第一支矛", "追踪", "伏击", "满载而归", "鹿角", "猎人誓言", "林间晨雾"]},
	{"name": "篝火之夜", "cards": ["钻木取火", "第一缕烟", "围炉", "火舞", "守夜人", "烤肉香", "火光故事", "星空下", "余烬"]},
	{"name": "洞穴壁画", "cards": ["赭石手印", "红色野牛", "画师", "炭笔", "火把照壁", "群手", "神秘符号", "壁上星辰", "传承"]},
	{"name": "丰收祭典", "cards": ["太阳鼓", "面具", "祭舞", "贝壳项链", "丰收果", "图腾柱", "长老祝福", "欢宴", "月下歌"]},
	{"name": "河畔渔猎", "cards": ["鱼叉", "浅滩", "编网", "跳跃的鲈鱼", "独木舟", "晒鱼", "水鸟", "河神", "满网"]},
]

const STORE_HOT := [
	{"id": "berry_3", "price": 2, "stock": 5},
	{"id": "meat_3", "price": 3, "stock": 5},
	{"id": "fish_3", "price": 8, "stock": 5},
	{"id": "stone_3", "price": 3, "stock": 5},
	{"id": "fire_3", "price": 12, "stock": 3},
	{"id": "basket_3", "price": 25, "stock": 1},
]

static func chain(id: String) -> String:
	return id.get_slice("_", 0)

static func lv(id: String) -> int:
	return int(id.get_slice("_", 1))

static func max_lv(ch: String) -> int:
	return CHAINS[ch]["items"].size()

static func type_of(id: String) -> String:
	return CHAINS[chain(id)]["type"]

static func name_of(id: String) -> String:
	return CHAINS[chain(id)]["items"][lv(id) - 1]

static func next_id(id: String) -> String:
	var ch := chain(id)
	var l := lv(id)
	if l >= max_lv(ch):
		return ""
	return "%s_%d" % [ch, l + 1]

static func value_of(id: String) -> int:
	var c: Dictionary = CHAINS[chain(id)]
	if c.has("value"):
		return c["value"][lv(id) - 1]
	return 0

static func producers_of(ch: String) -> Array:
	var out := []
	for g in CHAINS:
		var c: Dictionary = CHAINS[g]
		if c["type"] != "gen":
			continue
		for i in c["out"].size():
			if ch in c["out"][i]:
				out.append("%s_%d" % [g, i + 1])
				break
	return out

static func gen_outputs(id: String) -> Array:
	var c: Dictionary = CHAINS[chain(id)]
	if c["type"] != "gen":
		return []
	return c["out"][lv(id) - 1]

static func describe(id: String) -> String:
	var t := type_of(id)
	var nx := next_id(id)
	var tail := "合成可得：%s。" % name_of(nx) if nx != "" else "已经是最高级！"
	match t:
		"gen":
			var names := []
			for ch in gen_outputs(id):
				names.append(CHAINS[ch]["name"])
			return "点击生产：%s。%s" % ["、".join(names), tail]
		"energy":
			return "点击收取 %d 点体力。%s" % [value_of(id), tail]
		"shell":
			return "点击收取 %d 贝币。%s" % [value_of(id), tail]
		"amber":
			return "点击收取 %d 琥珀。%s" % [value_of(id), tail]
		"chest":
			return "点击打开，获得随机物品。"
		"pack":
			return "点击打开，获得丰收祭卡牌。"
	return tail

static func build_def(id: String) -> Dictionary:
	for b in BUILDS:
		if b["id"] == id:
			return b
	return {}
