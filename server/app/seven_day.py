"""Cumulative onboarding tasks. Page labels are estimates, never time gates."""
from .economy import Reject

def state(econ, st):
    return st.setdefault('seven_day', {'id':econ.gd.seven_day['id'], 'stats':{}, 'claimed':{}, 'stages':{}, 'days':{}})

def record(econ, st, metric, amount):
    if amount <= 0: return
    s = state(econ,st)
    s['stats'][metric] = int(s['stats'].get(metric,0)) + int(amount)

def login(econ, st):
    s = state(econ,st)
    s['days'][econ.day()] = True
    s['stats']['login_days'] = len(s['days'])

def points(econ, st):
    claimed = state(econ,st)['claimed']
    return sum(t['points'] for day in econ.gd.seven_day['days'] for t in day['tasks'] if t['id'] in claimed)

def claim(econ, st, key, stage=False):
    s = state(econ,st)
    entries = econ.gd.seven_day['milestones'] if stage else [t for d in econ.gd.seven_day['days'] for t in d['tasks']]
    entry = next((t for t in entries if t['id'] == key),None)
    if not entry: raise Reject('unknown_task','任务不存在',400)
    book = s['stages'] if stage else s['claimed']
    if key in book: raise Reject('already_claimed','已领取')
    current = points(econ,st) if stage else s['stats'].get(entry['metric'],0)
    target = entry['points'] if stage else entry['target']
    if current < target: raise Reject('not_completed','尚未完成')
    book[key] = True
    return econ.grant(st,entry['rewards'],{'rewards':entry['rewards']})
