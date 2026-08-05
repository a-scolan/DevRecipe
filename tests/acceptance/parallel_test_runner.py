#!/usr/bin/env python3
"""Run local unittest modules concurrently in isolated worker processes."""

from __future__ import annotations

import argparse
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass
import io
import os
from pathlib import Path
import sys
import time
import traceback
import unittest


TEST_DIRECTORY = Path(__file__).resolve().parent
DEFAULT_MAX_WORKERS = 4


@dataclass(frozen=True)
class TestOutcome:
    """Result returned by one independently executed unittest case."""

    test_id: str
    elapsed_seconds: float
    tests_run: int
    skipped: int
    passed: bool
    output: str


def add_test_directory_to_path() -> None:
    """Make sibling test modules importable in spawned worker processes."""
    test_directory = str(TEST_DIRECTORY)
    if test_directory not in sys.path:
        sys.path.insert(0, test_directory)


def iter_test_cases(suite: unittest.TestSuite):
    """Yield individual cases from a recursively nested unittest suite."""
    for test in suite:
        if isinstance(test, unittest.TestSuite):
            yield from iter_test_cases(test)
        else:
            yield test


def discover_test_ids() -> list[str]:
    """Discover every local test case without executing it in this process."""
    add_test_directory_to_path()
    suite = unittest.defaultTestLoader.discover(
        start_dir=str(TEST_DIRECTORY),
        pattern="test_*.py",
        top_level_dir=str(TEST_DIRECTORY),
    )
    return [test.id() for test in iter_test_cases(suite)]


def run_test_case(test_id: str) -> TestOutcome:
    """Execute one test by ID and return its captured unittest result."""
    add_test_directory_to_path()
    suite = unittest.defaultTestLoader.loadTestsFromName(test_id)
    stream = io.StringIO()
    started = time.perf_counter()
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    return TestOutcome(
        test_id=test_id,
        elapsed_seconds=time.perf_counter() - started,
        tests_run=result.testsRun,
        skipped=len(result.skipped),
        passed=result.wasSuccessful(),
        output=stream.getvalue(),
    )


def worker_count(requested: int | None, test_count: int) -> int:
    """Select a bounded default while allowing an explicit worker count."""
    if test_count == 0:
        return 0
    if requested is not None:
        return min(requested, test_count)
    return min(DEFAULT_MAX_WORKERS, os.cpu_count() or 1, test_count)


def run_test_cases(test_ids: list[str], workers: int) -> list[TestOutcome]:
    """Dispatch independent cases and return results in discovery order."""
    outcomes: dict[str, TestOutcome] = {}
    with ProcessPoolExecutor(max_workers=workers) as executor:
        futures = {executor.submit(run_test_case, test_id): test_id for test_id in test_ids}
        for future in as_completed(futures):
            test_id = futures[future]
            try:
                outcomes[test_id] = future.result()
            except Exception:
                outcomes[test_id] = TestOutcome(
                    test_id=test_id,
                    elapsed_seconds=0,
                    tests_run=0,
                    skipped=0,
                    passed=False,
                    output=traceback.format_exc(),
                )
    return [outcomes[test_id] for test_id in test_ids]


def positive_worker_count(value: str) -> int:
    """Parse a positive worker count for argparse."""
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("worker count must be at least 1")
    return parsed


def main(arguments: list[str] | None = None) -> int:
    """Run every local unittest case with a small, configurable worker pool."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-j",
        "--jobs",
        type=positive_worker_count,
        help=f"worker processes (default: up to {DEFAULT_MAX_WORKERS})",
    )
    arguments = sys.argv[1:] if arguments is None else arguments
    options = parser.parse_args(arguments)

    test_ids = discover_test_ids()
    workers = worker_count(options.jobs, len(test_ids))
    if workers == 0:
        print("No tests discovered.", file=sys.stderr)
        return 1

    print(f"Running {len(test_ids)} tests with {workers} worker process(es).")
    outcomes = run_test_cases(test_ids, workers)
    failures = [outcome for outcome in outcomes if not outcome.passed]
    skipped = sum(outcome.skipped for outcome in outcomes)

    for outcome in outcomes:
        status = "SKIP" if outcome.skipped else "PASS" if outcome.passed else "FAIL"
        print(f"{status} {outcome.test_id} ({outcome.elapsed_seconds:.3f}s)")
        if not outcome.passed:
            print(outcome.output, end="", file=sys.stderr)

    print(f"Ran {sum(outcome.tests_run for outcome in outcomes)} tests; {skipped} skipped.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())