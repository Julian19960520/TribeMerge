"""Export the local-save browser edition with Godot 4.6.3.

Usage: python tools/export_web.py /path/to/godot

Missing Web release templates are extracted from the official Godot archive by
fetch_web_template.py. The complete current project is exported by Godot, with
its export plugins, then independently checked before splitting/compression.
"""
from pathlib import Path
import gzip
import hashlib
import json
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
if len(sys.argv) != 2:
    raise SystemExit("Usage: python tools/export_web.py /path/to/godot")
version = subprocess.run([sys.argv[1], "--version"], capture_output=True, text=True, check=True).stdout.strip()
if not version.startswith("4.6.3.stable"):
    raise SystemExit("Web export requires the pinned Godot 4.6.3 runtime")
from fetch_web_template import install
print("Using official Web release template:", install(), flush=True)


def run_checked(command, label):
    log = root / ".godot" / ("web_export_" + label + ".log")
    log.parent.mkdir(exist_ok=True)
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=180)
    except subprocess.TimeoutExpired as error:
        def decoded(value):
            return value.decode(errors="replace") if isinstance(value, bytes) else (value or "")
        output = decoded(error.stdout) + "\n" + decoded(error.stderr)
        log.write_text(output)
        print(output[-18000:])
        raise SystemExit(f"Web {label} timed out; see {log}") from error
    output = result.stdout + "\n" + result.stderr
    log.write_text(output)
    if result.returncode or "ERROR:" in output:
        print(output[-18000:])
        raise SystemExit(f"Web {label} failed; see {log}")
    for line in output.splitlines():
        if line.startswith("PASS"):
            print(line, flush=True)

subprocess.run([sys.executable, str(root / "tools/stamp_replay.py")], check=True)
subprocess.run([sys.executable, str(root / "tools/bake_character_sprites.py"), "--check"], check=True)
dist = root / "dist"
dist.mkdir(exist_ok=True)
run_checked([sys.argv[1], "--headless", "--path", str(root),
                "--export-release", "Web"], "native")
# Verify the actual package from an empty directory, so source files cannot
# hide missing exported assets. Fail the build before publication on errors.
with tempfile.TemporaryDirectory(prefix="tribe-export-check-") as check_dir:
    script_manifest = Path(check_dir) / "scripts.json"
    from release_manifest import manifest
    script_manifest.write_text(json.dumps(manifest(root)))
    for check in ("check_export_items.gd", "check_export_scripts.gd"):
        run_checked([sys.argv[1], "--headless", "--path", check_dir,
                     "--main-pack", str(dist / "index.pck"),
                     "--script", str(root / "tools" / check),
                     "--", "--cloud-off", "--save=" + str(Path(check_dir) / "save.json"),
                     "--cloud-state=" + str(Path(check_dir) / "cloud.json"),
                     "--manifest=" + str(script_manifest)], check.removesuffix(".gd"))
pack = dist / "index.pck"
pack_bytes = pack.read_bytes()
pack_sha256 = hashlib.sha256(pack_bytes).hexdigest()
pack_chunks = []
for old_chunk in dist.glob("items-*.bin"):
    old_chunk.unlink()
for offset in range(0, len(pack_bytes), 16 * 1024 * 1024):
    chunk = pack_bytes[offset:offset + 16 * 1024 * 1024]
    name = "items-" + hashlib.sha256(chunk).hexdigest()[:16] + ".bin"
    (dist / name).write_bytes(chunk)
    pack_chunks.append(name)
pack.unlink()
wasm = dist / "index.wasm"
wasm_sha256 = hashlib.sha256(wasm.read_bytes()).hexdigest()
with (dist / "index.wasm.gz").open("wb") as compressed:
    with gzip.GzipFile(filename="", mode="wb", fileobj=compressed, compresslevel=9, mtime=0) as output:
        output.write(wasm.read_bytes())
wasm.unlink()
page = dist / "index.html"
html = page.read_text()
html = html.replace('"args":[]', '"args":["--","--cloud-off"]')
bootstrap = """<script>
// Keep the engine download below the hosting per-file limit.
const originalFetch = window.fetch.bind(window);
const packChunks = __PACK_CHUNKS__;
window.fetch = async function(resource, options) {
  const url = typeof resource === 'string' ? resource : resource.url;
  if (new URL(url, location.href).pathname.endsWith('/index.pck')) {
    const chunks = await Promise.all(packChunks.map(async name => {
      const response = await originalFetch(new URL(name, location.href), options);
      if (!response.ok) throw new Error('物品资源下载失败，请刷新重试');
      return response.arrayBuffer();
    }));
    return new Response(new Blob(chunks), {
      headers: { 'Content-Type': 'application/octet-stream' }
    });
  }
  if (new URL(url, location.href).pathname.endsWith('/index.wasm')) {
    const response = await originalFetch(new URL('index.wasm.gz', location.href), options);
    if (!response.ok) throw new Error('游戏引擎下载失败，请刷新重试');
    return new Response(response.body.pipeThrough(new DecompressionStream('gzip')), {
      headers: { 'Content-Type': 'application/wasm' }
    });
  }
  return originalFetch(resource, options);
};
</script>
"""
bootstrap = bootstrap.replace('__PACK_CHUNKS__', json.dumps(pack_chunks))
html = html.replace('<script src="index.js"></script>', bootstrap + '<script src="index.js"></script>')
assert bootstrap in html, "Godot HTML shell changed"
page.write_text(html)
(dist / "build.json").write_text(json.dumps({"godot": version, "runtime_source": "official Godot 4.6.3 export template", "rules_build": json.loads((root / "data/replay_build.json").read_text()), "pack_sha256": pack_sha256, "pack_bytes": len(pack_bytes), "wasm_sha256": wasm_sha256, "pack_chunks": pack_chunks}, indent=2) + "\n")
print("Web export ready:", dist, flush=True)
# The simulator report is a separate lightweight page; it does not load the game engine.
import shutil
for name in ("simulation.html", "simulation-events.js", "simulation-report.json.gz"):
    source = root / "web" / name
    if source.exists():
        shutil.copyfile(source, dist / name)
# Export retries can leave Godot staging files that exceed the hosting limit.
for pattern in ("*index.pck*", "*.import", "*index.wasm*"):
    for temporary in dist.glob(pattern):
        if temporary.name != "index.wasm.gz":
            temporary.unlink(missing_ok=True)
