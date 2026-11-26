"""Run the complete pre-release gate: import, configuration, resources, WAL, UI and server.

Usage: python tools/check_project.py --godot /path/to/godot --python /path/to/server/python
Missing Godot, failed script loads, and skipped server tests are failures rather than
partial successes. Each check has isolated temporary player and cloud files.
"""
from __future__ import annotations
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Compile Error:|^ERROR:|^FAIL(?: |:)", re.MULTILINE)


def run(command: list[str], *, env: dict[str, str], cwd: Path = ROOT, timeout: int = 300) -> str:
    result = subprocess.run(command, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=timeout)
    print(result.stdout, end="", flush=True)
    if result.returncode or SCRIPT_ERRORS.search(result.stdout):
        raise SystemExit(f"Check failed: {' '.join(command[:4])}")
    return result.stdout


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("TRIBE_GODOT") or os.environ.get("TRIBE_REPLAY_GODOT") or shutil.which("godot") or shutil.which("godot4"))
    parser.add_argument("--python", default=sys.executable, help="Python environment with server requirements-dev installed")
    parser.add_argument("--section", choices=("all", "frontend", "backend"), default="all", help="Explicit partial checks; all is the release gate")
    args = parser.parse_args()
    if not args.godot:
        raise SystemExit("Godot 4.6.3 is required; pass --godot or set TRIBE_GODOT")
    godot = str(Path(args.godot).resolve())
    env = dict(os.environ, TRIBE_GODOT=godot, GODOT_SILENCE_ROOT_WARNING="1")
    version = run([godot, "--version"], env=env).strip()
    if not version.startswith("4.6.3."):
        raise SystemExit(f"Expected Godot 4.6.3, received {version}")
    run([sys.executable, "tools/text_catalog.py", "--check"], env=env)
    run([sys.executable, "tools/stamp_replay.py"], env=env)
    run([sys.executable, "tools/stamp_replay.py", "--check"], env=env)
    run([sys.executable, "tools/bake_character_sprites.py", "--check"], env=env)
    run([sys.executable, "-m", "unittest", "discover", "-s", "tools/tests", "-p", "test_*.py"], env=env)
    with tempfile.TemporaryDirectory(prefix="tribe-check-") as temporary:
        temp = Path(temporary)
        env["XDG_DATA_HOME"] = str(temp / "user-data")
        if args.section in ("all", "frontend"):
            run([godot, "--headless", "--editor", "--path", str(ROOT), "--quit"], env=env)
            scripts = [
                ("check_text_catalog", ["--replay-test", "--cloud-off"], "text-catalog"),
                ("check_configuration", ["--replay-worker", "--cloud-off"], "configuration"),
                ("check_economy", ["--replay-test", "--cloud-off"], "economy"),
                ("check_fifth_line_unlock", ["--replay-test", "--cloud-off", "--phase=write"], "fifth-line-unlock"),
                ("check_fifth_line_unlock", ["--replay-test", "--cloud-off", "--phase=read"], "fifth-line-unlock"),
                ("check_early_reward_upgrade", ["--replay-test", "--cloud-off", "--phase=write"], "early-reward-upgrade"),
                ("check_early_reward_upgrade", ["--replay-test", "--cloud-off", "--phase=read"], "early-reward-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=write"], "browser-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=read"], "browser-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=write", "--previous-rules=80240f5439369be58b4aa8cdf831b9c5553ee39cf5b50e0661ce7a888915b3a9"], "coin-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=read"], "coin-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=write", "--previous-rules=38c358b1683e4966cd8bb9539303288785bd1c0d1195e1a53613d801ad0183d2"], "rare-coin-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=read"], "rare-coin-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=write", "--previous-rules=fa628d805418c824fee3bed4c9278942a9249dc4d95f5022b1fcd8b79af59f56"], "level-two-coin-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=read"], "level-two-coin-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=write", "--previous-rules=31ec7cbd1f190378cf1a8814c3ac0f9c298caff482c76815e252c207d22bdd7b"], "order-flow-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=read"], "order-flow-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=write", "--previous-rules=ef86550b91aa273856e22b106727f8dda55d4d85327c1c195b7470389ada58f0"], "starter-shop-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=read"], "starter-shop-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=write", "--previous-rules=e30916c754d1633c67d3e3affc43f587e352969010aad5955cfb8eb0660d0d97", "--owned-generator=basket_6"], "producer-pacing-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=read", "--owned-generator=basket_6"], "producer-pacing-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=write", "--previous-rules=4ec090c45c807a5174aaae85245097d900a4a4abbe4d1951ffbed8afd35faf1d", "--owned-generator=basket_6"], "text-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=read", "--owned-generator=basket_6"], "text-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=write", "--previous-rules=1865782de6ee1dd9fb3f854d042154831e6cd96d99abdb30bcb0f95eafce4d8f", "--owned-generator=basket_6"], "cook-pacing-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=read", "--owned-generator=basket_6"], "cook-pacing-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=write", "--previous-rules=e074486b0d78b486fb0cb7d423172f49966d3a1708e49ac9e342e3fe6a0c730e", "--owned-generator=basket_6"], "hot-shop-save-upgrade"),
                ("check_browser_save_upgrade", ["--replay-test", "--cloud-off", "--phase=read", "--owned-generator=basket_6"], "hot-shop-save-upgrade"),
                ("check_resources", ["--cloud-off"], "resources-client"),
                ("check_resources", ["--replay-worker", "--cloud-off"], "resources-worker"),
                ("check_export_items", ["--cloud-off"], "source-resources"),
                ("check_domain_rules", ["--replay-test", "--cloud-off"], "domains"),
                ("check_onboarding_stages", ["--replay-test", "--cloud-off"], "onboarding-stages"),
                ("check_cook_pacing", ["--replay-test", "--cloud-off"], "cook-pacing"),
                ("check_early_order_mix", ["--replay-test", "--cloud-off"], "early-order-mix"),
                ("check_order_flow", ["--replay-test", "--cloud-off"], "order-flow"),
                ("check_order_xp", ["--replay-test", "--cloud-off"], "order-xp"),
                ("check_activity_schedule", ["--replay-test", "--cloud-off"], "activity-schedule"),
                ("check_village_drag", ["--replay-test", "--cloud-off"], "village-drag"),
                ("check_chest_exit", ["--replay-test", "--cloud-off"], "chest-exit"),
                ("check_starter_generator", ["--replay-test", "--cloud-off"], "starter-generator"),
                ("check_craft_book_ui", ["--replay-test", "--cloud-off"], "craft-book-ui"),
                ("check_guide_playthrough", ["--replay-test", "--cloud-off"], "guide-playthrough"),
                ("check_guide_fast_merge", ["--replay-test", "--cloud-off"], "guide-fast-merge"),
                ("check_guide_resume", ["--replay-test", "--cloud-off"], "guide-resume"),
                ("check_onboarding_fixes", ["--replay-test", "--cloud-off"], "onboarding-fixes"),
                ("check_coin_discovery", ["--replay-test", "--cloud-off"], "coin-discovery"),
                ("check_resource_drops", ["--cloud-off"], "resource-drops"),
                ("check_generator_growth", ["--replay-test", "--cloud-off"], "generator-growth"),
                ("check_producer_pacing", ["--replay-test", "--cloud-off"], "producer-pacing"),
                ("check_build_flow", ["--replay-test", "--cloud-off"], "build-flow"),
                ("check_tips_layering", ["--replay-test", "--cloud-off"], "tips-layering"),
                ("check_storage", ["--replay-test", "--cloud-off"], "storage"),
                ("check_chest_grades", ["--replay-test", "--cloud-off"], "chest-grades"),
                ("check_rewards", ["--replay-test", "--cloud-off"], "rewards"),
                ("check_numeric_resources", ["--replay-test", "--cloud-off"], "numeric-resources"),
                ("check_replay_journal", ["--replay-test", "--cloud-off"], "journal"),
                ("check_replay_rules", ["--replay-test", "--cloud-off"], "rules-edit"),
                ("check_ui_refactor", ["--replay-test", "--cloud-off"], "ui"),
                ("check_runtime_optimization", ["--replay-test", "--cloud-off"], "runtime-optimization"),
                ("check_gm_all", ["--replay-test", "--cloud-off"], "gm-all"),
                ("check_collection_cards", ["--replay-test", "--cloud-off"], "collection-cards"),
                ("check_shop_and_activity_buttons", ["--replay-test", "--cloud-off"], "shop-activity"),
                ("check_hot_shop_tiers", ["--replay-test", "--cloud-off"], "hot-shop-tiers"),
                ("check_merge_event", ["--replay-test", "--cloud-off"], "merge-event"),
                ("check_merge_shop", ["--replay-test", "--cloud-off"], "merge-shop"),
                ("check_sim_policy", ["--replay-test", "--cloud-off"], "sim-policy"),
                ("check_sim_lines", ["--replay-test", "--cloud-off"], "sim-lines"),
            ]
            for name, arguments, label in scripts:
                script = ROOT / "tools" / f"{name}.gd"
                if not script.is_file():
                    raise SystemExit(f"Required regression check missing: {script.relative_to(ROOT)}")
                run([godot, "--headless", "--path", str(ROOT), "--script", str(script), "--", *arguments,
                     f"--save={temp / (label + '-save.json')}", f"--cloud-state={temp / (label + '-cloud.json')}"], env=env)
            run([sys.executable, "tools/check_config_editor_save.py", "--godot", godot], env=env)
        if args.section in ("all", "backend"):
            output = run([args.python, "-m", "pytest", "-q", "-rs"], env=env, cwd=ROOT / "server", timeout=600)
            if re.search(r"\b[1-9]\d* skipped\b", output):
                raise SystemExit("Server tests skipped; release validation is incomplete")
            run([godot, "--headless", "--path", str(ROOT), "--script", str(ROOT / "tools" / "check_cloud_save.gd"), "--",
                 "--replay-test", "--cloud-off", f"--save={temp / 'cloud-boot-save.json'}",
                 f"--cloud-state={temp / 'cloud-boot-cloud.json'}", f"--python={args.python}"], env=env)
    print("PASS complete release gate" if args.section == "all" else f"PASS explicit {args.section} checks (other section was not run)")


if __name__ == "__main__":
    main()
