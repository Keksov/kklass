#!/bin/bash
# BuilderNamespace (kcl review 2026-09-06: finding G8-04, X-LOCALS).
#
# `defineClass` / `defineMethod` walk their member lists with loop variables that
# were never declared `local`, so every class definition clobbered the caller's
# `p`, `m`, `sm`, `sp` and `wm`. kcl units define their classes at source time,
# which means `source tlist.sh` silently overwrote a script's own `$p`/`$m`.
# Only the documented cross-function channels (RESULT, REPLY, METHOD_BODY,
# METHOD_WRAPPER, __kk_*) may survive a definition.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "BuilderNamespace" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"

# Loop variables the builders use internally; a caller may legitimately own any
# of these one-letter names.
WATCHED=(p m sm sp wm i j k n v x)

set_sentinels() {
    local __w
    for __w in "${WATCHED[@]}"; do printf -v "$__w" '%s' "SENTINEL_$__w"; done
}

# Reports the watched names whose value changed, space separated.
clobbered() {
    local __w out=""
    for __w in "${WATCHED[@]}"; do
        [[ "${!__w}" == "SENTINEL_$__w" ]] || out+="$__w=${!__w} "
    done
    printf '%s' "${out% }"
}

# ---------------------------------------------------------------------------
kt_test_start "defineClass leaks no loop variable into the caller [G8-04]"
set_sentinels
defineClass TBn1 "" \
    property alpha property beta \
    property comp getComp function getComp 'RESULT="$alpha$beta"' \
    lazy_property lz initLz method initLz 'RESULT=1' \
    static_property total static_method bump 'total=$((${total:-0}+1))' \
    method one 'alpha=1' method two 'beta=2'
bad="$(clobbered)"
[[ -z "$bad" ]] && kt_test_pass "no leak" || kt_test_fail "clobbered: $bad"

# ---------------------------------------------------------------------------
kt_test_start "defineClass with a parent leaks no loop variable [G8-04]"
set_sentinels
defineClass TBn2 TBn1 property gamma method three 'gamma=3'
bad="$(clobbered)"
[[ -z "$bad" ]] && kt_test_pass "no leak" || kt_test_fail "clobbered: $bad"

# ---------------------------------------------------------------------------
kt_test_start "Pascal DSL (class/build) leaks no loop variable [G8-04]"
source "$KKLASS_DIR/kklass_pascal.sh"
set_sentinels
class TBn3
    public
        var  Name
        proc Greet
        func Salutation
end
TBn3.Greet()      { printf '%s\n' "Hello, $Name"; }
TBn3.Salutation() { RESULT="Greetings from $Name"; }
build TBn3
bad="$(clobbered)"
[[ -z "$bad" ]] && kt_test_pass "no leak" || kt_test_fail "clobbered: $bad"

# ---------------------------------------------------------------------------
kt_test_start "declareClass/implement DSL leaks no loop variable [G8-04]"
set_sentinels
declareClass TBn5 ""
privateSection
field FName
publicSection
property Name read FName write FName
func GetName
endClass
implement "TBn5.GetName" 'RESULT="$FName"'
endImplementation TBn5
bad="$(clobbered)"
[[ -z "$bad" ]] && kt_test_pass "no leak" || kt_test_fail "clobbered: $bad"

# ---------------------------------------------------------------------------
kt_test_start "defineMethod leaks no loop variable [G8-04]"
set_sentinels
defineMethod TBn2 four 'gamma=4'
bad="$(clobbered)"
[[ -z "$bad" ]] && kt_test_pass "no leak" || kt_test_fail "clobbered: $bad"

# ---------------------------------------------------------------------------
kt_test_start ".new / method call / property access leak no loop variable [G8-04]"
TBn1.new b1
set_sentinels
b1.alpha = 10
b1.beta = 20
b1.one
b1.comp >/dev/null
b1.lz >/dev/null
TBn1.bump
b1.alpha >/dev/null
bad="$(clobbered)"
[[ -z "$bad" ]] && kt_test_pass "no leak" || kt_test_fail "clobbered: $bad"

# ---------------------------------------------------------------------------
kt_test_start ".delete leaks no loop variable [G8-04]"
set_sentinels
b1.delete
bad="$(clobbered)"
[[ -z "$bad" ]] && kt_test_pass "no leak" || kt_test_fail "clobbered: $bad"

kt_test_log "129_BuilderNamespace.sh completed"
