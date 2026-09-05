#!/bin/bash
# StaticMethodStatus (P0 regression for F5, see PLAN.md).
# A static method on a class WITH static properties runs its body inside a
# capture wrapper. Before the fix: on bash 5.2 (brace-group + scratch file)
# `return N` propagated but left the scratch file behind, and a failing last
# command reported 0 (status of printf); on bash 5.3 (funsub) `return N` was
# swallowed entirely. Contract: the wrapper's exit status IS the body's status,
# no scratch file survives, static state mutations persist, stdout is captured.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "StaticMethodStatus" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Private TMPDIR so scratch-file leaks are countable.
export TMPDIR="${TMPDIR:-/tmp}/kk124_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

source "$KKLASS_DIR/kklass.sh"

defineClass TStat "" static_property cnt \
    static_method ret3  'cnt=$((cnt+1)); echo "out-$cnt"; return 3' \
    static_method lastf 'cnt=$((cnt+1)); false' \
    static_method ok    'cnt=$((cnt+1)); echo "ok-$cnt"'
defineClass TNoProp "" \
    static_method ret5 'echo "np"; return 5'

scratch() { ls "$TMPDIR"/.kk_static_* 2>/dev/null | wc -l | tr -d ' '; }
# Output is redirected to a file, never captured with $(...): a $() would run
# the static method in a subshell and the static-state mutation would be lost.
OUTF="$TMPDIR/out.txt"

# ---------------------------------------------------------------------------
kt_test_start "sanity: static method delivers stdout and mutates static state"
TStat.ok >"$OUTF"; out="$(<"$OUTF")"
TStat.ok >/dev/null
if [[ "$out" == "ok-1" && "$(TStat.cnt)" == "2" ]]; then
    kt_test_pass "stdout delivered, cnt=2"
else
    kt_test_fail "out='$out' cnt='$(TStat.cnt)'"
fi

# ---------------------------------------------------------------------------
kt_test_start "'return N' inside the body is the wrapper's exit status (F5)"
TStat.ret3 >"$OUTF"; rc=$?
[[ $rc -eq 3 ]] && kt_test_pass "rc=3" || kt_test_fail "rc=$rc (expected 3; bash $BASH_VERSION)"

# ---------------------------------------------------------------------------
kt_test_start "'return N' does not leak a scratch file (F5)"
n="$(scratch)"
[[ "$n" == "0" ]] && kt_test_pass "no scratch files" || kt_test_fail "$n scratch file(s) left in $TMPDIR"

# ---------------------------------------------------------------------------
kt_test_start "stdout is still delivered when the body returns non-zero"
out="$(<"$OUTF")"
[[ "$out" == "out-3" ]] && kt_test_pass "out='$out'" || kt_test_fail "out='$out' (expected out-3)"

# ---------------------------------------------------------------------------
kt_test_start "a failing last command yields a non-zero status (F5)"
TStat.lastf; rc=$?
[[ $rc -ne 0 ]] && kt_test_pass "rc=$rc" || kt_test_fail "rc=0 (status of printf leaked through)"

# ---------------------------------------------------------------------------
kt_test_start "class without static properties: status + output (thin path)"
out="$(TNoProp.ret5)"; TNoProp.ret5 >/dev/null; rc=$?
if [[ $rc -eq 5 && "$out" == "np" ]]; then
    kt_test_pass "rc=5 out=np"
else
    kt_test_fail "rc=$rc out='$out'"
fi

kt_test_log "124_StaticMethodStatus.sh completed"
