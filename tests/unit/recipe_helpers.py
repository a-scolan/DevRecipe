import re
import tomllib
from pathlib import Path


def resolve_profiles(requested: list[str]) -> list[str]:
    """Pure implementation of profile resolution and normalization."""
    known_profiles = {"default", "ai_agents", "cloud"}
    selected = ["default"]
    for val in requested:
        for candidate in val.split(","):
            norm = candidate.strip().lower().replace("-", "_")
            if not norm:
                continue
            if norm not in known_profiles:
                raise ValueError(f"Unknown profile '{candidate}'. Available profiles: default, ai-agents, cloud.")
            if norm not in selected:
                selected.append(norm)
    return selected


def calculate_levenshtein_score(query: str, evidence: str) -> int:
    """Calculates Levenshtein similarity score (0 to 100) identical to DevRecipe preflight."""
    left = query.lower()
    right = evidence.lower()
    if left == right:
        return 100
    if not left or not right:
        return 0

    previous = list(range(len(right) + 1))
    for i, c1 in enumerate(left, 1):
        current = [i] + [0] * len(right)
        for j, c2 in enumerate(right, 1):
            sub = previous[j - 1] + (0 if c1 == c2 else 1)
            deletion = previous[j] + 1
            insertion = current[j - 1] + 1
            current[j] = min(sub, deletion, insertion)
        previous = current

    max_len = max(len(left), len(right))
    return int(round((1 - (previous[len(right)] / max_len)) * 100))


def test_separator_prefix_match(query: str, evidence: str) -> bool:
    """Checks separator-flexible prefix match identical to DevRecipe preflight."""
    tokens = [t for t in re.split(r'[^A-Za-z0-9]+', query) if t]
    if not tokens:
        return False
    escaped = [re.escape(t) for t in tokens]
    pattern = r'(?i)^' + r'[^A-Za-z0-9]*'.join(escaped) + r'(?=$|[^A-Za-z0-9])'
    return bool(re.search(pattern, evidence))


def parse_and_validate_manifest(manifest_path: Path) -> dict:
    """Loads and validates a DevRecipe TOML manifest."""
    if not manifest_path.is_file():
        raise FileNotFoundError(f"Manifest not found: {manifest_path}")

    with manifest_path.open("rb") as f:
        data = tomllib.load(f)

    if data.get("metadata", {}).get("schema_version") != 2:
        raise ValueError("Invalid or missing schema_version, expected 2")

    if "profiles" not in data or "default" not in data["profiles"]:
        raise ValueError("Manifest missing required [profiles.default]")

    return data
