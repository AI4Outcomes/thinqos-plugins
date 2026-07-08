#!/bin/sh
# thinqOS plugin hook dispatcher (TOS-1217 Phase A).
#
# Resolves the thinqos-harvest engine binary (the plugin is packaging; the
# uv-installed CLI stays the engine) and passes the hook event stdin through.
# Fail-open: a missing engine prints an install hint to stderr and exits 0 so
# a session is never blocked.
#
# "prime-session" is SessionStart's prime: identical to "prime" plus a
# detached, daily-stamped engine self-update. The plugin itself updates via
# the marketplace autoUpdate; this keeps the ENGINE fresh without the
# dedicated SessionStart self-update hook the settings.json wiring used.

BIN="$(command -v thinqos-harvest 2>/dev/null)"
if [ -z "$BIN" ] && [ -x "$HOME/.local/bin/thinqos-harvest" ]; then
    BIN="$HOME/.local/bin/thinqos-harvest"
fi
if [ -z "$BIN" ]; then
    echo "thinqos plugin: thinqos-harvest engine not found. Install it with: uv tool install thinqos-harvest" >&2
    exit 0
fi

export THINQOS_BASE_URL="${THINQOS_BASE_URL:-https://thinqos.com}"

kind="$1"
if [ -z "$kind" ]; then
    exit 0
fi
shift

if [ "$kind" = "prime-session" ]; then
    ("$BIN" hook self-update >/dev/null 2>&1 &)
    exec "$BIN" hook prime "$@"
fi

# Fail-open on engine/plugin version skew. The plugin (marketplace autoUpdate)
# and the engine (uv-installed CLI) update independently, so the plugin can
# reference a hook command the currently-installed engine does not implement
# yet (or any longer). Without this guard, `exec`-ing a missing command exits
# non-zero; on a PreToolUse hook a non-zero exit BLOCKS the tool call and the
# session cannot use any tool. Probe first and no-op if the command is absent.
if ! "$BIN" hook "$kind" --help >/dev/null 2>&1; then
    exit 0
fi

exec "$BIN" hook "$kind" "$@"
