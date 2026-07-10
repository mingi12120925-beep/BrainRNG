from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str]) -> int:
    print("> " + " ".join(command))
    return subprocess.call(command, cwd=ROOT)


def main() -> int:
    return run([sys.executable, "tests/run_persistence_tests.py"])


if __name__ == "__main__":
    sys.exit(main())
