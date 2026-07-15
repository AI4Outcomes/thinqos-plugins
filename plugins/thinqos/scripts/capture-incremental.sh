#!/bin/sh
# thinqOS plugin debounce shim for PostToolUse capture-incremental
# (TOS-1217 Phase C semantics, plugin packaging per Phase A).
#
# PostToolUse fires after every tool call; starting a Python interpreter each
# time costs ~90-100ms. This gate checks the per-session mtime stamp the
# engine's incremental.record_attempt touches and only hands off to Python
# when the debounce window has elapsed. Fail-open in every branch: anything
# uncertain (unparseable stdin, missing stamp, non-integer interval, no
# usable stat) runs the engine, which performs the authoritative check.

json=$(cat)
iv="${THINQOS_INCREMENTAL_MIN_INTERVAL_S:-90}"
case "$iv" in
    ''|*[!0-9]*) iv="" ;;
esac
if [ -n "$iv" ]; then
    tp=$(printf '%s' "$json" | sed -n \
        's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
    if [ -n "$tp" ]; then
        digest=$(printf '%s' "$tp" | (shasum 2>/dev/null || sha1sum) | cut -c1-40)
        stamp="$HOME/.config/thinqos/debounce/$digest"
        if [ -n "$digest" ] && [ -f "$stamp" ]; then
            now=$(date +%s)
            # GNU form FIRST: on Linux `stat -f %m` can succeed and print a
            # MOUNT POINT (non-numeric, exit 0, coreutils-version-dependent),
            # which would mask the BSD fallback. `stat -c` errors cleanly on
            # BSD/macOS, so this order is unambiguous on both.
            mt=$(stat -c %Y "$stamp" 2>/dev/null || stat -f %m "$stamp" 2>/dev/null)
            case "$mt" in
                ''|*[!0-9]*) mt="" ;;
            esac
            if [ -n "$mt" ] && [ $((now - mt)) -lt "$iv" ]; then
                exit 0
            fi
        fi
    fi
fi

BIN="$(command -v thinqos 2>/dev/null)"
if [ -z "$BIN" ] && [ -x "$HOME/.local/bin/thinqos" ]; then
    BIN="$HOME/.local/bin/thinqos"
fi
if [ -z "$BIN" ]; then
    exit 0
fi
export THINQOS_BASE_URL="${THINQOS_BASE_URL:-https://thinqos.com}"
printf '%s' "$json" | exec "$BIN" hook capture-incremental
