"""Open the simulation timeline in the browser.

python tools/sim/view.py              newest finished run in tools/sim/results (falls back to web/)
python tools/sim/view.py <folder>     a batch folder (has simulation-report.json.gz or report.json)
python tools/sim/view.py <report.json>
python tools/sim/view.py <folder> --publish   copy that report into web/ for the next web export
Ctrl+C stops the local server.
"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
import tempfile
import webbrowser

import gzip
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]


def publish_report(report, destination):
    """Package a report.json next to the timeline page (simulation.html) so a browser can load it."""
    destination.mkdir(parents=True, exist_ok=True)
    payload = Path(report).read_bytes()
    if not json.loads(payload).get('runs'):
        raise ValueError('No completed runs in report')
    (destination / 'simulation-report.json.gz').write_bytes(gzip.compress(payload, mtime=0))
    for name in ('simulation.html', 'simulation-events.js'):
        source = ROOT / 'web' / name
        if source.resolve() != (destination / name).resolve():
            shutil.copyfile(source, destination / name)


class NoCacheHandler(SimpleHTTPRequestHandler):
    """Always serve the current page/report, never a stale cached copy."""
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *args):
        pass


def newest_batch():
    results = ROOT / 'tools/sim/results'
    # 统一演算的结果：单局在 autoplay-*/，批量在 autoplay-batch-*/<每一局>/
    found = [p.parent for p in results.glob('**/report.json')] if results.exists() else []
    if not found:
        return ROOT / 'web'
    newest = max(found, key=lambda p: (p / 'report.json').stat().st_mtime)
    if not (newest / 'simulation-report.json.gz').exists():
        publish_report(newest / 'report.json', newest)
    return newest


def folder_for(arg):
    path = Path(arg).resolve()
    if path.is_file():  # a report.json: package it into a temp folder
        out = Path(tempfile.mkdtemp(prefix='tribemerge-sim-'))
        publish_report(path, out)
        return out
    if (path / 'simulation-report.json.gz').exists():
        return path
    if (path / 'report.json').exists():
        publish_report(path / 'report.json', path)
        return path
    sys.exit(f'找不到演算结果：{path}')


def main():
    args = [a for a in sys.argv[1:] if a != '--publish']
    folder = folder_for(args[0]) if args else newest_batch()
    if '--publish' in sys.argv:
        # 把这一局的报告放进 web/，随下次网页导出一起发布
        publish_report(folder / 'report.json', ROOT / 'web')
        print(f'已发布到 {ROOT / "web"}')
        return
    if not (folder / 'simulation.html').exists():  # older batch folders: borrow the page from web/
        publish_report(folder / 'report.json', folder) if (folder / 'report.json').exists() else sys.exit(f'{folder} 里没有 simulation.html')
    handler = partial(NoCacheHandler, directory=str(folder))
    server = ThreadingHTTPServer(('127.0.0.1', 0), handler)
    url = f'http://127.0.0.1:{server.server_port}/simulation.html'
    sys.stdout.reconfigure(encoding='utf-8')
    print(f'演算结果：{folder}\n打开：{url}\n关闭这个窗口或按 Ctrl+C 停止。', flush=True)
    webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()
