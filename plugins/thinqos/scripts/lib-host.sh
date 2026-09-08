# shellcheck shell=sh
# Shared host detection and stand-down policy for the thinqOS plugin (TOS-2773).
#
# Sourced, never executed. Defines:
#   thinqos_host          -> "codex" | "claude"
#   thinqos_should_stand_down -> 0 when this plugin must NOT wire hooks here
#   thinqos_detach        -> run a command fully detached from the hook

# Codex reuses Claude's CLAUDE_PLUGIN_ROOT variable (verified against the
# codex 0.145.0 binary), so the variable name does not identify the host -
# the cache location does.
thinqos_host() {
    case "${CLAUDE_PLUGIN_ROOT:-}" in
        *"/.codex/"*) echo codex ;;
        *) echo claude ;;
    esac
}

# Stand-down exists because the plugin and the `thinqos` CLI are two wirings
# for the same hooks, and they MERGE rather than replace each other: Claude
# and Codex both dedupe only on identical command strings, so leaving both
# active fires every prime, resume and capture twice.
#
# Who yields depends on the host, and the asymmetry is deliberate:
#
#   claude / vscode - the PLUGIN wins. `thinqos install` detects the enabled
#       plugin and strips its own managed entries. Nothing to do here.
#   codex           - the CLI wins, so the plugin yields. Codex gates plugin
#       hooks behind a per-source Trust toggle that defaults OFF and never
#       prompts, so a plugin-provided hook is not reliably live. Handing
#       Codex capture to an untrusted hook would silently stop capture; the
#       CLI's ~/.codex/hooks.json entries are not trust-gated.
#
# Set THINQOS_PLUGIN_FORCE_HOOKS=1 to override (useful when the CLI is not
# installed and the plugin is the only wiring).
thinqos_should_stand_down() {
    [ "${THINQOS_PLUGIN_FORCE_HOOKS:-}" = "1" ] && return 1
    [ "$(thinqos_host)" = "codex" ] || return 1
    codex_hooks="${CODEX_HOOKS_PATH:-$HOME/.codex/hooks.json}"
    [ -f "$codex_hooks" ] || return 1
    grep -qE '(thinqos|thinqos-harvest)[^"]* hook ' "$codex_hooks" 2>/dev/null
}

# Run "$@" detached, reading stdin from $1_FILE, so the hook returns
# immediately.
#
# TOS-1542 required PostToolUse to stay off the critical command path and
# solved it with `"async": true` in hooks.json. Codex's hook loader REJECTS
# that key outright ("async hooks are not supported yet") and skips the whole
# hook, so async cannot be what provides the guarantee. Detaching in the
# script is host-independent: every host returns immediately, and hosts that
# also honour `async` lose nothing.
thinqos_detach() {
    payload_file="$1"
    shift
    # Double-fork via the ( cmd & ) idiom so the hook's shell does not wait on
    # the job. Same pattern the prime-session self-update path has used since
    # TOS-1649.
    (
        (
            if [ -n "$payload_file" ]; then
                "$@" <"$payload_file" >/dev/null 2>&1
            else
                "$@" >/dev/null 2>&1
            fi
            [ -n "$payload_file" ] && rm -f "$payload_file"
        ) &
    )
}

# --- CLI compatibility (TOS-4490) ------------------------------------------
#
# The plugin and the `thinqos` CLI ship on SEPARATE tracks: the marketplace
# auto-updates this plugin onto every installed machine, while the CLI moves
# only when someone runs `uv tool install --upgrade thinqos`. So a user can
# and does end up running new plugin hooks against an old CLI, and the hooks
# then call subcommands and flags that CLI has never heard of.
#
# Declare the floor, and say something TRUTHFUL when it is not met. Never
# block: a session that cannot start because its memory plugin is unhappy is
# a far worse failure than one that captures nothing for a turn.
#
# Raise this only when the plugin genuinely starts depending on something
# newer, and say what in the comment - a floor nobody can justify is a floor
# that gets bumped reflexively and locks users out for no reason.
#
# 1.8.6: first release carrying the installation-attempt marker
# (`thinqos_install` on captured sessions) and the persisted per-source
# capture-history policy, both of which the connect UI's setup verification
# depends on.
THINQOS_MIN_CLI_VERSION="1.8.6"

# Print the installed CLI's version, or nothing if it cannot be determined.
# `--version` landed alongside this floor, so a CLI that does not answer it is
# by construction older than the floor.
thinqos_cli_version() {
    "$1" --version 2>/dev/null | awk 'NR==1 {print $NF}'
}

# 0 when $1 (found) is >= $2 (required). Pure POSIX sh: no sort -V, which is
# absent on some BSD/macOS layouts, and no bashisms - Codex and Claude both
# invoke these hooks with /bin/sh.
thinqos_version_at_least() {
    found="$1"
    required="$2"
    [ -n "$found" ] || return 1
    IFS=. read -r f_major f_minor f_patch <<EOF
$found
EOF
    IFS=. read -r r_major r_minor r_patch <<EOF
$required
EOF
    # A non-numeric component (a dev build, say) is not something to guess at.
    for part in "${f_major:-x}" "${f_minor:-0}" "${f_patch:-0}"; do
        case "$part" in
            ''|*[!0-9]*) return 1 ;;
        esac
    done
    [ "${f_major:-0}" -gt "${r_major:-0}" ] && return 0
    [ "${f_major:-0}" -lt "${r_major:-0}" ] && return 1
    [ "${f_minor:-0}" -gt "${r_minor:-0}" ] && return 0
    [ "${f_minor:-0}" -lt "${r_minor:-0}" ] && return 1
    [ "${f_patch:-0}" -ge "${r_patch:-0}" ]
}

# Warn ONCE per session, on stderr, if the installed CLI is below the floor.
# Called only from the session-start path: a warning on every PostToolUse
# capture would be unreadable noise and would train people to ignore it.
thinqos_warn_if_cli_too_old() {
    bin="$1"
    found="$(thinqos_cli_version "$bin")"
    if thinqos_version_at_least "$found" "$THINQOS_MIN_CLI_VERSION"; then
        return 0
    fi
    # Name what is actually degraded, not just "please upgrade". A user who
    # cannot see the consequence has no basis to decide whether to act now.
    echo "thinqOS plugin: the installed CLI is ${found:-older than $THINQOS_MIN_CLI_VERSION}, below the $THINQOS_MIN_CLI_VERSION this plugin expects." >&2
    echo "thinqOS plugin: capture and recall still work; setup verification in the web app cannot confirm this machine until you upgrade." >&2
    echo "thinqOS plugin: upgrade with: uv tool install --upgrade thinqos" >&2
}
