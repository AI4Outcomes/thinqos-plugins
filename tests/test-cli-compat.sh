#!/bin/sh
# Conformance tests for the CLI compatibility floor (TOS-4490).
#
# These run under /bin/sh deliberately. The hooks are invoked by whatever sh
# the host has, so a bashism that works in a developer's zsh and fails on a
# user's dash is exactly the class of defect this file exists to catch.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
. "$ROOT/plugins/thinqos/scripts/lib-host.sh"

failures=0
pass() { printf '  ok   %s\n' "$1"; }
fail() {
    printf '  FAIL %s\n' "$1" >&2
    failures=$((failures + 1))
}

check_at_least() {
    # $1 found, $2 required, $3 expected ("yes"/"no")
    if thinqos_version_at_least "$1" "$2"; then
        got=yes
    else
        got=no
    fi
    if [ "$got" = "$3" ]; then
        pass "at_least('$1', '$2') = $3"
    else
        fail "at_least('$1', '$2') = $got, expected $3"
    fi
}

echo "== thinqos_version_at_least"
check_at_least "1.8.6" "1.8.6" yes
check_at_least "1.8.7" "1.8.6" yes
check_at_least "1.9.0" "1.8.6" yes
check_at_least "2.0.0" "1.8.6" yes
check_at_least "1.8.5" "1.8.6" no
check_at_least "1.7.9" "1.8.6" no
check_at_least "0.9.9" "1.8.6" no
# Two-component and one-component versions: missing parts read as 0.
check_at_least "2.0" "1.8.6" yes
check_at_least "1.8" "1.8.6" no
check_at_least "2" "1.8.6" yes
# String comparison would call 1.10.0 older than 1.9.0. Numeric must not.
check_at_least "1.10.0" "1.9.0" yes
# Anything unparseable is treated as below the floor: warn rather than guess.
check_at_least "" "1.8.6" no
check_at_least "not-a-version" "1.8.6" no
check_at_least "1.8.6rc1" "1.8.6" no

echo "== thinqos_cli_version"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# A CLI that answers --version in the shape `thinqos 1.8.6`.
cat >"$tmp/good" <<'SH'
#!/bin/sh
echo "thinqos 1.8.6"
SH
chmod +x "$tmp/good"
got="$(thinqos_cli_version "$tmp/good")"
if [ "$got" = "1.8.6" ]; then
    pass "parses 'thinqos 1.8.6' -> 1.8.6"
else
    fail "parsed '$got', expected 1.8.6"
fi

# A CLI predating --version: Click writes usage to stderr and exits nonzero.
cat >"$tmp/old" <<'SH'
#!/bin/sh
echo "Error: No such option: --version" >&2
exit 2
SH
chmod +x "$tmp/old"
got="$(thinqos_cli_version "$tmp/old")"
if [ -z "$got" ]; then
    pass "a CLI without --version yields no version"
else
    fail "expected empty version, got '$got'"
fi

echo "== thinqos_warn_if_cli_too_old"
# Below the floor: warns, and still returns success so no session is blocked.
out="$(thinqos_warn_if_cli_too_old "$tmp/old" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then
    pass "an old CLI does not fail the hook"
else
    fail "expected exit 0 for an old CLI, got $rc"
fi
# The message has to be actionable: name the fix, not just the problem.
if printf '%s' "$out" | grep -q 'uv tool install --upgrade thinqos'; then
    pass "warning names the upgrade command"
else
    fail "warning is missing the upgrade command: $out"
fi
if printf '%s' "$out" | grep -q "$THINQOS_MIN_CLI_VERSION"; then
    pass "warning names the required version"
else
    fail "warning is missing the required version: $out"
fi

# At or above the floor: completely silent. A warning that fires for everyone
# is a warning everyone learns to ignore.
out="$(thinqos_warn_if_cli_too_old "$tmp/good" 2>&1)"
if [ -z "$out" ]; then
    pass "a current CLI produces no output"
else
    fail "expected silence for a current CLI, got: $out"
fi

# The declared floor must itself be a version this comparator accepts,
# otherwise every user is warned forever.
if thinqos_version_at_least "$THINQOS_MIN_CLI_VERSION" "$THINQOS_MIN_CLI_VERSION"; then
    pass "the declared floor $THINQOS_MIN_CLI_VERSION satisfies itself"
else
    fail "the declared floor $THINQOS_MIN_CLI_VERSION is unparseable"
fi

echo
if [ "$failures" -eq 0 ]; then
    echo "all cli-compat checks passed"
    exit 0
fi
echo "$failures cli-compat check(s) failed" >&2
exit 1
