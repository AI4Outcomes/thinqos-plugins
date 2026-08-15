#!/usr/bin/env python3
"""Structural validation for the thinqos-plugins marketplace.

`claude plugin validate` checks a single plugin manifest. It does not check the
marketplace file, that a plugin's `source` path resolves, that hook commands
point at scripts that exist and are executable, or that the marketplace name is
still loadable. Those failures reach users through auto-update with no rollback,
so they are gated here.

Exits non-zero with an explicit list of problems. stdlib only, no network.
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MARKETPLACE = REPO_ROOT / ".claude-plugin" / "marketplace.json"

# Names reserved for official Anthropic use. A marketplace registered under one
# of these stops loading for every existing user and reports itself as an
# untrusted source, so renaming into one is a silent total outage.
# Source: https://code.claude.com/docs/en/plugin-marketplaces
RESERVED_MARKETPLACE_NAMES = {
    "claude-code-marketplace",
    "claude-code-plugins",
    "claude-plugins-official",
    "claude-plugins-community",
    "claude-community",
    "anthropic-marketplace",
    "anthropic-plugins",
    "agent-skills",
    "anthropic-agent-skills",
    "knowledge-work-plugins",
    "life-sciences",
    "claude-for-legal",
    "claude-for-financial-services",
    "financial-services-plugins",
    "first-party-plugins",
    "healthcare",
}

KEBAB = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
PLUGIN_ROOT_VAR = "${CLAUDE_PLUGIN_ROOT}"

errors: list[str] = []


def fail(msg: str) -> None:
    errors.append(msg)


def load_json(path: Path) -> object | None:
    if not path.exists():
        fail(f"{path.relative_to(REPO_ROOT)}: missing")
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        fail(f"{path.relative_to(REPO_ROOT)}: invalid JSON: {exc}")
        return None


def check_hooks(
    plugin_dir: Path,
    rel: str,
    claude_manifest: dict[str, object],
) -> None:
    expected_hook_path = "./.claude-plugin/hooks.json"
    if claude_manifest.get("hooks") != expected_hook_path:
        fail(
            f"{rel}/.claude-plugin/plugin.json: 'hooks' must be "
            f"{expected_hook_path!r} so Codex does not auto-discover Claude hooks"
        )
    root_hooks = plugin_dir / "hooks" / "hooks.json"
    if root_hooks.exists():
        fail(
            f"{rel}/hooks/hooks.json: root hook discovery is shared with Codex; "
            f"move Claude-only hooks to {expected_hook_path}"
        )
    hooks_file = plugin_dir / expected_hook_path
    data = load_json(hooks_file)
    if data is None:
        return
    if not isinstance(data, dict) or not isinstance(data.get("hooks"), dict):
        fail(f"{rel}/{expected_hook_path}: expected a top-level 'hooks' object")
        return
    for event, entries in data["hooks"].items():
        if not isinstance(entries, list):
            fail(f"{rel}/{expected_hook_path}: '{event}' must be a list")
            continue
        for entry in entries:
            for hook in entry.get("hooks", []) if isinstance(entry, dict) else []:
                if not isinstance(hook, dict):
                    fail(f"{rel}/{expected_hook_path}: '{event}' has a non-object hook")
                    continue
                if not hook.get("type"):
                    fail(f"{rel}/{expected_hook_path}: '{event}' hook is missing 'type'")
                command = hook.get("command", "")
                if hook.get("type") != "command" or not isinstance(command, str):
                    continue
                if PLUGIN_ROOT_VAR not in command:
                    fail(
                        f"{rel}/{expected_hook_path}: '{event}' command does not use "
                        f"{PLUGIN_ROOT_VAR}, so it will not resolve once installed: {command}"
                    )
                    continue
                # Resolve the script path out of the command string.
                tail = command.split(PLUGIN_ROOT_VAR, 1)[1].lstrip('"').lstrip("/")
                script_rel = tail.split()[0].strip('"') if tail.split() else ""
                script = plugin_dir / script_rel
                if not script.is_file():
                    fail(
                        f"{rel}/{expected_hook_path}: '{event}' points at missing script "
                        f"{script_rel}"
                    )
                elif not os.access(script, os.X_OK):
                    fail(
                        f"{rel}/{script_rel}: referenced by the '{event}' hook but not "
                        f"executable (chmod +x)"
                    )


def check_skills(plugin_dir: Path, rel: str) -> None:
    skills_dir = plugin_dir / "skills"
    if not skills_dir.is_dir():
        return
    for child in sorted(skills_dir.iterdir()):
        if not child.is_dir():
            continue
        skill_md = child / "SKILL.md"
        if not skill_md.is_file():
            fail(f"{rel}/skills/{child.name}: missing SKILL.md")
            continue
        text = skill_md.read_text()
        if not text.startswith("---"):
            fail(f"{rel}/skills/{child.name}/SKILL.md: missing YAML frontmatter")
            continue
        parts = text.split("---", 2)
        front = parts[1] if len(parts) >= 3 else ""
        for key in ("name", "description"):
            if not re.search(rf"^{key}\s*:", front, re.MULTILINE):
                fail(f"{rel}/skills/{child.name}/SKILL.md: frontmatter missing '{key}'")


def check_codex_manifest(
    plugin_dir: Path,
    rel: str,
    claude_manifest: dict[str, object],
) -> None:
    """Require an explicit Codex surface instead of falling back to Claude hooks."""
    path = plugin_dir / ".codex-plugin" / "plugin.json"
    manifest = load_json(path)
    if not isinstance(manifest, dict):
        if manifest is not None:
            fail(f"{rel}/.codex-plugin/plugin.json: expected a JSON object")
        return
    if manifest.get("name") != claude_manifest.get("name"):
        fail(
            f"{rel}/.codex-plugin/plugin.json: 'name' must match the Claude manifest"
        )
    if manifest.get("version") != claude_manifest.get("version"):
        fail(
            f"{rel}/.codex-plugin/plugin.json: 'version' must match the Claude manifest"
        )
    if manifest.get("skills") != "./skills/":
        fail(
            f"{rel}/.codex-plugin/plugin.json: 'skills' must preserve the packaged skills"
        )
    if "hooks" in manifest:
        fail(
            f"{rel}/.codex-plugin/plugin.json: 'hooks' is unsupported by Codex; "
            "omit it and keep Claude hooks out of root discovery"
        )
    allowed = {
        "id",
        "name",
        "version",
        "description",
        "skills",
        "apps",
        "mcpServers",
        "interface",
        "author",
        "homepage",
        "repository",
        "license",
        "keywords",
    }
    for key in sorted(set(manifest) - allowed):
        fail(
            f"{rel}/.codex-plugin/plugin.json: field {key!r} is unsupported by Codex"
        )
    interface = manifest.get("interface")
    if not isinstance(interface, dict):
        fail(f"{rel}/.codex-plugin/plugin.json: 'interface' must be an object")
        return
    for key in (
        "displayName",
        "shortDescription",
        "longDescription",
        "developerName",
        "category",
    ):
        if not isinstance(interface.get(key), str) or not interface[key].strip():
            fail(
                f"{rel}/.codex-plugin/plugin.json: 'interface.{key}' must be a "
                "non-empty string"
            )
    capabilities = interface.get("capabilities")
    if not isinstance(capabilities, list) or not all(
        isinstance(value, str) and value.strip() for value in capabilities
    ):
        fail(
            f"{rel}/.codex-plugin/plugin.json: 'interface.capabilities' must be "
            "an array of strings"
        )
    if "defaultPrompt" not in interface and "default_prompt" not in interface:
        fail(
            f"{rel}/.codex-plugin/plugin.json: 'interface.defaultPrompt' is required"
        )


def main() -> int:
    market = load_json(MARKETPLACE)
    if not isinstance(market, dict):
        if market is not None:
            fail(".claude-plugin/marketplace.json: expected a JSON object")
        print_report()
        return 1

    name = market.get("name")
    if not isinstance(name, str) or not KEBAB.match(name):
        fail(f"marketplace.json: 'name' must be kebab-case, got {name!r}")
    elif name in RESERVED_MARKETPLACE_NAMES:
        fail(
            f"marketplace.json: 'name' {name!r} is reserved for Anthropic. A marketplace "
            f"using it stops loading for every installed user."
        )

    owner = market.get("owner")
    if not isinstance(owner, dict) or not owner.get("name"):
        fail("marketplace.json: 'owner' must be an object with a 'name'")

    plugins = market.get("plugins")
    if not isinstance(plugins, list) or not plugins:
        fail("marketplace.json: 'plugins' must be a non-empty array")
        print_report()
        return 1 if errors else 0

    for entry in plugins:
        if not isinstance(entry, dict):
            fail("marketplace.json: every plugin entry must be an object")
            continue
        pname = entry.get("name")
        if not isinstance(pname, str) or not KEBAB.match(pname):
            fail(f"marketplace.json: plugin 'name' must be kebab-case, got {pname!r}")
            continue

        # Claude Code always prefers plugin.json's version and ignores this one
        # without warning, so a version here is a trap, not a redundancy.
        if "version" in entry:
            fail(
                f"marketplace.json: plugin {pname!r} sets 'version'. plugin.json always "
                f"wins silently; keep the version in plugin.json only."
            )

        source = entry.get("source")
        if not isinstance(source, str):
            # Remote sources (github/url/git-subdir/npm) are not resolvable here.
            if not isinstance(source, dict):
                fail(f"marketplace.json: plugin {pname!r} is missing 'source'")
            continue
        if not source.startswith("./"):
            fail(f"marketplace.json: plugin {pname!r} local source must start with './'")
            continue

        plugin_dir = (REPO_ROOT / source).resolve()
        rel = source.rstrip("/")
        if not plugin_dir.is_dir():
            fail(f"marketplace.json: plugin {pname!r} source {source} does not exist")
            continue

        manifest = load_json(plugin_dir / ".claude-plugin" / "plugin.json")
        if isinstance(manifest, dict):
            if manifest.get("name") != pname:
                fail(
                    f"{rel}/.claude-plugin/plugin.json: 'name' is "
                    f"{manifest.get('name')!r} but the marketplace entry says {pname!r}"
                )
            version = manifest.get("version")
            if not isinstance(version, str) or not version.strip():
                fail(
                    f"{rel}/.claude-plugin/plugin.json: 'version' is required. Without it "
                    f"the version-bump guard cannot protect releases."
                )
            check_codex_manifest(plugin_dir, rel, manifest)
            check_hooks(plugin_dir, rel, manifest)
        elif manifest is not None:
            fail(f"{rel}/.claude-plugin/plugin.json: expected a JSON object")
        check_skills(plugin_dir, rel)

    print_report()
    return 1 if errors else 0


def print_report() -> None:
    if errors:
        print(f"✘ {len(errors)} manifest problem(s):\n", file=sys.stderr)
        for err in errors:
            print(f"  ❯ {err}", file=sys.stderr)
    else:
        print("✔ marketplace, plugin, hook and skill manifests all valid")


if __name__ == "__main__":
    sys.exit(main())
