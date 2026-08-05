#!/usr/bin/env python3
"""Run fast deterministic DevRecipe checks without sandboxed recipe runs."""

from __future__ import annotations

import sys

from quality_gate import run_developer_checks


def main(arguments: list[str] | None = None) -> int:
    """Run the local developer feedback gate."""
    arguments = sys.argv[1:] if arguments is None else arguments
    if arguments:
        print("Usage : python tests/acceptance/developer_gate.py", file=sys.stderr)
        return 2
    return 1 if run_developer_checks() else 0


if __name__ == "__main__":
    raise SystemExit(main())