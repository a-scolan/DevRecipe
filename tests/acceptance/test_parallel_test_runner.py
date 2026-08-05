#!/usr/bin/env python3
"""Contracts for the local parallel unittest runner."""

from __future__ import annotations

import unittest

from parallel_test_runner import discover_test_ids, run_test_case, worker_count


class ParallelTestRunnerTests(unittest.TestCase):
    """Keep process-runner mechanics covered without nesting worker pools."""

    def test_discovery_includes_the_baseline_suite(self) -> None:
        test_ids = discover_test_ids()
        self.assertIn(
            "test_baseline.UnixBootstrapperContractTests.test_public_runtime_messages_do_not_regress_to_french",
            test_ids,
        )

    def test_run_test_case_reports_a_passing_baseline_case(self) -> None:
        outcome = run_test_case(
            "test_baseline.UnixBootstrapperContractTests.test_public_runtime_messages_do_not_regress_to_french"
        )
        self.assertTrue(outcome.passed, outcome.output)
        self.assertEqual(1, outcome.tests_run)

    def test_worker_count_honours_explicit_and_bounded_values(self) -> None:
        self.assertEqual(1, worker_count(None, 1))
        self.assertEqual(2, worker_count(8, 2))
        self.assertEqual(2, worker_count(2, 10))