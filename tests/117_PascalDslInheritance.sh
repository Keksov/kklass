#!/bin/bash
# PascalDslInheritance — the Pascal-style DSL: inheritance, `inherited` in
# methods / constructors / destructors, constructor inheritance, func chains,
# override guard and abstract resolution.
# Companion example: examples/48_deep_inheritance_scopes.sh.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "PascalDslInheritance" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass_pascal.sh"

# --- three-level hierarchy with inherited chaining ---------------------------
class TDslBase
    public
        var         Kind
        constructor Create
        destructor  Destroy
        proc        Speak
        func        Describe
        static var  Alive
        static func Census
end
TDslBase.Create()   { Kind="$1"; Alive=$(( Alive + 1 )); }
TDslBase.Destroy()  { Alive=$(( Alive - 1 )); }
TDslBase.Speak()    { echo "base:$Kind"; }
TDslBase.Describe() { RESULT="$Kind"; }
TDslBase.Census()   { RESULT="$Alive"; }
build TDslBase

class TDslMid : TDslBase
    public
        var         Level
        constructor Create
        override proc Speak
        override func Describe
end
TDslMid.Create()   { inherited; Level="$2"; }                     # bare inherited: parent ctor + args
TDslMid.Speak()    { echo "mid"; inherited Speak; }               # named inherited in a method
TDslMid.Describe() { inherited; RESULT="$RESULT/L$Level"; }       # bare inherited func chain
build TDslMid

class TDslLeaf : TDslMid
    public
        var Tag
        constructor Create
        override func Describe
        destructor  Destroy         # chains to parent
        static var  Freed
end
TDslLeaf.Create()   { inherited; Tag="$3"; }
TDslLeaf.Describe() { inherited; RESULT="$RESULT+$Tag"; }
TDslLeaf.Destroy()  { Freed=$(( Freed + 1 )); inherited; }        # own cleanup, then parent's
build TDslLeaf

TDslBase.Alive = "0"
TDslLeaf.Freed = "0"

kt_test_start "constructor chains through all levels with argument forwarding"
TDslLeaf.new leaf "cat" "7" "x"
if [[ "$(leaf.Kind)" == "cat" && "$(leaf.Level)" == "7" && "$(leaf.Tag)" == "x" ]]; then
    kt_test_pass "constructor chains through all levels with argument forwarding"
else
    kt_test_fail "ctor chain (Kind='$(leaf.Kind)' Level='$(leaf.Level)' Tag='$(leaf.Tag)')"
fi

kt_test_start "bare inherited chains a func through three levels"
if [[ "$(leaf.Describe)" == "cat/L7+x" ]]; then
    kt_test_pass "bare inherited chains a func through three levels"
else
    kt_test_fail "func chain (got '$(leaf.Describe)')"
fi

kt_test_start "named inherited calls the parent method"
expected="$(printf 'mid\nbase:cat')"
if [[ "$(leaf.Speak)" == "$expected" ]]; then
    kt_test_pass "named inherited calls the parent method"
else
    kt_test_fail "named inherited (got '$(leaf.Speak)')"
fi

# --- constructor inheritance (none declared -> parent's runs) -----------------
kt_test_start "class without constructor inherits the parent's"
class TDslNoCtor : TDslBase
    public
        proc Noop
end
TDslNoCtor.Noop() { :; }
build TDslNoCtor
TDslNoCtor.new nc "dog"
if [[ "$(nc.Kind)" == "dog" ]]; then
    kt_test_pass "class without constructor inherits the parent's"
else
    kt_test_fail "inherited constructor (Kind='$(nc.Kind)')"
fi

# --- destructors --------------------------------------------------------------
kt_test_start "destructors run and chain on delete"
count_before="$(TDslBase.Census)"          # leaf + nc = 2
leaf.delete                                 # TDslLeaf.Destroy + inherited TDslBase.Destroy
nc.delete                                   # inherited TDslBase.Destroy
count_after="$(TDslBase.Census)"
freed="$(TDslLeaf.Freed)"
if [[ "$count_before" == "2" && "$count_after" == "0" && "$freed" == "1" ]]; then
    kt_test_pass "destructors run and chain on delete"
else
    kt_test_fail "destructors (before=$count_before after=$count_after freed=$freed)"
fi

# --- override guard -----------------------------------------------------------
kt_test_start "override guard rejects a method that overrides nothing"
class TDslTypo : TDslBase
    public
        override proc Speka        # typo: ancestor has 'Speak'
end
TDslTypo.Speka() { echo "oops"; }
err="$(build TDslTypo 2>&1)"
status=$?
if [[ $status -ne 0 && "$err" == *"overrides nothing"* ]]; then
    kt_test_pass "override guard rejects a method that overrides nothing"
else
    kt_test_fail "override guard (status=$status, err='$err')"
fi

# --- abstract resolution across inheritance ------------------------------------
class TDslAbstract
    public
        abstract func Area
        func Kind
end
TDslAbstract.Kind() { RESULT="shape"; }
build TDslAbstract

class TDslConcrete : TDslAbstract
    public
        var Side
        override func Area
end
TDslConcrete.Area() { RESULT=$(( Side * Side )); }
build TDslConcrete

kt_test_start "subclass implementing the abstract method is instantiable"
TDslConcrete.new sq
sq.Side = 5
if [[ "$(sq.Area)" == "25" && "$(sq.Kind)" == "shape" ]]; then
    kt_test_pass "subclass implementing the abstract method is instantiable"
else
    kt_test_fail "abstract resolution (Area='$(sq.Area)' Kind='$(sq.Kind)')"
fi
sq.delete

# --- virtual dispatch from an inherited body (template-method pattern) --------
# Regression companion to the "named inherited" check above: with owner-class
# frames, a NON-overridden parent method must still dispatch $this.call
# virtually, so a subclass override of the callee wins (Pascal semantics).
class TDslTemplate
    public
        proc Run
        func Step
end
TDslTemplate.Run()  { $this.call Step > /dev/null; echo "run:$RESULT"; }
TDslTemplate.Step() { RESULT="base-step"; }
build TDslTemplate

class TDslTemplateChild : TDslTemplate
    public
        override func Step
end
TDslTemplateChild.Step() { RESULT="child-step"; }
build TDslTemplateChild

kt_test_start "inherited body dispatches \$this.call virtually"
TDslTemplateChild.new tm
if [[ "$(tm.Run)" == "run:child-step" ]]; then
    kt_test_pass "inherited body dispatches \$this.call virtually"
else
    kt_test_fail "virtual dispatch (got '$(tm.Run)', want 'run:child-step')"
fi
tm.delete
