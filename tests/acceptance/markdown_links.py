#!/usr/bin/env python3
"""Validate repository-local Markdown paths and heading anchors."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

from manifest_contract import REPOSITORY_ROOT


LINK_PATTERN = re.compile(r"(?<!!)\[[^\]]*\]\((?P<target><[^>]+>|[^)\s]+)(?:\s+[^)]*)?\)")
HEADING_PATTERN = re.compile(r"^(?: {0,3})(?:#{1,6})[ \t]+(?P<text>.*?)[ \t]*#*[ \t]*$")
FENCE_PATTERN = re.compile(r"^\s*(?P<marker>`{3,}|~{3,})")
INLINE_CODE_PATTERN = re.compile(r"`([^`]*)`")
INLINE_LINK_PATTERN = re.compile(r"\[([^\]]+)\]\([^)]+\)")


def markdown_anchor(value: str) -> str:
    """Return the GitHub-compatible anchor shape used by this repository."""
    value = INLINE_CODE_PATTERN.sub(r"\1", value)
    value = INLINE_LINK_PATTERN.sub(r"\1", value)
    value = value.casefold()
    value = "".join(character for character in value if character.isalnum() or character in {" ", "-", "_"})
    return re.sub(r"[\s-]+", "-", value).strip("-")


@lru_cache(maxsize=None)
def heading_anchors(path: Path) -> frozenset[str]:
    """Return all heading anchors in one Markdown document, excluding code fences."""
    anchors: set[str] = set()
    occurrences: dict[str, int] = {}
    fence_marker: str | None = None

    for line in path.read_text(encoding="utf-8").splitlines():
        fence = FENCE_PATTERN.match(line)
        if fence:
            marker = fence.group("marker")[0]
            if fence_marker is None:
                fence_marker = marker
            elif fence_marker == marker:
                fence_marker = None
            continue
        if fence_marker is not None:
            continue

        heading = HEADING_PATTERN.match(line)
        if heading is None:
            continue
        base_anchor = markdown_anchor(heading.group("text"))
        if not base_anchor:
            continue
        occurrence = occurrences.get(base_anchor, 0)
        occurrences[base_anchor] = occurrence + 1
        anchors.add(base_anchor if occurrence == 0 else f"{base_anchor}-{occurrence}")

    return frozenset(anchors)


def display_path(path: Path, repository_root: Path) -> str:
    """Render paths relative to the validated repository when possible."""
    try:
        return path.relative_to(repository_root).as_posix()
    except ValueError:
        return str(path)


def target_parts(target: str) -> tuple[str, str] | None:
    """Return decoded local path and fragment, or None for an external link."""
    target = target.strip()
    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1]
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc:
        return None
    return unquote(parsed.path), unquote(parsed.fragment)


def validate_markdown_links(repository_root: Path = REPOSITORY_ROOT) -> list[str]:
    """Return errors for broken repository-local paths and Markdown anchors."""
    repository_root = repository_root.resolve()
    errors: list[str] = []
    for source_path in sorted(repository_root.rglob("*.md")):
        if ".git" in source_path.parts:
            continue
        for line_number, line in enumerate(source_path.read_text(encoding="utf-8").splitlines(), start=1):
            for match in LINK_PATTERN.finditer(line):
                target = target_parts(match.group("target"))
                if target is None:
                    continue
                relative_path, fragment = target
                destination = (source_path.parent / relative_path).resolve() if relative_path else source_path.resolve()
                source_name = display_path(source_path, repository_root)

                try:
                    destination.relative_to(repository_root)
                except ValueError:
                    errors.append(f"{source_name}:{line_number}: link outside repository: {match.group('target')}")
                    continue

                if not destination.is_file():
                    errors.append(f"{source_name}:{line_number}: target not found: {match.group('target')}")
                    continue
                if not fragment:
                    continue
                if destination.suffix.casefold() != ".md":
                    errors.append(f"{source_name}:{line_number}: anchor on a non-Markdown file: {match.group('target')}")
                    continue

                anchor = markdown_anchor(fragment)
                if anchor not in heading_anchors(destination):
                    errors.append(f"{source_name}:{line_number}: anchor not found: {match.group('target')}")

    return errors


def main(arguments: list[str] | None = None) -> int:
    """Run the local Markdown-link check as a standalone quality gate."""
    arguments = sys.argv[1:] if arguments is None else arguments
    if arguments:
        print("Usage : python tests/acceptance/markdown_links.py", file=sys.stderr)
        return 2

    errors = validate_markdown_links()
    if errors:
        print("Invalid local Markdown links:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1

    print("Valid local Markdown links.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())