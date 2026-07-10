from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str]) -> int:
    print("> " + " ".join(command))
    return subprocess.call(command, cwd=ROOT)


def main() -> int:
	persistence_result = run([sys.executable, "tests/run_persistence_tests.py"])
	if persistence_result != 0:
		return persistence_result

	dirty_save_result = run([sys.executable, "tests/run_dirty_save_tests.py"])
	if dirty_save_result != 0:
		return dirty_save_result

	return run([sys.executable, "tests/run_loading_tests.py"])


if __name__ == "__main__":
    sys.exit(main())
