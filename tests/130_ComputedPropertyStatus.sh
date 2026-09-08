#!/bin/bash
# ComputedPropertyStatus (kcl review found_in_P6: P6-F1).
#
# A method-backed computed property lost its getter's exit status: the
# generated _get_<prop> shim ran `RESULT=""; $__inst__.call Getter` and then
# the func trailer `kk._return "$RESULT"`, whose status (0) replaced the
# getter's. kk._prop_computed does propagate the shim's status, so the only
# thing missing was the shim keeping it. Consequence before the fix: an
# rc-carrying boolean (kcl contract: predicates answer by exit status) could
# not be exposed as a property — `sw.isRunning` answered rc 0 with
# RESULT=false.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ComputedPropertyStatus" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass_pascal.sh"

declareClass TCps ""
publicSection
field FOn
property On read GetOn write FOn
property Value read GetValue
func GetOn
func GetValue
endClass
implement "TCps.GetOn" 'if [[ "$FOn" == "1" ]]; then kk._return true; return 0; fi; kk._return false; return 1'
implement "TCps.GetValue" 'kk._return 42; return 3'
endImplementation TCps

TCps.new c

kt_test_start "computed property propagates a FALSE getter status (rc 1) [P6-F1]"
c.FOn = 0
c.On >/dev/null; rc=$?
[[ $rc -eq 1 && "$RESULT" == "false" ]] && kt_test_pass "rc=1 RESULT=false" || kt_test_fail "rc=$rc RESULT=$RESULT"

kt_test_start "computed property propagates a TRUE getter status (rc 0) [P6-F1]"
c.FOn = 1
c.On >/dev/null; rc=$?
[[ $rc -eq 0 && "$RESULT" == "true" ]] && kt_test_pass "rc=0 RESULT=true" || kt_test_fail "rc=$rc RESULT=$RESULT"

kt_test_start "an arbitrary getter status (3) reaches the caller with RESULT intact [P6-F1]"
c.Value >/dev/null; rc=$?
[[ $rc -eq 3 && "$RESULT" == "42" ]] && kt_test_pass "rc=3 RESULT=42" || kt_test_fail "rc=$rc RESULT=$RESULT"

kt_test_start "the status also survives a \$( ) capture, and the value prints once"
got="$(c.Value)"; rc=$?
[[ $rc -eq 3 && "$got" == "42" ]] && kt_test_pass "rc=3 captured 42" || kt_test_fail "rc=$rc got=$got"

kt_test_start "the property is usable as an rc predicate: if/||"
c.FOn = 0
if c.On >/dev/null; then kt_test_fail "true branch taken"; else kt_test_pass "false branch taken"; fi

kt_test_start "Pascal DSL func getter: status propagated too [P6-F1]"
class TCpsP
    public
        var  FOk
        property Ok read GetOk
        func GetOk
end
TCpsP.GetOk() { kk._return "$FOk"; [[ "$FOk" == "true" ]]; return $?; }   # explicit return: the func trailer would otherwise yield 0
build TCpsP
TCpsP.new p
p.FOk = false
p.Ok >/dev/null; rc=$?
[[ $rc -eq 1 && "$RESULT" == "false" ]] && kt_test_pass "rc=1" || kt_test_fail "rc=$rc RESULT=$RESULT"

c.delete; p.delete
kt_test_log "130_ComputedPropertyStatus.sh completed"
