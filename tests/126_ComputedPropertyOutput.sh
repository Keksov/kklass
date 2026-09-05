#!/bin/bash
# ComputedPropertyOutput (P0 regression for F7 / decision D1 as amended at P3).
# A computed property follows the kk._return contract every kcl unit relies on
# (pinned for tstopwatch by kcl/tstopwatch/tests/004_ZeroFork.sh):
#   * a DIRECT call is silent and sets RESULT;
#   * `$(obj.prop)` prints the value exactly once.
# A getter declared as `function` (RESULT-returning) runs in the CURRENT shell,
# so its side effects on the instance persist and no fork is paid per read —
# before the fix every read went through `RESULT="$($__inst__.call G)"`,
# forking a subshell (16-45 ms once the shell held a few hundred objects).
# Getters declared as `method` (echo-returning) keep working via capture.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ComputedPropertyOutput" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"

# function-kind getter with a side effect (reads counter)
defineClass TCpF "" property w property h property reads \
    property area getArea \
    function getArea 'reads=$((reads+1)); RESULT=$((w*h))'
# method-kind getter (legacy echo style)
defineClass TCpM "" property first property last \
    property full get_full \
    method get_full 'echo "$first $last"'

TCpF.new f; f.w = 3; f.h = 4; f.reads = 0
TCpM.new m; m.first = John; m.last = Doe
bare_file="${TMPDIR:-/tmp}/kk126_$$.txt"
trap 'rm -f "$bare_file"' EXIT

# ---------------------------------------------------------------------------
kt_test_start "direct call is silent and sets RESULT (kk._return contract)"
RESULT=""
f.area >"$bare_file"; rc=$?
bytes=$(wc -c <"$bare_file")
if [[ $rc -eq 0 && "$bytes" -eq 0 && "$RESULT" == "12" ]]; then
    kt_test_pass "0 bytes, RESULT=12"
else
    kt_test_fail "rc=$rc bytes=$bytes RESULT='$RESULT'"
fi

# ---------------------------------------------------------------------------
kt_test_start "\$(obj.prop) prints the value exactly once"
out="$(f.area)"
[[ "$out" == "12" ]] && kt_test_pass "captured '12'" || kt_test_fail "captured '$out'"

# ---------------------------------------------------------------------------
kt_test_start "function-kind getter runs in the current shell: side effects persist (F7)"
f.reads = 0
f.area >/dev/null
f.area >/dev/null
n="$(f.reads)"
[[ "$n" == "2" ]] && kt_test_pass "reads=2" || kt_test_fail "reads='$n' (getter ran in a subshell?)"

# ---------------------------------------------------------------------------
kt_test_start "inside a method body, reading a computed property does not print"
# Direct call of the outer method (redirected, not \$()): under \$() every nested
# RESULT-returning call echoes by the kk._return contract, same as \$this.func.
defineClass TCpUse "" property v property dbl getDbl \
    function getDbl 'RESULT=$((v*2))' \
    method report '$this.dbl; echo "dbl=$RESULT"'
TCpUse.new u; u.v = 21
u.report >"$bare_file"; out="$(<"$bare_file")"; u.delete
[[ "$out" == "dbl=42" ]] && kt_test_pass "'dbl=42' only" || kt_test_fail "got '$out'"

# ---------------------------------------------------------------------------
kt_test_start "method-kind (echo) getter: direct silent + RESULT, \$() prints once"
RESULT=""
m.full >"$bare_file"; bytes=$(wc -c <"$bare_file"); direct="$RESULT"
out="$(m.full)"
if [[ "$bytes" -eq 0 && "$direct" == "John Doe" && "$out" == "John Doe" ]]; then
    kt_test_pass "direct: 0 bytes + RESULT; captured 'John Doe'"
else
    kt_test_fail "bytes=$bytes RESULT='$direct' captured='$out'"
fi

# ---------------------------------------------------------------------------
kt_test_start "write-only property: read fails with status, prints nothing"
declareClass TCpWO ""
    field secret
    property token write secret
endClass
endImplementation TCpWO
TCpWO.new wo
wo.token >"$bare_file" 2>/dev/null; rc=$?
bytes=$(wc -c <"$bare_file"); wo.delete
[[ $rc -ne 0 && "$bytes" -eq 0 ]] && kt_test_pass "rc=$rc, 0 bytes" || kt_test_fail "rc=$rc bytes=$bytes"

f.delete; m.delete
kt_test_log "126_ComputedPropertyOutput.sh completed"
