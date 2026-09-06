#!/bin/bash
# SetUContract (kcl review 2026-09-06: findings G8-01 / G1-14, X-SETU; decision D7).
#
# `set -u` is a kcl-wide contract (D7): a kcl unit must be sourceable and usable
# from a script that runs with `set -u`, because that is how careful callers run.
# Before the fix nothing did:
#
#   bash -c 'set -u; source kklass_pascal.sh'  -> _KKLASS_PASCAL_SOURCED: unbound
#   bash -c 'set -u; source kklass.sh'         -> __KLIB_SOURCED: unbound (kkore)
#   ( set -u; TList.new U; U.delete )          -> !__kk_dv: unbound  (G1-14)
#   set -u; defineClass A "" method m '...'    -> meth_index[$2]: unbound
#
# Every check below runs in a CHILD shell so that a failure cannot abort this
# file, and asserts on the child's stderr as well as its status: the whole point
# of `set -u` is that it turns a silent typo into a message, so an empty stderr
# is part of the contract.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "SetUContract" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KKORE_DIR="$(cd "$KKLASS_DIR/../kkore" && pwd)"

# Run SNIPPET in a pristine child shell under `set -u`; the child must print
# exactly OK on stdout, nothing on stderr, and exit 0.
expect_clean() {   # TITLE SNIPPET
    local title="$1" snippet="$2"
    local errf="$(kt_fixture_tmpdir)/setu.err" out rc
    kt_test_start "$title"
    out="$(bash -c "set -u
$snippet
printf OK" 2>"$errf")"; rc=$?
    local err="$(<"$errf")"
    if [[ $rc -eq 0 && "$out" == "OK" && -z "$err" ]]; then
        kt_test_pass "clean under set -u"
    else
        kt_test_fail "rc=$rc out='$out' stderr='$err'"
    fi
}

# ---------------------------------------------------------------------------
# 1. Sourcing every entry point of the framework and of kkore. [G8-01]
for f in "$KKORE_DIR/klib.sh" "$KKORE_DIR/kerr.sh" "$KKORE_DIR/kvar.sh" \
         "$KKORE_DIR/kcfg.sh" "$KKORE_DIR/kuse.sh" \
         "$KKLASS_DIR/kklass.sh" "$KKLASS_DIR/kklass_decl.sh" \
         "$KKLASS_DIR/kklass_pascal.sh" "$KKLASS_DIR/kklass_autoload.sh"; do
    expect_clean "source $(basename "$f") under set -u [G8-01]" "source '$f'"
done

# kklass_serializable.sh is a mixin: on its own it refuses to load, so it is
# checked on top of an already loaded framework.
expect_clean "source kklass_serializable.sh under set -u [G8-01]" \
    "source '$KKLASS_DIR/kklass.sh'; source '$KKLASS_DIR/kklass_serializable.sh'"

# ---------------------------------------------------------------------------
# 2. The re-source guard itself must not trip on the SECOND source. [G8-01]
#
# This is not hypothetical: kklass.sh sources kkore, and tlist.sh, tdictionary.sh
# and tstopwatch.sh then source klib.sh and kerr.sh AGAIN, so loading any of them
# takes the guard branch. kerr.sh's branch read a bare "$1" (it forwards
# `source kerr.sh set_trap`), which is unbound on a plain re-source — the first
# pass of this file loaded each file exactly once in a fresh shell and missed it.
for f in "$KKORE_DIR/klib.sh" "$KKORE_DIR/kerr.sh" "$KKORE_DIR/kvar.sh" \
         "$KKORE_DIR/kcfg.sh" "$KKORE_DIR/kuse.sh" \
         "$KKLASS_DIR/kklass.sh" "$KKLASS_DIR/kklass_decl.sh" \
         "$KKLASS_DIR/kklass_pascal.sh" "$KKLASS_DIR/kklass_autoload.sh"; do
    expect_clean "double source of $(basename "$f") under set -u [G8-01]" \
        "source '$f'; source '$f'"
done

# The real-world shape: kklass first (it pulls in all of kkore), then a unit
# re-sourcing klib.sh and kerr.sh on top of it, exactly as tlist.sh does.
expect_clean "kklass then a unit's own re-source of klib+kerr under set -u [G8-01]" \
    "source '$KKLASS_DIR/kklass.sh'; source '$KKORE_DIR/klib.sh'; source '$KKORE_DIR/kerr.sh'"

# kerr.sh's guard branch forwards the `set_trap` argument; that path must keep
# working and must still not trip on the missing argument.
expect_clean "re-source of kerr.sh with set_trap under set -u [G8-01]" \
    "source '$KKORE_DIR/kerr.sh'; source '$KKORE_DIR/kerr.sh' set_trap; trap - ERR"

# ---------------------------------------------------------------------------
# 3. Declaring a class under set -u (this is what `source <unit>.sh` does).
expect_clean "defineClass under set -u" "
source '$KKLASS_DIR/kklass.sh'
defineClass TSuA '' property v method m 'v=1' function g 'RESULT=\"\$v\"'"

expect_clean "defineClass with inheritance/statics/lazy under set -u" "
source '$KKLASS_DIR/kklass.sh'
defineClass TSuB '' property v static_property sp static_method sm 'sp=1' \
    lazy_property lz initLz method initLz 'echo 42' \
    property comp getComp function getComp 'RESULT=\"c\$v\"'
defineClass TSuC TSuB property w method m2 'w=2'"

# The Pascal front-end is what every kcl unit uses to declare its classes.
expect_clean "Pascal DSL (class/build) under set -u" "
source '$KKLASS_DIR/kklass_pascal.sh'
class TSuD
    public
        var         Name
        constructor Create
        proc        Greet
        func        Salutation
end
TSuD.Create()     { Name=\"\${1:-World}\"; }
TSuD.Greet()      { printf '%s\n' \"Hello, \$Name\"; }
TSuD.Salutation() { RESULT=\"Greetings from \$Name\"; }
build TSuD
TSuD.new d Alice
d.Salutation
d.delete"

expect_clean "declareClass/implement DSL under set -u" "
source '$KKLASS_DIR/kklass.sh'
declareClass TSuI ''
privateSection
field FName
publicSection
property Name read FName write FName
func GetName
endClass
implement 'TSuI.GetName' 'RESULT=\"\$FName\"'
endImplementation TSuI
TSuI.new i
i.Name = Alice
i.GetName
i.delete"

# ---------------------------------------------------------------------------
# 4. Full instance lifecycle under set -u, including .delete. [G1-14]
expect_clean "instance lifecycle under set -u (no destructor) [G1-14]" "
source '$KKLASS_DIR/kklass.sh'
defineClass TSuE '' property v method m 'v=\$((v+1))' function g 'RESULT=\"\$v\"'
TSuE.new e
e.v = 1
e.m
e.g
e.delete"

expect_clean "instance lifecycle under set -u (with destructor) [G1-14]" "
source '$KKLASS_DIR/kklass.sh'
defineClass TSuF '' property v destructor Destroy method Destroy 'v=' \
    constructor 'v=0'
TSuF.new f
f.delete"

expect_clean "computed, lazy and static members under set -u" "
source '$KKLASS_DIR/kklass.sh'
defineClass TSuG '' property v property d getD function getD 'RESULT=\$((v*2))' \
    lazy_property lz initLz method initLz 'RESULT=7' \
    static_property sp static_method sinc 'sp=\$((\${sp:-0}+1))'
TSuG.new g
g.v = 21
g.d
g.lz >/dev/null
TSuG.sinc
g.delete"

expect_clean "inherited / .parent / .call under set -u" "
source '$KKLASS_DIR/kklass.sh'
defineClass TSuP '' property v method speak 'RESULT=base'
defineClass TSuQ TSuP method speak 'inherited speak; RESULT=\"child:\$RESULT\"'
TSuQ.new q
q.call speak
q.delete"

# ---------------------------------------------------------------------------
# 4b. Boolean members answer with their exit status (kcl contract, README 1.3).
#     Under `set -e` a bare false command aborts the script, so the contract says
#     such a member is always called from an `if`, a `&&`/`||` or a `!`. Pinned
#     here under `set -eu` — including the false answer, which is the case that
#     aborts — so the rule the README states is the rule the framework honours.
expect_clean "rc-boolean methods under set -eu via if / || / ! [D7, README 1.3]" "
set -e
source '$KKLASS_DIR/kklass.sh'
defineClass TSuBool '' property v method isPos '[[ \"\$v\" -gt 0 ]]'
TSuBool.new b
b.v = 5
if b.isPos; then :; else printf 'WRONG-TRUE'; fi
b.v = -5
if b.isPos; then printf 'WRONG-FALSE'; fi
b.isPos || :
! b.isPos || printf 'WRONG-NEGATE'
b.delete"

# ---------------------------------------------------------------------------
# 5. `.delete` of an instance whose class has NO destructor was the exact
#    G1-14 crash; keep a dedicated, minimal check for it.
kt_test_start "kk._delete resolves a missing destructor name under set -u [G1-14]"
errf="$(kt_fixture_tmpdir)/g114.err"
bash -c "source '$KKLASS_DIR/kklass.sh'
set -u
defineClass TSuH '' property v
TSuH.new h
h.delete
printf DELETED" >"$(kt_fixture_tmpdir)/g114.out" 2>"$errf"; rc=$?
out="$(<"$(kt_fixture_tmpdir)/g114.out")"; err="$(<"$errf")"
if [[ $rc -eq 0 && "$out" == "DELETED" && -z "$err" ]]; then
    kt_test_pass "deleted cleanly"
else
    kt_test_fail "rc=$rc out='$out' stderr='$err'"
fi

kt_test_log "128_SetUContract.sh completed"
