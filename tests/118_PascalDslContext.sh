#!/bin/bash
# PascalDslContext — the Pascal-style DSL: per-instance context correctness.
# Independent instances, cross-instance calls (frame restore), factory scopes,
# caller-local shadowing, subshell isolation, shared static state.
# Companion example: examples/48_deep_inheritance_scopes.sh.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "PascalDslContext" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass_pascal.sh"

class TDslActor
    public
        var         Name
        constructor Create
        func        WhoAmI
        proc        Meet
        static var  Total
        static func Count
end
TDslActor.Create() { Name="$1"; Total=$(( Total + 1 )); }
TDslActor.WhoAmI() { RESULT="$Name"; }
TDslActor.Count()  { RESULT="$Total"; }
# Calls ANOTHER instance mid-body: the frame must be restored afterwards.
TDslActor.Meet() {
    local other="$1"
    echo "$Name meets $($other.WhoAmI)"
    echo "$Name walks away"
}
build TDslActor

TDslActor.Total = "0"

kt_test_start "independent instances hold independent state"
TDslActor.new a "Alpha"
TDslActor.new b "Beta"
a.Name = "Alpha2"
if [[ "$(a.Name)" == "Alpha2" && "$(b.Name)" == "Beta" ]]; then
    kt_test_pass "independent instances hold independent state"
else
    kt_test_fail "independence (a='$(a.Name)' b='$(b.Name)')"
fi

kt_test_start "cross-instance call restores the caller's frame"
out="$(a.Meet b)"
expected="$(printf 'Alpha2 meets Beta\nAlpha2 walks away')"
if [[ "$out" == "$expected" ]]; then
    kt_test_pass "cross-instance call restores the caller's frame"
else
    kt_test_fail "frame restore (got '$out')"
fi

kt_test_start "instance created inside a function survives the scope"
spawn_actor() { TDslActor.new "$1" "$2"; }
spawn_actor c "Gamma"
if [[ "$(c.WhoAmI)" == "Gamma" ]]; then
    kt_test_pass "instance created inside a function survives the scope"
else
    kt_test_fail "factory scope (got '$(c.WhoAmI)')"
fi

kt_test_start "caller-local variables do not shadow instance fields"
shadow_scope() {
    local Name="CALLER-LOCAL"
    [[ "$(a.Name)" == "Alpha2" && "$(a.WhoAmI)" == "Alpha2" ]]
}
if shadow_scope; then
    kt_test_pass "caller-local variables do not shadow instance fields"
else
    kt_test_fail "caller-local shadowing leaked into the method"
fi

kt_test_start "subshell calls to different instances stay isolated"
combined="$(a.WhoAmI)-$(b.WhoAmI)-$(c.WhoAmI)"
if [[ "$combined" == "Alpha2-Beta-Gamma" ]]; then
    kt_test_pass "subshell calls to different instances stay isolated"
else
    kt_test_fail "subshell isolation (got '$combined')"
fi

kt_test_start "static state is shared across instances"
if [[ "$(TDslActor.Count)" == "3" ]]; then
    kt_test_pass "static state is shared across instances"
else
    kt_test_fail "shared static (Count='$(TDslActor.Count)', want 3)"
fi

a.delete; b.delete; c.delete
