"""Per-level table from a simulation report: python tools/sim/levels.py report.json [out.md]"""
import json
import sys
from pathlib import Path

SOURCES = {'level': '等级奖励', 'seven_day_task': '七日任务', 'seven_day_stage': '七日里程碑', 'resource_energy': '棋盘体力',
           'book': '图鉴', 'banana': '香蕉竞速', 'duel_match': '双人竞速', 'duel_milestone': '双人里程碑', 'build': '部落建造',
           'moon': '月石', 'ph_gather_fest': '采集祭', 'ph_treasure_dig': '寻宝', 'ph_hunt_fest': '狩猎大会', 'ph_expedition': '远征', 'ph_festival': '庆典', 'land': '开地', 'pass': '通行证', 'daily': '每日补给', 'chest': '宝箱', 'stash': '暂存'}


def hm(sec):
    sec = int(sec)
    return f"{sec // 3600}:{sec % 3600 // 60:02d}"


def table(report):
    out = []
    for run in report['runs']:
        rows = run.get('levels', [])
        out.append(f"## 第 {run['run']} 轮（种子 {run['seed']}，结束：{run['finish_reason']}，用时 {run['duration'] / 86400:.2f} 天）\n")
        out.append('| 等级 | 第几天 | 开局后 | 累计在线 | 本级在线 | 订单/经验单 | 需经验 | 生产 | 体力消耗 | 体力收入(不含恢复) | 自然恢复 | 满体力浪费 | 卡住/卡体力 | 体力峰值 | 新解锁 |')
        out.append('|' + '---|' * 15)
        played = 0.0
        for r in rows:
            income = sorted(r['energy_income'].items(), key=lambda kv: -kv[1])
            inc = '、'.join(f"{SOURCES.get(k, k)}{v}" for k, v in income[:3]) or '-'
            total_inc = sum(r['energy_income'].values())
            out.append(f"| {r['level']}{'…' if r['partial'] else ''} | {r['day']} | {hm(r['reached'])} | {hm(played)} | {r['play_sec'] / 60:.0f}分"
                       f" | {r['orders']}/{r['xp_orders']} | {r['xp_need']} | {r['produce']} | {r['energy_spent']} | {total_inc}（{inc}）"
                       f" | {r['energy_regen']} | {r['energy_wasted']} | {r['stuck']}/{r['stuck_energy']} | {r['energy_peak']} | {'；'.join(r['unlocks']) or '-'} |")
            played += r['play_sec']
        days = {}
        for r in rows:
            d = days.setdefault(r['day'], {'levels': [], 'play': 0, 'stuck_energy': 0})
            d['levels'].append(r['level']); d['play'] += r['play_sec']; d['stuck_energy'] += r['stuck_energy']
        out.append('\n| 天 | 当天升到的等级 | 在线（按升级那天计） | 卡体力次数 |\n|---|---|---|---|')
        for day, d in sorted(days.items()):
            out.append(f"| {day} | {min(d['levels'])}→{max(d['levels'])} | {hm(d['play'])} | {d['stuck_energy']} |")
        out.append('')
    return '\n'.join(out)


if __name__ == '__main__':
    text = table(json.loads(Path(sys.argv[1]).read_text(encoding='utf-8')))
    if len(sys.argv) > 2: Path(sys.argv[2]).write_text(text, encoding='utf-8')
    else: sys.stdout.reconfigure(encoding='utf-8'); print(text)
