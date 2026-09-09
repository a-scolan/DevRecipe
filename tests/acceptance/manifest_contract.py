#!/usr/bin/env python3
"""Validate the schema-version-2 DevRecipe manifest contract."""

from __future__ import annotations

from collections.abc import Mapping
from pathlib import Path
import sys
import tomllib
from typing import cast


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
KNOWN_PROFILES = frozenset({"default", "ai_agents", "cloud"})
KNOWN_TOP_LEVEL_SECTIONS = frozenset(
    {"metadata", "profiles", "packages", "runtimes", "tools", "containers"}
)
PACKAGE_PROVIDERS = {
    "windows": frozenset({"os"}),
    "macos": frozenset({"os", "cask"}),
    "linux": frozenset({"os", "flatpak"}),
}
REPOSITORY_MANIFESTS = (
    ("windows", "DevRecipe_windows.toml"),
    ("macos", "DevRecipe_macos.toml"),
    ("linux", "DevRecipe_linux.toml"),
)


def as_mapping(value: object) -> Mapping[object, object] | None:
    """Return a generic mapping only when the TOML value is a table."""
    if not isinstance(value, Mapping):
        return None
    return cast(Mapping[object, object], value)


def is_non_empty_name(value: object) -> bool:
    """Accept TOML identifiers that do not add surrounding or internal whitespace."""
    return isinstance(value, str) and bool(value) and value == value.strip() and not any(
        character.isspace() for character in value
    )


def add_error(errors: list[str], source: str, path: str, message: str) -> None:
    errors.append(f"{source}: {path}: {message}")


def validate_entry_tree(
    entries_by_profile: object,
    *,
    entry_type: str,
    allowed_providers: frozenset[str],
    declared_profiles: set[str],
    source: str,
    errors: list[str],
) -> None:
    """Validate the common profile/provider/category/package nesting."""
    profile_tables = as_mapping(entries_by_profile)
    if profile_tables is None:
        add_error(errors, source, entry_type, "must be a TOML table.")
        return

    for profile, providers_by_name in profile_tables.items():
        profile_path = f"{entry_type}.{profile}"
        if not is_non_empty_name(profile):
            add_error(errors, source, entry_type, "contains an invalid profile name.")
            continue
        if profile not in KNOWN_PROFILES:
            add_error(errors, source, profile_path, "unsupported profile.")
        elif profile not in declared_profiles:
            add_error(errors, source, profile_path, "profile is not declared in [profiles].")

        provider_tables = as_mapping(providers_by_name)
        if provider_tables is None:
            add_error(errors, source, profile_path, "must contain provider tables.")
            continue

        for provider, categories_by_name in provider_tables.items():
            provider_path = f"{profile_path}.{provider}"
            if not is_non_empty_name(provider):
                add_error(errors, source, profile_path, "contains an invalid provider.")
                continue
            if provider not in allowed_providers:
                expected = ", ".join(sorted(allowed_providers))
                add_error(
                    errors,
                    source,
                    provider_path,
                    f"unsupported provider; expected: {expected}.",
                )

            category_tables = as_mapping(categories_by_name)
            if category_tables is None:
                add_error(errors, source, provider_path, "must contain TOML categories.")
                continue

            for category, package_versions in category_tables.items():
                category_path = f"{provider_path}.{category}"
                if not is_non_empty_name(category):
                    add_error(errors, source, provider_path, "contains an invalid category.")
                    continue

                package_table = as_mapping(package_versions)
                if package_table is None:
                    add_error(errors, source, category_path, "must contain at least one entry.")
                    continue
                if not package_table and not (entry_type == "runtimes" and category == "optional"):
                    add_error(errors, source, category_path, "must contain at least one entry.")
                    continue

                for package, version in package_table.items():
                    package_path = f"{category_path}.{package}"
                    if not is_non_empty_name(package):
                        add_error(errors, source, category_path, "contains an invalid package identifier.")
                        continue
                    if not isinstance(version, str):
                        add_error(errors, source, package_path, "version must be a string.")
                        continue
                    if version == "":
                        if entry_type != "runtimes" or category != "optional":
                            add_error(
                                errors,
                                source,
                                package_path,
                                "empty version is reserved for runtimes in the optional category.",
                            )
                    elif version != version.strip():
                        add_error(errors, source, package_path, "version must not contain leading or trailing spaces.")


def validate_manifest(
    manifest: Mapping[object, object],
    *,
    platform: str,
    source: str = "manifest",
) -> list[str]:
    """Return every contract error found in one parsed manifest."""
    if platform not in PACKAGE_PROVIDERS:
        raise ValueError(f"Unknown DevRecipe platform: {platform}")

    errors: list[str] = []
    for section in manifest:
        if not isinstance(section, str) or section not in KNOWN_TOP_LEVEL_SECTIONS:
            add_error(errors, source, str(section), "unknown TOML section.")

    metadata = as_mapping(manifest.get("metadata"))
    if metadata is None:
        add_error(errors, source, "metadata", "[metadata] table is required.")
    elif metadata.get("schema_version") != 2:
        add_error(errors, source, "metadata.schema_version", "must be integer 2.")

    profile_table = as_mapping(manifest.get("profiles"))
    declared_profiles: set[str] = set()
    if profile_table is None:
        add_error(errors, source, "profiles", "[profiles] table is required.")
    else:
        for profile, description in profile_table.items():
            profile_path = f"profiles.{profile}"
            if not is_non_empty_name(profile):
                add_error(errors, source, "profiles", "contains an invalid profile name.")
                continue
            if profile not in KNOWN_PROFILES:
                add_error(errors, source, profile_path, "unsupported profile.")
                continue
            declared_profiles.add(profile)
            description_table = as_mapping(description)
            if description_table is None or not isinstance(description_table.get("description"), str):
                add_error(errors, source, profile_path, "must define a text description.")
            elif not description_table["description"].strip():
                add_error(errors, source, profile_path, "description cannot be empty.")

        if "default" not in declared_profiles:
            add_error(errors, source, "profiles.default", "required profile is missing.")

    for entry_type in ("packages", "runtimes", "tools"):
        if entry_type not in manifest:
            continue
        allowed_providers = PACKAGE_PROVIDERS[platform] if entry_type == "packages" else frozenset({"mise"})
        validate_entry_tree(
            manifest[entry_type],
            entry_type=entry_type,
            allowed_providers=allowed_providers,
            declared_profiles=declared_profiles,
            source=source,
            errors=errors,
        )

    if "containers" in manifest:
        validate_entry_tree(
            manifest["containers"],
            entry_type="containers",
            allowed_providers=PACKAGE_PROVIDERS[platform],
            declared_profiles=declared_profiles,
            source=source,
            errors=errors,
        )

    return errors


def validate_manifest_file(path: Path, *, platform: str) -> list[str]:
    """Parse then validate a manifest, returning readable parse or contract errors."""
    try:
        with path.open("rb") as manifest_file:
            manifest = tomllib.load(manifest_file)
    except (OSError, tomllib.TOMLDecodeError) as error:
        return [f"{path}: TOML is invalid or inaccessible: {error}"]
    return validate_manifest(manifest, platform=platform, source=str(path))


def validate_repository_manifests(repository_root: Path = REPOSITORY_ROOT) -> list[str]:
    """Validate every platform manifest shipped by this repository."""
    errors: list[str] = []
    for platform, manifest_name in REPOSITORY_MANIFESTS:
        errors.extend(validate_manifest_file(repository_root / manifest_name, platform=platform))
    return errors


def main(arguments: list[str] | None = None) -> int:
    """Run the repository-level validator as a small local quality gate."""
    arguments = sys.argv[1:] if arguments is None else arguments
    if arguments:
        print("Usage : python tests/acceptance/manifest_contract.py", file=sys.stderr)
        return 2

    errors = validate_repository_manifests()
    if errors:
        print("Invalid manifest contract:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1

    print("Valid DevRecipe v2 manifest contract.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())