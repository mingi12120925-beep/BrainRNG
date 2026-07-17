from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str]) -> int:
    print("> " + " ".join(command))
    return subprocess.call(command, cwd=ROOT)


def main() -> int:
    test_files = [
        "tests/run_persistence_tests.py",
        "tests/run_dirty_save_tests.py",
        "tests/run_loading_tests.py",
        "tests/run_lobby_map_tests.py",
        "tests/run_study_simulator_tests.py",
    ]

    for test_file in test_files:
        result = run([sys.executable, test_file])
        if result != 0:
            return result

    return 0


if __name__ == "__main__":
    sys.exit(main())
