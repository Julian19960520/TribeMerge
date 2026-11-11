"""Install the official Godot 4.6.3 single-thread Web release template.

The official all-platform archive is over 1 GiB. Fetch only the ZIP directory
and the two required members using bounded HTTP ranges; verify member CRCs and
the nested template ZIP before installing it. No third-party runtime is used.

Usage: python tools/fetch_web_template.py
"""
from __future__ import annotations

import io
import os
from pathlib import Path
import re
import struct
import urllib.request
import zipfile
import zlib

VERSION = "4.6.3"
ARCHIVE_URL = (
    f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/"
    f"Godot_v{VERSION}-stable_export_templates.tpz"
)
MEMBER = "templates/web_nothreads_release.zip"
_location = ""
_archive_size = 0


def _range(start: int | None, end: int | None = None) -> tuple[bytes, int, int]:
    global _location, _archive_size
    if not _location:
        with urllib.request.urlopen(urllib.request.Request(ARCHIVE_URL, method="HEAD"), timeout=20) as response:
            _location = response.geturl()
            _archive_size = int(response.headers["Content-Length"])
    if start is None:
        start, end = max(0, _archive_size - 65557), _archive_size - 1
    value = f"bytes={start}-{end}"
    request = urllib.request.Request(_location, headers={"Range": value})
    with urllib.request.urlopen(request, timeout=30) as response:
        match = re.fullmatch(r"bytes (\d+)-(\d+)/(\d+)", response.headers.get("Content-Range", ""))
        if response.status != 206 or match is None:
            raise RuntimeError("Official template host did not honor a bounded HTTP range")
        first, last, total = map(int, match.groups())
        if start is not None and (first != start or last != end):
            raise RuntimeError("Official template response returned an unexpected range")
        expected = last - first + 1
        if expected > 32 * 1024 * 1024:
            raise RuntimeError("Unexpectedly large official Web template member")
        data = response.read(expected + 1)
        if len(data) != expected:
            raise RuntimeError("Official template download is truncated")
        return data, first, total


def _directory() -> dict[str, tuple[int, int, int, int, int]]:
    tail, first, _total = _range(None)
    end = tail.rfind(b"PK\x05\x06")
    if end < 0:
        raise RuntimeError("Official archive has no ZIP directory")
    eocd = struct.unpack("<4s4H2IH", tail[end : end + 22])
    size, offset = eocd[5], eocd[6]
    directory = tail[offset - first : offset - first + size] if offset >= first else _range(offset, offset + size - 1)[0]
    entries: dict[str, tuple[int, int, int, int, int]] = {}
    position = 0
    while position < len(directory):
        header = struct.unpack("<4s6H3I5H2I", directory[position : position + 46])
        if header[0] != b"PK\x01\x02":
            raise RuntimeError("Invalid official ZIP directory entry")
        name_length, extra_length, comment_length = header[10:13]
        name = directory[position + 46 : position + 46 + name_length].decode("utf-8")
        entries[name] = (header[16], header[4], header[7], header[8], header[9])
        position += 46 + name_length + extra_length + comment_length
    return entries


def _member(entry: tuple[int, int, int, int, int]) -> bytes:
    offset, method, expected_crc, compressed_size, size = entry
    header = struct.unpack("<4s5H3I2H", _range(offset, offset + 29)[0])
    if header[0] != b"PK\x03\x04" or header[2] & 1:
        raise RuntimeError("Invalid or encrypted official ZIP member")
    start = offset + 30 + header[9] + header[10]
    compressed = _range(start, start + compressed_size - 1)[0]
    data = zlib.decompress(compressed, -zlib.MAX_WBITS) if method == 8 else compressed if method == 0 else None
    if data is None or len(data) != size or zlib.crc32(data) & 0xFFFFFFFF != expected_crc:
        raise RuntimeError("Official template member failed size/CRC verification")
    return data


def _verify_template(archive: zipfile.ZipFile) -> None:
    if archive.testzip() is not None:
        raise RuntimeError("Official Web template failed ZIP verification")
    wasm_paths = [name for name in archive.namelist() if name.endswith(".wasm")]
    if len(wasm_paths) != 1 or (f"Godot Engine v{VERSION}.stable.official").encode() not in archive.read(wasm_paths[0]):
        raise RuntimeError("Web template does not contain the pinned official engine version")


def install() -> Path:
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    target = data_home / "godot/export_templates" / f"{VERSION}.stable" / Path(MEMBER).name
    if target.exists():
        with zipfile.ZipFile(target) as archive:
            _verify_template(archive)
        return target
    entries = _directory()
    version = _member(entries["templates/version.txt"]).decode().strip()
    if version != f"{VERSION}.stable":
        raise RuntimeError(f"Expected Godot {VERSION}.stable template, got {version}")
    template = _member(entries[MEMBER])
    with zipfile.ZipFile(io.BytesIO(template)) as archive:
        _verify_template(archive)
    target.parent.mkdir(parents=True, exist_ok=True)
    staging = target.with_suffix(".zip.tmp")
    staging.write_bytes(template)
    staging.replace(target)
    return target


if __name__ == "__main__":
    print("Official Web release template ready:", install())
