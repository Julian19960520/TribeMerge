"""Pin the gameplay code revision in data, shared by source and Web exports."""
import hashlib
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
paths = [root / 'scripts/Game.gd', root / 'scripts/HotDeals.gd', root / 'scripts/OrderRoll.gd', root / 'scripts/Rewards.gd']
paths += sorted((root / 'scripts/events').glob('*.gd'))
paths += sorted((root / 'scripts/replay').glob('*.gd'))
h = hashlib.sha256()
for p in sorted(paths):
    h.update(p.relative_to(root).as_posix().encode() + b'\0' + p.read_bytes() + b'\0')
(root / 'data/replay_build.json').write_text(json.dumps({'protocol': 1, 'godot': '4.6.3', 'code_sha256': h.hexdigest()}, indent=2) + '\n')
