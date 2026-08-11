#!/bin/sh
# thinqOS plugin hook dispatcher.
#
# The plugin packages hooks; the uv-installed thinqos CLI performs the work.
# Fail open: a missing CLI prints an install hint and never blocks a session.
#
# Resolution order (TOS-1649): the canonical `thinqos` CLI first, then the
# retired `thinqos-harvest` name so machines that have not upgraded the uv
# tool yet keep priming/capturing instead of silently no-oping.

. "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/scripts/lib-host.sh"

# TOS-2773: yield to the CLI's own hooks where the CLI is the reliable wiring,
# so prime/resume/capture each run once rather than twice.
if thinqos_should_stand_down; then
    exit 0
fi

BIN="$(command -v thinqos 2>/dev/null)"
if [ -z "$BIN" ] && [ -x "$HOME/.local/bin/thinqos" ]; then
    BIN="$HOME/.local/bin/thinqos"
fi
if [ -z "$BIN" ]; then
    BIN="$(command -v thinqos-harvest 2>/dev/null)"
fi
if [ -z "$BIN" ] && [ -x "$HOME/.local/bin/thinqos-harvest" ]; then
    BIN="$HOME/.local/bin/thinqos-harvest"
fi
if [ -z "$BIN" ]; then
    echo "thinqos plugin: CLI not found. Install it with: uv tool install thinqos" >&2
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

# Marketplace and CLI updates are independent. Do not turn an unknown hook
# command into a blocking Claude Code failure.
if ! "$BIN" hook "$kind" --help >/dev/null 2>&1; then
    exit 0
fi

# TOS-2773: capture posts over the network and must never hold a turn open.
# It used to rely on `"async": true` in hooks.json, which Codex rejects
# outright (skipping the hook entirely), so detach here instead - that works
# on every host. prime/resume stay synchronous: their stdout IS the context
# block the host injects, so backgrounding them would emit nothing.
case "$kind" in
    capture | capture-incremental)
        payload="$(mktemp "${TMPDIR:-/tmp}/thinqos-capture.XXXXXX" 2>/dev/null)" || exit 0
        cat >"$payload" 2>/dev/null || {
            rm -f "$payload"
            exit 0
        }
        thinqos_detach "$payload" "$BIN" hook "$kind" "$@"
        exit 0
        ;;
esac

exec "$BIN" hook "$kind" "$@"
