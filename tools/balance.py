"""石器部落 · 合成 —— 数值模型。

用法：python tools/balance.py          只算，输出 tools/balance_out.json 和 难度曲线.html
      python tools/balance.py --write  同时把结果写回 data/*.json

思路：先定节奏（每级玩几天、每天能点几下），再用「点击次数」做统一度量，
反推订单难度、剧情订单、升级奖励、建造价格。所有可调的旋钮都在 KNOBS 里。

模型是期望值模型，不是逐次点击的模拟：
- 生产器每次点击的期望火苗 = Σ 掉率 × 2^(级-1)（主产物）。
- 合成会剩零头，用 WASTE 放大需要的点击数。
- 生产器等级由「1 级零件当量」决定：4 级 = 8 当量，每升一级翻倍。
  当量来源：产线开放送的 4 级、建造部件送的 3 级、升级奖励送的 3 级。
"""
import itertools
import json
import math
import os
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

KNOBS = {
    "levels": 40,
    # 每级总共花多少火种（点击），含升级送的火种。(到这一级为止, 点击数)
    # 目标节奏：第 1 天（约 3.5 小时）1→12 级一直有事干；第 2 天 13→15 级偶尔卡体力；
    # 16 级第四产线约第 3 天；之后越来越慢，40 级约第 40 天。
    # 演算校准（2026-11-07，含占位活动）：自动玩家实际花的体力 ≈ 前期 0.52×、后期 0.55× 这里的点击数
    "taps": [(1, 75), (4, 200), (8, 260), (12, 380), (15, 820), (20, 1050), (25, 1400), (30, 2050), (35, 2450), (40, 2950)],
    # 第 3 天起每天折合多少点击（体力约 750/天 ÷ 演算校准 0.55），只用来估算天数
    "day_taps": 1350,
    # 每级点击里有多少花在经验订单上，其余给随机单 / 制作单（换贝币）
    "story_share": 0.8,
    # 经验订单基本 1 点声望；6 级起每 5 点需求里有 1 张 2 点的大单
    "xp2_from": 6, "xp2_every": 5,
    # 合成剩零头、产出不对口的损耗
    "waste": 1.15,
    # 随机订单难度（点击数）：简单单 = easy_a + easy_b × 等级，难单 = hard_a + hard_b × 等级
    "easy_a": 12, "easy_b": 0.5,
    "hard_a": 60, "hard_b": 4.0,
    # 常驻 4 张随机单在简单～难之间的位置：1 简单、2 中等、1 难
    "slots": [0.0, 0.3, 0.55, 1.0],
    # 升到下一级要的声望 = xp_base + (等级-1) // xp_div：1~4 级 3 点，之后每 4 级 +1，40 级 12 点
    "xp_base": 3, "xp_div": 4,
    # 升级送的火种 = fire_a + fire_b × 等级
    "fire_a": 5, "fire_b": 3,
    # 第几级送火种罐
    "emberpot_level": 12,
    # 制作订单：几级开放；craft_cap_at 每个元素是多开一张制作单的等级
    "craft_level": 3, "craft_cap_at": [3, 16],
    # 沙漏：一份快多少秒；升级送的沙漏份数 = sand_a + 等级 // sand_div（制作开放后）
    "rush_sec": 60, "sand_a": 3, "sand_div": 3,
    # 制作单附送的沙漏实物：按菜的制作秒数取档 [最少秒数, 物品]
    "craft_sand": [[0, "sand_2"], [300, "sand_3"], [1800, "sand_4"], [7200, "sand_5"]],
    # 合成普通物品时掉沙漏：和合成掉贝币共用掷点，排在贝币后面
    "merge_sand": {"chance": 0.03, "min_level": 3, "tiers": [[2, "sand_1"], [7, "sand_2"], [10, "sand_3"]]},
    # 贝币：建造总价占全程订单贝币收入的比例
    "build_share": 0.85,
    # 每个区域从开放到建完大约用几级
    "build_span": 7,
    "seed": 20261104,
}

MAIN_PAY = 3   # 随机单每火苗贝币
STORY_PAY = 4  # 剧情单每火苗贝币


def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return json.load(f)


CHAINS = {c["id"]: c for c in load("chains.json")}
RAW_CHAINS = load("chains.json")
TAB = chr(9)
NL = chr(10)

# 生产器掉落表模板：(主产物等级, 掉率) 和 (副产物等级, 掉率)。每升一级主产物期望火苗约 +15~25%。
DROP_TEMPLATE = {
    4: ([(1, 100)], []),
    5: ([(1, 80), (2, 15)], [(1, 5)]),
    6: ([(1, 62), (2, 22), (3, 6)], [(1, 8), (2, 2)]),
    7: ([(1, 50), (2, 25), (3, 10), (4, 3)], [(1, 9), (2, 3)]),
    8: ([(1, 38), (2, 27), (3, 14), (4, 6), (5, 1)], [(1, 9), (2, 4), (3, 1)]),
    9: ([(1, 28), (2, 26), (3, 17), (4, 9), (5, 3)], [(1, 9), (2, 5), (3, 3)]),
}


def apply_drop_template():
    for l in LINES:
        gen = CHAINS[l["gen"]]
        for i, slot in enumerate(gen["prod"]):
            g = i + 1
            if not slot or g not in DROP_TEMPLATE:
                continue
            main, sub = DROP_TEMPLATE[g]
            drops = [{"id": "%s_%d" % (l["main"], lv), "p": p} for lv, p in main]
            drops += [{"id": "%s_%d" % (l["sub"], lv), "p": p} for lv, p in sub]
            slot["drops"] = drops

LINES = load("lines.json")
BUILDS = load("builds.json")
PEOPLE = load("people.json")
UNLOCKS = load("unlocks.json")
BASE = os.path.join(ROOT, "tools", "baseline")


def load_base(name):
    """改版前的原始数值，只用来画新旧对比。"""
    with open(os.path.join(BASE, name), encoding="utf-8") as f:
        return json.load(f)


OLD_RANDOM = load_base("random_orders.json")
OLD_STORY = load_base("story.json")
OLD_BUILDS = load_base("builds.json")
apply_drop_template()


def taps_of(L):
    for top, t in KNOBS["taps"]:
        if L <= top:
            return t
    return KNOBS["taps"][-1][1]


def days_of(L):
    """估算天数：第 1 天 1~12 级、第 2 天 13~15 级，之后按每天能花的火种折算。"""
    if L <= 12:
        return round(1 / 12, 3)
    if L <= 15:
        return round(1 / 3, 3)
    return round(taps_of(L) / KNOBS["day_taps"], 3)


def xp_need(L):
    return KNOBS["xp_base"] + (L - 1) // KNOBS["xp_div"]


def level_fire(L):
    return KNOBS["fire_a"] + KNOBS["fire_b"] * L


def max_lv(ch):
    return len(CHAINS[ch]["items"])


def prod_levels(gen):
    return [i + 1 for i, s in enumerate(CHAINS[gen]["prod"]) if s]


def eff(gen, g):
    """这一级生产器每次点击的期望火苗（主产物）和副产物 1 级当量。"""
    prods = CHAINS[gen]["prod"]
    g = max(min(g, max(prod_levels(gen))), min(prod_levels(gen)))
    slot = prods[g - 1]
    line = next(l for l in LINES if l["gen"] == gen)
    em = es = 0.0
    for d in slot["drops"]:
        ch, lv = d["id"].rsplit("_", 1)
        v = d["p"] / 100.0 * 2 ** (int(lv) - 1)
        if ch == line["main"]:
            em += v
        elif ch == line["sub"]:
            es += v
    return em, es


def sub_avg_percent(sub):
    """副产物 1 级在各级生产器里的平均掉率，用来算副产物的理论火苗。和 OrderRoll.gd 一致。"""
    line = next(l for l in LINES if l["sub"] == sub)
    ps = []
    for s in CHAINS[line["gen"]]["prod"]:
        if not s:
            continue
        for d in s["drops"]:
            if d["id"] == sub + "_1" and d["p"] > 0:
                ps.append(d["p"])
    return sum(ps) / len(ps) if ps else 5.0


def gen_level(eq, gen):
    g = int(math.floor(math.log2(max(eq, 1)))) + 1
    return max(4, min(g, max(prod_levels(gen))))


def open_lines(L):
    return [l for l in LINES if l["unlock"] <= L]


def product_open(L, ch):
    for row in UNLOCKS["rows"]:
        if row["id"] == ch:
            return row["open"][min(L - 1, len(row["open"]) - 1)] != 0
    return any(l["main"] == ch and l["unlock"] <= L for l in LINES)


# ---------------------------------------------------------------- 主循环


def area_window(b):
    if b["line"] == "":
        return 1, 5
    u = next(l["unlock"] for l in LINES if l["id"] == b["line"])
    if u == 1:
        return 2, 9
    return u, u + KNOBS["build_span"]


def simulate(costs, level_gens):
    """costs: {area: [part costs]}，level_gens: {L: gen id 或 None}。返回逐级数据。"""
    K = KNOBS
    eq = {l["gen"]: 0 for l in LINES}
    eq["basket"] = 8
    built = {b["id"]: (1 if b["id"] == "fire" else 0) for b in BUILDS}
    coins = 0.0
    cum_coins = 0.0
    cum_cost = 0.0
    rows = []
    for L in range(1, K["levels"] + 1):
        for l in LINES:
            if l["unlock"] == L and L > 1:
                eq[l["gen"]] += 8
        g = level_gens.get(L)
        if g:
            eq[g] += 2 ** (gen_reward_lv(L) - 1)
        lines = open_lines(L)
        gl = {l["gen"]: gen_level(eq[l["gen"]], l["gen"]) for l in lines}
        effs = [eff(l["gen"], gl[l["gen"]])[0] for l in lines]
        e = sum(effs) / len(effs)
        taps = taps_of(L)
        story_taps = taps * K["story_share"]
        rand_taps = taps - story_taps
        story_f = story_taps * e / K["waste"]
        rand_f = rand_taps * e / K["waste"]
        income = story_f * STORY_PAY + rand_f * MAIN_PAY
        # 建造：这一级的贝币分几步到账，每到账一次就把能盖的都盖掉（推荐最便宜的）
        built_now = []
        steps = 4
        for _s in range(steps):
            coins += income / steps
            cum_coins += income / steps
            while True:
                best = None
                for b in BUILDS:
                    lo, _hi = area_window(b)
                    if lo > L:
                        continue
                    k = built[b["id"]]
                    if k >= len(b["parts"]):
                        continue
                    c = costs[b["id"]][k]
                    if best is None or c < best[1]:
                        best = (b, c)
                if best is None or best[1] > coins:
                    break
                b, c = best
                coins -= c
                cum_cost += c
                part = b["parts"][built[b["id"]]]
                built[b["id"]] += 1
                built_now.append(part["name"])
                for rid, n in part["rewards"]:
                    ch, lv = rid.rsplit("_", 1)
                    if ch in eq:
                        eq[ch] += n * 2 ** (int(lv) - 1)
        lo_t = K["easy_a"] + K["easy_b"] * L
        hi_t = K["hard_a"] + K["hard_b"] * L
        old_lo = OLD_RANDOM["curves"][0]["diff"][L - 1]
        old_hi = OLD_RANDOM["curves"][1]["diff"][L - 1]
        rows.append({
            "level": L,
            "days": days_of(L),
            "taps": round(taps),
            "eff": round(e, 3),
            "gens": dict(gl),
            "easy_taps": round(lo_t, 1),
            "hard_taps": round(hi_t, 1),
            "slot_taps": [round(lo_t + (hi_t - lo_t) * s, 1) for s in K["slots"]],
            "easy_f": max(1, round(lo_t * e / K["waste"])),
            "hard_f": max(2, round(hi_t * e / K["waste"])),
            "story_taps": round(story_taps),
            "story_f": round(story_f),
            "income": round(income),
            "cum_coins": round(cum_coins),
            "cum_cost": round(cum_cost),
            "built": built_now,
            "xp_need": xp_need(L),
            # 旧设计：同一张订单要点几下（按新的产能折算，旧曲线本身就是火苗）
            "old_easy_taps": round(old_lo * K["waste"] / e, 1),
            "old_hard_taps": round(old_hi * K["waste"] / e, 1),
            "old_avg_taps": round((old_lo + old_hi) / 2 * K["waste"] / e, 1),
        })
    return rows, built, eq


def gen_reward_lv(L):
    """升级奖励送的生产器等级：前期 3 级，中期 4 级，后期 5 级。"""
    return 3 if L < 12 else (4 if L < 24 else 5)


def plan_level_gens():
    """升级奖励里送哪条产线的 3 级生产器：新产线开放那级送 4 级（由 eq 处理），其余送「最落后」的产线。"""
    eq = {l["gen"]: 0 for l in LINES}
    eq["basket"] = 8
    out = {}
    for L in range(2, KNOBS["levels"] + 1):
        fresh = [l for l in LINES if l["unlock"] == L]
        for l in fresh:
            eq[l["gen"]] += 8
        if fresh:
            out[L] = None
            continue
        cand = [l for l in open_lines(L) if gen_level(eq[l["gen"]], l["gen"]) < max(prod_levels(l["gen"]))]
        if not cand:
            out[L] = None
            continue
        # 越早开的产线目标越高；按「开放后经过的级数 / 当量」最落后的优先
        def behind(l):
            age = L - l["unlock"] + 4
            return eq[l["gen"]] / age
        pick = min(cand, key=behind)
        eq[pick["gen"]] += 2 ** (gen_reward_lv(L) - 1)
        out[L] = pick["gen"]
    return out


def make_costs(rows):
    """按每级贝币收入给部件定价：部件均匀排在区域的建造窗口里，价格 ∝ 那一级的收入。"""
    income = {r["level"]: r["income"] for r in rows}
    total = sum(income.values())
    slots = []
    for b in BUILDS:
        lo, hi = area_window(b)
        parts = b["parts"]
        paid = [i for i, p in enumerate(parts) if not (b["id"] == "fire" and i == 0)]
        for j, i in enumerate(paid):
            t = lo + (hi - lo) * (j + 0.5) / len(paid)
            slots.append((b["id"], i, t))
    # 价格 ∝ 部件目标等级的收入（线性插值），再整体缩放到总价 = 收入 × build_share
    def rate(t):
        a = max(1, min(KNOBS["levels"], int(math.floor(t))))
        b = min(KNOBS["levels"], a + 1)
        f = t - math.floor(t)
        return income[a] * (1 - f) + income[b] * f
    weights = [rate(t) for _b, _i, t in slots]
    k = total * KNOBS["build_share"] / sum(weights)
    costs = {b["id"]: [0] * len(b["parts"]) for b in BUILDS}
    for (bid, i, _t), w in zip(slots, weights):
        costs[bid][i] = int(round(w * k / 10.0)) * 10
    # 区域内价格不降
    for bid in costs:
        row = costs[bid]
        for i in range(1, len(row)):
            if row[i] and row[i] < row[i - 1]:
                row[i] = row[i - 1] + 10
    return costs


# ---------------------------------------------------------------- 剧情订单


# 人物：0 老酋长 巴图、1 巫医 月禾、2 猎手 阿石、3 小不点 果果
# 每条主产物链由谁来要、说什么。交单时弹出「名字：台词」。
SAYS = {
    "fruit": [(3, "甜甜的，还想要！"), (0, "大家今晚有果子吃了。"), (1, "这果子晒干能存一冬。"), (3, "我一口气吃了三个！"),
              (2, "带上果子，打猎不饿肚子。"), (0, "丰收的季节到了。"), (1, "果子熟得正好。")],
    "seed": [(1, "种下去，明年就有收成。"), (0, "种子是部落的未来。")],
    "tool": [(2, "这把石器真顺手！"), (0, "好工具才有好猎手。"), (2, "磨得真快，能削木头了。")],
    "gem": [(1, "这块石头会发光呢。"), (3, "亮晶晶的，送给我吧！")],
    "cloth": [(1, "冬天不怕冷了。"), (3, "新衣服好软！"), (0, "老骨头总算暖和了。")],
    "armor": [(2, "穿上它去打猎。")],
    "beast": [(2, "今天收获不错！"), (0, "够全部落吃三天。"), (3, "阿石叔叔好厉害！")],
    "bird": [(3, "羽毛真漂亮！"), (2, "这些鸟可不好抓。")],
    "veg": [(0, "火塘边香喷喷的。"), (3, "烤得真香！"), (1, "热乎的吃了不生病。")],
    "roast": [(2, "烤肉配篝火，最棒了。")],
    "furn": [(0, "大屋里终于有凳子坐了。"), (1, "这木头纹路真好看。")],
    "craft": [(1, "雕得真好看。")],
    "pot": [(1, "陶罐能装好多水。"), (0, "有了陶罐，粮食不怕潮了。"), (3, "我也想捏一个！")],
    "ware": [(0, "这彩陶要传下去。")],
}
# 产线开放那一级的第一张剧情单，用这句把新产线引出来
INTRO = {
    "food": (0, "篝火边有吃的了，大家都很高兴！"),
    "tool": (2, "石匠台的第一把石器，真顺手！"),
    "cloth": (1, "编织架织出的第一件衣服，真暖和。"),
    "hunt": (2, "第一次下陷阱就有收获！"),
    "fire": (0, "火塘生起来了，烤得真香！"),
    "wood": (0, "木工场开工了，部落要盖大屋了！"),
    "pot": (1, "第一只陶罐烧好了，真结实。"),
}


LAST_SAYS = set()
LAST_ITEMS = set()
SUB_CHAINS = {l["sub"] for l in LINES}


def item_flames(x):
    """理论火苗：主产物 2^(等级-1)，副产物再除以平均掉率（和 OrderRoll.gd 一致）。"""
    ch, lv = x.rsplit("_", 1)
    f = 2 ** (int(lv) - 1)
    if ch in SUB_CHAINS:
        f = f * 100.0 / sub_avg_percent(ch)
    return f


# 1 级的两张剧情单和新手引导绑在一起，保持原样
STORY_L1 = next(x["orders"] for x in load("story.json")["levels"] if x["level"] == 1)


def story_for(L, rows_by_level, rng):
    if L == 1:
        return [dict(o) for o in STORY_L1]
    r = rows_by_level[L]
    total_f = r["story_f"]
    need = xp_need(L)
    # 1 级：新手引导最后那张草籽单的 1 点声望也算在 1 级里
    if L == 1:
        need -= 1
    # 每张 1 点声望；中后期每 xp2_every 点里有一张 2 点的大单，放在中间和压轴
    n2 = need // KNOBS["xp2_every"] if L >= KNOBS["xp2_from"] else 0
    xps = [1] * (need - 2 * n2)
    for j in range(n2):
        xps.insert(len(xps) if j == 0 else len(xps) // 2, 2)
    # 火苗按声望分，带 ±25% 浮动，同一级里订单有大有小
    weights = [x * rng.uniform(0.75, 1.25) for x in xps]
    shares = [w / sum(weights) for w in weights]
    fresh = [l for l in LINES if l["unlock"] <= L <= l["unlock"] + 2]
    chains = [l["main"] for l in open_lines(L) if product_open(L, l["main"])]
    subs = [l["sub"] for l in open_lines(L) if product_open(L, l["sub"])]
    out = []
    # 同一级、上一级已经要过的物品尽量不再要，免得订单栏里全是同一两种东西
    recent = set(LAST_ITEMS)
    k_n = len(shares)
    for i, s in enumerate(shares):
        f = total_f * s
        if f <= 24:
            n = 1 if L == 1 else rng.choice([1, 2])
        elif f <= 80:
            n = rng.choice([1, 2, 2])
        else:
            n = rng.choice([2, 2, 3])
        # 在 n 件物品的组合里找理论火苗最接近目标的；第一件优先用刚开放的产线
        first = fresh[0]["main"] if fresh else None
        picks = [first if (first and k == 0) else rng.choice(chains) for k in range(n)]
        # 副产物开放后，多件订单里偶尔换一件副产物，颜色、外形都和主产物不一样
        if subs and n >= 2 and rng.random() < 0.5:
            picks[-1] = rng.choice(subs)
        best = None
        for combo in itertools.product(*[range(1 if c in subs else 2, (4 if c in subs else max_lv(c) - 1)) for c in picks]):
            its = [f"{c}_{lv}" for c, lv in zip(picks, combo)]
            got = sum(item_flames(x) for x in its)
            err = abs(got - f) / f
            err += 0.45 * sum(1 for x in its if x in recent) + 0.3 * (len(its) - len(set(its)))
            if best is None or err < best[0] - 1e-9:
                best = (err, combo)
        items = [f"{c}_{lv}" for c, lv in zip(picks, best[1])]
        items.sort(key=lambda x: -int(x.rsplit("_", 1)[1]))
        # 游戏会跳过同一级里物品完全相同的剧情单（声望就丢了），这里换一换
        seen = [sorted(o["items"]) for o in out]
        tries = 0
        while sorted(items) in seen and tries < 20:
            tries += 1
            k = tries % len(items)
            ch, lv = items[k].rsplit("_", 1)
            lv = int(lv)
            if tries % 2 == 1 and len(items) < 3 and lv > 2:
                items[k] = f"{ch}_{lv - 1}"
                items.append(f"{rng.choice(chains)}_{lv - 1}")
            else:
                alt = [c for c in chains if c != ch]
                items[k] = f"{rng.choice(alt) if alt else ch}_{lv + (0 if alt else 1)}"
            items.sort(key=lambda x: -int(x.rsplit("_", 1)[1]))
        flames = round(sum(item_flames(x) for x in items))
        recent.update(items)
        lead = items[0].rsplit("_", 1)[0]
        opened = [l for l in LINES if l["unlock"] == L]
        if i == 0 and opened:
            who, say = INTRO[opened[0]["id"]]
        else:
            pool = SAYS.get(lead, [(0, "谢谢你！")])
            used = {o["say"] for o in out} | LAST_SAYS
            fresh_pool = [x for x in pool if x[1] not in used] or [x for x in pool if x[1] not in {o["say"] for o in out}] or pool
            who, say = rng.choice(fresh_pool)
        o = {"items": items, "rewards": [], "say": say, "shell": STORY_PAY * flames,
             "who": who, "xp": xps[i]}
        if i == 1 and L >= 8:
            o["rewards"] = ["pack_1"]
        if i == k_n - 1 and L >= 2:
            o["token"] = 2 + L // 2
        out.append(o)
    LAST_SAYS.clear()
    LAST_SAYS.update(o["say"] for o in out)
    LAST_ITEMS.clear()
    LAST_ITEMS.update(x for o in out for x in o["items"])
    return out


def level_rewards(L, level_gens):
    rw = [["fire_2", level_fire(L)], ["chest_1", 1]]
    if L >= 8:
        rw.append(["pack_1", 1])
    fresh = [l for l in LINES if l["unlock"] == L]
    if fresh:
        rw.append([f"{fresh[0]['gen']}_4", 1])
    elif level_gens.get(L):
        rw.append([f"{level_gens[L]}_{gen_reward_lv(L)}", 1])
    if L % 2 == 0:
        rw.append(["amber_3", 5])
    if L >= KNOBS["craft_level"]:
        rw.append(["sand_2", KNOBS["sand_a"] + L // KNOBS["sand_div"]])
    # 火种罐（体力生产器）只送一个：第 2 天开始卡体力前拿到，每 12 小时一批约 90 体力
    if L == KNOBS["emberpot_level"]:
        rw.append(["emberpot_1", 1])
    return rw


def run():
    level_gens = plan_level_gens()
    costs = {b["id"]: [p["cost"] for p in b["parts"]] for b in BUILDS}
    rows = None
    for _ in range(4):
        rows, built, eq = simulate(costs, level_gens)
        costs = make_costs(rows)
    rows, built, eq = simulate(costs, level_gens)
    by = {r["level"]: r for r in rows}
    rng = random.Random(KNOBS["seed"])
    story = [{"level": L, "orders": story_for(L, by, rng)} for L in range(1, KNOBS["levels"] + 1)]

    # 声望对比：旧设计每级剧情约 5 点、需要 L+1；新设计每级剧情正好给满
    old_supply = 0
    old_need = 0
    stuck = None
    for r in rows:
        L = r["level"]
        lv = next((x for x in OLD_STORY["levels"] if x["level"] == L), None)
        old_supply += sum(o["xp"] for o in lv["orders"]) if lv else 5
        old_need += L + 1
        r["old_xp_supply"] = old_supply
        r["old_xp_need"] = old_need
        if stuck is None and old_supply < old_need:
            stuck = L
        r["new_xp_supply"] = sum(xp_need(i) for i in range(1, L + 1))
        r["new_xp_need"] = r["new_xp_supply"]
        sl = story[L - 1]["orders"]
        r["story_items"] = [o["items"] for o in sl]
        r["story_order_taps"] = [round(sum(item_flames(x) for x in o["items"]) * KNOBS["waste"] / r["eff"]) for o in sl]

    cum = 0.0
    for r in rows:
        cum += r["days"]
        r["cum_days"] = round(cum, 2)

    out = {
        "knobs": KNOBS,
        "rows": rows,
        "costs": costs,
        "level_gens": {str(k): v for k, v in level_gens.items()},
        "old_stuck_level": stuck,
        "final_eq": eq,
        "total_build": sum(sum(v) for v in costs.values()),
        "old_total_build": sum(p["cost"] for b in OLD_BUILDS for p in b["parts"]),
        "story": story,
        "level_rewards": {L: level_rewards(L, level_gens) for L in range(2, KNOBS["levels"] + 1)},
        "sub_percent": {l["sub"]: round(sub_avg_percent(l["sub"]), 2) for l in LINES},
    }
    return out


# ---------------------------------------------------------------- 写回


def dump_rows(path, head, rows, tail):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(head)
        f.write(",\n".join(rows))
        f.write(tail)


def write_back(out):
    rows = out["rows"]
    # 随机订单：下限 = 简单单火苗，上限 = 难单火苗，slots 是 4 张常驻单的位置
    rnd = {"curves": [
        {"name": "下限", "diff": [r["easy_f"] for r in rows]},
        {"name": "上限", "diff": [r["hard_f"] for r in rows]},
    ], "slots": KNOBS["slots"]}
    with open(os.path.join(DATA, "random_orders.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(rnd, f, ensure_ascii=False, indent="\t")
        f.write("\n")
    with open(os.path.join(DATA, "story.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"levels": out["story"]}, f, ensure_ascii=False, indent="\t")
        f.write("\n")
    lv_rows = ['\t\t{"level": %d, "rewards": %s}' % (L, json.dumps(rw, ensure_ascii=False))
               for L, rw in out["level_rewards"].items()]
    dump_rows(os.path.join(DATA, "levels.json"), '{\n\t"levels": [\n', lv_rows, "\n\t]\n}\n")
    blocks = []
    for b in BUILDS:
        parts = []
        for i, p in enumerate(b["parts"]):
            q = dict(p)
            q["cost"] = out["costs"][b["id"]][i]
            parts.append("\t\t" + json.dumps(q, ensure_ascii=False))
        head = {k: v for k, v in b.items() if k != "parts"}
        h = json.dumps(head, ensure_ascii=False)[:-1]
        blocks.append("\t%s, \"parts\": [\n%s\n\t]}" % (h, ",\n".join(parts)))
    with open(os.path.join(DATA, "builds.json"), "w", encoding="utf-8", newline="\n") as f:
        f.write("[\n" + ",\n".join(blocks) + "\n]\n")
    lines = []
    for c in RAW_CHAINS:
        lines.append(TAB + json.dumps(CHAINS[c["id"]], ensure_ascii=False))
    with open(os.path.join(DATA, "chains.json"), "w", encoding="utf-8", newline=NL) as f:
        f.write("[" + NL + ("," + NL).join(lines) + NL + "]" + NL)
    rules = load("rules.json")
    rules.update({"random_orders": len(KNOBS["slots"]), "xp_base": KNOBS["xp_base"], "xp_div": KNOBS["xp_div"],
                  "energy_price": 20, "energy_price_step": 10, "energy_price_max": 60,
                  "craft_level": KNOBS["craft_level"], "craft_cap_at": KNOBS["craft_cap_at"],
                  "rush_sec": KNOBS["rush_sec"], "craft_sand": KNOBS["craft_sand"], "merge_sand": KNOBS["merge_sand"]})
    with open(os.path.join(DATA, "rules.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(rules, f, ensure_ascii=False, indent="\t")
        f.write("\n")


def write_html(out):
    tpl_path = os.path.join(ROOT, "tools", "curve_template.html")
    with open(tpl_path, encoding="utf-8") as f:
        tpl = f.read()
    slim = {k: out[k] for k in ["knobs", "rows", "costs", "old_stuck_level", "total_build", "old_total_build"]}
    html = tpl.replace("/*DATA*/null", json.dumps(slim, ensure_ascii=False))
    with open(os.path.join(ROOT, "难度曲线.html"), "w", encoding="utf-8", newline="\n") as f:
        f.write(html)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    out = run()
    with open(os.path.join(ROOT, "tools", "balance_out.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    if "--write" in sys.argv:
        write_back(out)
    if os.path.exists(os.path.join(ROOT, "tools", "curve_template.html")):
        write_html(out)
    r = out["rows"]
    print("旧设计声望断供等级:", out["old_stuck_level"])
    print("建造总价 旧 %d → 新 %d" % (out["old_total_build"], out["total_build"]))
    print("到 Lv40 预计天数: %.1f" % r[-1]["cum_days"])
    for x in r[::3] + [r[-1]]:
        print("Lv%2d 效率%.2f 简单%3.0f下 难%4.0f下 | 旧均值%4.0f下 | 剧情%s下 | 收入%5d 累计收%6d 累计建%6d | 生产器%s" % (
            x["level"], x["eff"], x["easy_taps"], x["hard_taps"], x["old_avg_taps"], x["story_order_taps"],
            x["income"], x["cum_coins"], x["cum_cost"], x["gens"]))
