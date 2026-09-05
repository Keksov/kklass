#!/bin/bash
# ReservedNames (P0 regression for F6 / decision D2, see PLAN.md).
# Member names that would shadow the names a method body sees by contract
# (this, __inst__, __class__, RESULT, REPLY, IFS) are REJECTED at declaration
# time. Names that merely collided with internal locals of the dispatcher
# (method_body, frame_id) are NOT reserved — the locals are renamed to __kk_*
# instead — and a property VALUE must never be executed as code (before the
# fix, `p.method_body = "echo PWNED"; p.show` ran the value). `state` is NOT
# reserved either: a property of that name shadows the instance-data nameref
# (test 066 relies on it) while tcustomapplication uses the nameref itself.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ReservedNames" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"

ERRF="${TMPDIR:-/tmp}/kk125_$$.txt"
trap 'rm -f "$ERRF"' EXIT

# ---------------------------------------------------------------------------
for nm in this __inst__ __class__ RESULT REPLY IFS; do
    kt_test_start "property named '$nm' is rejected"
    : >"$ERRF"
    defineClass "TRes_$nm" "" property "$nm" 2>"$ERRF"; rc=$?
    err="$(<"$ERRF")"
    if [[ $rc -ne 0 && "$err" == *"$nm"* ]]; then
        kt_test_pass "rejected: $err"
    else
        kt_test_fail "accepted (rc=$rc err='$err')"
    fi
done

# ---------------------------------------------------------------------------
kt_test_start "method named 'this' is rejected"
: >"$ERRF"
defineClass TResM "" method this 'echo x' 2>"$ERRF"; rc=$?
[[ $rc -ne 0 ]] && kt_test_pass "rejected" || kt_test_fail "accepted"

# ---------------------------------------------------------------------------
kt_test_start "declarative DSL rejects a reserved field name too"
: >"$ERRF"
{ declareClass TResD ""; field RESULT; } 2>"$ERRF"; rc=$?
KK_DECL_CURRENT_CLASS=""     # leave no half-open class behind
[[ $rc -ne 0 ]] && kt_test_pass "field RESULT rejected" || kt_test_fail "field RESULT accepted"

# ---------------------------------------------------------------------------
kt_test_start "property 'method_body' is allowed and its value is data, not code (F6)"
defineClass TResOk "" property method_body property frame_id \
    method show 'echo "[$method_body|$frame_id]"'; rc=$?
if [[ $rc -ne 0 ]]; then
    kt_test_fail "class with property method_body/frame_id refused (rc=$rc)"
else
    TResOk.new r1
    r1.method_body = "echo PWNED"
    r1.frame_id = "fid"
    out="$(r1.show 2>&1)"
    r1.delete
    if [[ "$out" == "[echo PWNED|fid]" ]]; then
        kt_test_pass "value round-trips verbatim"
    else
        kt_test_fail "got '$out' (value executed or dispatch broken)"
    fi
fi

# ---------------------------------------------------------------------------
kt_test_start "property 'state' is allowed and shadows the data nameref (066 contract)"
defineClass TResState "" property state method show 'echo "[$state]"'; rc=$?
if [[ $rc -ne 0 ]]; then
    kt_test_fail "class with property state refused (rc=$rc)"
else
    TResState.new rs; rs.state = ok
    out="$(rs.show 2>&1)"; rs.delete
    [[ "$out" == "[ok]" ]] && kt_test_pass "state property works" || kt_test_fail "got '$out'"
fi

# ---------------------------------------------------------------------------
kt_test_start "the instance-data nameref 'state' is visible in a body (tcustomapplication contract)"
defineClass TResNref "" property x method poke 'state["x"]="via-state"; echo "${state[x]}"'
TResNref.new rn
rn.poke >"$ERRF"; out="$(<"$ERRF")"      # not $(...): a subshell would lose the write
val="$(rn.x)"; rn.delete
[[ "$out" == "via-state" && "$val" == "via-state" ]] && kt_test_pass "state[] reaches instance data" \
    || kt_test_fail "out='$out' x='$val'"

kt_test_log "125_ReservedNames.sh completed"
