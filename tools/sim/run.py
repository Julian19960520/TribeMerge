"""Real-rule accelerated player. Python 3 + Godot 4.6; no third-party dependencies."""
import argparse
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

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    ap.add_argument('--config', type=Path, default=ROOT / 'tools/sim/config.json')
    ap.add_argument('--output', type=Path, default=ROOT / 'tools/sim/results')
    ap.add_argument('--runs', type=int)
    ap.add_argument('--days', type=float)
    ap.add_argument('--seed', type=int)
    ap.add_argument('--forever', action='store_true', help='Start fresh batches until Ctrl+C; keep every batch')
    ap.add_argument('--publish-report', action='store_true', help='Copy latest report to web/ for the next game export')
    ap.add_argument('--report-only', type=Path, help='Package an existing completed report')
    args = ap.parse_args()
    if args.report_only:
        publish_report(args.report_only, ROOT / 'web' if args.publish_report else args.output)
        return
    config = json.loads(args.config.read_text(encoding='utf-8'))
    for arg, key in [('runs', 'runs'), ('days', 'cycle_days'), ('seed', 'seed')]:
        if getattr(args, arg) is not None: config[key] = getattr(args, arg)
    batch = 0
    try:
        while True:
            cfg = dict(config, seed=int(config['seed']) + batch * int(config['runs']))
            folder = args.output.resolve() / f"batch-{time.time_ns()}-{batch + 1:04d}"
            folder.mkdir(parents=True)
            path = folder / 'config.json'
            path.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding='utf-8')
            report = folder / 'report.json'
            command = [args.godot, '--headless', '--path', str(ROOT), '--script', 'tools/sim/run.gd', '--', '--cloud-off',
                       '--save=user://sim-player.json', '--cloud-state=user://sim-cloud.json', '--rank-state=user://sim-rank.json',
                       '--config=' + str(path), '--output=' + str(report)]
            with (folder / 'engine.log').open('w') as log:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
            if result.returncode or 'SCRIPT ERROR' in (folder / 'engine.log').read_text(encoding='utf-8', errors='replace'):
                raise RuntimeError(f"Simulation failed: {folder / 'engine.log'}")
            publish_report(report, folder)
            (folder / 'levels.md').write_text(level_table(json.loads(report.read_text(encoding='utf-8'))), encoding='utf-8')
            if args.publish_report: publish_report(report, ROOT / 'web')
            print(f"Saved {folder}", flush=True)
            batch += 1
            if not args.forever: break
    except KeyboardInterrupt:
        print('Stopped. Completed batches and the current JSONL log are retained.')

if __name__ == '__main__':
    main()
