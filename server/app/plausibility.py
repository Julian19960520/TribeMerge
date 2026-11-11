"""Cheap after-the-fact sanity checks on uploaded snapshots.

The client is authoritative for single-player progress, so nothing here rejects a
save. A violation only flags the account: flagged accounts leave the public
ranking and are written to the audit log for manual review.
"""

from .config import get_settings

CURRENCIES = ("amber", "shells")


def _number(state: dict, key: str, default: int = 0) -> int:
    value = state.get(key, default)
    return int(value) if isinstance(value, (int, float)) and not isinstance(value, bool) else default


def check(previous: dict, current: dict, elapsed_sec: float, paid_amber: int = 0) -> list[str]:
    """Return human-readable reasons; empty means the upload looks plausible.

    paid_amber is amber the server granted for purchases since the previous upload
    (from its own ledger), so bought amber never flags an account."""
    s = get_settings()
    reasons: list[str] = []
    level = _number(current, "level", 1)
    if level < 1:
        reasons.append(f"level={level}")
    for key in ("xp", *CURRENCIES):
        if _number(current, key) < 0:
            reasons.append(f"{key}<0")
    # The first upload has no trusted baseline (players may start offline).
    if not previous or "level" not in previous:
        return reasons
    hours = max(0.0, elapsed_sec) / 3600.0
    level_gain = level - _number(previous, "level", 1)
    if level_gain > s.plaus_level_burst + s.plaus_level_per_hour * hours:
        reasons.append(f"level +{level_gain} in {hours:.2f}h")
    for key, burst, rate, paid in (("amber", s.plaus_amber_burst, s.plaus_amber_per_hour, max(0, paid_amber)),
                                   ("shells", s.plaus_shells_burst, s.plaus_shells_per_hour, 0)):
        gain = _number(current, key) - _number(previous, key)
        if gain > burst + rate * hours + paid:
            reasons.append(f"{key} +{gain} in {hours:.2f}h")
    return reasons
