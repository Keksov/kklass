#!/usr/bin/env bash
# BuilderNamespace (kcl review 2026-09-06: finding G8-04, X-LOCALS).
#
# `defineClass` / `defineMethod` walk their member lists with loop variables that
# were never declared `local`, so every class definition clobbered the caller's
# `p`, `m`, `sm`, `sp` and `wm`. kcl units define their classes at source time,
# which means `source tlist.sh` silently overwrote a script's own `$p`/`$m`.
# Only the documented cross-function channels (RESULT, REPLY, __kk_*) and the
# class generation _KKLASS_GEN may survive a definition (METHOD_BODY and
# METHOD_WRAPPER are the builders' locals since the image fix round F3).

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


# ---------------------------------------------------------------------------
# kkore's chained load images (docs/dev/IMAGE_PLAN.md, I2b fix round F3): the
# builders' channels are their locals, and every change of class structure
# bumps the generation _KKLASS_GEN (a load that builds a class makes it a base
# slot of its image)
kt_test_start "METHOD_BODY / METHOD_WRAPPER: locals of the builders, never left as globals [image F3]"
unset METHOD_BODY METHOD_WRAPPER
defineClass TBg1 "" method m1 'echo m1' function f1 'RESULT=1'
defineMethod TBg1 m2 'echo m2'
defineFunction TBg1 f2 'RESULT=2'
if [[ -z ${METHOD_BODY+x} && -z ${METHOD_WRAPPER+x} ]]; then kt_test_pass "none left"; else kt_test_fail "left: ${METHOD_BODY+METHOD_BODY} ${METHOD_WRAPPER+METHOD_WRAPPER}"; fi

kt_test_start "_KKLASS_GEN: +1 per class build and per defineMethod; a preset that is not a count starts again at 1 [image F3]"
g0=$_KKLASS_GEN
defineClass TBg2 "" method m1 'echo m1'
g1=$_KKLASS_GEN
defineMethod TBg2 m2 'echo m2'
g2=$_KKLASS_GEN
TBg2.new b4; b4.m2 >/dev/null; b4.delete
g3=$_KKLASS_GEN
_KKLASS_GEN='a[$(echo bad >&2)]'
defineMethod TBg2 m3 'echo m3' 2>"$_KT_TMPDIR/gen.err"
g4=$_KKLASS_GEN
if [[ $g0 == +([0-9]) && $g1 == $(( g0 + 1 )) && $g2 == $(( g1 + 1 )) && $g3 == "$g2" && $g4 == 1 && ! -s $_KT_TMPDIR/gen.err ]]; then
    kt_test_pass "ok"
else
    kt_test_fail "g0=$g0 g1=$g1 g2=$g2 g3=$g3 g4=$g4 err=$(< "$_KT_TMPDIR/gen.err")"
fi

kt_test_start "_KKLASS_GEN: defined (0) when kklass loads — a class build only changes it; a value already there kept; kk._unit_forget_class bumps it [image G1, G5]"
a=$(env -u _KKLASS_GEN "$BASH" -c 'source "$1/kklass.sh" >/dev/null 2>&1; echo "${_KKLASS_GEN-unset}"' _ "$KKLASS_DIR")
b=$(_KKLASS_GEN=7 "$BASH" -c 'source "$1/kklass.sh" >/dev/null 2>&1; echo "${_KKLASS_GEN-unset}"' _ "$KKLASS_DIR")
g0=$_KKLASS_GEN
kk._unit_forget_class TBg2
g1=$_KKLASS_GEN
if [[ $a == 0 && $b == 7 && $g1 == $(( g0 + 1 )) ]]; then kt_test_pass "ok"; else kt_test_fail "load=$a preset=$b forget $g0 -> $g1"; fi

kt_test_log "129_BuilderNamespace.sh completed"
