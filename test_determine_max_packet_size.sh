#!/bin/sh
# Test wrapper for determine_max_packet_size
set -u

SCRIPT="$(PWD)/determine_max_packet_size"
TMPDIR=/tmp/mtu_test_$$
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

LOG="$TMPDIR/test.log"
ERR="$TMPDIR/test.err"

echo "============================================"
echo "  MTU checker v4 - Test Suite"
echo "============================================"
echo ""

count=0
pass=0
fail=0

run_test() {
    _name="$1"
    _args="$2"
    _min_ok="$3"       # 0=exit ok, 1=exit fail
    _should_contain="$4"  # string that must appear in stdout

    count=$((count + 1))
    printf 'Test %d: %-40s ' "$count" "$_name"

    if ! [ -x "$SCRIPT" ]; then
        echo "FAIL (script not executable)"
        fail=$((fail + 1))
        return
    fi

    _rc=0
    "$SCRIPT" $_args >"$LOG" 2>"$ERR" || _rc=1

    if [ "$_min_ok" -eq 0 ] && [ "$_rc" -ne 0 ]; then
        echo "FAIL (exit $_rc, expected 0)"
        fail=$((fail + 1))
        return
    fi

    if [ "$_min_ok" -eq 1 ] && [ "$_rc" -eq 0 ]; then
        echo "FAIL (exit 0, expected non-zero)"
        fail=$((fail + 1))
        return
    fi

    if ! grep -q "$_should_contain" "$LOG" "$ERR"; then
        echo "FAIL (missing '$_should_contain')"
        fail=$((fail + 1))
        return
    fi

    echo "PASS"
    pass=$((pass + 1))
}

# 1. Localhost - must succeed, obviously reachable
run_test "localhost (IPv4+IPv6)" "localhost" 0 "IPv4:"

# 2. Google DNS IPv4
run_test "8.8.8.8 (IPv4 literal)" "8.8.8.8" 0 "IPv4:"

# 3. Google DNS IPv6
run_test "2001:4860:4860::8888 (IPv6 literal)" "2001:4860:4860::8888" 0 "IPv6:"

# 4. Google.com by name (dual stack)
run_test "google.com (dual stack)" "google.com" 0 "IPv4:"

# 5. Bad hostname
run_test "invalid.bad.tld (DNS fail)" "invalid.bad.tld" 1 "failed entirely"

# 6. Verbose mode on working host (must contain debug output)
run_test "localhost -v (verbose)" "-v localhost" 0 "Checking"

echo ""
echo "============================================"
printf  "  Results: %d passed, %d failed, %d total\n" "$pass" "$fail" "$count"
echo "============================================"

if [ "$fail" -gt 0 ]; then
    echo ""
    echo "--- Last stdout ---"
    cat "$LOG"
    echo ""
    echo "--- Last stderr ---"
    cat "$ERR"
    exit 1
fi
exit 0
