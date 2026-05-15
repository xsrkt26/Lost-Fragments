from __future__ import annotations

import argparse
import sys
from pathlib import Path

if __package__ is None or __package__ == "":
    sys.path.insert(0, str(Path(__file__).resolve().parent))

from design_config_common import DesignConfigValidator, REPO_ROOT


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate planner-editable Lost Fragments config files.")
    parser.add_argument("--root", default=str(REPO_ROOT), help="Repository root. Defaults to the current script's repo.")
    args = parser.parse_args(argv)

    validator = DesignConfigValidator(Path(args.root).resolve())
    result = validator.validate_all()

    for message in result.messages:
        print(f"{message.level}: {message.path}: {message.message}")

    summary = ", ".join(f"{key}={value}" for key, value in sorted(result.summary.items()))
    if result.error_count > 0:
        print(f"DESIGN_CONFIG_VALIDATION: FAIL ({result.error_count} errors, {result.warning_count} warnings) {summary}")
        return 1
    print(f"DESIGN_CONFIG_VALIDATION: PASS ({result.warning_count} warnings) {summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
