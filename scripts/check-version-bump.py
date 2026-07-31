#!/usr/bin/env python3
"""Fail a PR that changes plugin content without bumping the plugin version.

Claude Code resolves a plugin's version from `plugin.json` first. If that string
does not change, `/plugin update` and background auto-update both skip the
plugin and every existing user keeps the cached copy. Pushing a fix without a
bump therefore reaches nobody, and looks identical to a successful release.

Usage: check-version-bump.py <base-sha> <head-sha>
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

PLUGINS_PREFIX = "plugins/"
MANIFEST = ".claude-plugin/plugin.json"


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, check=True
    ).stdout


def version_at(ref: str, manifest_path: str) -> str | None:
    """Read plugin.json's version at a git ref, or None if absent/unparseable."""
    try:
        blob = subprocess.run(
            ["git", "show", f"{ref}:{manifest_path}"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except subprocess.CalledProcessError:
        return None
    try:
        value = json.loads(blob).get("version")
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, str) else None


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(f"usage: {Path(argv[0]).name} <base-sha> <head-sha>", file=sys.stderr)
        return 2
    base, head = argv[1], argv[2]

    changed = [
        line
        for line in git("diff", "--name-only", f"{base}...{head}").splitlines()
        if line.strip()
    ]
    touched_plugins = sorted(
        {
            path.split("/")[1]
            for path in changed
            if path.startswith(PLUGINS_PREFIX) and len(path.split("/")) > 2
        }
    )

    if not touched_plugins:
        print("✔ no plugin content changed; version bump not required")
        return 0

    failures: list[str] = []
    for plugin in touched_plugins:
        manifest_path = f"{PLUGINS_PREFIX}{plugin}/{MANIFEST}"
        base_version = version_at(base, manifest_path)
        head_version = version_at(head, manifest_path)

        if head_version is None:
            failures.append(
                f"{plugin}: {manifest_path} is missing or has no string 'version' at HEAD"
            )
            continue
        if base_version is None:
            print(f"✔ {plugin}: new plugin at version {head_version}")
            continue
        if base_version == head_version:
            failures.append(
                f"{plugin}: content under {PLUGINS_PREFIX}{plugin}/ changed but 'version' "
                f"is still {head_version!r}. Claude Code pins on this string, so existing "
                f"users would never receive the change. Bump it in {manifest_path}."
            )
        else:
            print(f"✔ {plugin}: version bumped {base_version} -> {head_version}")

    if failures:
        print("\n✘ version-bump guard failed:\n", file=sys.stderr)
        for failure in failures:
            print(f"  ❯ {failure}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
