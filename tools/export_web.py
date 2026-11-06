"""Export the local-save browser edition with Godot 4.6.3.

Usage: python tools/export_web.py /path/to/godot
"""
from pathlib import Path
import gzip
import hashlib
import json
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
dist = root / "dist"
dist.mkdir(exist_ok=True)
subprocess.run([sys.argv[1], "--headless", "--path", str(root),
                "--export-release", "Web"], check=True)
# Verify the actual package from an empty directory, so source files cannot
# hide missing exported assets. Fail the build before publication on errors.
with tempfile.TemporaryDirectory(prefix="tribe-export-check-") as check_dir:
    subprocess.run([sys.argv[1], "--headless", "--path", check_dir,
                    "--main-pack", str(dist / "index.pck"),
                    "--script", str(root / "tools/check_export_items.gd"),
                    "--", "--cloud-off"], check=True)
pack = dist / "index.pck"
pack_bytes = pack.read_bytes()
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
with gzip.open(dist / "index.wasm.gz", "wb", compresslevel=9) as output:
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
print("Web export ready:", dist)
