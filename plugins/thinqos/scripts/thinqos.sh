#!/bin/sh
# thinqOS plugin hook dispatcher.
#
# The plugin packages hooks; the uv-installed thinqos CLI performs the work.
# Fail open: a missing CLI prints an install hint and never blocks a session.

BIN="$(command -v thinqos 2>/dev/null)"
if [ -z "$BIN" ] && [ -x "$HOME/.local/bin/thinqos" ]; then
    BIN="$HOME/.local/bin/thinqos"
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

exec "$BIN" hook "$kind" "$@"
