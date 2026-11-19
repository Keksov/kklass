#!/usr/bin/env bash
# NoFields (K-8, fv D21 §6 "K" / §7 Q4, owner 2026-11-19) — field-free
# method bodies.
#
# At every method entry kklass binds every field of the class (and its static
# properties and `state`) as a local nameref (one `local -n` line in the body
# function, kk._body_fn): ~2.8 us per name, paid even by a one-line body that
# only delegates with "$this". A body declared `nofields` is built WITHOUT
# that line; at build kklass refuses (one `Error:` line naming class, method
# and name) a nofields body whose text uses a bound name as a whole word.
# Spellings: Pascal `nofields proc X` / `nofields override proc X` /
# `override nofields proc X` / `nofields destructor D`; declarative
# `nofields` on its own line before `procedure` / `func`; defineClass and
# kk._build_class_runtime token `nofields method|procedure|function NAME
# BODY`; defineMethod / defineProcedure / defineFunction 4th argument
# `nofields`; .kkp `procedure X; nofields;`. The stored text starts with the
# marker line `# kk.nofields` (__KK_NOFIELDS_MARK); caches keep it (format
# unchanged, 7).
#
# Red on the kklass before K-8: `nofields` is not a verb / token (the
# declarations fail), so no class here builds and every behaviour check
# fails.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "NoFields" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KBOOL_ROOT="$(cd "$KKLASS_DIR/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_pascal.sh"

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/kk153.XXXXXX")" && TMPD="$(cd "$TMPD" && pwd)"
mkdir -p "$TMPD/home" "$TMPD/etc"
kk153_cleanup() { rm -rf "$TMPD"; }
kt_fixture_cleanup_register kk153_cleanup
ERRF="$TMPD/err"

check() {   # NAME WANT GOT
    if [[ "$3" == "$2" ]]; then kt_test_pass "$1"; else kt_test_fail "$1: got '${3//$'\n'/|}' want '${2//$'\n'/|}'"; fi
}
# case_run NAME — run $TMPD/NAME.sh in a child bash (cwd $TMPD, no user
# config); OUT, ERR, RC.
case_run() {
    ( cd "$TMPD" && env -u KBOOL_CONFIG -u KBOOL_HOME -u USERPROFILE -u ProgramData -u KKLASS_CKK_DIR \
        HOME="$TMPD/home" __KK_CFG_ETC="$TMPD/etc" \
        KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" KBOOL_ROOT="$KBOOL_ROOT" \
        "$BASH" "$TMPD/$1.sh" >"$TMPD/$1.out" 2>"$TMPD/$1.err" ); RC=$?
    OUT="$(<"$TMPD/$1.out")"; ERR="$(<"$TMPD/$1.err")"
}
# binds FN -> "binds" when FN's text has the bind line, else "none"
binds() {
    local t
    t=$(declare -f "$1") || { echo "missing"; return; }
    [[ $t == *'local -n +x "${__kk_binds[@]//@/$this}"'* ]] && echo binds || echo none
}

# helpers the thin bodies delegate to (plain functions, as fv.*'s)
nf_echo() { echo "h:$1:${*:2}"; }
nf_set()  { RESULT="set:$1:${*:2}"; }
nf_fail() { RESULT=failed; return "${2:-3}"; }
nf_peek() { echo "peek:${Name-unset}"; }           # reads a field through dynamic scope (the hole)

# ===========================================================================
# §1 Pascal DSL: the binds are absent, the behaviour is a normal body's
# ===========================================================================
class TNfBase
    public
        var Name
        var Count
        static var Total
        proc Plain
        nofields proc Thin
        nofields func ThinF
        nofields func ThinFail
        nofields proc ThinProcFail
        nofields func ThinReturn0
        nofields proc CallsPlain
        nofields proc Peek
        func Describe
        nofields destructor Done
end
TNfBase.Plain()        { echo "plain:$this:$Name:$Count"; }
TNfBase.Thin()         { nf_echo "$this" "$@" || return; }
TNfBase.ThinF()        { nf_set "$this" "$@"; }
TNfBase.ThinFail()     { nf_fail "$this" 4; }
TNfBase.ThinProcFail() { nf_fail "$this" 5; }
TNfBase.ThinReturn0()  { RESULT="r0:$this"; return 0; }
TNfBase.CallsPlain()   { $this.Plain; }
TNfBase.Peek()         { nf_peek; }
TNfBase.Describe()     { RESULT="base($Name)"; }
TNfBase.Done()         { NF_DONE+="done:$this "; }
build TNfBase; NF_RC_BUILD=$?

class TNfMid : TNfBase
    public
        var Extra
        nofields override func Describe
end
TNfMid.Describe() { inherited; RESULT="mid<$RESULT>"; }
build TNfMid; NF_RC_BUILD+=" $?"

class TNfLeaf : TNfMid
    public
        override func Describe
        override nofields proc Thin
end
TNfLeaf.Describe() { inherited; RESULT="leaf[$Extra]{$RESULT}"; }
TNfLeaf.Thin()     { nf_echo "leaf-$this" "$@"; inherited Thin "$@"; }
build TNfLeaf; NF_RC_BUILD+=" $?"

kt_test_start "1.1 the three classes build (rc 0 each)"
check "1.1" "0 0 0" "$NF_RC_BUILD"

kt_test_start "1.2 a nofields body function has no bind line; a normal one keeps it (introspected with declare -f)"
check "1.2" "none none none none none binds binds none binds none" \
    "$(binds __kkm.TNfBase.Thin) $(binds __kkm.TNfBase.ThinF) $(binds __kkm.TNfBase.Done) $(binds __kkm.TNfMid.Describe) $(binds __kkm.TNfLeaf.Thin) $(binds __kkm.TNfBase.Plain) $(binds __kkm.TNfBase.Describe) $(binds __kkm.TNfBase.CallsPlain) $(binds __kkm.TNfLeaf.Describe) $(binds __kkm.TNfBase.Peek)"

kt_test_start "1.3 the stored text starts with the marker line; the func marker stays at the end"
m=0
[[ $TNfBase_method_body_Thin == "$__KK_NOFIELDS_MARK"* ]] && (( ++m ))
[[ $TNfBase_method_body_ThinF == "$__KK_NOFIELDS_MARK"*"$__KK_FUNC_MARK" ]] && (( ++m ))
[[ $TNfLeaf_method_body_ThinF == "$__KK_NOFIELDS_MARK"* ]] && (( ++m ))     # the subclass's copy
[[ $TNfBase_method_body_Plain != "$__KK_NOFIELDS_MARK"* ]] && (( ++m ))
check "1.3" "4" "$m"

TNfBase.new nb Ann 1
nb.Name = Ann; nb.Count = 2
kt_test_start "1.4 \$this and the arguments; a proc keeps the caller's RESULT; rc of a delegating proc"
RESULT=keep; out=$(nb.Thin a "b c"); rc=$?
RESULT=keep; nb.Thin x >/dev/null
check "1.4" "h:nb:a b c|0|keep" "$out|$rc|$RESULT"

kt_test_start "1.5 a nofields func answers by the func rule: RESULT on rc 0, printed once in \$( ); a failing one keeps the caller's RESULT; return 0 answers"
RESULT=keep; nb.ThinF 1 2; a="$?:$RESULT"
c=$(nb.ThinF 3)
RESULT=keep; nb.ThinFail; b="$?:$RESULT"
d=$(nb.ThinFail)
RESULT=keep; nb.ThinReturn0; e="$?:$RESULT"
RESULT=keep; nb.ThinProcFail; f="$?:$RESULT"
check "1.5" "0:set:nb:1 2|[set:nb:3]|4:keep|[]|0:r0:nb|5:keep" "$a|[$c]|$b|[$d]|$e|$f"

kt_test_start "1.6 a nofields body calling \$this.Plain: the normal callee binds its own fields"
check "1.6" "plain:nb:Ann:2" "$(nb.CallsPlain)"

kt_test_start "1.7 .call and \$( ) of a nofields method; the static property is untouched"
TNfBase.Total = 7
check "1.7" "h:nb:z|7" "$(nb.call Thin z)|$(TNfBase.Total)"

TNfLeaf.new nl
nl.Name = Lee; nl.Extra = X
kt_test_start "1.8 inherited chains mixing nofields and normal bodies: leaf (normal) -> mid (nofields) -> base (normal); leaf (nofields) -> base (nofields)"
RESULT=keep; nl.Describe; a=$RESULT
check "1.8" "leaf[X]{mid<base(Lee)>}|h:leaf-nl:q|h:nl:q" "$a|$(nl.Thin q | tr '\n' '|' | sed 's/|$//')"

kt_test_start "1.9 the documented hole: a helper reading a field through dynamic scope sees nothing under a nofields body called from outside"
check "1.9" "peek:unset" "$(nb.Peek)"

kt_test_start "1.10 a nofields destructor runs on .delete"
NF_DONE=""; TNfBase.new nd; nd.delete
check "1.10" "done:nd " "$NF_DONE"

# ===========================================================================
# §2 shell state: set -eu, nocasematch, odd IFS (child shells)
# ===========================================================================
cat > "$TMPD/S1.sh" <<'EOF'
set -eu
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass_pascal
hh() { echo "hh:$1:$#"; RESULT="r:$1"; }
class TS
    public
        var Name
        nofields proc P
        nofields func F
        nofields proc Fail
end
TS.P()    { hh "$this" "$@" || return; }
TS.F()    { hh "$this" "$@" >/dev/null; }
TS.Fail() { false; }
build TS
TS.new s
s.P 1 2
RESULT=x; s.F a; echo "F:$RESULT"
shopt -s nocasematch; s.P nc; shopt -u nocasematch
IFS=: ; s.P "a b" c; IFS=$' \t\n'
if s.Fail; then echo "Fail:0"; else echo "Fail:$?"; fi
s.Fail
echo "not reached"
EOF
kt_test_start "2.1 under set -eu, nocasematch and IFS=: a nofields body runs as a normal one; a failing one stops set -e"
case_run S1
check "2.1" "hh:s:3|F:r:s|hh:s:2|hh:s:3|Fail:1|rc=1" "${OUT//$'\n'/|}|rc=$RC"

# ===========================================================================
# §3 the build-time check: every reference form refuses, one Error line
# ===========================================================================
# nf_refuse NAME BODY -> "rc=N|E" (class TNfR_NAME : TNfBase, nofields proc M)
nf_refuse() {
    local c="TNfR_$1" rc
    eval "class $c : TNfBase
    public
        var Own
        nofields proc M
end"
    eval "$c.M() {
$2
}"
    build "$c" 2>"$ERRF"; rc=$?
    unset -f "$c.M"
    echo "rc=$rc|$(grep -c '^Error: nofields method' "$ERRF")|$(<"$ERRF")"
}
nf_form() {   # LABEL BODY FIELDWORD
    local r
    r=$(nf_refuse "$1" "$2")
    if [[ $r == "rc=1|1|"*"'TNfR_$1.M'"*"$3"*"of class 'TNfR_$1'"* ]] && ! declare -F "TNfR_$1.new" >/dev/null; then
        kt_test_pass "$1"
    else
        kt_test_fail "$1: $r"
    fi
}
kt_test_start "3.1 \$Name (an inherited field)"
nf_form dollar 'echo "$Name"' "the field 'Name'"
kt_test_start "3.2 \${Name:-x}"
nf_form brace 'echo "${Name:-x}"' "the field 'Name'"
kt_test_start "3.3 Own=1 (an own field)"
nf_form assign 'Own=1' "the field 'Own'"
kt_test_start "3.4 Count[1]=x"
nf_form subscript 'Count[1]=x' "the field 'Count'"
kt_test_start "3.5 (( Count + 1 ))"
nf_form arith '(( Count + 1 ))' "the field 'Count'"
kt_test_start "3.6 local Name"
nf_form local 'local Name' "the field 'Name'"
kt_test_start "3.7 unset Own"
nf_form unset 'unset Own' "the field 'Own'"
kt_test_start "3.8 state[Name] (the instance data)"
nf_form state 'echo "${state[x]}"' "the instance data 'state'"
kt_test_start "3.9 \$Total (a static property)"
nf_form static 'echo "$Total"' "the static property 'Total'"
kt_test_start "3.10 a quoted string: \"Name\" (a false positive, documented)"
nf_form string 'echo "the Name is"' "the field 'Name'"
kt_test_start "3.11 \${#Count[@]} / \${!Own}"
nf_form length 'echo "${#Count[@]}"' "the field 'Count'"

kt_test_start "3.12 NOT refused: \$this.Name, fv.x.Name, NameX, xName, _Name, a local of another name"
class TNfOk : TNfBase
    public
        nofields proc M
end
TNfOk.M() { local NameX=1 xName=2 _Name=3; $this.Name >/dev/null; nf.x.Name 2>/dev/null; echo "$NameX$xName$_Name"; }
build TNfOk 2>"$ERRF"; rc=$?
TNfOk.new nok
check "3.12" "rc=0||123" "rc=$rc|$(<"$ERRF")|$(nok.M)"

kt_test_start "3.13 a refused REbuild leaves the built class as it was"
class TNfRe
    public
        var Name
        nofields proc M
end
TNfRe.M() { echo ok1; }
build TNfRe
kk.class --forget TNfRe 2>/dev/null
class TNfRe
    public
        var Name
        nofields proc M
end
TNfRe.M() { echo "$Name"; }
build TNfRe 2>"$ERRF"; rc=$?
unset -f TNfRe.M
TNfRe.new nre
check "3.13" "rc=1|ok1|none" "rc=$rc|$(nre.M)|$(binds __kkm.TNfRe.M)"

kt_test_start "3.14 nofields refused on a static method, an abstract method, a constructor and a field (the class fails, one message)"
r=""
{ class TNfX1
    public
        nofields static proc S
  end; } 2>"$ERRF"
r+="$?:$(grep -c "static method 'TNfX1.S'" "$ERRF")"
{ class TNfX2
    public
        nofields abstract proc A
  end; } 2>"$ERRF"
r+=" $?:$(grep -c "abstract method 'TNfX2.A'" "$ERRF")"
{ class TNfX3
    public
        nofields constructor Create
  end; } 2>"$ERRF"
r+=" $?:$(grep -c 'Modifiers are not supported for constructors' "$ERRF")"
{ class TNfX4
    public
        nofields var V
  end; } 2>"$ERRF"
r+=" $?:$(grep -c 'Modifiers are not supported for fields' "$ERRF")"
check "3.14" "1:1 1:1 1:1 1:1" "$r"

# ===========================================================================
# §4 the other declaration styles
# ===========================================================================
kt_test_start "4.1 declarative: nofields on its own line before procedure / func (with override); a field name in a COMMENT refuses (a raw text keeps its comments)"
declareClass TNfD ""
    field Name
    nofields
    procedure Thin
    nofields
    func ThinF
    procedure Plain
endClass
implement TNfD.Thin 'nf_echo "$this" "$@"'
implement TNfD.ThinF 'nf_set "$this"'
implement TNfD.Plain 'echo "p:$Name"'
endImplementation TNfD; rc=$?
TNfD.new nfd; nfd.Name = D
RESULT=k; nfd.ThinF
a="$rc|$(binds __kkm.TNfD.Thin)$(binds __kkm.TNfD.ThinF)$(binds __kkm.TNfD.Plain)|$(nfd.Thin 1)|$RESULT|$(nfd.Plain)"
declareClass TNfDc ""
    field Name
    nofields
    procedure M
endClass
implement TNfDc.M '# uses Name? no
nf_echo "$this"'
endImplementation TNfDc 2>"$ERRF"; rc=$?
check "4.1" "0|nonenonebinds|h:nfd:1|set:nfd:|p:D|rc=1|1" "$a|rc=$rc|$(grep -c "names the field 'Name' of class 'TNfDc'" "$ERRF")"

kt_test_start "4.2 defineClass: the token nofields before method / procedure / function; a nofields token before anything else refuses (rc 2)"
defineClass TNfDf "" property Name nofields method Thin 'nf_echo "$this"' nofields function F 'nf_set "$this"' procedure Plain 'echo "p:$Name"'; rc=$?
TNfDf.new ndf; ndf.Name = F
RESULT=k; ndf.F
a="$rc|$(binds __kkm.TNfDf.Thin)$(binds __kkm.TNfDf.F)$(binds __kkm.TNfDf.Plain)|$(ndf.Thin)|$RESULT|$(ndf.Plain)"
defineClass TNfDf2 "" property Name nofields property X 2>"$ERRF"; rc=$?
defineClass TNfDf3 "" property Name nofields method M 'echo $Name' 2>"$ERRF"; rc3=$?
declare -F TNfDf3.new >/dev/null && n3=built || n3=none
check "4.2" "0|nonenonebinds|h:ndf:|set:ndf:|p:F|2|1|none" "$a|$rc|$rc3|$n3"

kt_test_start "4.3 kk._build_class_runtime: the token nofields; the check runs there too"
kk._build_class_runtime TNfRaw "" property Name nofields procedure Thin 'nf_echo "$this"' procedure Plain 'echo "p:$Name"'; rc=$?
TNfRaw.new nraw; nraw.Name = R
a="$rc|$(binds __kkm.TNfRaw.Thin)$(binds __kkm.TNfRaw.Plain)|$(nraw.Thin)|$(nraw.Plain)"
kk._build_class_runtime TNfRaw2 "" property Name nofields procedure M 'Name=1' 2>"$ERRF"; rc=$?
check "4.3" "0|nonebinds|h:nraw:|p:R|1|1" "$a|$rc|$(grep -c "Error: nofields method 'TNfRaw2.M' names the field 'Name'" "$ERRF")"

kt_test_start "4.4 defineMethod / defineProcedure / defineFunction: a 4th argument nofields; the check; any other 4th argument refuses"
defineProcedure TNfRaw Thin2 'nf_echo "$this" two' nofields; a=$?
defineFunction TNfRaw F2 'nf_set "$this"' nofields; a+=" $?"
defineMethod TNfRaw Bad 'echo "$Name"' nofields 2>"$ERRF"; a+=" $?:$(grep -c "names the field 'Name'" "$ERRF")"
defineMethod TNfRaw Bad2 'echo hi' nofeilds 2>"$ERRF"; a+=" $?:$(grep -c 'Usage: defineMethod CLASS_NAME METHOD_NAME BODY \[nofields\]' "$ERRF")"
TNfRaw.new nraw2
RESULT=k; nraw2.F2
check "4.4" "0 0 1:1 1:1|nonenone|h:nraw2:two|set:nraw2:|no-Bad" \
    "$a|$(binds __kkm.TNfRaw.Thin2)$(binds __kkm.TNfRaw.F2)|$(nraw2.Thin2)|$RESULT|$(declare -F nraw2.Bad >/dev/null && echo has-Bad || echo no-Bad)"

kt_test_start "4.5 a raw body whose text starts with the marker line is nofields (and is checked)"
kk._build_class_runtime TNfMk "" property Name procedure M "$__KK_NOFIELDS_MARK"'nf_echo "$this"'; a=$?
kk._build_class_runtime TNfMk2 "" property Name procedure M "$__KK_NOFIELDS_MARK"'echo $Name' 2>"$ERRF"; a+=" $?"
check "4.5" "0 1|none" "$a|$(binds __kkm.TNfMk.M)"

kt_test_start "4.6 Pascal: the prefixes in any order (nofields override / override nofields) — see §1; nofields is a refused class name (a DSL verb)"
defineClass nofields "" 2>"$ERRF"; rc=$?
check "4.6" "1|1" "$rc|$(grep -c "a kklass DSL verb" "$ERRF")"

cat > "$TMPD/nfu.kkp" <<'EOF'
unit nfu;

interface

type
  TNfK = class
  private
    FValue: Integer;
  public
    property Value read FValue write FValue;
    procedure Thin; nofields;
    procedure Plain;
  end;

implementation

procedure TNfK.Thin;
begin
echo "thin:$this:$1"
end;

procedure TNfK.Plain;
begin
echo "plain:$FValue"
end;

end.
EOF
cat > "$TMPD/K1.sh" <<'EOF'
export KBOOL_HOME=$KBOOL_ROOT
bash "$KKLASS_DIR/kklass_kkp.sh" "$TMPD/nfu.kkp" "$TMPD/nfu.sh" >/dev/null 2>&1 || echo "translate failed"
grep -c '^nofields$' "$TMPD/nfu.sh"
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
source "$TMPD/nfu.sh"
TNfK.new k; k.Value = 5
k.Thin a; k.Plain
t=$(declare -f __kkm.TNfK.Thin); [[ $t == *'local -n'* ]] && echo binds || echo none
EOF
kt_test_start "4.7 .kkp: procedure X; nofields; — the translation emits nofields, the method is built field-free"
case_run K1
check "4.7" "1|thin:k:a|plain:5|none" "${OUT//$'\n'/|}"

# ===========================================================================
# §5 compiled caches: the marker travels, the format stays 7
# ===========================================================================
cat > "$TMPD/nf.kk" <<'EOF'
kk.uses kklass_pascal
class TNfC
    public
        var Name
        nofields proc Thin
        nofields func ThinF
        proc Plain
end
TNfC.Thin()  { echo "thin:$this:$*"; }
TNfC.ThinF() { RESULT="f:$this"; }
TNfC.Plain() { echo "plain:$Name"; }
build TNfC
class TNfC2 : TNfC
    public
        override nofields proc Plain
end
TNfC2.Plain() { echo "c2"; inherited; }
build TNfC2
EOF
cat > "$TMPD/nf_scn.inc" <<'EOF'
nf_scn() {
    local r t f
    TNfC2.new c; c.Name = N
    RESULT=x; c.ThinF
    r="$(c.Thin 1)|$RESULT|$(c.Plain | tr '\n' ' ')"
    for f in __kkm.TNfC.Thin __kkm.TNfC.ThinF __kkm.TNfC.Plain __kkm.TNfC2.Plain; do
        t=$(declare -f "$f"); [[ $t == *'local -n'* ]] && r+="|b" || r+="|n"
    done
    echo "$r"
}
EOF
NF_SCN="thin:c:1|f:c|c2 plain:N |n|n|b|n"
cat > "$TMPD/C1.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk
source "$KKLASS_DIR/kklass_autoload.sh"
source "$TMPD/nf_scn.inc"
autoloadClasses "$TMPD/nf.kk"; echo "first=$?"
nf_scn
EOF
kt_test_start "5.1 source build (first autoload compiles; this run built from source)"
case_run C1
check "5.1" "first=0|$NF_SCN" "${OUT//$'\n'/|}"

cat > "$TMPD/C2.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk
source "$KKLASS_DIR/kklass_autoload.sh"
source "$TMPD/nf_scn.inc"
c=$KKLASS_CKK_DIR/nf.ckk.sh
grep '^kk._ckk_format ' "$c"
autoloadClasses "$TMPD/nf.kk"; echo "second=$?"
[[ ${_KKLASS_CLASS_CKK[TNfC]-} == 1 ]] && echo from-cache || echo from-source
m=0; for v in TNfC_method_body_Thin TNfC_method_body_ThinF TNfC2_method_body_Plain TNfC2_method_body_Thin; do
    [[ ${!v} == "$__KK_NOFIELDS_MARK"* ]] && (( ++m )); done; echo "markers=$m"
nf_scn
EOF
kt_test_start "5.2 the compiled cache: format 7, loaded from the cache, the stored texts keep the marker, the body functions are made field-free again"
case_run C2
check "5.2" "kk._ckk_format 7|second=0|from-cache|markers=4|$NF_SCN" "${OUT//$'\n'/|}"

nb.delete; nl.delete; nok.delete; nre.delete; nfd.delete; ndf.delete; nraw.delete; nraw2.delete

kt_test_start "5.3 a constructor text that starts with the marker line still binds (a constructor is never nofields; the critic round)"
Name=global0
kk._build_class_runtime TNfK "" property Name constructor "$__KK_NOFIELDS_MARK"'Name=set-by-ctor'
krc=$?
TNfK.new nfk
r="$krc|${nfk_data[Name]-}|$Name"
nfk.delete; unset Name
if [[ $r == '0|set-by-ctor|global0' ]]; then kt_test_pass "ok"; else kt_test_fail "[$r]"; fi
kt_test_log "153_NoFields.sh completed"
