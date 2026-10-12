#!/bin/bash
# UnitHeaders — the kklass modules are units (kklass/USES_PLAN.md phase U3: §7.4
# header shapes, P7, C13/P9 caches, C19 runtime dirs; found_in_U1a lint,
# found_in_U2b cache prologue + source-unit registration).
#
#   units  kklass.sh, kklass_decl.sh, kklass_pascal.sh, kklass_serializable.sh,
#          kklass_autoload.sh: the two §7.4 header lines (relative, ../kbool.sh)
#          right after the shebang; dependencies through kk.uses (no ../kkore
#          path, no $(cd ...) fork); a direct `source kklass/X.sh` bootstraps
#          kbool.sh and registers X once (P7).
#   tools  kklass_compiler.sh and kklass_kkp.sh run as `bash FILE ...` (a
#          top-level `return` is an error there): no header; kklass_kkp.sh can
#          still be sourced for its functions.
#   .ckk   the cache loads kklass with `kk.uses kklass`; it does NOT register the
#          unit it was compiled from (review R1: a cache holds classes only) —
#          a later kk.uses / source of the unit runs it (helpers, variables,
#          dependencies) and skips the cached classes silently (R1, R4).
#   R5     kklass_decl.sh loaded first loads kklass at its end.
#   R7     a translated .kkp unit loads kklass itself.
#   R2     a failed `kk.uses kklass` leaves kklass_pascal incomplete: the retry
#          runs it again.
# Every scenario runs in a fresh bash against a private copy of the tree whose
# modules count their complete body runs, with an empty private config.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "UnitHeaders" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KBOOL_ROOT="$(cd "$KKLASS_DIR/.." && pwd)"
source "$KBOOL_ROOT/kkore/tests/unit_lint.sh"

TMPD="$(kt_fixture_tmpdir)"
TMPD="$(cd "$TMPD" && pwd)"
mkdir -p "$TMPD/home" "$TMPD/etc"
UNITS=(kklass kklass_decl kklass_pascal kklass_serializable kklass_autoload)
TOOLS=(kklass_compiler kklass_kkp)

# The private tree: kbool.sh, kkore, kklass; every kklass module counts its runs.
T="$TMPD/tree"
mkdir -p "$T/kkore" "$T/kklass" "$T/kcl/kx"
cp "$KBOOL_ROOT/kbool.sh" "$T/"
cp "$KBOOL_ROOT"/kkore/*.sh "$T/kkore/"
cp "$KKLASS_DIR"/kklass*.sh "$T/kklass/"
for u in "${UNITS[@]}"; do
    printf '\n__T141_N_%s=$(( ${__T141_N_%s:-0} + 1 ))\n' "$u" "$u" >> "$T/kklass/$u.sh"
done
# a kcl-shaped unit inside the tree that uses kklass_pascal by NAME
printf '%s\n' '[[ ${__KK_UNITS[@]@a} == A* ]] || source "${BASH_SOURCE%kx.sh}../../kbool.sh" || return' \
    'kk.unit kx || return $__kk_unit_rc' 'kk.uses kklass_pascal || return' \
    'class TKx; public; var a; end; build TKx' 'KX_N=$(( ${KX_N:-0} + 1 ))' > "$T/kcl/kx/kx.sh"
# a user unit outside the tree that uses kklass by NAME
mkdir -p "$TMPD/proj"
printf '%s\n' '[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2' \
    'kk.unit pu || return $__kk_unit_rc' 'kk.uses kklass || return' \
    'defineClass TPu "" property a' 'PU_N=$(( ${PU_N:-0} + 1 ))' > "$TMPD/proj/pu.sh"

COUNTS='for u in kklass kklass_decl kklass_pascal kklass_serializable kklass_autoload; do n=__T141_N_$u; printf "%s=%s " ${u#kklass_} "${!n:-0}"; done; echo'

# case_run NAME — run $TMPD/NAME.sh in a child bash (cwd $TMPD), hermetic; OUT, ERR, RC.
case_run() {
    ( cd "$TMPD" && env -u KBOOL_CONFIG -u KBOOL_HOME -u USERPROFILE -u ProgramData -u PROGRAMDATA \
        -u KKLASS_CKK_DIR -u KK_UNIT_DIR -u VERBOSE_KKLASS \
        HOME="$TMPD/home" __KK_CFG_ETC="$TMPD/etc" \
        T="$T" TMPD="$TMPD" COUNTS="$COUNTS" \
        "$BASH" "$TMPD/$1.sh" >"$TMPD/$1.out" 2>"$TMPD/$1.err" ); RC=$?
    OUT="$(<"$TMPD/$1.out")"; ERR="$(<"$TMPD/$1.err")"
}
check() {   # TITLE WANT-OUT  (stderr must be empty)
    kt_test_start "$1"
    if [[ "$OUT" == "$2" && -z "$ERR" ]]; then
        kt_test_pass "ok"
    else
        kt_test_fail "out='${OUT//$'\n'/|}' want='${2//$'\n'/|}' err='${ERR//$'\n'/|}' rc=$RC"
    fi
}

# ---------------------------------------------------------------------------
# K1-K2: the files
kt_test_start "K1 the units carry the §7.4 relative header right after the shebang; the tools (compiler, kkp) carry none [U3, §7.4]"
bad=""
for u in "${UNITS[@]}"; do
    mapfile -t -n 3 h < "$KKLASS_DIR/$u.sh"
    [[ "${h[0]}" == '#!/bin/bash' \
       && "${h[1]}" == '[[ ${__KK_UNITS[@]@a} == A* ]] || source "${BASH_SOURCE%'"$u"'.sh}../kbool.sh" || return' \
       && "${h[2]}" == "kk.unit $u || return \$__kk_unit_rc" ]] || bad+=" $u"
done
for u in "${TOOLS[@]}"; do
    grep -q '^kk\.unit ' "$KKLASS_DIR/$u.sh" && bad+=" tool:$u"
done
if [[ -z "$bad" ]]; then kt_test_pass "5 units, 2 tools"; else kt_test_fail "wrong:$bad"; fi

kt_test_start "K2 no unit hard-codes a kkore path or forks for its own folder (no '../kkore', no \$(cd ...) / dirname of BASH_SOURCE, no source of a sibling by path); its dependencies come through kk.uses [U3, U26]"
bad="$(cd "$KKLASS_DIR" && grep -n -E '\.\./kkore|\$\(cd |dirname "\$\{?BASH_SOURCE|^source "\$\{?KKLASS' kklass.sh kklass_decl.sh kklass_pascal.sh kklass_serializable.sh kklass_autoload.sh | grep -v -E '^[^:]+:[0-9]+:[[:space:]]*#')"
if [[ -z "$bad" ]]; then kt_test_pass "none"; else kt_test_fail "${bad//$'\n'/ | }"; fi

kt_test_start "K3 lint: no file-scope 'local' / 'declare' without -g in the kklass units (kk.uses runs them inside a function) [U3, C11]"
lint="$(cd "$KKLASS_DIR" && kk_unit_lint kklass.sh kklass_decl.sh kklass_pascal.sh kklass_serializable.sh kklass_autoload.sh 2>&1)"; lrc=$?
if (( lrc == 0 )) && [[ -z "$lint" ]]; then kt_test_pass "clean"; else kt_test_fail "rc=$lrc ${lint//$'\n'/ | }"; fi

# ---------------------------------------------------------------------------
# K4-K8: direct sources bootstrap kbool and load each module once
cat > "$TMPD/K4.sh" <<'EOF'
source "$T/kcl/kx/../../kklass/kklass.sh"; r=$?
[[ ${__KK_UNITS[@]@a} == A* ]] && g=on || g=off
[[ ${__KK_UNITS[kklass]-} -ef $T/kklass/kklass.sh && ${__KK_UNITS[kklass_decl]-} -ef $T/kklass/kklass_decl.sh ]] && f=reg || f=noreg
echo "r=$r guard=$g $f dir=${KKLASS_DIR#$T} home=${KBOOL_HOME#$T}"
source "$T/kklass/kklass.sh"; source "$T/kklass/kklass_decl.sh"; kk.uses kklass kklass_decl; echo "u=$?"
eval "$COUNTS"
EOF
case_run K4
check "K4 a bare shell: source kklass/kklass.sh (a .. spelling) -> kbool bootstrapped, kklass and kklass_decl registered once, KKLASS_DIR the normalised folder; later sources and kk.uses are silent no-ops [U27, C19]" \
    $'r=0 guard=on reg dir=/kklass home=\nu=0\nkklass=1 decl=1 pascal=0 serializable=0 autoload=0 '

cat > "$TMPD/K5.sh" <<'EOF'
source "$T/kklass/kklass.sh"
source "$TMPD/proj/pu.sh"; echo "pu=$? n=$PU_N"
source "$T/kcl/kx/kx.sh"; echo "kx=$? n=$KX_N"
kk.uses kklass kklass_pascal "$T/kklass/kklass.sh"; echo "u=$?"
TPu.new a; TKx.new b; echo "objects=$?"
eval "$COUNTS"
EOF
case_run K5
check "K5 P7: kklass sourced directly by its old path FIRST, then a user unit and a kcl unit that 'kk.uses kklass' / 'kk.uses kklass_pascal' -> kklass loaded once, both units load, silent [P7]" \
    $'pu=0 n=1\nkx=0 n=1\nu=0\nobjects=0\nkklass=1 decl=1 pascal=1 serializable=0 autoload=0 '

cat > "$TMPD/K5b.sh" <<'EOF'
export KBOOL_HOME=$T
source "$TMPD/proj/pu.sh"; echo "pu=$?"
source "$T/kklass/kklass.sh"; echo "direct=$?"
source "$T/kklass/kklass_pascal.sh"; source "$T/kcl/kx/kx.sh"; echo "kx=$?"
eval "$COUNTS"
EOF
case_run K5b
check "K5b the other order: a unit's 'kk.uses kklass' first, then kklass sourced directly by path -> a silent no-op, kklass once [P7]" \
    $'pu=0\ndirect=0\nkx=0\nkklass=1 decl=1 pascal=1 serializable=0 autoload=0 '

cat > "$TMPD/K6.sh" <<'EOF'
source "$T/kklass/kklass_pascal.sh"; echo "p=$? reg=${__KK_UNITS[kklass_pascal]+p}${__KK_UNITS[kklass]+k}${__KK_UNITS[kklass_decl]+d}"
source "$T/kklass/kklass_pascal.sh"; echo "again=$?"
eval "$COUNTS"
EOF
case_run K6
check "K6 a bare shell: source kklass_pascal.sh -> kbool, kklass, kklass_decl, kklass_pascal each loaded once and registered; again: silent [U3]" \
    $'p=0 reg=pkd\nagain=0\nkklass=1 decl=1 pascal=1 serializable=0 autoload=0 '

cat > "$TMPD/K7.sh" <<'EOF'
source "$T/kklass/kklass_serializable.sh"; echo "s=$? reg=${__KK_UNITS[kklass_serializable]+s}${__KK_UNITS[kklass]+k}"
defineSerializableClass TSz "" : string property v; echo "def=$?"
eval "$COUNTS"
EOF
case_run K7
check "K7 a bare shell: kklass_serializable.sh loads kklass itself through kk.uses (it used to refuse to load) [U3]" \
    $'s=0 reg=sk\ndef=0\nkklass=1 decl=1 pascal=0 serializable=1 autoload=0 '

cat > "$TMPD/K8.sh" <<'EOF'
cd "$T/kklass" && source kklass_autoload.sh; echo "a=$? lib=${KKLASS_LIB_DIR#$T} reg=${__KK_UNITS[kklass_autoload]+a}${__KK_UNITS[kklass]+k}"
cd "$TMPD"
printf 'defineClass TAl "" property v\n' > al.kk
KKLASS_CKK_DIR="$TMPD/ckk8" autoloadClasses al.kk --no-compile >/dev/null 2>al8.log; echo "run=$?"
TAl.new o; echo "obj=$?"
eval "$COUNTS"
EOF
case_run K8
check "K8 a no-slash source of kklass_autoload.sh from its folder: kklass loaded through kk.uses, KKLASS_LIB_DIR absolute (its run-time copy, C19); autoloadClasses works after a cd [U3, C4, C19]" \
    $'a=0 lib=/kklass reg=ak\nrun=0\nobj=0\nkklass=1 decl=1 pascal=0 serializable=0 autoload=1 '

cat > "$TMPD/K9.sh" <<'EOF'
set -- one two
source "$T/kklass/kklass.sh"; echo "r=$? args=$#:$1:$2"
EOF
case_run K9
check "K9 a caller's positional parameters do not count as unit arguments (no WARNING) and survive [P8, C10]" 'r=0 args=2:one:two'

# ---------------------------------------------------------------------------
# K10: the tools
cat > "$TMPD/K10.sh" <<'EOF'
"$BASH" "$T/kklass/kklass_kkp.sh" >/dev/null 2>&1; echo "kkp-usage=$?"
"$BASH" "$T/kklass/kklass_compiler.sh" >/dev/null 2>&1; echo "compiler-usage=$?"
printf 'defineClass TCm "" property v method hi "echo hi-\\$v"\n' > cm.kk
"$BASH" "$T/kklass/kklass_compiler.sh" cm.kk cm.ckk.sh >/dev/null 2>compile10.log; echo "compile=$? err=$(wc -c < compile10.log)"
grep -c '^        kk\.uses kklass || return$' cm.ckk.sh
"$BASH" -c 'source "$1"; TCm.new o; o.v = 5; o.hi; echo "kklass=${__KK_UNITS[kklass]+registered}"' _ "$TMPD/cm.ckk.sh"
"$BASH" -c 'source "$1/kklass/kklass_kkp.sh"; declare -F kkp.compile >/dev/null && echo "kkp sourced, kbool=${__KK_UNITS[@]@a}"' _ "$T"
EOF
case_run K10
check "K10 the tools run as 'bash FILE' (usage rc 1, no stray 'return' error), the compiler writes 'kk.uses kklass' into the cache prologue, the cache loads in a bare shell; kklass_kkp.sh can still be sourced on its own (no kbool needed) [U3, C13]" \
    $'kkp-usage=1\ncompiler-usage=1\ncompile=0 err=0\n1\nhi-5\nkklass=registered\nkkp sourced, kbool='

# ---------------------------------------------------------------------------
# K11-K18: caches (review R1, R4), kklass_decl first (R5), translated units (R7),
# a failed dependency (R2)
mkdir -p "$TMPD/cu/.ckk"
# a unit with a helper function, a variable and a dependency besides its class
# (critic ckk/proj/shapes.sh): the cache holds the class only
cat > "$TMPD/cu/shapes.sh" <<'EOF'
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit shapes || return $__kk_unit_rc
kk.uses kklass_serializable || return
SHAPES_SCALE=3
shapes.scale() { echo $(( $1 * SHAPES_SCALE )); }
defineClass TShape "" \
    property w \
    method area 'shapes.scale $(( w * w ))'
SHAPES_N=$(( ${SHAPES_N:-0} + 1 ))
EOF
printf 'defineClass TNu "" property a\n' > "$TMPD/cu/nounit.sh"
STATE='echo "helper=$(type -t shapes.scale) scale=${SHAPES_SCALE-unset} ser=$(type -t addSerializable) n=${SHAPES_N:-0}"'
cat > "$TMPD/K11.sh" <<EOF
KBOOL_HOME="\$T" "\$BASH" "\$T/kklass/kklass_compiler.sh" "\$TMPD/cu/shapes.sh" "\$TMPD/cu/.ckk/shapes.ckk.sh" >/dev/null 2>&1; echo "c1=\$?"
KBOOL_HOME="\$T" "\$BASH" "\$T/kklass/kklass_compiler.sh" "\$TMPD/cu/nounit.sh" "\$TMPD/cu/.ckk/nounit.ckk.sh" >/dev/null 2>&1; echo "c2=\$?"
source "\$T/kbool.sh"
n0=\${#__KK_UNITS[@]}
source "\$TMPD/cu/.ckk/shapes.ckk.sh"; echo "ckk=\$? unit=\${__KK_UNITS[shapes]+reg} ns=\${__KK_NAMESPACES[shapes]+decl} classes=[\${__KK_UNIT_CLASSES[shapes]-}]"
$STATE
kk.uses "\$TMPD/cu/shapes.sh"; echo "uses=\$? done=\${__KK_UNIT_DONE[shapes]-}"
$STATE
TShape.new s; s.w = 2; echo "area=\$(s.area 2>&1)"
source "\$TMPD/cu/shapes.sh"; cd "\$TMPD/cu" && kk.uses shapes; echo "again=\$?"; cd "\$TMPD"
n1=\${#__KK_UNITS[@]}
source "\$TMPD/cu/.ckk/nounit.ckk.sh"; echo "nounit=\$? added=\$(( \${#__KK_UNITS[@]} - n1 ))"
kk.unit --forget shapes; echo "forget=\$?"
source "\$TMPD/cu/shapes.sh"; echo "rebuilt=\$?"; $STATE
TShape.new t; t.w = 3; echo "area=\$(t.area 2>&1)"
EOF
case_run K11
check "K11 R1: a cache does NOT register its unit (nor its namespace); kk.uses of the unit then RUNS it — helper, variable, dependency (kklass_serializable) — and skips the cached class silently: area 12; a cache of a non-unit registers nothing; --forget + source rebuilds silently" \
    $'c1=0\nc2=0\nckk=0 unit= ns= classes=[TShape]\nhelper= scale=unset ser= n=0\nuses=0 done=1\nhelper=function scale=3 ser=function n=1\narea=12\nagain=0\nnounit=0 added=0\nforget=0\nrebuilt=0\nhelper=function scale=3 ser=function n=2\narea=27'

cat > "$TMPD/K12.sh" <<EOF
export KKLASS_CKK_DIR="\$TMPD/cu/.ckk"
source "\$T/kklass/kklass_autoload.sh"
autoloadClasses "\$TMPD/cu/shapes.sh" >/dev/null 2>&1; echo "auto=\$? unit=\${__KK_UNITS[shapes]+reg}"
kk.uses "\$TMPD/cu/shapes.sh"; echo "uses=\$?"
$STATE
TShape.new s; s.w = 2; echo "area=\$(s.area 2>&1)"
EOF
case_run K12
check "K12 R1: the same through autoloadClasses (compiled mode): not registered; kk.uses then runs the unit (helper, variable, dependency), the class silently skipped, area 12" \
    $'auto=0 unit=\nuses=0\nhelper=function scale=3 ser=function n=1\narea=12'

cat > "$TMPD/K12b.sh" <<'EOF'
source "$T/kbool.sh"
kk.uses "$TMPD/cu/shapes.sh"; echo "unit=$? n=$SHAPES_N"
source "$TMPD/cu/.ckk/shapes.ckk.sh" 2>cache12.log; echo "ckk=$? warn=$(grep -c "WARNING: class 'TShape'" cache12.log) dup=$(grep -c Duplicate cache12.log)"
EOF
case_run K12b
check "K12b the unit loaded first, then its cache: the class is not rebuilt (one same-place WARNING, as in U2b) [C13]" \
    $'unit=0 n=1\nckk=0 warn=1 dup=0'

cat > "$TMPD/K13.sh" <<'EOF'
source "$T/kklass/kklass.sh"
defineClass TX "" property a; TX.new shapes; echo "inst=$?"
source "$TMPD/cu/.ckk/shapes.ckk.sh"; echo "ckk=$? unit=${__KK_UNITS[shapes]+reg} ns=${__KK_NAMESPACES[shapes]+decl}"
source "$TMPD/cu/shapes.sh" 2>k13.log; echo "plain=$? refused=$(grep -c "already an instance" k13.log)"
EOF
case_run K13
check "K13 R4: after 'TX.new shapes' a cache of unit shapes registers neither the unit nor the namespace shapes; the unit's own load is refused (rc 2), as without the cache" \
    $'inst=0\nckk=0 unit= ns=\nplain=2 refused=1'

cat > "$TMPD/K14.sh" <<'EOF'
cd "$TMPD/home"
"$BASH" -c 'set -a; source "$1/kbool.sh"; source "$1/kklass/kklass.sh"; set +a
  "$BASH" -c "kk._ckk_begin \"x[\\\$(touch PWN)]\" \"y[\\\$(touch PWN)]\" \"\"; echo b=\$?; kk._ckk_class \"z[\\\$(touch PWN)]\" s; echo c=\$?; kk._ckk_end; echo e=\$?; kk._class_register TZz s \"u[\\\$(touch PWN)]\"; echo r=\$?"' _ "$T" 2>/dev/null
[[ -e PWN ]] && echo PWNED || echo clean
EOF
case_run K14
check "K14 R14: in a set -a child (functions exported, no tables) kk._ckk_begin / _class / _end and kk._class_register with a hostile unit called first evaluate nothing [R14]" \
    $'b=0\nc=1\ne=0\nr=0\nclean'

cat > "$TMPD/K15.sh" <<'EOF'
source "$T/kklass/kklass_decl.sh"; echo "decl=$? core=$(type -t kk._class_verdict)"
declareClass TDf ""; field a; endClass; endImplementation TDf; echo "class=$?"
TDf.new o; echo "obj=$?"
eval "$COUNTS"
"$BASH" -c 'source "$1/kbool.sh"; kk.uses kklass_decl; echo "uses=$? core=$(type -t kk._class_verdict) reg=${__KK_UNITS[kklass]+k}${__KK_UNITS[kklass_decl]+d}"; eval "$2"' _ "$T" "$COUNTS"
EOF
case_run K15
check "K15 R5: kklass_decl.sh loaded first (a direct source; kk.uses kklass_decl) loads kklass at its end: a working DSL, each module once" \
    $'decl=0 core=function\nclass=0\nobj=0\nkklass=1 decl=1 pascal=0 serializable=0 autoload=0 \nuses=0 core=function reg=kd\nkklass=1 decl=1 pascal=0 serializable=0 autoload=0 '

mkdir -p "$TMPD/kp7"
cat > "$TMPD/kp7/Cnt.kkp" <<'EOF'
unit Cnt;
interface
type
  TCnt7 = class
  public
    function Hi;
  end;
implementation
function TCnt7.Hi;
begin
RESULT=hi7
end;
end.
EOF
cat > "$TMPD/K16.sh" <<'EOF'
"$BASH" "$T/kklass/kklass_kkp.sh" "$TMPD/kp7/Cnt.kkp" "$TMPD/kp7/Cnt.sh" >/dev/null 2>&1; echo "tr=$?"
sed -n 4p "$TMPD/kp7/Cnt.sh"
source "$T/kbool.sh"; echo "kklass=${__KK_UNITS[kklass]+loaded}"
kk.uses "$TMPD/kp7/Cnt.sh"; echo "uses=$? kklass=${__KK_UNITS[kklass]+loaded}"
TCnt7.new c; c.Hi; echo "hi=$RESULT"
EOF
case_run K16
check "K16 R7: a translated .kkp unit loads kklass itself (kk.uses kklass after its header): 'kk.uses …/Cnt.sh' with only kbool loaded works" \
    $'tr=0\nkk.uses kklass || return\nkklass=\nuses=0 kklass=loaded\nhi=hi7'

# R2 at the kklass level (critic broken2.sh): kklass.sh failing under kklass_pascal
B2="$TMPD/brk"
rm -rf "$B2"; cp -r "$T" "$B2"
sed -i '4i return 6' "$B2/kklass/kklass.sh"
cat > "$TMPD/K17.sh" <<'EOF'
source "$B2/kklass/kklass_pascal.sh" 2>/dev/null; echo "r1=$?"
source "$B2/kklass/kklass_pascal.sh" 2>/dev/null; echo "r2=$? dsl=$(type -t class) core=$(type -t defineClass)"
sed -i '4d' "$B2/kklass/kklass.sh"
source "$B2/kklass/kklass_pascal.sh"; echo "r3=$? dsl=$(type -t class) core=$(type -t defineClass)"
kk.uses kklass_pascal kklass; echo "uses=$?"
EOF
( cd "$TMPD" && env -u KBOOL_CONFIG -u KBOOL_HOME -u USERPROFILE -u ProgramData -u PROGRAMDATA -u KK_UNIT_DIR -u VERBOSE_KKLASS \
    HOME="$TMPD/home" __KK_CFG_ETC="$TMPD/etc" B2="$B2" "$BASH" "$TMPD/K17.sh" >"$TMPD/K17.out" 2>"$TMPD/K17.err" ); RC=$?
OUT="$(<"$TMPD/K17.out")"; ERR="$(<"$TMPD/K17.err")"
check "K17 R2/U42: kklass.sh returns 6 under kklass_pascal: the pascal source fails, a retry fails again (not rc 0 with nothing loaded); once kklass.sh is repaired the retry runs it again and loads everything" \
    $'r1=6\nr2=6 dsl= core=\nr3=0 dsl=function core=function\nuses=0'

kt_test_log "141_UnitHeaders.sh completed"
