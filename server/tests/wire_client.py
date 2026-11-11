"""Reference test client for the single current binary protocol."""
import gzip
from app import replay_wire as wire


def encode(payload):
    out = bytearray(b'TRP1')
    def number(value):
        if value < 0: raise ValueError('negative unsigned integer')
        while value >= 128:
            out.append((value & 127) | 128)
            value >>= 7
        out.append(value)
    number(payload['base'])
    for name in ('rules', 'hash', 'batch'): out.extend(bytes.fromhex(payload[name]))
    operations = payload['ops']
    number(operations[0]['seq']); number(operations[0]['at']); number(len(operations))
    strings = []
    for operation in operations:
        for key, value in operation['args'].items():
            if key in wire.STRING_FIELDS and value not in strings: strings.append(value)
    number(len(strings))
    for value in strings:
        raw = value.encode('utf-8'); number(len(raw)); out.extend(raw)
    names = [row[0] for row in wire.REGISTRY]
    at = operations[0]['at']
    for operation in operations:
        number(operation['at'] - at); at = operation['at']
        code = names.index(operation['name']); out.append(code)
        fields = wire.REGISTRY[code][1]
        if not fields: continue
        mask = sum(1 << index for index, field in enumerate(fields) if field in operation['args'])
        number(mask)
        for field in fields:
            if field not in operation['args']: continue
            value = operation['args'][field]
            if field in wire.STRING_FIELDS: number(strings.index(value))
            elif field in wire.BOOL_FIELDS: out.append(int(value))
            else: number(value * 2 if value >= 0 else -value * 2 - 1)
    return gzip.compress(bytes(out), mtime=0)
