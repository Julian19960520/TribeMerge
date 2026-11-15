"""Real-rule accelerated player. Python 3 + Godot 4.6; no third-party dependencies."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import gzip
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

from levels import table as level_table

ROOT = Path(__file__).resolve().parents[2]

def publish_report(report, destination):
    destination.mkdir(parents=True, exist_ok=True)
    payload = Path(report).read_bytes()
    # Validate before replacing the last readable report.
    parsed = json.loads(payload)
    if not parsed.get('runs'):
        raise ValueError('No completed runs in report')
    (destination / 'simulation-report.json.gz').write_bytes(gzip.compress(payload, mtime=0))
    for name in ('simulation.html', 'simulation-events.js'):
        source = ROOT / 'web' / name
        if source.resolve() != (destination / name).resolve():
            shutil.copyfile(source, destination / name)

def run_one(godot, cfg, folder, fast, publish_web=False):
    """Run one Godot batch in its own folder (own save files, safe to run in parallel)."""
    folder.mkdir(parents=True)
    path = folder / 'config.json'
    path.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding='utf-8')
    report = folder / 'report.json'
    user = folder.as_posix()
    command = [godot, '--headless', '--path', str(ROOT), '--script', 'tools/sim/run.gd', '--', '--cloud-off',
               f'--save={user}/sim-player.json', f'--cloud-state={user}/sim-cloud.json', f'--rank-state={user}/sim-rank.json',
               '--config=' + str(path), '--output=' + str(report)]
    with (folder / 'engine.log').open('w') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode or 'SCRIPT ERROR' in (folder / 'engine.log').read_text(encoding='utf-8', errors='replace'):
        raise RuntimeError(f"Simulation failed: {folder / 'engine.log'}")
    data = json.loads(report.read_text(encoding='utf-8'))
    if not fast:
        publish_report(report, folder)
        if publish_web: publish_report(report, ROOT / 'web')
    (folder / 'levels.md').write_text(level_table(data), encoding='utf-8')
    return data

def overview(name, data, watch=(20, 25, 30)):
    """One line per run: seed, final level, day each watched level was reached, levels/day around L30."""
    out = []
    for run in data['runs']:
        rows = {int(r['level']): r for r in run['levels']}
        days = {lv: rows[lv]['day'] for lv in watch if lv in rows}
        near = [lv for lv in rows if 28 <= lv <= 32 and not rows[lv].get('partial')]
        pace = ''
        if len(near) >= 2:
            span = (float(rows[max(near)]['reached']) - float(rows[min(near)]['reached'])) / 86400
            if span > 0: pace = f"{(max(near) - min(near)) / span:.1f} 级/天"
        reached = '，'.join(f"{lv} 级第 {d} 天" for lv, d in days.items())
        out.append(f"{name} 种子 {run['seed']}：到 {run['state']['level']} 级（{run['finish_reason']}），{reached}" + (f"，28～32 级 {pace}" if pace else ''))
    return out

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    ap.add_argument('--config', type=Path, nargs='+', default=[ROOT / 'tools/sim/config.json'], help='One or more configs; several run side by side')
    ap.add_argument('--output', type=Path, default=ROOT / 'tools/sim/results')
    ap.add_argument('--runs', type=int)
    ap.add_argument('--days', type=float)
    ap.add_argument('--seed', type=int)
    ap.add_argument('--seeds', type=int, default=1, help='Run each config with this many consecutive seeds, side by side')
    ap.add_argument('--jobs', type=int, default=0, help='Parallel Godot processes (default: one per task, at most CPU count)')
    ap.add_argument('--fast', action='store_true', help='Summary only: per-level table, no per-event timeline (several times faster)')
    ap.add_argument('--forever', action='store_true', help='Start fresh batches until Ctrl+C; keep every batch')
    ap.add_argument('--publish-report', action='store_true', help='Copy latest report to web/ for the next game export')
    ap.add_argument('--report-only', type=Path, help='Package an existing completed report')
    args = ap.parse_args()
    if args.report_only:
        publish_report(args.report_only, ROOT / 'web' if args.publish_report else args.output)
        return
    if args.fast and args.publish_report:
        raise SystemExit('--fast has no timeline to publish; run without --fast for --publish-report')
    configs = []
    for path in args.config:
        config = json.loads(path.read_text(encoding='utf-8'))
        for arg, key in [('runs', 'runs'), ('days', 'cycle_days'), ('seed', 'seed')]:
            if getattr(args, arg) is not None: config[key] = getattr(args, arg)
        if args.fast: config['summary_only'] = True
        configs.append((path.stem, config))
    batch = 0
    try:
        while True:
            tasks = []
            stamp = time.time_ns()
            for name, config in configs:
                for k in range(max(1, args.seeds)):
                    cfg = dict(config, seed=int(config['seed']) + (batch * max(1, args.seeds) + k) * int(config['runs']))
                    label = name if len(configs) > 1 or args.seeds > 1 else ''
                    folder = args.output.resolve() / f"batch-{stamp}-{batch + 1:04d}{'-' + label if label else ''}{f'-s{k + 1}' if args.seeds > 1 else ''}"
                    tasks.append((name, cfg, folder))
            jobs = args.jobs or min(len(tasks), os.cpu_count() or 1)
            started = time.time()
            with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
                futures = [(name, folder, pool.submit(run_one, args.godot, cfg, folder, args.fast, args.publish_report and len(tasks) == 1)) for name, cfg, folder in tasks]
                lines = []
                for name, folder, future in futures:
                    data = future.result()
                    print(f"Saved {folder}", flush=True)
                    lines += overview(name, data)
            print(f"用时 {time.time() - started:.0f} 秒，{len(tasks)} 个演算，{jobs} 个并行")
            for line in lines: print(line)
            batch += 1
            if not args.forever: break
    except KeyboardInterrupt:
        print('Stopped. Completed batches and the current JSONL log are retained.')

if __name__ == '__main__':
    main()
