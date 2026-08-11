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
