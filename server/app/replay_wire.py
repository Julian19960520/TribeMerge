"""TRP1 transport codec. Registry is shared with Godot; ordinals are append-only."""
import json
import zlib

from .config import REPO_DIR

MIME = 'application/x-tribe-replay'
MAX_COMPRESSED = 96 * 1024
MAX_RAW = 128 * 1024
MAX_INTEGER = (1 << 63) - 1
REGISTRY = json.loads((REPO_DIR / 'scripts/net/replay_wire.json').read_text(encoding='utf-8'))
STRING_FIELDS = {'id', 'key', 'track', 'season', 'action', 'kind'}
BOOL_FIELDS = {'on', 'stage'}


class WireError(ValueError):
    pass


class Reader:
    def __init__(self, raw):
        self.raw = raw
        self.pos = 0

    def take(self, n):
        if n < 0 or self.pos + n > len(self.raw):
            raise WireError('truncated payload')
        out = self.raw[self.pos:self.pos + n]
        self.pos += n
        return out

    def byte(self):
        return self.take(1)[0]

    def varint(self):
        value = 0
        for shift in range(0, 63, 7):
            b = self.byte()
            value |= (b & 127) << shift
            if not b & 128:
                if shift and b == 0:
                    raise WireError('noncanonical integer')
                return value
        raise WireError('integer overflow')


def inflate(data):
    if len(data) > MAX_COMPRESSED:
        raise WireError('compressed payload too large')
    try:
        d = zlib.decompressobj(31)
        raw = d.decompress(data, MAX_RAW + 1)
    except zlib.error as e:
        raise WireError('invalid gzip') from e
    if len(raw) > MAX_RAW or not d.eof or d.unused_data or d.unconsumed_tail:
        raise WireError('oversized, truncated or trailing gzip data')
    return raw


def decode(raw):
    if len(raw) > MAX_RAW:
        raise WireError('payload too large')
    r = Reader(raw)
    if r.take(4) != b'TRP1':
        raise WireError('unsupported transport version')
    out = {'base': r.varint()}
    for key, size in [('rules', 32), ('hash', 32), ('batch', 16)]:
        out[key] = r.take(size).hex()
    first, at, count = r.varint(), r.varint(), r.varint()
    if first < 1 or not 1 <= count <= 256 or first + count - 1 > MAX_INTEGER:
        raise WireError('invalid operation count/sequence')
    string_count = r.varint()
    if string_count > 2048:
        raise WireError('string table too large')
    strings = []
    for _ in range(string_count):
        size = r.varint()
        if size > 1024:
            raise WireError('string too long')
        try:
            strings.append(r.take(size).decode('utf-8'))
        except UnicodeDecodeError as e:
            raise WireError('invalid utf-8') from e
    ops = []
    for i in range(count):
        at += r.varint()
        code = r.byte()
        if at > MAX_INTEGER or code >= len(REGISTRY):
            raise WireError('invalid time/opcode')
        name, fields = REGISTRY[code]
        args = {}
        if fields:
            mask = r.varint()
            if mask >= 1 << len(fields):
                raise WireError('unknown argument')
            for bit, key in enumerate(fields):
                if not mask & (1 << bit):
                    continue
                if key in STRING_FIELDS:
                    index = r.varint()
                    if index >= len(strings):
                        raise WireError('invalid string index')
                    value = strings[index]
                elif key in BOOL_FIELDS:
                    value = r.byte()
                    if value > 1:
                        raise WireError('invalid boolean')
                    value = bool(value)
                else:
                    value = r.varint()
                    value = value // 2 if not value & 1 else -(value // 2) - 1
                    if not -(1 << 31) <= value < 1 << 31:
                        raise WireError('argument overflow')
                args[key] = value
        ops.append({'seq': first + i, 'at': at, 'name': name, 'args': args})
    if r.pos != len(raw):
        raise WireError('trailing data')
    out['ops'] = ops
    return out
