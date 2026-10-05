#!/bin/bash
# IdentifierLocale, kklass side (round 4 / P12, findings L1 + L2, decision DR13).
#   L2  round 3 / P11 put a `local LC_ALL=C` into kklass's kk._is_ident: under
#       a UTF-8 caller locale every call paid ≈4.5× (kk.derivesFrom 70 -> 213
#       us). The helper now lives in kkore/klib.sh (kklass sources klib.sh
#       first and keeps `export -f kk._is_ident`): ASCII ranges + a
#       `*[![:ascii:]]*` guard, nocasematch switched off around the core — no
#       locale switch (the 12-combo exactness matrix is kkore test 008; the
#       inline .new guard's equivalence is 135 C5).
#   L1/C10  under `shopt -s nocasematch` the reserved-name checks folded case:
#       kk.decl._validate_ident refused result / ifs / reply / __KK_x, so
#       `defineClass T "" property result` was rc 1. The reserved sets are
#       case-SENSITIVE (bash names are): the comparisons now run with
#       nocasematch off, and the caller's nocasematch is restored.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "IdentifierLocale" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"

kt_test_start "I1 kk._is_ident is kkore's: defined in kkore/klib.sh, kklass.sh carries no copy"
shopt -s extdebug
where="$(declare -F kk._is_ident)"
shopt -u extdebug
n="$(grep -c '^kk\._is_ident()' "$KKLASS_DIR/kklass.sh")"
if [[ "$where" == *"/kkore/klib.sh" && "$n" == 0 ]]; then kt_test_pass "klib.sh"; else kt_test_fail "declare -F: '$where', copies in kklass.sh: $n"; fi

kt_test_start "I2 nocasematch: kk.decl._validate_ident accepts result/Result/This/STATE/ifs/reply/Reply/__KK_x/__Kk_x, still refuses RESULT/REPLY/IFS/this/__inst__/__class__/__kk_x; nocasematch kept"
bad=""
shopt -s nocasematch
for nm in result Result This STATE ifs reply Reply __KK_x __Kk_x; do
    kk.decl._validate_ident "$nm" "member name" 2>/dev/null || bad+=" $nm-refused"
    shopt -q nocasematch || { bad+=" nocasematch-lost($nm)"; shopt -s nocasematch; }
done
for nm in RESULT REPLY IFS this __inst__ __class__ __kk_x; do
    ! kk.decl._validate_ident "$nm" "member name" 2>/dev/null || bad+=" $nm-accepted"
    shopt -q nocasematch || { bad+=" nocasematch-lost($nm)"; shopt -s nocasematch; }
done
shopt -u nocasematch
if [[ -z "$bad" ]]; then kt_test_pass "case-sensitive"; else kt_test_fail "$bad"; fi

kt_test_start "I3 nocasematch: the member and static reserved sets are case-sensitive too (method Delete / Parent, static New / Constructor build; delete / new still refused)"
bad=""
shopt -s nocasematch
defineClass TNcm1 "" method Delete 'echo D' method Parent 'echo P' static_method New 'echo N' static_method Constructor 'echo C' 2>"$(kt_fixture_tmpdir)/e1" \
    || bad+=" refused: '$(<"$(kt_fixture_tmpdir)/e1")'"
! defineClass TNcm2 "" method delete 'echo d' 2>/dev/null || bad+=" delete-accepted"
! defineClass TNcm3 "" static_method new 'echo n' 2>/dev/null || bad+=" static-new-accepted"
shopt -q nocasematch || bad+=" nocasematch-lost"
shopt -u nocasematch
if [[ -z "$bad" ]]; then
    TNcm1.new nc1; o="$(nc1.Delete)$(nc1.Parent)$(TNcm1.New)$(TNcm1.Constructor)"
    [[ "$o" == DPNC ]] || bad+=" calls='$o'"
fi
if [[ -z "$bad" ]]; then kt_test_pass "ok"; else kt_test_fail "$bad"; fi

kt_test_start "I4 nocasematch: defineClass T \"\" property result builds and works (C10 repro)"
shopt -s nocasematch
defineClass TOvr "" property result property ifs 2>"$(kt_fixture_tmpdir)/e4"; rc=$?
shopt -u nocasematch
o=""
if (( rc == 0 )); then TOvr.new ov; ov.result = 5; ov.ifs = 6; o="$(ov.result)$(ov.ifs)"; fi
if [[ $rc == 0 && "$o" == 56 ]]; then kt_test_pass "built"; else kt_test_fail "rc=$rc o='$o' err='$(<"$(kt_fixture_tmpdir)/e4")'"; fi

kt_test_start "I5 KKLASS_EXPORT_FUNCTIONS=1 still exports kk._is_ident to a child shell (kklass keeps the export)"
o="$(KKLASS_EXPORT_FUNCTIONS=1 "$BASH" -c 'source "$1/kklass.sh" && "$BASH" -c "kk._is_ident ok_1 && ! kk._is_ident \"a b\" && echo child-ok"' _ "$KKLASS_DIR" 2>&1)"
if [[ "$o" == child-ok ]]; then kt_test_pass "exported"; else kt_test_fail "'$o'"; fi

kt_test_log "138_IdentifierLocale.sh completed"
