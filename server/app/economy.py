"""Server-owned economy policy and resolved, versioned client catalog.

All commercial numbers live in server/config/economy.json. Clients receive final
item prices, value/difficulty metadata and regional product displays, not pricing
formulae. The static browser demo fetches the same generated catalog separately
from its game package; the authenticated backend always re-quotes purchases.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POLICY = ROOT / "server/config/economy.json"
RESOURCE_KIND = {"fire": "energy", "shell": "shell", "amber": "amber", "sand": "sand"}


def policy() -> dict:
    result = json.loads(POLICY.read_text(encoding="utf-8"))
    prices = result["energy"]["prices"]
    if not prices or prices != sorted(prices) or any(type(x) is not int or x <= 0 for x in prices):
        raise ValueError("Energy prices must be positive, ascending integers")
    for market in result["markets"].values():
        previous = 0
        for price, amount in market["packs"]:
            if price <= 0 or amount / price < previous:
                raise ValueError("Larger recharge packs must not have worse unit value")
            previous = amount / price
    return result


def money(minor: int, market: dict) -> str:
    amount = minor / 100
    return market["symbol"] + (str(int(amount)) if amount.is_integer() else f"{amount:.2f}")


def tier_price(prices: list, level: int) -> int:
    return int(prices[level - 1]) if level <= len(prices) else int(prices[-1]) * 2 ** (level - len(prices))


def energy_price(bought: int) -> int:
    prices = policy()["energy"]["prices"]
    return prices[min(max(int(bought), 0), len(prices) - 1)]


def line_products(line: dict) -> list:
    """A line lists its product chains; old rows (save replays) still say main / sub."""
    return list(line.get("products") or [c for c in (line.get("main"), line.get("sub")) if c])


def line_primary(line: dict, chains: dict) -> str:
    """The product its generator drops most often; mirrors Data.primary() in the client."""
    products = line_products(line)
    weight = {c: 0 for c in products}
    for slot in chains.get(line.get("gen", ""), {}).get("prod") or []:
        for drop in (slot or {}).get("drops", []):
            chain = drop["id"].rsplit("_", 1)[0]
            if chain in weight:
                weight[chain] += int(drop.get("p", 0))
    return max(products, key=lambda c: (weight[c], -products.index(c))) if products else ""


def line_secondaries(line: dict, chains: dict) -> list:
    main = line_primary(line, chains)
    return [c for c in line_products(line) if c != main]


def build(market: str = "CN", data_dir: str | Path | None = None) -> dict:
    p = policy()
    if market not in p["markets"]:
        raise ValueError("Unknown pricing market")
    regional = p["markets"][market]
    directory = Path(data_dir) if data_dir else ROOT / "data"
    docs = {path.stem: json.loads(path.read_text(encoding="utf-8")) for path in directory.glob("*.json")}
    chains = {r["id"]: r for r in docs["chains"]}
    lines = docs["lines"]
    subs = {}
    for r in lines:
        for chain in line_secondaries(r, chains):
            subs[chain] = r
    item_values = {}
    for chain, row in chains.items():
        kind = row.get("type", "")
        probability = 1.0
        if chain in subs:
            producers = chains[subs[chain]["gen"]].get("prod", [])
            rates = [sum(float(d["p"]) for d in (slot or {}).get("drops", []) if d["id"] == chain + "_1") for slot in producers]
            rates = [r for r in rates if r > 0]
            probability = sum(rates) / len(rates) / 100 if rates else .05
        for index in range(len(row.get("items", []))):
            level = index + 1
            mass = 2 ** index
            value = mass / probability if kind == "item" else 0.0
            amber = tier_price(p["sub_prices"] if chain in subs else p["main_prices"], level) if kind == "item" else 0
            resource = RESOURCE_KIND.get(chain, kind)
            physical = int(row.get("value", [0] * len(row["items"]))[index]) if index < len(row.get("value", [])) else 0
            if kind in ("energy", "shell", "amber", "sand"):
                value = (physical if physical else .5) * p["units"][resource]
                amber = max(1, math.ceil(value)) if value else 0
            if kind == "gen":
                value = amber = p["generator_level_one_price"] * mass
            if chain in p["fallback_item_values"] or kind in p["fallback_item_values"]:
                table = p["fallback_item_values"].get(chain, p["fallback_item_values"].get(kind))
                value = tier_price(table, level)
                amber = max(1, math.ceil(value))
            item_values[f"{chain}_{level}"] = {"value": round(value, 6), "difficulty": round(mass / probability if kind == "item" else value, 6), "amber": amber, "shell": math.ceil(value / p["units"]["shell"]) if value else 0, "kind": kind, "line": row.get("line", ""), "level": level, "physical_amount": physical, "generator_units": mass if kind == "gen" else 0}
    for pack in docs["card_packs"]["packs"]:
        weights = pack["weights"]
        cv = p["card_values"]
        rate = cv["reference_new_card_rate"]
        expected = sum(w / sum(weights) * (rate * cv["new_card_by_rarity"][i] + (1-rate) * docs["card_packs"]["duplicate_stars_by_rarity"][i] * cv["star_value"]) for i, w in enumerate(weights)) * docs["card_packs"]["cards_per_pack"]
        item_values[pack["id"]].update(value=round(expected, 6), amber=math.ceil(expected), valuation="expected", reference_new_card_rate=rate)
    for item, row in docs.get("reward_resources", {}).items():
        kind = row.get("type", "")
        value = p["units"].get(kind, 0)
        item_values[item] = {"value": value, "difficulty": value, "amber": math.ceil(value), "shell": math.ceil(value / p["units"]["shell"]), "kind": kind, "physical_amount": 1, "generator_units": 0}
    for dish in docs["dishes"]:
        materials = sum(item_values.get(i, {}).get("value", 0) for i in dish["mats"])
        value = materials + dish["secs"] * p["sand"]["diamonds_per_hour"] / 3600
        item_values[dish["id"]] = {"value": round(value, 6), "difficulty": materials, "amber": math.ceil(value), "shell": math.ceil(value / p["units"]["shell"]), "kind": "dish", "seconds": dish["secs"], "generator_units": 0}

    for entry in item_values.values():
        b = p["bubble"]
        raw = b["price_k"] * max(entry["difficulty"], 1) ** b["price_exp"]
        entry["bubble"] = min(b["price_max"], max(b["price_min"], math.floor(raw / b["price_step"] + .5) * b["price_step"])) if entry["kind"] == "item" else 0
    docs["card_packs"]["star_exchange"] = p["card_star_exchange"]
    docs["rules"]["merge_bubble"].update(p["bubble"])

    def reward_value(rewards):
        total = 0.0
        for rw in rewards:
            entry = item_values.get(rw[0], {})
            kind = entry.get("kind")
            physical = len(rw) > 2 and rw[2] in ("physical", "item")
            unit = p["units"][kind] if kind in p["units"] and not physical else entry.get("value", 0)
            total += rw[1] * unit
        return total

    # Exact expected values for resource chests; generator-containing chests
    # retain separate generator-unit metadata in addition to their scalar value.
    for chain, cfg in docs.get("special_chests", {}).items():
        for index, spec in enumerate(cfg.get("levels", [])):
            key = f"{chain}_{index + 1}"
            value = 0.0
            generator_units = 0.0
            if "items" in spec:
                value = sum(item_values.get(i, {}).get("value", 0) for i in spec["items"])
            elif "resource_weights" in spec:
                rw, tw = spec["resource_weights"], spec["tier_weights"]
                for resource, weight in rw.items():
                    for i, tier_weight in enumerate(tw):
                        value += weight / sum(rw.values()) * tier_weight / sum(tw) * item_values.get(f"{resource}_{i+1}", {}).get("value", 0)
                guaranteed = spec.get("guaranteed_resources", [])[:spec["count"]]
                random_count = spec["count"] - len(guaranteed)
                value *= random_count
                for resource in guaranteed:
                    value += sum(tier_weight / sum(tw) * item_values.get(f"{resource}_{i+1}", {}).get("value", 0) for i, tier_weight in enumerate(tw))
            elif "base_pool" in spec:
                pool = list(spec["base_pool"])
                for line in lines:
                    pool += [f'{line_primary(line, chains)}_{lv}' for lv in spec.get("main_tiers", [])]
                    pool += [f'{chain}_{lv}' for chain in line_secondaries(line, chains) for lv in spec.get("sub_tiers", [])]
                    pool += [f'{line["gen"]}_{lv}' for lv in spec.get("gen_tiers", [])]
                value = sum(item_values.get(i, {}).get("value", 0) for i in pool) / max(len(pool), 1) * spec["count"]
                chance = float(spec.get("gen_chance", 0))
                generator_units = chance * 2 ** (int(spec.get("gen_tier", 1))-1) * spec["count"]
                value = value * (1-chance) + generator_units * p["generator_level_one_price"]
            if key in item_values and value:
                item_values[key].update(value=round(value, 6), amber=math.ceil(value), generator_units=round(generator_units, 6), valuation="expected")

    def cash(base):
        return regional["cash_map"].get(str(int(base)), int(round(float(base) * 100)) if market == "CN" else 0)

    def cash_fields(row, field="price_cny"):
        minor = cash(row[field])
        if not minor:
            raise ValueError(f"No {market} price configured for {row[field]}")
        row[field] = minor / 100
        row["price_minor"] = minor
        row["price_str"] = money(minor, regional)
        row["currency"] = regional["currency"]

    docs["amber_packs"] = [{"n": amount, "price": money(minor, regional), "price_minor": minor, "currency": regional["currency"]} for minor, amount in regional["packs"]]
    docs["rules"].update(energy_prices=p["energy"]["prices"], energy_amount=p["energy"]["amount"], energy_price=p["energy"]["prices"][0], energy_price_max=p["energy"]["prices"][-1], energy_price_step=0, rush_sec=p["sand"]["seconds_per_unit"])
    docs["rules"].update(storage_expand_price=p["storage"]["initial_price"], storage_expand_step=p["storage"]["row_step"], hot_refresh_price=p["refresh"]["hot"])
    docs["store_shell"]["refresh_amber"] = p["refresh"]["shell"]
    for deal in docs["daily_deals"]:
        if deal["key"] == "deal_energybox": deal["price"] = p["daily_energy_box_shell_price"]
        if deal["key"] in ("deal_member_1", "deal_member_2"): deal["rewards"] = [["amber_4", p["member_daily_amber"]]]
    docs["store"] = [dict(row, price=item_values[row["id"]]["amber"]) for row in docs["store"]]
    docs["store_shell"]["items"] = [dict(row, price=math.ceil(item_values[row["id"]]["difficulty"] * 4)) for row in docs["store_shell"]["items"]]
    for row in docs["pass"]["purchase"].values():
        cash_fields(row)
    for kind, offer in docs["offers"].items():
        if not isinstance(offer, dict) or "tiers" not in offer:
            continue
        for row in offer["tiers"]:
            cash_fields(row)
            # True value ratio against the local smallest ordinary recharge pack.
            anchor_price, anchor_amount = regional["packs"][0]
            row["value_pct"] = round(reward_value(row["rewards"]) / (row["price_minor"] * anchor_amount / anchor_price) * 100)
    for row in docs["gift_chain"]["steps"]:
        if row["price"]:
            cash_fields(row, "price")
    docs["gift_chain"]["value"] = dict(p["units"], **{k: v["value"] for k, v in item_values.items() if v.get("kind") not in p["units"]})
    docs["gift_chain"]["cny_amber"] = regional["packs"][0][1] / (regional["packs"][0][0] / 100)
    cash_fields(docs["ufo_offer"])
    docs["ufo_offer"]["original_price_str"] = money(cash(docs["ufo_offer"]["original_price_cny"]), regional)

    docs["ufo_offer"]["original_price_cny"] = cash(docs["ufo_offer"]["original_price_cny"]) / 100

    # Existing activity reward lists remain the authoring inputs. Budgeting is
    # resolved once on the server, and identical final rows are shown and granted.
    audits = {}
    def reward_lists(node):
        if isinstance(node, list):
            if node and all(isinstance(r, list) and len(r) >= 2 and isinstance(r[0], str) and isinstance(r[1], (int, float)) and r[0] in item_values for r in node):
                yield node
            else:
                for child in node:
                    yield from reward_lists(child)
        elif isinstance(node, dict):
            for child in node.values():
                yield from reward_lists(child)
    # Activities sharing a schedule slot share one budget, so a reskin in the
    # same slot can replace another without changing the reward pace.
    budgets = dict(p["reward_budgets"])
    slot_of = {}
    for slot in docs.get("activity_schedule", {}).get("slots", []):
        for row in slot.get("rotation", []):
            if "budget" in slot and row["doc"] in budgets:
                budgets[row["doc"]] = slot["budget"]
                slot_of[row["doc"]] = slot["id"]
    for activity, budget in budgets.items():
        rows = list(reward_lists(docs.get(activity, {})))
        total = sum(reward_value(r) for r in rows)
        scale = min(1, budget / total) if total else 1
        generator_remaining = float(p["generator_reward_units_per_activity"])
        for rows_list in rows:
            final = []
            for rw in rows_list:
                entry = item_values[rw[0]]
                quantity = math.floor(rw[1] * scale)
                units = entry.get("generator_units", 0)
                if units:
                    quantity = min(quantity, math.floor(generator_remaining / units))
                    generator_remaining -= quantity * units
                if quantity:
                    final.append([rw[0], quantity, *rw[2:]])
            rows_list[:] = final
        audits[activity] = {"slot": slot_of.get(activity, ""), "budget": budget, "before": round(total, 3), "after": round(sum(reward_value(r) for r in rows), 3), "generator_units": p["generator_reward_units_per_activity"] - generator_remaining}

    products = {}
    for i, row in enumerate(docs["amber_packs"]):
        products[f"amber:{i}"] = {"price_minor": row["price_minor"], "price_str": row["price"], "amber": row["n"]}
    for key, row in docs["pass"]["purchase"].items():
        products["pass:" + ("super" if key == "super_vip" else "vip")] = {"price_minor": row["price_minor"], "price_str": row["price_str"], "value": reward_value(row["rewards"])}
    for kind, cfg in docs["offers"].items():
        if isinstance(cfg, dict):
            for i, row in enumerate(cfg.get("tiers", [])):
                products[f"offer:{kind}:{i}"] = {"price_minor": row["price_minor"], "price_str": row["price_str"], "value": reward_value(row["rewards"])}
    for i, row in enumerate(docs["gift_chain"]["steps"]):
        if row["price"]:
            products[f"gift:{i}"] = {"price_minor": row["price_minor"], "price_str": row["price_str"], "value": reward_value(row["rewards"])}
    difference = docs["pass"]["purchase"]["super_vip"]["price_minor"] - docs["pass"]["purchase"]["vip"]["price_minor"]
    products["pass:upgrade"] = {"price_minor": difference, "price_str": money(difference, regional)}
    products["ufo"] = {"price_minor": docs["ufo_offer"]["price_minor"], "price_str": docs["ufo_offer"]["price_str"]}
    selected = ["builds", "card_packs", "daily_deals", "random_orders", "dishes", "rules", "store", "store_shell", "amber_packs", "pass", "offers", "gift_chain", "ufo_offer", *p["reward_budgets"]]
    result = {"schema": 1, "market": market, "currency": regional["currency"], "symbol": regional["symbol"], "items": item_values, "units": p["units"], "energy": p["energy"], "sand": p["sand"], "shell": p["shell"], "orders": p["orders"], "products": products, "reward_audit": audits, "documents": {key: docs[key] for key in selected}}
    result["resource_products"] = [{"product":"shell", "kind":"shell", "id":"shell_2", "amount":p["shell"]["amount"], "price":p["shell"]["price"], "rewards":[["shell_2",p["shell"]["amount"]]]}]
    for i, (seconds, price) in enumerate(p["sand"]["packs"]):
        result["resource_products"].append({"product":f"sand:{i}", "kind":"sand", "id":"sand_2", "seconds":seconds, "amount":seconds//p["sand"]["seconds_per_unit"], "price":price, "rewards":[["sand_2",seconds//p["sand"]["seconds_per_unit"]]]})
    shared_rules = {"policy":{k:v for k,v in p.items() if k not in ("markets","default_market","revision")}, "items":item_values, "gameplay":{k:docs[k] for k in ("builds","card_packs","rules","random_orders","dishes","daily_deals",*p["reward_budgets"])}}
    result["rules_version"] = hashlib.sha256(json.dumps(shared_rules, sort_keys=True).encode()).hexdigest()[:20]
    result["version"] = p["revision"] + "-" + hashlib.sha256(json.dumps(result, sort_keys=True).encode()).hexdigest()[:12]
    return result


def current() -> dict:
    from .config import get_settings
    settings = get_settings()
    return build(settings.pricing_market, settings.data_dir)
