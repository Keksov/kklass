#!/bin/bash
# StaticThinDispatch — regression tests for the thin (capture-free) static
# dispatcher that classes WITHOUT static variables receive.
#
# Guards two things:
#   1. THE BUG (found while porting tfile to the Pascal DSL): the thin
#      dispatcher's trailing `if (( __kk_return_set ))` used to clobber the
#      body's exit status with 0 when the body's last command failed WITHOUT
#      an explicit `return` (a fall-through failure). The old
#      kk.register_static_methods wrappers propagated that status.
#   2. Dispatcher selection: a class with NO static vars must get the thin
#      dispatcher (no funsub, no scratch file — fast on bash 5.2 and 5.3);
#      a class WITH static vars must keep the capturing dispatcher (its
#      mutations have to survive stdout capture).

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "StaticThinDispatch" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass_pascal.sh"

# --- a pure static-utility class: NO static vars -> thin dispatcher ---------
class TThinUtil
    public
        static proc fallThroughFail
        static proc explicitCode
        static proc echoes
        static func viaResult
end
# Last command fails, NO explicit return — the regression case.
TThinUtil.fallThroughFail() { [[ -f "/nonexistent_kk_thin_$$" ]]; }
# Explicit non-zero code must come through unchanged.
TThinUtil.explicitCode()    { return 3; }
# Plain stdout passthrough, status 0.
TThinUtil.echoes()          { echo "out:$1"; }
# RESULT-style func still returns its value through the thin dispatcher.
TThinUtil.viaResult()       { RESULT="r:$1"; }
build TThinUtil

# --- a stateful class: static var -> capturing dispatcher required ----------
class TStatefulUtil
    public
        static var  Count
        static proc bump
        static func getCount
end
TStatefulUtil.bump()     { Count=$(( Count + 1 )); }
TStatefulUtil.getCount() { RESULT="$Count"; }
build TStatefulUtil

kt_test_start "thin dispatcher propagates fall-through failure status (the bug)"
if TThinUtil.fallThroughFail >/dev/null 2>&1; then
    kt_test_fail "thin dispatcher propagates fall-through failure status (got 0, want non-zero)"
else
    kt_test_pass "thin dispatcher propagates fall-through failure status (the bug)"
fi

kt_test_start "thin dispatcher preserves explicit return code"
TThinUtil.explicitCode >/dev/null 2>&1
status=$?
if [[ "$status" == "3" ]]; then
    kt_test_pass "thin dispatcher preserves explicit return code"
else
    kt_test_fail "thin dispatcher preserves explicit return code (got $status, want 3)"
fi

kt_test_start "thin dispatcher passes stdout through with status 0"
out="$(TThinUtil.echoes hi)"
status=$?
if [[ "$out" == "out:hi" && "$status" == "0" ]]; then
    kt_test_pass "thin dispatcher passes stdout through with status 0"
else
    kt_test_fail "thin dispatcher passes stdout through (got '$out' status $status)"
fi

kt_test_start "thin dispatcher returns RESULT-style func value"
out="$(TThinUtil.viaResult x)"
if [[ "$out" == "r:x" ]]; then
    kt_test_pass "thin dispatcher returns RESULT-style func value"
else
    kt_test_fail "thin dispatcher returns RESULT-style func value (got '$out', want 'r:x')"
fi

kt_test_start "class without static vars gets the thin dispatcher (no capture)"
decl="$(declare -f TThinUtil.echoes)"
if [[ "$decl" == *"__kk_static_out"* || "$decl" == *'REPLY=${'* ]]; then
    kt_test_fail "class without static vars gets the thin dispatcher (capturing dispatcher found)"
else
    kt_test_pass "class without static vars gets the thin dispatcher (no capture)"
fi

kt_test_start "class WITH static vars keeps the capturing dispatcher"
decl="$(declare -f TStatefulUtil.bump)"
if [[ "$decl" == *"__kk_static_out"* || "$decl" == *'REPLY=${'* ]]; then
    kt_test_pass "class WITH static vars keeps the capturing dispatcher"
else
    kt_test_fail "class WITH static vars keeps the capturing dispatcher (thin dispatcher found)"
fi

kt_test_start "capturing dispatcher still persists static var mutations"
TStatefulUtil.Count = "0"
TStatefulUtil.bump >/dev/null
TStatefulUtil.bump >/dev/null
count="$(TStatefulUtil.getCount)"
if [[ "$count" == "2" ]]; then
    kt_test_pass "capturing dispatcher still persists static var mutations"
else
    kt_test_fail "capturing dispatcher still persists static var mutations (got '$count', want 2)"
fi
