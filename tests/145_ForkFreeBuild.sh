#!/bin/bash
# ForkFreeBuild (kklass round 5 / P14; PLAN.md "# Round 5", findings K1/K1+,
# decision DR18).
#   K1   every class declaration forked: `$(kk.decl._rewrite_inherited …)` per
#        implement, `$(kk.pascal._body …)` + its inner `$(declare -f …)` +
#        `$(kk.pascal._name_bare_inherited …)` per Pascal method, two `$( )`
#        per accessor property, `$(declare -f X.new)` per class — 741 forks
#        (~86 % of 10 s) for a fresh `kk.uses dateutils` on MSYS. The string
#        helpers now return through the caller's `local __kk_btxt`, the one
#        real capture (`declare -f`) is kk._fn_text (two READ descriptors per
#        shell on a deleted scratch file, the write side opened per capture
#        or per build, a random marker per capture), and X.__decl_new_impl
#        is generated from the X.new template (kk._new_define).
#   F10  the fd setup works (and leaves nothing) under an EMPTY PATH.
#   F7, F11-F15  review P14 (critic p14 F1-F6): a caller's reopened numbers
#        are never touched; no write descriptor outlives a build and a child
#        cannot inject a capture; the caller's $RANDOM is not drawn from;
#        functions cannot stand in for rm; failures are bounded (no fd
#        growth); reloading kklass.sh closes the pair.
#   C10  moving kk.decl._rewrite_inherited into the current shell must not
#        clobber the caller's RESULT (kk.decl._parent_of answers in RESULT).
#   F18-F19  round 6 / P17 (E5, DR24): the capture reads back with
#        `read -N 16777216` (block reads) — big texts stay in step; a text
#        over the cap falls back to `$( )`.
# The fork counts run in a child bash under `set -x` with PS4 = $BASHPID: a
# trace line of another pid is a subshell. Files live in $TMPD; kbool loads
# with an empty, private config (HOME, __KK_CFG_ETC, no KBOOL_CONFIG).

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ForkFreeBuild" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KBOOL_ROOT="$(cd "$KKLASS_DIR/.." && pwd)"
source "$KKLASS_DIR/kklass_pascal.sh"

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/kk145.XXXXXX")" && TMPD="$(cd "$TMPD" && pwd)"
mkdir -p "$TMPD/home" "$TMPD/etc" "$TMPD/tmp"
kk145_cleanup() { rm -rf "$TMPD"; }
kt_fixture_cleanup_register kk145_cleanup

# case_run NAME [ENV=VAL...] — run $TMPD/NAME.sh in a child bash (cwd $TMPD,
# TMPDIR=$TMPD/tmp); OUT, ERR, RC.
case_run() {
    local n=$1; shift
    ( cd "$TMPD" && env -u KBOOL_CONFIG -u KBOOL_HOME -u USERPROFILE -u ProgramData -u KKLASS_CKK_DIR \
        HOME="$TMPD/home" __KK_CFG_ETC="$TMPD/etc" TMPDIR="$TMPD/tmp" \
        KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" KBOOL_ROOT="$KBOOL_ROOT" "$@" \
        "$BASH" "$TMPD/$n.sh" >"$TMPD/$n.out" 2>"$TMPD/$n.err" ); RC=$?
    OUT="$(<"$TMPD/$n.out")"; ERR="$(<"$TMPD/$n.err")"
}
# tmp_files — FILES = the names left in $TMPD/tmp (no fork: a glob)
tmp_files() { local -a a; shopt -s nullglob dotglob; a=("$TMPD"/tmp/*); shopt -u nullglob dotglob; FILES="${a[*]##*/}"; }

# ===========================================================================
# F1 — no fork on any declaration path (red before P14: 7 / 11 / 29 / 1 forks)
# ===========================================================================
cat >"$TMPD/f1.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass_pascal || exit 9
f0() { :; }
kk._fn_text f0 v                                     # the one fd setup of this shell
F1S.a() { echo a; }
F1S.b() { echo b; }
exec 9>"$TMPD/f1.trace"; BASH_XTRACEFD=9; PS4='+${BASHPID}|'
echo "MAIN=$BASHPID" >&9
set -x
defineClass F1Def "" property FX method m1 'echo 1' method m2 'inherited m1' constructor 'FX=$1'
declareClass F1Decl F1Def; field FY; property PY read FY write FY; constructor Create; procedure m1; func f1; endClass
implementConstructor F1Decl 'FY=$1'; implement F1Decl.m1 'inherited m1'; implement F1Decl.f1 'RESULT=$FY'; endImplementation F1Decl
class F1Pas F1Decl
  public
    var FZ
    property PZ read FZ write FZ
    constructor Create
    proc m1
    func f2
end
F1Pas.Create() { FZ=$1; inherited; }
F1Pas.m1() { echo pas; inherited; }
F1Pas.f2() { RESULT=$FZ; }
build F1Pas
kk.register_static_methods F1Stat F1S F1Stat a b
set +x
F1Pas.new o 7; o.m1; o.f2; echo "f2=$RESULT"; F1S.a
shopt -s nullglob dotglob; t=("$TMPDIR"/*); echo "tmp=${#t[@]}"
EOF
kt_test_start "F1 K1 defineClass, declarative, Pascal (accessors, ctor, inherited) and kk.register_static_methods fork no subshell"
case_run f1
forks=0; main=""
while IFS= read -r line; do
    case $line in MAIN=*) main=${line#MAIN=}; continue ;; +*) ;; *) continue ;; esac   # not a continuation line
    p=${line%%|*}; p=${p##*+}
    [[ -n $p && $p != *[!0-9]* ]] || continue
    [[ -n $main && $p != "$main" ]] && (( forks++ ))
done <"$TMPD/f1.trace"
want=$'pas\n1\nf2=7\na\ntmp=0'
if [[ $RC == 0 && -n $main && $forks == 0 && "$OUT" == "$want" ]]; then kt_test_pass "0 forks"; else kt_test_fail "rc=$RC forks(lines)=$forks out=[$OUT] err=[${ERR:0:300}]"; fi

# ===========================================================================
# F2 — RESULT survives implement / implementConstructor (critic r5a C10)
# ===========================================================================
kt_test_start "F2 C10 RESULT=keep; implement / implementConstructor (inherited rewrite walks the parent chain) leave RESULT alone"
defineClass F2Base "" method m 'echo base'
declareClass F2Kid F2Base; procedure m; constructor Create; endClass
RESULT=keep;  implement F2Kid.m 'inherited m; echo kid'; r1=$RESULT
RESULT=keep2; implementConstructor F2Kid 'inherited m'; r2=$RESULT
b1=${F2Kid_decl_method_body[m]}; b2=$F2Kid_decl_constructor_body
endImplementation F2Kid
F2Kid.new f2o >/dev/null; o2="$(f2o.m)"
if [[ $r1 == keep && $r2 == keep2 && $b1 == '$this.parent m; echo kid' && $b2 == '$this.parent m' && $o2 == $'base\nkid' ]]; then
    kt_test_pass "kept"
else
    kt_test_fail "RESULT=[$r1][$r2] bodies=[$b1][$b2] out=[$o2]"
fi

# ===========================================================================
# F3..F8 — kk._fn_text NAME VAR
# ===========================================================================
f3a() { echo hi; }
f3b() {
    cat <<'HD'
a $b `c`
HD
    local s=$'x\ny\n\n'
    printf '%s\n' "é ü 日本 $s"
}
f3c() { : "f3c () "; echo "}"; echo '{'; }
function f3d { local -a a=("x y" '' $'\t'); echo "${a[@]}"; }
F3.dot() { echo dot; }
f3-dash() { echo dash; }
f3e() { if true; then echo 1; fi
# a comment line is dropped by declare -f
}
kt_test_start "F3 kk._fn_text NAME VAR == \$(declare -f NAME) (heredoc, unicode, braces in strings, function keyword, dotted/dashed names); into the caller's local"
bad=""
f3_local() { local v=unset; kk._fn_text "$1" v || bad+=" $1:rc$?"; [[ "$v" == "$(declare -f "$1")" ]] || bad+=" $1:text"; }
for fn in f3a f3b f3c f3d F3.dot f3-dash f3e kk._fn_text kk.pascal._body; do f3_local "$fn"; done
v=global; f3_local f3a; [[ $v == global ]] || bad+=" global-clobbered"
if [[ -z "$bad" ]]; then kt_test_pass "equal"; else kt_test_fail "$bad"; fi

kt_test_start "F4 kk._fn_text: not a function -> rc 1, VAR empty; a bad VAR (empty, 1x, a-b, its own __kk_ft_t, non-ASCII) -> rc 2, nothing assigned"
v=old; kk._fn_text f4_no_such v; r1=$?; v1=$v
r2=""; for n in "" 1x a-b __kk_ft_t "é"; do kk._fn_text f3a "$n"; r2+=$?; done
if [[ $r1 == 1 && -z $v1 && $r2 == 22222 && $v == "" ]]; then kt_test_pass "refused"; else kt_test_fail "r1=$r1 v=[$v1] r2=$r2"; fi

kt_test_start "F5 kk._fn_text: >256 KB captured reopens the pair (texts stay equal); no kbool_fntext file is left in TMPDIR at any time"
cat >"$TMPD/f5.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass || exit 9
body=""; for ((i=0; i<6000; i++)); do body+="echo line_$i;"$'\n'; done
eval "big() { $body }"
want="$(declare -f big)"; bad=""; ns=""
for ((k=0; k<6; k++)); do
    kk._fn_text big v || bad+=" rc$k"
    [[ "$v" == "$want" ]] || bad+=" text$k"
    ns+=" ${__kk_ft[3]}"
    shopt -s nullglob dotglob; t=("$TMPDIR"/*); shopt -u nullglob dotglob
    (( ${#t[@]} == 0 )) || bad+=" file$k:${t[*]}"
done
r=0; p=0; for n in $ns; do (( n < p )) && r=1; p=$n; done   # the count restarted = reopened
echo "len=${#want} bad=[$bad] reopened=$r setups=${__kk_ft[5]} ns=[$ns]"
EOF
case_run f5
tmp_files
if [[ $RC == 0 && "$OUT" == *"bad=[] reopened=1 setups=2 "* && -z "$FILES" ]]; then kt_test_pass "reopened"; else kt_test_fail "rc=$RC out=[$OUT] left=[$FILES] err=[${ERR:0:300}]"; fi

kt_test_start "F6 kk._fn_text in a subshell and in \$( ) opens its own pair; the parent's pair stays in step"
kk._fn_text f3a v; r0=${__kk_ft[1]}; p0=${__kk_ft[0]}
s1="$( kk._fn_text f3b v; [[ "$v" == "$(declare -f f3b)" ]] && echo ok; [[ ${__kk_ft[0]} != "$p0" && -n ${__kk_ft[1]} ]] && echo own )"
( kk._fn_text f3c v; [[ "$v" == "$(declare -f f3c)" ]] ) && s2=ok || s2=bad
kk._fn_text f3d v; [[ "$v" == "$(declare -f f3d)" ]] && s3=ok || s3=bad
if [[ $s1 == $'ok\nown' && $s2 == ok && $s3 == ok && ${__kk_ft[1]} == "$r0" && ${__kk_ft[0]} == "$p0" ]]; then kt_test_pass "in step"; else kt_test_fail "sub=[$s1] [$s2] parent=[$s3] r=$r0/${__kk_ft[1]}"; fi

kt_test_start "F7 review F1: the caller reopened the numbers (R for writing its own file, R2 for its own input) -> nothing written into the caller's file, the caller's read still gets its first line, the text is right, a new pair"
cat >"$TMPD/f7.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass_pascal || exit 9
mkp() { eval "class $1
  public
    proc m1
  end
  $1.m1() { echo m1-of-$1; }
  build $1"; }
mkp F7A
R=${__kk_ft[1]} R2=${__kk_ft[2]}
printf 'caller-line-1\ncaller-line-2\n' >"$TMPD/f7in.txt"; : >"$TMPD/f7out.txt"
eval "exec $R>>\"\$TMPD/f7out.txt\""
eval "exec $R2<\"\$TMPD/f7in.txt\""
mkp F7B
F7B.new o; o.m1
IFS= read -r line <&"$R2" || line=NOTHING
echo "out=[$(<"$TMPD/f7out.txt")] read=[$line] newpair=$([[ -n ${__kk_ft[1]} && ${__kk_ft[1]} != "$R" && ${__kk_ft[1]} != "$R2" ]] && echo yes)"
# the HELD write side (inside a hold, as in a build) reopened by the caller
f7g() { echo g; }
kk._fn_text_hold; kk._fn_text f7g v; HW=${__kk_ft[6]}
: >"$TMPD/f7held.txt"; eval "exec $HW>>\"\$TMPD/f7held.txt\""
kk._fn_text f7g v; [[ $v == "$(declare -f f7g)" ]] && t=ok || t=bad
kk._fn_text_release
{ echo mine >&"$HW"; } 2>/dev/null
echo "held=[$(<"$TMPD/f7held.txt")] $t"
EOF
case_run f7
if [[ $RC == 0 && "$OUT" == $'m1-of-F7B\nout=[] read=[caller-line-1] newpair=yes\nheld=[mine] ok' ]]; then kt_test_pass "caller untouched"; else kt_test_fail "rc=$RC out=[$OUT] err=[${ERR:0:300}]"; fi

kt_test_start "F8 R14: __kk_ft* inherited from the environment (pid = this process, numbers 0/1) are ignored — no function text reaches stdout"
cat >"$TMPD/f8.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass_pascal || exit 9
class F8C
  public
    proc go
end
F8C.go() { echo went; }
build F8C
F8C.new o; o.go
EOF
cat >"$TMPD/f8x.sh" <<'EOF'
exec env __kk_ft="$$" __kk_ft_pid=$$ __kk_ft_w=1 __kk_ft_r=0 __kk_ft_n=0 "$BASH" "$TMPD/f8.sh"
EOF
case_run f8x
if [[ $RC == 0 && "$OUT" == went ]]; then kt_test_pass "ignored"; else kt_test_fail "rc=$RC out=[${OUT:0:300}] err=[${ERR:0:300}]"; fi

kt_test_start "F9 kk._fn_text under set -Eeuo pipefail with an ERR trap: no ERR, no abort (first open, held and per-capture write, reopen)"
cat >"$TMPD/f9.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass || exit 9
set -Eeuo pipefail; errs=0; trap 'errs=$((errs+1))' ERR
g() { echo g; }
kk._fn_text g v; a=$v
kk._fn_text_hold; kk._fn_text g v; b=$v; kk._fn_text_release
__kk_ft[3]=999999; kk._fn_text g v; c=$v
trap - ERR
[[ "$a" == "$(declare -f g)" && "$b" == "$a" && "$c" == "$a" ]] && echo "ok errs=$errs"
EOF
case_run f9
if [[ $RC == 0 && "$OUT" == "ok errs=0" ]]; then kt_test_pass "clean"; else kt_test_fail "rc=$RC out=[$OUT] err=[${ERR:0:300}]"; fi

kt_test_start "F10 kk._fn_text with an EMPTY PATH (kcl tpath's test loads that way): the pair still opens (the system rm by absolute path), the text is right, no kbool_fntext file is left"
cat >"$TMPD/f10.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass_pascal || exit 9
g() { echo g; }
want="$(declare -f g)"
PATH=""
kk._fn_text g v; [[ "$v" == "$want" ]] && t=ok || t=bad
[[ -n ${__kk_ft[1]-} ]] && p=pair || p=nopair
shopt -s nullglob dotglob; f=("$TMPDIR"/*); shopt -u nullglob dotglob
echo "$t $p left=${#f[@]}"
EOF
case_run f10
tmp_files
if [[ $RC == 0 && "$OUT" == "ok pair left=0" && -z "$FILES" && -z "$ERR" ]]; then kt_test_pass "no leftover"; else kt_test_fail "rc=$RC out=[$OUT] left=[$FILES] err=[${ERR:0:300}]"; fi

kt_test_start "F11 review F2: after a build no WRITE descriptor on the scratch file is left (the two kept ones refuse writes); a child appending junk, a whole fake capture or a forged one through the inherited descriptor injects nothing"
cat >"$TMPD/f11.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass_pascal || exit 9
mkp() { eval "class $1
  public
    proc m1
  end
  $1.m1() { echo m1-of-$1; }
  build $1"; }
mkp F11A
R=${__kk_ft[1]} R2=${__kk_ft[2]}
ro=yes; { printf x >&"$R"; } 2>/dev/null && ro=no; { printf x >&"$R2"; } 2>/dev/null && ro=no
echo "held=[${__kk_ft[6]}] readonly=$ro"
# (each child writes into an OPEN pair: the capture before it (re)opens one;
# each injection is one failure, the third switches the pair off)
g() { :; }
kk._fn_text g v; "$BASH" -c "printf 'garbage\n' >>/dev/fd/${__kk_ft[1]}"
mkp F11B; F11B.new o1; o1.m1
kk._fn_text g v; "$BASH" -c "printf '%s\n' 'F11C.m1 () ' '{ ' '    echo INJECTED' '}' >>/dev/fd/${__kk_ft[1]}"
mkp F11C; F11C.new o2; o2.m1
kk._fn_text g v; "$BASH" -c "printf '%s\n' '#kk_ft.1.2' 'F11D.m1 () ' '{ ' '    echo INJECTED' '}' '#kk_ft.1.2' >>/dev/fd/${__kk_ft[1]}"
mkp F11D; F11D.new o3; o3.m1
EOF
case_run f11
if [[ $RC == 0 && "$OUT" == $'held=[] readonly=yes\nm1-of-F11B\nm1-of-F11C\nm1-of-F11D' ]]; then kt_test_pass "nothing injected"; else kt_test_fail "rc=$RC out=[$OUT] err=[${ERR:0:300}]"; fi

kt_test_start "F12 review F4: opening the pair draws nothing from the caller's \$RANDOM (a seeded sequence is the same with and without a build)"
cat >"$TMPD/f12.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass_pascal || exit 9
RANDOM=99; ref="$RANDOM $RANDOM"
RANDOM=99
class F12C
  public
    proc m1
end
F12C.m1() { echo m1; }
build F12C
got="$RANDOM $RANDOM"
[[ -n ${__kk_ft[1]} && $got == "$ref" ]] && echo same || echo "differs ref=$ref got=$got"
EOF
case_run f12
if [[ $RC == 0 && "$OUT" == same ]]; then kt_test_pass "same"; else kt_test_fail "rc=$RC out=[$OUT] err=[${ERR:0:300}]"; fi

kt_test_start "F13 review F5: functions named rm or /usr/bin/rm do not stand in for the system rm (command): the pair opens, no file is left"
cat >"$TMPD/f13.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass || exit 9
/usr/bin/rm() { return 1; }; /bin/rm() { return 1; }; rm() { return 1; }
g() { echo g; }
kk._fn_text g v
shopt -s nullglob dotglob; f=("$TMPDIR"/*); shopt -u nullglob dotglob
[[ "$v" == "$(declare -f g)" && -n ${__kk_ft[1]} ]] && echo "ok left=${#f[@]}"
EOF
case_run f13
tmp_files
if [[ $RC == 0 && "$OUT" == "ok left=0" && -z "$FILES" ]]; then kt_test_pass "system rm"; else kt_test_fail "rc=$RC out=[$OUT] left=[$FILES] err=[${ERR:0:300}]"; fi

kt_test_start "F14 review F6: a DEBUG trap capturing inside every capture: all texts right, the pair switches itself off after 3 failures, no descriptor leaks"
cat >"$TMPD/f14.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass || exit 9
f_a() { echo a; }; f_b() { echo b; }
kk._fn_text f_a t; ref=$(declare -f f_a); refb=$(declare -f f_b)
p0=(/proc/$BASHPID/fd/*); n0=${#p0[@]}               # open descriptors, the pair included
bad=0
tr() { local x; kk._fn_text f_b x; [[ $x == "$refb" ]] || bad=$((bad+1)); }
set -T; trap 'tr' DEBUG
for i in 1 2 3 4 5 6 7 8 9 10; do kk._fn_text f_a t; [[ $t == "$ref" ]] || bad=$((bad+1)); done
trap - DEBUG; set +T
p1=(/proc/$BASHPID/fd/*); n1=${#p1[@]}
echo "bad=$bad off=$(( __kk_ft[4] >= 3 )) setups<=3=$(( __kk_ft[5] <= 3 )) fd=$( (( n1 <= n0 )) && echo bounded || echo "$n0->$n1")"
EOF
case_run f14
if [[ $RC == 0 && "$OUT" == "bad=0 off=1 setups<=3=1 fd=bounded" && -z "$ERR" ]]; then kt_test_pass "bounded"; else kt_test_fail "rc=$RC out=[$OUT] err=[${ERR:0:300}]"; fi

kt_test_start "F15 review F6: loading kklass.sh again closes this shell's pair (kk.unit --forget kklass + source)"
cat >"$TMPD/f15.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass || exit 9
g() { echo g; }
kk._fn_text g v; R=${__kk_ft[1]} R2=${__kk_ft[2]}
kk.unit --forget kklass >/dev/null 2>&1
source "$KBOOL_ROOT/kklass/kklass.sh" || echo "reload rc=$?"
{ : <&"$R"; } 2>/dev/null && a=open || a=closed
{ : <&"$R2"; } 2>/dev/null && b=open || b=closed
echo "$a $b state=[${__kk_ft[*]-}]"
EOF
case_run f15
if [[ $RC == 0 && "$OUT" == "closed closed state=[]" ]]; then kt_test_pass "closed"; else kt_test_fail "rc=$RC out=[$OUT] err=[${ERR:0:300}]"; fi

kt_test_start "F16 review P14 round 2: a writer that saw the in-flight marker M appends 'NAME () {forged} M' between the opening marker and the text -> the marker occurs 3 times, the capture is refused (\$( ) fallback), nothing injected; in and outside a build"
cat >"$TMPD/f16.sh" <<'EOF2'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass_pascal || exit 9
g() { echo real-g; }
kk._fn_text g v                                      # the pair is open
# deterministic stand-in for the racing writer: a DEBUG trap (functrace) that
# runs right before kk._fn_text's `declare -f`, reads the in-flight marker and
# appends a forged function text + that marker through a reopened descriptor
fired=0
forge() {
    [[ $fired == 0 && ${FUNCNAME[1]-} == kk._fn_text && $BASH_COMMAND == "declare -f -- "* && -n ${__kk_ft_r-} ]] || return 0
    fired=1
    printf '%s\n' "$1 () " '{ ' '    echo INJECTED' '}' "$__kk_ft_m" >>"/proc/$BASHPID/fd/$__kk_ft_r" 2>/dev/null \
        || printf '%s\n' "$1 () " '{ ' '    echo INJECTED' '}' "$__kk_ft_m" >>"/dev/fd/$__kk_ft_r"
}
set -T; trap 'forge g' DEBUG
kk._fn_text g v
trap - DEBUG; set +T
[[ $v == "$(declare -f g)" ]] && a=ok || a="bad[$v]"
# inside a build (held write side)
class F16C
  public
    proc m1
end
F16C.m1() { echo real-m1; }
fired=0
set -T; trap 'forge F16C.m1' DEBUG
build F16C
trap - DEBUG; set +T
F16C.new o; b=$(o.m1)
echo "$a fired=$fired m1=[$b]"
EOF2
case_run f16
if [[ $RC == 0 && "$OUT" == "ok fired=1 m1=[real-m1]" ]]; then kt_test_pass "refused"; else kt_test_fail "rc=$RC out=[$OUT] err=[${ERR:0:300}]"; fi

kt_test_start "F17 review P14 round 2: the scratch file is created under umask 077 and the caller's umask is restored (0027 and 0000 kept); its probe file is removed too"
cat >"$TMPD/f17.sh" <<'EOF2'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass || exit 9
g() { echo g; }
out=""
for m in 0027 0000; do
    umask "$m"; __kk_ft[4]=0; kk._fn_text_close; kk._fn_text g v
    [[ $v == "$(declare -f g)" && -n ${__kk_ft[1]} ]] || out+=" text$m"
    out+=" $(umask)"
done
shopt -s nullglob dotglob; f=("$TMPDIR"/*); shopt -u nullglob dotglob
echo "${out# } left=${#f[@]}"
EOF2
case_run f17
tmp_files
if [[ $RC == 0 && "$OUT" == "0027 0000 left=0" && -z "$FILES" ]]; then kt_test_pass "kept"; else kt_test_fail "rc=$RC out=[$OUT] left=[$FILES] err=[${ERR:0:300}]"; fi

# ===========================================================================
# F18-F19 — round 6 / P17 (E5, DR24): the capture reads back with
# `read -N 16777216` (block reads; `read -d ''` read one byte per read() on
# MSYS). Every acceptance check stays; a text over the cap falls back.
# ===========================================================================
kt_test_start "F18 P17: kk._fn_text reads back with read -N; texts over 64 KB (one long line, many lines) round-trip in step (no out-of-step capture, the pair stays open), also after the 256 KB reopen"
cat >"$TMPD/f18.sh" <<'EOF2'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass || exit 9
out=""
[[ $(declare -f kk._fn_text) == *'read -r -N 16777216 -u "$__kk_ft_r" __kk_ft_t'* ]] || out+=" not-N"
printf -v line '%070000d' 7
eval "f_long() { echo $line; }"
body=""; for ((i = 0; i < 2500; i++)); do body+="echo line-$i 'x\\y' \"\$HOME\""$'\n'; done
eval "f_many() { $body
}"
for n in f_long f_many f_long f_many f_long f_many; do
    kk._fn_text "$n" v || out+=" rc-$n"
    [[ $v == "$(declare -f "$n")" ]] || out+=" text-$n"
done
(( ${#v} > 65536 )) || out+=" short"
echo "${out# }${out:+ }fails=${__kk_ft[4]} setups=${__kk_ft[5]} open=$([[ -n ${__kk_ft[1]} ]] && echo y || echo n)"
EOF2
case_run f18
if [[ $RC == 0 && "$OUT" =~ ^fails=0\ setups=[2-9]\ open=y$ ]]; then kt_test_pass "in step"; else kt_test_fail "rc=$RC out=[$OUT] err=[${ERR:0:300}]"; fi

kt_test_start "F19 P17: a text longer than the read -N cap (16777216 characters) is not taken half-read: one out-of-step capture, the \$( ) fallback gives the whole text (rc 0); the next capture is in step again"
cat >"$TMPD/f19.sh" <<'EOF2'
source "$KBOOL_ROOT/kbool.sh" && kk.uses kklass || exit 9
g() { echo g; }
kk._fn_text g v
printf -v line '%065536d' 0; body=""
for ((i = 0; i < 257; i++)); do body+="echo $line"$'\n'; done   # 257 long lines: > 16777216
eval "f_huge() { $body
}"; unset body line
out=""
kk._fn_text f_huge v || out+=" rc"
ref=$(declare -f f_huge)
(( ${#ref} > 16777216 )) || out+=" small"
[[ $v == "$ref" ]] || out+=" text(${#v}/${#ref})"
unset v ref
f1=${__kk_ft[4]}
kk._fn_text g v; [[ $v == "$(declare -f g)" ]] || out+=" text-g"
echo "${out# }${out:+ }fails=$f1/${__kk_ft[4]} open=$([[ -n ${__kk_ft[1]} ]] && echo y || echo n)"
EOF2
case_run f19
tmp_files
if [[ $RC == 0 && "$OUT" == "fails=1/1 open=y" && -z "$FILES" ]]; then kt_test_pass "fell back"; else kt_test_fail "rc=$RC out=[$OUT] left=[$FILES] err=[${ERR:0:300}]"; fi

cd / || :
kt_test_log "145_ForkFreeBuild.sh completed"
