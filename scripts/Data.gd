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
	"token": {"name": "祭典鼓", "type": "token", "items": ["祭典鼓"]},
	"xp": {"name": "声望星", "type": "xp", "items": ["声望星"]},
}

const ORDER_CHAINS := ["berry", "stone", "meat", "fish"]

const PEOPLE := ["老酋长 巴图", "巫医 月禾", "猎手 阿石", "小不点 果果"]

## 剧情订单：只有它们给声望（经验），每级的声望需求 = 该级剧情订单声望之和，严格控制升级节奏。
const STORY := {
	1: [{"who": 0, "items": ["berry_2"], "xp": 1, "shell": 8},
		{"who": 2, "items": ["stone_2"], "xp": 1, "shell": 8},
		{"who": 1, "items": ["berry_2", "meat_2"], "xp": 2, "shell": 16, "pack": 1}],
	2: [{"who": 3, "items": ["berry_3"], "xp": 2, "shell": 14},
		{"who": 2, "items": ["meat_2", "stone_2"], "xp": 2, "shell": 18},
		{"who": 0, "items": ["fish_2"], "xp": 2, "shell": 12, "token": 2}],
	3: [{"who": 1, "items": ["berry_3", "stone_3"], "xp": 3, "shell": 30},
		{"who": 2, "items": ["meat_3"], "xp": 2, "shell": 20, "pack": 1},
		{"who": 0, "items": ["fish_3", "berry_2"], "xp": 3, "shell": 26}],
	4: [{"who": 3, "items": ["berry_4"], "xp": 3, "shell": 36},
		{"who": 2, "items": ["stone_3", "meat_3", "fish_2"], "xp": 4, "shell": 48, "token": 3},
		{"who": 1, "items": ["fish_3"], "xp": 3, "shell": 30, "pack": 1}],
	5: [{"who": 0, "items": ["stone_4", "meat_3"], "xp": 4, "shell": 56},
		{"who": 1, "items": ["berry_4", "fish_3"], "xp": 4, "shell": 56, "pack": 1},
		{"who": 2, "items": ["meat_4"], "xp": 4, "shell": 50, "token": 4}],
}

const ALBUMS := [
	{"name": "猛犸迁徙", "cards": ["雪原足迹", "长牙首领", "幼崽", "河边饮水", "围猎", "风雪夜", "长鼻嬉戏", "迁徙路", "猛犸之歌"]},
	{"name": "林中狩猎", "cards": ["鹿影", "潜行", "第一支矛", "追踪", "伏击", "满载而归", "鹿角", "猎人誓言", "林间晨雾"]},
	{"name": "篝火之夜", "cards": ["钻木取火", "第一缕烟", "围炉", "火舞", "守夜人", "烤肉香", "火光故事", "星空下", "余烬"]},
	{"name": "洞穴壁画", "cards": ["赭石手印", "红色野牛", "画师", "炭笔", "火把照壁", "群手", "神秘符号", "壁上星辰", "传承"]},
	{"name": "丰收祭典", "cards": ["太阳鼓", "面具", "祭舞", "贝壳项链", "丰收果", "图腾柱", "长老祝福", "欢宴", "月下歌"]},
	{"name": "河畔渔猎", "cards": ["鱼叉", "浅滩", "编网", "跳跃的鲈鱼", "独木舟", "晒鱼", "水鸟", "河神", "满网"]},
	{"name": "采集时节", "cards": ["第一颗莓", "藤篮", "蜂巢", "野蘑菇", "坚果林", "晨露", "满篮", "分享", "种子"]},
	{"name": "石器工坊", "cards": ["燧石", "敲击", "石片飞溅", "磨刃", "绑柄", "石斧", "石矛", "老匠人", "传艺"]},
	{"name": "部落人物", "cards": ["老酋长", "巫医", "猎手", "小不点", "阿焰", "小牙", "长老", "画师", "守夜人"]},
	{"name": "四季轮转", "cards": ["春雨", "夏雷", "秋实", "冬雪", "候鸟", "冰河", "花开", "落叶", "新月"]},
	{"name": "远古巨兽", "cards": ["剑齿虎", "巨鹿", "洞熊", "披毛犀", "恐鸟", "巨狼", "大地懒", "古象", "巨鳄"]},
	{"name": "星空传说", "cards": ["北斗", "银河", "流星", "月神", "日神", "风神", "雷神", "星图", "启明"]},
]

const AMBER_PACKS := [
	{"n": 80, "price": "¥6"}, {"n": 500, "price": "¥30"}, {"n": 1200, "price": "¥68"},
	{"n": 2500, "price": "¥128"}, {"n": 6500, "price": "¥328"}, {"n": 14000, "price": "¥648"},
]

static func story_orders(level: int) -> Array:
	if STORY.has(level):
		return STORY[level]
	var r := RandomNumberGenerator.new()
	r.seed = level * 7919
	var out := []
	var top: int = mini(5, 2 + level / 2)
	for i in 3:
		var items := []
		var n := 1 + r.randi() % 3
		var shell := 0
		for k in n:
			var ch: String = ORDER_CHAINS[r.randi() % ORDER_CHAINS.size()]
			var l := r.randi_range(3, mini(top, max_lv(ch)))
			items.append("%s_%d" % [ch, l])
			shell += 4 * int(pow(2, l - 1))
		var o := {"who": r.randi() % PEOPLE.size(), "items": items, "xp": 2 + n + level / 3, "shell": shell}
		if i == 1:
			o["pack"] = 1
		if i == 2:
			o["token"] = 2 + level / 2
		out.append(o)
	return out

static func xp_need(level: int) -> int:
	var n := 0
	for o in story_orders(level):
		n += int(o["xp"])
	return n

## 升到 level 时获得的奖励
static func level_rewards(level: int) -> Array:
	var out := [["fire_2", 30 + level * 10], ["chest_1", 1], ["pack_1", 1]]
	if level % 3 == 0:
		out.append(["basket_3" if level % 6 == 0 else "hunt_3", 1])
	else:
		out.append(["amber_2", 5])
	return out

const BUILDS := [
	{"id": "fire", "name": "篝火广场", "stages": 7},
	{"id": "hut", "name": "酋长大屋", "stages": 6},
	{"id": "totem", "name": "部落图腾", "stages": 5},
	{"id": "rack", "name": "晾肉架", "stages": 5},
	{"id": "tower", "name": "瞭望塔", "stages": 6},
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
		"token":
			return "丰收祭的活动积分，每攒 %d 个换一个兽皮卡包。" % 10
		"xp":
			return "部落声望，只有带星标的剧情订单才会给，攒满即可升级。"
	return tail

static func build_def(id: String) -> Dictionary:
	for b in BUILDS:
		if b["id"] == id:
			return b
	return {}
