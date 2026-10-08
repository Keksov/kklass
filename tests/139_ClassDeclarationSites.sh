#!/bin/bash
# ClassDeclarationSites (uses phase U2a; kklass/USES_PLAN.md U20, U21, U23, U18',
# C6, C14, P4).
#   site   the declaration site of a class = the chain of FILE:LINE call
#          positions from the declaring frame outward up to the first `source`
#          frame (or the script's own frame). A re-source and a loop give the
#          same chain; two calls through a wrapper do not.
#   U21    a built class declared again from ANOTHER site -> "Duplicate
#          identifier": rc 1, one error naming both sites, the class poisoned
#          and the rest of that block swallowed (an imposter cannot rebuild the
#          original, its Pascal bodies leave nothing behind).
#   U20    the SAME site again (a header-less file sourced again) -> one
#          WARNING; the class is not rebuilt (instances, defineMethod changes,
#          static values and Pascal static methods survive; no scratch
#          functions left); defineClass is ignored as a whole.
#   U18'   the file parts are compared with -ef: other spellings of one file
#          are the same site.
#   C14    a declaration chain with no file frame (a prompt) may redefine; a
#          file sourced at a prompt is still checked.
#   P4     a class built while a unit loads is filed under the unit;
#          `kk.unit --forget` forgets it, so the next source rebuilds it.
#   R14    the site tables are guarded: a set -a child with hostile names and
#          paths evaluates nothing.
# Every case runs in a child bash (fresh class registry), files in $TMPD.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ClassDeclarationSites" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KBOOL_ROOT="$(cd "$KKLASS_DIR/.." && pwd)"

TMPD="${TMPDIR:-/tmp}/kk139_$$"
mkdir -p "$TMPD" && TMPD="$(cd "$TMPD" && pwd)"
kk139_cleanup() { rm -rf "$TMPD"; }
kt_fixture_cleanup_register kk139_cleanup

# case_run NAME — run $TMPD/NAME.sh in a child bash (cwd $TMPD); OUT, ERR, RC.
case_run() {
    ( cd "$TMPD" && KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" KBOOL_ROOT="$KBOOL_ROOT" \
        "$BASH" "$TMPD/$1.sh" >"$TMPD/$1.out" 2>"$TMPD/$1.err" ); RC=$?
    OUT="$(<"$TMPD/$1.out")"; ERR="$(<"$TMPD/$1.err")"
}
# nlines TEXT -> N (number of lines; 0 for empty)
nlines() { N=0; [[ -z "$1" ]] && return 0; local -a a; mapfile -t a <<<"$1"; N=${#a[@]}; }
fl() { local f; for f in "$@"; do printf '%s' "$(<"$TMPD/$f")"; done; }

# ---------------------------------------------------------------------------
cat > "$TMPD/unitA.sh" <<'EOF'
defineClass TSa "" property a
defineClass TSa "" property b
EOF
cat > "$TMPD/A.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
source "$TMPD/unitA.sh"; echo "rc=$? props=${TSa_class_properties[*]}"
EOF
kt_test_start "S1 the same file, another line: Duplicate identifier, rc 1, ONE error naming both sites, the first definition kept"
case_run A; nlines "$ERR"
if [[ "$OUT" == "rc=1 props=a" && $N -eq 1 && "$ERR" == *"Duplicate identifier"* && "$ERR" == *"'TSa'"* \
      && "$ERR" == *"unitA.sh:1"* && "$ERR" == *"unitA.sh:2"* ]]; then
    kt_test_pass "$ERR"
else
    kt_test_fail "out='$OUT' lines=$N err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/unitB.sh" <<'EOF'
mk() { defineClass "$1" "" property "$2"; }
mk TSw x
mk TSw y
echo "second=$? props=${TSw_class_properties[*]}"
EOF
cat > "$TMPD/B.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
source "$TMPD/unitB.sh"
EOF
kt_test_start "S2 a wrapper called twice (mk A x; mk A y) is two sites: the second is refused"
case_run B; nlines "$ERR"
if [[ "$OUT" == "second=1 props=x" && $N -eq 1 && "$ERR" == *"Duplicate identifier"* && "$ERR" == *"unitB.sh:2"* && "$ERR" == *"unitB.sh:3"* ]]; then
    kt_test_pass "$ERR"
else
    kt_test_fail "out='$OUT' lines=$N err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/origC.sh" <<'EOF'
class TSp
    public
        func Who
        static func Tag
end
TSp.Who() { RESULT="ORIGINAL"; }
TSp.Tag() { RESULT="orig-tag"; }
build TSp
EOF
cat > "$TMPD/impC.sh" <<'EOF'
class TSp
    public
        func Who
        func Extra
        static func Tag
        static var Bogus
end
TSp.Who() { RESULT="IMPOSTER"; }
TSp.Extra() { RESULT="x"; }
TSp.Tag() { RESULT="imp-tag"; }
build TSp
echo "imposter-build=$?"
class TSpTail
    public
        func Tag
end
TSpTail.Tag() { RESULT="tail"; }
build TSpTail
EOF
cat > "$TMPD/C.sh" <<'EOF'
source "$KKLASS_DIR/kklass_pascal.sh"
source "$TMPD/origC.sh"
TSp.new p1
source "$TMPD/impC.sh" 2>"$TMPD/C.err2"
p1.Who; echo "who1=$RESULT"
TSp.new p2; p2.Who; echo "who2=$RESULT"
echo "tag=$(TSp.Tag)"
for f in TSp.Who TSp.Extra TSp.Bogus; do declare -F "$f" >/dev/null && echo "left=$f"; done
TSpTail.new t; t.Tag; echo "tail=$RESULT"
echo "open=[$KK_DECL_CURRENT_CLASS] static=[${__KK_PASCAL_STATIC}]"
build TSp 2>/dev/null; echo "rebuild=$?"
endImplementation TSp 2>/dev/null; echo "endimpl=$?"
TSp.new p3; p3.Who; echo "who3=$RESULT tag=$(TSp.Tag)"
EOF
kt_test_start "S3 a Pascal imposter unit: one error, build rc 1, the original (instances, new instances, static Tag) intact, no scratch left, a later build/endImplementation cannot rebuild it, the next class builds"
case_run C; e2="$(fl C.err2)"; nlines "$e2"
want=$'imposter-build=1\nwho1=ORIGINAL\nwho2=ORIGINAL\ntag=orig-tag\ntail=tail\nopen=[] static=[]\nrebuild=1\nendimpl=1\nwho3=ORIGINAL tag=orig-tag'
if [[ "$OUT" == "$want" && $N -eq 1 && "$e2" == *"Duplicate identifier"* && "$e2" == *"origC.sh:1"* && "$e2" == *"impC.sh:1"* && -z "$ERR" ]]; then
    kt_test_pass "$e2"
else
    kt_test_fail "out='${OUT//$'\n'/|}' lines=$N err2='$e2' err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/origC2.sh" <<'EOF'
declareClass TSq ""
    field n
    procedure Hi
endClass
implement TSq.Hi 'echo "orig $n"'
endImplementation TSq
EOF
cat > "$TMPD/impC2.sh" <<'EOF'
declareClass TSq ""
    field n
    field m
    procedure Hi
endClass
implement TSq.Hi 'echo "imposter $n"'
implementConstructor TSq 'n=ctor'
endImplementation TSq
echo "imposter-end=$?"
EOF
cat > "$TMPD/C2.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
source "$TMPD/origC2.sh"
source "$TMPD/impC2.sh" 2>"$TMPD/C2.err2"
TSq.new q; q.n = z; q.Hi
echo "fields=${TSq_decl_fields[*]} props=${TSq_class_properties[*]}"
EOF
kt_test_start "S4 a declarative imposter: one error, the rest of the block swallowed (rc 1), the original intact"
case_run C2; e2="$(fl C2.err2)"; nlines "$e2"
if [[ "$OUT" == $'imposter-end=1\norig z\nfields=n props=n' && $N -eq 1 && "$e2" == *"Duplicate identifier"* ]]; then
    kt_test_pass "$e2"
else
    kt_test_fail "out='${OUT//$'\n'/|}' lines=$N err2='$e2' err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/unitD.sh" <<'EOF'
declareClass TSd ""
    field n
    procedure Hi
    classVar Count
    classProcedure Bump
endClass
implement TSd.Hi 'echo "hi $n"'
implement TSd.Bump 'Count=$((Count + 1))'
endImplementation TSd
EOF
cat > "$TMPD/D.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
source "$TMPD/unitD.sh"
TSd.new d1; d1.n = alice; TSd.Bump; TSd.Bump
defineMethod TSd Hi 'echo "changed $n"'
source "$TMPD/unitD.sh" 2>"$TMPD/D.err2"; echo "rc=$?"
d1.Hi; TSd.new d2; d2.n = bob; d2.Hi
echo "count=$TSd_static_Count open=[$KK_DECL_CURRENT_CLASS]"
EOF
kt_test_start "S5 a header-less DECLARATIVE file sourced again: rc 0, ONE WARNING, not rebuilt (live instance, defineMethod change, static value survive)"
case_run D; e2="$(fl D.err2)"; nlines "$e2"
if [[ "$OUT" == $'rc=0\nchanged alice\nchanged bob\ncount=2 open=[]' && $N -eq 1 && "$e2" == *WARNING* && "$e2" == *"'TSd'"* && -z "$ERR" ]]; then
    kt_test_pass "$e2"
else
    kt_test_fail "out='${OUT//$'\n'/|}' lines=$N err2='$e2' err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/unitE.sh" <<'EOF'
class TU20
    public
        var Name
        func Hello
        constructor Create
        destructor Done
        static var Count
        static func GetCount
end
TU20.Create()   { Name="$1"; Count=$((Count + 1)); }
TU20.Done()     { :; }
TU20.Hello()    { RESULT="hello $Name"; }
TU20.GetCount() { RESULT="count=$Count"; }
build TU20
EOF
cat > "$TMPD/E.sh" <<'EOF'
source "$KKLASS_DIR/kklass_pascal.sh"
source "$TMPD/unitE.sh"
TU20.new a1 alice; TU20.new a2 bob
source "$TMPD/unitE.sh" 2>"$TMPD/E.err2"; echo "rc=$?"
echo "sub=$(TU20.GetCount)"
for f in TU20.Create TU20.Hello TU20.Done; do declare -F "$f" >/dev/null && echo "left=$f"; done
a1.Hello; echo "a1=$RESULT"
TU20.new a3 carol; a3.Hello; echo "a3=$RESULT after=$(TU20.GetCount)"
EOF
kt_test_start "S6 a header-less PASCAL file sourced again: ONE WARNING, Count kept, the static GetCount restored, no scratch body functions left, instances work"
case_run E; e2="$(fl E.err2)"; nlines "$e2"
if [[ "$OUT" == $'rc=0\nsub=count=2\na1=hello alice\na3=hello carol after=count=3' && $N -eq 1 && "$e2" == *WARNING* && "$e2" == *"'TU20'"* && -z "$ERR" ]]; then
    kt_test_pass "$e2"
else
    kt_test_fail "out='${OUT//$'\n'/|}' lines=$N err2='$e2' err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/unitF.sh" <<'EOF'
defineClass TSf "" property a method m 'echo m1'
defineSerializableClass TSs "" ":" string property x
defineClass TSfc TSs property y
EOF
cat > "$TMPD/F.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"; source "$KKLASS_DIR/kklass_serializable.sh"
source "$TMPD/unitF.sh"
TSf.new f1; defineMethod TSf m 'echo m2'
source "$TMPD/unitF.sh" 2>"$TMPD/F.err2"; echo "rc=$?"
f1.m; TSf.new f2; f2.m
echo "open=[$KK_DECL_CURRENT_CLASS]"
EOF
kt_test_start "S7 defineClass / defineSerializableClass sourced again: ignored as a whole, one WARNING per class, no other output, the defineMethod change survives"
case_run F; e2="$(fl F.err2)"; nlines "$e2"
if [[ "$OUT" == $'rc=0\nm2\nm2\nopen=[]' && $N -eq 3 && "$e2" == *"'TSf'"* && "$e2" == *"'TSs'"* && "$e2" == *"'TSfc'"* && "$e2" != *[Ee]rror* && "$e2" != *subclass* ]]; then
    kt_test_pass "3 warnings"
else
    kt_test_fail "out='${OUT//$'\n'/|}' lines=$N err2='$e2' err='$ERR'"
fi

# ---------------------------------------------------------------------------
mkdir -p "$TMPD/g/sub"
printf 'defineClass TSg "" property v\n' > "$TMPD/g/unitG.sh"
cat > "$TMPD/G.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
D="$TMPD/g"
source "$D/unitG.sh"
sps=("$D/unitG.sh" "$D/sub/../unitG.sh" "$D/./unitG.sh" "$D//unitG.sh")
W="$(cd "$D" && pwd -W 2>/dev/null)" || W=""
if [[ -n "$W" && "$W" == [A-Za-z]:/* ]]; then
    d="${W:0:1}"
    sps+=("$W/unitG.sh" "${W//\//\\}\\unitG.sh" "/${d,}${W:2}/unitG.sh" "/${d^}${W:2}/unitG.sh" "${W^^}/UNITG.SH")
fi
n=0
for sp in "${sps[@]}"; do
    [[ -e "$sp" ]] || { echo "MISSING[$sp]"; continue; }
    source "$sp" 2>"$TMPD/G.e"; rc=$?; e="$(<"$TMPD/G.e")"
    n=$((n + 1))
    [[ $rc -eq 0 && "$e" == *WARNING* && "$e" != *Duplicate* ]] || echo "BAD[$sp] rc=$rc e=$e"
done
cd "$D" && { source ./unitG.sh 2>"$TMPD/G.e"; rc=$?; e="$(<"$TMPD/G.e")"; [[ $rc -eq 0 && "$e" == *WARNING* && "$e" != *Duplicate* ]] || echo "BAD[./] rc=$rc e=$e"; n=$((n + 1)); }
echo "spellings=$n props=${TSg_class_properties[*]}"
EOF
kt_test_start "S8 U18': the same file through other spellings (.., ., //, ./, and on MSYS C:/, C:\\, /c/, /C/, upper case) is the same site: WARNING, never Duplicate"
case_run G
if [[ "$OUT" == "spellings="*" props=v" && "$OUT" != *BAD* && "$OUT" != *MISSING* && -z "$ERR" ]]; then
    kt_test_pass "$OUT"
else
    kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/unitH.sh" <<'EOF'
defineClass TSh "" property a
defineClass TSh "" property b
EOF
kt_test_start "S9 C14: at an interactive prompt (bash -i) a redefinition is allowed; a file sourced at the prompt is still checked"
printf '%s\n' 'source "$KKLASS_DIR/kklass.sh"' 'defineClass TSi "" property a' 'defineClass TSi "" property b' \
    'echo "i=${TSi_class_properties[*]}"' 'source "$TMPD/unitH.sh"' 'echo "h=${TSh_class_properties[*]}"' 'exit' >"$TMPD/H.in"
( cd "$TMPD" && KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" HISTFILE= "$BASH" --norc --noprofile -i <"$TMPD/H.in" >"$TMPD/H.out" 2>"$TMPD/H.err" )
OUT="$(<"$TMPD/H.out")"; ERR="$(<"$TMPD/H.err")"
if [[ "$OUT" == *"i=b"* && "$OUT" == *"h=a"* && "$ERR" != *"'TSi'"* && "$ERR" == *"Duplicate identifier: class 'TSh'"* ]]; then
    kt_test_pass "prompt redefines, file checked"
else
    kt_test_fail "out='${OUT//$'\n'/|}' err='${ERR//$'\n'/|}'"
fi

# ---------------------------------------------------------------------------
mkdir -p "$TMPD/home" "$TMPD/etc" "$TMPD/u"
cat > "$TMPD/u/myu.sh" <<'EOF'
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit myu || return $__kk_unit_rc
class TSu
    public
        func Who
end
TSu.Who() { RESULT="v1"; }
build TSu
EOF
cat > "$TMPD/I.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" || { echo "no kbool"; exit 1; }
source "$KKLASS_DIR/kklass_pascal.sh"
source "$TMPD/u/myu.sh"; echo "load=$?"
TSu.new u1; u1.Who; echo "u1=$RESULT"
kk._unit_classes myu; echo "classes=[$RESULT]"
sed -i 's/v1/v2/' "$TMPD/u/myu.sh"
source "$TMPD/u/myu.sh"; TSu.new u2; u2.Who; echo "u2=$RESULT"
kk.unit --forget myu; echo "forget=$?"
source "$TMPD/u/myu.sh" 2>"$TMPD/I.err2"; echo "reload=$?"
TSu.new u3; u3.Who; echo "u3=$RESULT"
kk._unit_classes myu; echo "classes=[$RESULT]"
EOF
kt_test_start "S10 P4: a class built while a unit loads is filed under it; kk.unit --forget then a source REBUILDS it (silently)"
( cd "$TMPD" && env -u KBOOL_CONFIG -u USERPROFILE -u ProgramData -u PROGRAMDATA HOME="$TMPD/home" __KK_CFG_ETC="$TMPD/etc" \
    KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" KBOOL_ROOT="$KBOOL_ROOT" "$BASH" "$TMPD/I.sh" >"$TMPD/I.out" 2>"$TMPD/I.err" )
OUT="$(<"$TMPD/I.out")"; ERR="$(<"$TMPD/I.err")"; e2="$(fl I.err2)"
if [[ "$OUT" == $'load=0\nu1=v1\nclasses=[TSu]\nu2=v1\nforget=0\nreload=0\nu3=v2\nclasses=[TSu]' && -z "$e2" && -z "$ERR" ]]; then
    kt_test_pass "rebuilt after --forget"
else
    kt_test_fail "out='${OUT//$'\n'/|}' err2='$e2' err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/unitJ.sh" <<'EOF'
for i in 1 2 3; do defineClass TSl "" property a; done
echo "loop=$? props=${TSl_class_properties[*]}"
EOF
cat > "$TMPD/J.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
source "$TMPD/unitJ.sh"
EOF
kt_test_start "S11 a loop declaring the same class is ONE site: rc 0, never Duplicate (the repeats are the same-site case: one WARNING each)"
case_run J; nlines "$ERR"
if [[ "$OUT" == "loop=0 props=a" && "$ERR" != *Duplicate* && $N -eq 2 && "$ERR" == *WARNING* ]]; then
    kt_test_pass "rc 0"
else
    kt_test_fail "out='$OUT' lines=$N err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/unitK.sh" <<'EOF'
kk._build_class_runtime TSr "" property a
EOF
cat > "$TMPD/K.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
source "$TMPD/unitK.sh"; TSr.new r1; r1.a = 1
source "$TMPD/unitK.sh" 2>"$TMPD/K.err2"; echo "same=$? r1=$(r1.a)"
kk._build_class_runtime TSr "" property b 2>"$TMPD/K.err3"; echo "other=$? props=${TSr_class_properties[*]}"
EOF
kt_test_start "S12 a raw kk._build_class_runtime: the same site again -> WARNING, not rebuilt; another site -> Duplicate identifier"
case_run K; e2="$(fl K.err2)"; e3="$(fl K.err3)"
if [[ "$OUT" == $'same=0 r1=1\nother=1 props=a' && "$e2" == *WARNING* && "$e3" == *"Duplicate identifier"* && -z "$ERR" ]]; then
    kt_test_pass "ok"
else
    kt_test_fail "out='${OUT//$'\n'/|}' err2='$e2' err3='$e3' err='$ERR'"
fi

# ---------------------------------------------------------------------------
INJ="$TMPD/inj/d[\$(touch PWN)]"
mkdir -p "$INJ" "$TMPD/pw"
printf 'defineClass TSx "" property a\n' > "$INJ/u.sh"
cat > "$TMPD/L.sh" <<'EOF'
set -a
source "$KKLASS_DIR/kklass_pascal.sh"
set +a
cd "$TMPD/pw" || exit 1
TSx='a[$(touch PWN)]' "$BASH" -c '
    source "$1"; source "$1"
    TSx.new x1 && echo "child-built"
    kk._unit_forget_class "x[\$(touch PWN)]"; echo "forget-hostile=$?"
    kk._unit_forget_class TSx; echo "forget=$?"
    source "$1" 2>/dev/null; echo "again=$?"
' _ "$2"
cd "$1" && "$BASH" -c 'source "$1/kklass.sh"; source ./u.sh; source ./u.sh; echo "inj-dir=$?"' _ "$KKLASS_DIR"
EOF
kt_test_start "S13 R14: a set -a child (no site tables of its own) with a hostile class-named variable, a hostile folder name and a hostile forget argument evaluates nothing"
( cd "$TMPD" && KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" "$BASH" "$TMPD/L.sh" "$INJ" "$INJ/u.sh" >"$TMPD/L.out" 2>"$TMPD/L.err" )
OUT="$(<"$TMPD/L.out")"; ERR="$(<"$TMPD/L.err")"
pwn=""
for f in "$TMPD/pw/PWN" "$TMPD/PWN" "$INJ/PWN" "$TMPD/inj/PWN"; do [[ -e "$f" ]] && pwn+=" $f"; done
if [[ -z "$pwn" && "$OUT" == $'child-built\nforget-hostile=2\nforget=0\nagain=0\ninj-dir=0' && "$ERR" != *Duplicate* ]]; then
    kt_test_pass "no PWN"
else
    kt_test_fail "pwn='$pwn' out='${OUT//$'\n'/|}' err='${ERR//$'\n'/|}'"
fi


# ===========================================================================
# Review round 1 (R1-R9)
# ===========================================================================

# ---------------------------------------------------------------------------
cat > "$TMPD/s14.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
defineClass TNi "" property a
defineClass TNi "" property b
echo "rc=$? props=${TNi_class_properties[*]}"
EOF
kt_test_start "S14 R1: only a real prompt (\$- has i) may redefine: bash -c, bash < file, bash -s, a pipe -> Duplicate identifier for another line"
bad=""
for form in c stdin s pipe; do
    case $form in
        c)     o=$(cd "$TMPD" && KKLASS_DIR="$KKLASS_DIR" "$BASH" -c "$(<"$TMPD/s14.sh")" 2>"$TMPD/s14.err") ;;
        stdin) o=$(cd "$TMPD" && KKLASS_DIR="$KKLASS_DIR" "$BASH" <"$TMPD/s14.sh" 2>"$TMPD/s14.err") ;;
        s)     o=$(cd "$TMPD" && KKLASS_DIR="$KKLASS_DIR" "$BASH" -s <"$TMPD/s14.sh" 2>"$TMPD/s14.err") ;;
        pipe)  o=$(cd "$TMPD" && cat "$TMPD/s14.sh" | KKLASS_DIR="$KKLASS_DIR" "$BASH" 2>"$TMPD/s14.err") ;;
    esac
    e=$(<"$TMPD/s14.err")
    [[ "$o" == "rc=1 props=a" && "$e" == *"Duplicate identifier: class 'TNi'"* && "$e" == *"(no file):2"* && "$e" == *"(no file):3"* ]] || bad+=" [$form] out='$o' err='$e';"
done
if [[ -z "$bad" ]]; then kt_test_pass "4 forms"; else kt_test_fail "$bad"; fi

# ---------------------------------------------------------------------------
kt_test_start "S15 R2: a wrapper defined inside bash -c / bash -s: two lines -> Duplicate, one line twice -> the same site; no fake file named after \$0 on either bash"
bad=""
o=$(cd "$TMPD" && KKLASS_DIR="$KKLASS_DIR" "$BASH" -c 'source "$KKLASS_DIR/kklass.sh"
mk() { defineClass "$1" "" property "$2"; }
mk TCw a
mk TCw b
echo "two=$? props=${TCw_class_properties[*]}"
mk TCs a; mk TCs a
echo "one=$? props=${TCs_class_properties[*]}"' snippet 2>"$TMPD/s15.err")
e=$(<"$TMPD/s15.err")
[[ "$o" == $'two=1 props=a\none=0 props=a' && "$e" == *"Duplicate identifier: class 'TCw'"* && "$e" == *"WARNING: class 'TCs'"* ]] || bad+=" [-c] out='${o//$'\n'/|}' err='$e';"
[[ "$e" != *snippet* ]] || bad+=" [-c] \$0 used as a file: '$e';"
printf '%s\n' 'source "$KKLASS_DIR/kklass.sh"' 'mk() { defineClass "$1" "" property "$2"; }' 'mk TCx a' 'mk TCx b' 'echo "two=$?"' >"$TMPD/s15.in"
o=$(cd "$TMPD" && KKLASS_DIR="$KKLASS_DIR" "$BASH" -s <"$TMPD/s15.in" 2>"$TMPD/s15.err")
e=$(<"$TMPD/s15.err")
[[ "$o" == "two=1" && "$e" == *"Duplicate identifier: class 'TCx'"* && "$e" != *"/bash:"* && "$e" != *"/bash.exe:"* && "$e" != *"(main)"* ]] || bad+=" [-s] out='$o' err='$e';"
# $0 naming a real file (the ktests runner shape: bash -c 'source "$0"' FILE) stays a file
o=$(cd "$TMPD" && KKLASS_DIR="$KKLASS_DIR" "$BASH" -c 'source "$KKLASS_DIR/kklass.sh"; source "$0"; echo "rc=$?"' "$TMPD/unitA.sh" 2>"$TMPD/s15.err")
e=$(<"$TMPD/s15.err")
[[ "$o" == "rc=1" && "$e" == *"unitA.sh:1"* && "$e" == *"unitA.sh:2"* ]] || bad+=" [\$0 file] out='$o' err='$e';"
if [[ -z "$bad" ]]; then kt_test_pass "same verdicts"; else kt_test_fail "$bad"; fi

# ---------------------------------------------------------------------------
cat > "$TMPD/origX.sh" <<'EOF'
class TPX
    public
        var v
        func Who
        static var N
        static func Tag
end
TPX.Who() { RESULT="ORIG"; }
TPX.Tag() { RESULT="orig-tag N=$N"; }
build TPX
EOF
cat > "$TMPD/impX.sh" <<'EOF'
class TPX
    public
        func Who
        static func Tag
end
TPX.Who() { RESULT="IMP"; }
TPX.Tag() { RESULT="imp-tag"; }
EOF
cat > "$TMPD/extX.sh" <<'EOF'
implement TPX.Late 'echo late'
echo "ext=$?"
EOF
cat > "$TMPD/S16.sh" <<'EOF'
source "$KKLASS_DIR/kklass_pascal.sh"
source "$TMPD/origX.sh"; TPX.N = 5
source "$TMPD/impX.sh" 2>/dev/null
source "$TMPD/extX.sh" 2>"$TMPD/S16.err2"
echo "tag=$(TPX.Tag) who=$(declare -F TPX.Who) sink=[$__KK_SINK]"
TPX.new p; p.Who; echo "p=$RESULT"
source "$TMPD/impX.sh" 2>/dev/null
defineClass TPOther "" property z
echo "tag2=$(TPX.Tag) who2=$(declare -F TPX.Who) sink2=[$__KK_SINK]"
EOF
kt_test_start "S16 R3: an imposter without build leaves a sink; a verb from another file is NOT swallowed and closes the stale sink (the original's static restored, imposter bodies dropped); so does the next declareClass"
case_run S16; e2="$(fl S16.err2)"
if [[ "$OUT" == $'ext=1\ntag=orig-tag N=5 who= sink=[]\np=ORIG\ntag2=orig-tag N=5 who2= sink2=[]' && "$e2" == *"not declared"* && -z "$ERR" ]]; then
    kt_test_pass "closed"
else
    kt_test_fail "out='${OUT//$'\n'/|}' err2='$e2' err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/lu.sh" <<'EOF'
class TLS
    public
        func Who
        static var N
        static func Tag
end
TLS.Who() { RESULT="who"; }
TLS.Tag() { RESULT="tag N=$N"; }
[[ -n ${STOP-} ]] && return 0
build TLS
EOF
cat > "$TMPD/extL.sh" <<'EOF'
implement TLS.Extra 'echo extra'
echo "ext=$?"
EOF
cat > "$TMPD/S17.sh" <<'EOF'
source "$KKLASS_DIR/kklass_pascal.sh"
source "$TMPD/lu.sh"; TLS.N = 7
STOP=1 source "$TMPD/lu.sh" 2>/dev/null
source "$TMPD/extL.sh" 2>"$TMPD/S17.err2"
echo "tag=$(TLS.Tag) who=$(declare -F TLS.Who) sink=[$__KK_SINK]"
source "$TMPD/lu.sh" 2>/dev/null; echo "full=$? tag=$(TLS.Tag) sink=[$__KK_SINK] fns=[$__KK_SINK_FNS]"
EOF
kt_test_start "S17 R3: a header-less Pascal re-source that returns before build: a later verb from another file is not swallowed, the stale sink is closed (Tag restored, scratch dropped)"
case_run S17; e2="$(fl S17.err2)"
if [[ "$OUT" == $'ext=1\ntag=tag N=7 who= sink=[]\nfull=0 tag=tag N=7 sink=[] fns=[]' && "$e2" == *"not declared"* && -z "$ERR" ]]; then
    kt_test_pass "closed"
else
    kt_test_fail "out='${OUT//$'\n'/|}' err2='$e2' err='$ERR'"
fi

# ---------------------------------------------------------------------------
mkdir -p "$TMPD/pw4"
cat > "$TMPD/S18.sh" <<'EOF'
set -a
source "$KKLASS_DIR/kklass_pascal.sh"
declareClass TFoo ""
field a
set +a
cd "$TMPD/pw4" || exit 1
for verb in endClass end 'build TFoo' 'endImplementation TFoo' 'implement TFoo.m x' 'kk.decl._snap_drop TFoo' 'kk.decl._close_refused TFoo' 'kk._unit_forget_class TFoo' 'kk.class --forget TFoo'; do
    TFoo='a[$(touch PWN)]' "$BASH" -c "$verb" >/dev/null 2>&1
    [[ -e PWN ]] && { echo "PWN: $verb"; rm -f PWN; }
done
echo done
EOF
kt_test_start "S18 R4: a set -a child with an inherited open class and a hostile class-named variable: endClass, end, build, endImplementation, implement, the snapshot helpers, the forget hooks evaluate nothing"
case_run S18
if [[ "$OUT" == done ]]; then kt_test_pass "no PWN"; else kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR'"; fi

# ---------------------------------------------------------------------------
mkdir -p "$TMPD/pw5"
cat > "$TMPD/S19.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" || { echo "no kbool"; exit 1; }
source "$KKLASS_DIR/kklass.sh"
cd "$TMPD/pw5" || exit 1
H='a[$(touch PWN)]'
kk._class_register "$H" "x:1"; echo "register=$?"
[[ -e PWN ]] && { echo "PWN register"; rm -f PWN; }
kk._unit_drop "$H"; [[ -e PWN ]] && { echo "PWN drop"; rm -f PWN; }
__KK_UNIT_CLASSES[u]="$H"; kk._unit_drop u; [[ -e PWN ]] && { echo "PWN drop-class"; rm -f PWN; }
kk.unit --forget "$H" 2>/dev/null; [[ -e PWN ]] && { echo "PWN forget"; rm -f PWN; }
echo done
EOF
kt_test_start "S19 R5: no double-quoted unset of a table element with a variable key in kklass or kuse.sh; hostile keys through kk._class_register / kk._unit_drop / kk.unit --forget run nothing"
( cd "$TMPD" && env -u KBOOL_CONFIG -u USERPROFILE -u ProgramData -u PROGRAMDATA HOME="$TMPD/home" __KK_CFG_ETC="$TMPD/etc" \
    KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" KBOOL_ROOT="$KBOOL_ROOT" "$BASH" "$TMPD/S19.sh" >"$TMPD/S19.out" 2>"$TMPD/S19.err" )
OUT="$(<"$TMPD/S19.out")"
hits=""
for f in "$KKLASS_DIR"/kklass*.sh "$KBOOL_ROOT/kkore/kuse.sh"; do
    while IFS= read -r l; do hits+=" ${f##*/}: $l;"; done < <(grep -n 'unset "[^"]*\[\$' "$f")
done
if [[ -z "$hits" && "$OUT" == $'register=2\ndone' ]]; then kt_test_pass "clean"; else kt_test_fail "hits='$hits' out='${OUT//$'\n'/|}' err='$(<"$TMPD/S19.err")'"; fi

# ---------------------------------------------------------------------------
mkdir -p "$TMPD/e/e1" "$TMPD/e/e2" "$TMPD/e/d1" "$TMPD/e/d2"
cat > "$TMPD/e/e.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
for d in e1 e2; do cd "$d"; defineClass TRe "" property a; echo "E[$d]=$?"; cd ..; done
printf 'defineClass TRd "" property v\n' > d1/u.sh
printf 'defineClass TRd "" property w\n' > d2/u.sh
cd d1; source ./u.sh; echo "d1=$?"; cd ../d2; source ./u.sh; echo "d2=$? props=${TRd_class_properties[*]}"
EOF
kt_test_start "S20 R6: a relatively started script with cd in a loop is ONE site (WARNING, not Duplicate); two different files spelled ./u.sh from two folders are two sites"
o=$(cd "$TMPD/e" && KKLASS_DIR="$KKLASS_DIR" "$BASH" e.sh 2>"$TMPD/S20.err"); e=$(<"$TMPD/S20.err")
if [[ "$o" == $'E[e1]=0\nE[e2]=0\nd1=0\nd2=1 props=v' && "$e" == *WARNING*"'TRe'"* && "$e" != *"Duplicate identifier: class 'TRe'"* && "$e" == *"Duplicate identifier: class 'TRd'"* ]]; then
    kt_test_pass "ok"
else
    kt_test_fail "out='${o//$'\n'/|}' err='$e'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/u/dupu.sh" <<'EOF'
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit dupu || return $__kk_unit_rc
defineClass TDu "" property a
defineClass TDu "" property b
return 0
EOF
cat > "$TMPD/S21.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" || { echo "no kbool"; exit 1; }
source "$KKLASS_DIR/kklass.sh"
source "$TMPD/u/dupu.sh" 2>/dev/null; echo "plain=$?"
kk.uses "$TMPD/u/dupu.sh" 2>"$TMPD/S21.err2"; echo "uses=$?"
EOF
kt_test_start "S21 R7: a Duplicate identifier while a unit loads taints the unit (U34): kk.uses of it -> rc 2 'not completely loaded'"
( cd "$TMPD" && env -u KBOOL_CONFIG -u USERPROFILE -u ProgramData -u PROGRAMDATA HOME="$TMPD/home" __KK_CFG_ETC="$TMPD/etc" \
    KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" KBOOL_ROOT="$KBOOL_ROOT" "$BASH" "$TMPD/S21.sh" >"$TMPD/S21.out" 2>"$TMPD/S21.err" )
OUT="$(<"$TMPD/S21.out")"; e2="$(fl S21.err2)"
if [[ "$OUT" == $'plain=0\nuses=2' && "$e2" == *"not completely loaded"* ]]; then kt_test_pass "tainted"; else kt_test_fail "out='${OUT//$'\n'/|}' err2='$e2' err='$(<"$TMPD/S21.err")'"; fi

# ---------------------------------------------------------------------------
mkdir -p "$TMPD/pw6"
printf 'defineClass TKf "" method who '"'"'echo v1'"'"'\n' > "$TMPD/kf.sh"
cat > "$TMPD/S22.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
source "$TMPD/kf.sh"; TKf.new k1
sed -i 's/v1/v2/' "$TMPD/kf.sh"
source "$TMPD/kf.sh" 2>/dev/null; TKf.new k2; echo "before=$(k2.who)"
kk.class --forget TKf; echo "forget=$?"
source "$TMPD/kf.sh" 2>"$TMPD/S22.err2"; echo "reload=$?"
TKf.new k3; echo "after=$(k3.who) old=$(k1.who)"
kk.class --forget TNoSuchClass; echo "unknown=$?"
cd "$TMPD/pw6"; kk.class --forget 'a[$(touch PWN)]'; echo "hostile=$?"; [[ -e PWN ]] && echo PWN
kk.class --forget; echo "none=$?"
kk.class --bogus TKf; echo "bad-opt=$?"
EOF
kt_test_start "S22 R8: kk.class --forget X -> the next source of its header-less file rebuilds X (silently); rc 1 unknown class, rc 2 malformed (silent, no PWN)"
case_run S22; e2="$(fl S22.err2)"
if [[ "$OUT" == $'before=v1\nforget=0\nreload=0\nafter=v2 old=v2\nunknown=1\nhostile=2\nnone=2\nbad-opt=2' && -z "$e2" && -z "$ERR" ]]; then
    kt_test_pass "ok"
else
    kt_test_fail "out='${OUT//$'\n'/|}' err2='$e2' err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/S23.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
printf 'defineClass TQq "" property a\n' > "$TMPD/q.sh"
VERBOSE_KKLASS=quiet
source "$TMPD/q.sh"; source "$TMPD/q.sh" 2>"$TMPD/S23.e1"; echo "same=$? lines=$(wc -l <"$TMPD/S23.e1")"
defineClass TQq "" property z 2>"$TMPD/S23.e2"; echo "dup=$? lines=$(wc -l <"$TMPD/S23.e2")"
unset VERBOSE_KKLASS
source <(echo 'defineClass TQp "" property a')
source <(echo 'defineClass TQp "" property b') 2>"$TMPD/S23.e3"; echo "procsub=$? props=${TQp_class_properties[*]} warn=$(grep -c WARNING "$TMPD/S23.e3")"
defineClass TQl "" property a; defineClass TQl "" property b 2>"$TMPD/S23.e4"; echo "oneline=$? props=${TQl_class_properties[*]} warn=$(grep -c WARNING "$TMPD/S23.e4")"
grep -h WARNING "$TMPD/S23.e3" | grep -c 'sourced again'
EOF
kt_test_start "S23 R9: VERBOSE_KKLASS=quiet hides the WARNING, not the Duplicate; two process substitutions and two definitions on ONE line are the same site (pinned: WARNING, ignored); the WARNING does not claim a re-source"
case_run S23
if [[ "$OUT" == $'same=0 lines=0\ndup=1 lines=1\nprocsub=0 props=a warn=1\noneline=0 props=a warn=1\n0' ]]; then kt_test_pass "pinned"; else kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR'"; fi

# ---------------------------------------------------------------------------
cat > "$TMPD/cnt.kkp" <<'EOF'
unit cnt;

interface

type
  TCU = class
  private
    FValue: Integer;
  public
    class var Total: Integer;
    constructor Create(
      V: Integer
    );
    function GetValue(
    ): Integer;
    class function GetTotal(
    ): Integer;
  end;

implementation

constructor TCU.Create(
  V: Integer
);
begin
FValue="${1:-0}"
Total=$((Total + 1))
end;

function TCU.GetValue(
): Integer;
begin
RESULT="$FValue"
end;

class function TCU.GetTotal(
): Integer;
begin
RESULT="$Total"
end;

end.
EOF
sed '1d' "$TMPD/cnt.kkp" | sed 's/TCU/TCH/g' > "$TMPD/cnth.kkp"     # the same without `unit cnt;`
cat > "$TMPD/S24.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk
source "$KKLASS_DIR/kklass_autoload.sh"
autoloadClasses "$TMPD/cnt.kkp" --no-compile >/dev/null 2>&1; echo "first=$? unit=${__KK_UNITS[cnt]+registered}"
TCU.new a 5
autoloadClasses "$TMPD/cnt.kkp" --no-compile 2>"$TMPD/S24.err2" >/dev/null; echo "second=$? warn=$(grep -c "WARNING: class 'TCU'" "$TMPD/S24.err2")"
TCU.new b 7; echo "b=$(b.GetValue) total=$(TCU.GetTotal) a=$(a.GetValue) sink=[$__KK_SINK]"
autoloadClasses "$TMPD/cnth.kkp" --no-compile >/dev/null 2>&1; echo "h-first=$?"
TCH.new c 3
autoloadClasses "$TMPD/cnth.kkp" --no-compile 2>"$TMPD/S24.err3" >/dev/null; echo "h-second=$? warn=$(grep -c "WARNING: class 'TCH'" "$TMPD/S24.err3")"
TCH.new d 4; echo "d=$(d.GetValue) total=$(TCH.GetTotal) c=$(c.GetValue) sink=[$__KK_SINK]"
EOF
kt_test_start "S24 R9 + U36: a .kkp loaded twice through autoload (runtime translation): with \`unit cnt;\` it is a unit — the second load is a silent no-op; without it one WARNING; neither rebuilt, the static totals kept"
case_run S24
if [[ "$OUT" == $'first=0 unit=registered\nsecond=0 warn=0\nb=7 total=2 a=5 sink=[]\nh-first=0\nh-second=0 warn=1\nd=4 total=2 c=3 sink=[]' ]]; then kt_test_pass "ok"; else kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR'"; fi

kt_test_log "139_ClassDeclarationSites.sh completed"
