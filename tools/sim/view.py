"""Open the simulation timeline in the browser.

python tools/sim/view.py              newest finished batch in tools/sim/results (falls back to web/)
python tools/sim/view.py <folder>     a batch folder (has simulation-report.json.gz or report.json)
python tools/sim/view.py <report.json>
Ctrl+C stops the local server.
"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
import tempfile
import webbrowser

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import ROOT, publish_report  # noqa: E402


class NoCacheHandler(SimpleHTTPRequestHandler):
    """Always serve the current page/report, never a stale cached copy."""
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *args):
        pass


def newest_batch():
    results = ROOT / 'tools/sim/results'
    found = [p.parent for p in results.glob('*/simulation-report.json.gz')] if results.exists() else []
    return max(found, key=lambda p: (p / 'simulation-report.json.gz').stat().st_mtime) if found else ROOT / 'web'


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
    folder = folder_for(sys.argv[1]) if len(sys.argv) > 1 else newest_batch()
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
