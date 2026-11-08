#!/usr/bin/env bash
# PerfRoundK (call-path speedup round K, docs/dev/PERF_PLAN.md) — behaviour the
# round's phases pin while they shorten the method call path.
#
# K4: `inherited` (kk._parent) and the visibility check (kk._warn_visibility)
# read the frame class straight from the frame arrays. Before, they went through
# kv.frameCurrent + kv.frameClass, which overwrote RESULT: a body calling
# `inherited X` saw RESULT = its class name afterwards (the parent body's frame
# restored that as "the caller's RESULT").

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "PerfRoundK" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_pascal.sh"

check() {   # NAME WANT GOT
    if [[ "$3" == "$2" ]]; then kt_test_pass "$1"; else kt_test_fail "$1: got '$3' want '$2'"; fi
}

class TK4Base
    public
        proc Nop
        proc Set
        func Get
    protected
        proc Hidden
end
TK4Base.Nop() { :; }
TK4Base.Set() { RESULT=fromparent; }
TK4Base.Get() { kk._return "parentvalue"; }
TK4Base.Hidden() { :; }
build TK4Base

class TK4Child : TK4Base
    public
        override proc Nop
        override proc Set
        override func Get
        proc CallHidden
end
TK4Child.Nop() { RESULT=keep; inherited Nop; K4_SEEN=$RESULT; }
TK4Child.Set() { RESULT=keep; inherited Set; K4_SEEN=$RESULT; }
TK4Child.Get() { inherited Get; kk._return "child+$RESULT"; }
TK4Child.CallHidden() { RESULT=keep; $this.Hidden; K4_SEEN=$RESULT; }
build TK4Child
TK4Child.new k4

kt_test_start "K4.1 after 'inherited X' (parent body sets nothing) a body keeps its own RESULT"
K4_SEEN=""; RESULT=outer; k4.Nop
check "K4.1" "keep" "$K4_SEEN"

kt_test_start "K4.2 a parent body's plain RESULT= is not a return value: the child's RESULT survives"
K4_SEEN=""; RESULT=outer; k4.Set
check "K4.2" "keep" "$K4_SEEN"

kt_test_start "K4.3 the caller's RESULT is restored after a proc that returns nothing"
RESULT=outer; k4.Nop
check "K4.3" "outer" "$RESULT"

kt_test_start "K4.4 a returned value still passes through inherited (func chain)"
RESULT=""; k4.Get
check "K4.4" "child+parentvalue" "$RESULT"

kt_test_start "K4.5 inherited resolves from the frame class at depth (grandchild -> child -> base)"
class TK4Grand : TK4Child
    public
        override func Get
end
TK4Grand.Get() { inherited Get; kk._return "grand+$RESULT"; }
build TK4Grand
TK4Grand.new k4g
RESULT=""; k4g.Get
check "K4.5" "grand+child+parentvalue" "$RESULT"

kt_test_start "K4.6 a protected call from inside the class is silent and keeps RESULT"
K4_SEEN=""; RESULT=outer
k4.CallHidden 2>"$(kt_fixture_tmpdir)/k4.err"
check "K4.6 RESULT" "keep" "$K4_SEEN"
check "K4.6 stderr" "" "$(<"$(kt_fixture_tmpdir)/k4.err")"

kt_test_start "K4.7 a protected call from outside still warns"
k4.Hidden 2>"$(kt_fixture_tmpdir)/k4b.err"
if [[ -s "$(kt_fixture_tmpdir)/k4b.err" ]]; then kt_test_pass "K4.7"; else kt_test_fail "K4.7: no visibility warning"; fi

kt_test_log "150_PerfRoundK.sh completed"
