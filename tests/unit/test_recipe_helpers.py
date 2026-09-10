import unittest
from pathlib import Path

from tests.unit.recipe_helpers import (
    calculate_levenshtein_score,
    parse_and_validate_manifest,
    resolve_profiles,
    test_separator_prefix_match,
)


class TestRecipeHelpers(unittest.TestCase):
    def test_resolve_profiles_default_always_included(self):
        res = resolve_profiles([])
        self.assertEqual(res, ["default"])

    def test_resolve_profiles_hyphen_and_underscore_tolerance(self):
        self.assertEqual(resolve_profiles(["ai-agents"]), ["default", "ai_agents"])
        self.assertEqual(resolve_profiles(["ai_agents"]), ["default", "ai_agents"])
        self.assertEqual(resolve_profiles(["ai-agents,cloud"]), ["default", "ai_agents", "cloud"])

    def test_resolve_profiles_unknown_rejected(self):
        with self.assertRaises(ValueError):
            resolve_profiles(["unknown-profile"])

    def test_levenshtein_score_exact_match(self):
        self.assertEqual(calculate_levenshtein_score("git", "git"), 100)
        self.assertEqual(calculate_levenshtein_score("Git", "git"), 100)

    def test_levenshtein_score_dissimilar(self):
        score = calculate_levenshtein_score("git", "github")
        self.assertLess(score, 90)

    def test_levenshtein_score_high_similarity(self):
        score = calculate_levenshtein_score("firefox-developer", "FirefoxDeveloper Edition")
        self.assertGreaterEqual(score, 60)

    def test_separator_prefix_match(self):
        self.assertTrue(test_separator_prefix_match("docker-compose", "dockercompose"))
        self.assertTrue(test_separator_prefix_match("docker-compose", "docker-compose.exe"))
        self.assertTrue(test_separator_prefix_match("firefox-developer", "FirefoxDeveloper Edition"))
        self.assertFalse(test_separator_prefix_match("git", "github"))

    def test_manifest_parsing_all_platforms(self):
        repo_root = Path(__file__).resolve().parent.parent.parent
        for platform in ("windows", "macos", "linux"):
            path = repo_root / f"DevRecipe_{platform}.toml"
            data = parse_and_validate_manifest(path)
            self.assertEqual(data["metadata"]["schema_version"], 2)
            self.assertIn("default", data["profiles"])


if __name__ == "__main__":
    unittest.main()
