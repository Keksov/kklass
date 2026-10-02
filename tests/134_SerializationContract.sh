#!/bin/bash
# SerializationContract (kklass round 3 / P10, findings S1 S1b S2 S3 S4,
# decisions DR4 DR4b DR5 DR6 DR7).
#
# Before P10:
#   * defineSerializableClass carried an inline copy of the string generator:
#     FORMAT=json built a class with EMPTY toString/fromString and no
#     toJSON/fromJSON (rc 0); inherited and lazy properties were not
#     serialized; an unknown format or a short call was not refused (S1);
#   * the SEPARATOR was spliced unquoted into generated code: `$(touch x)`
#     executed, `*` broke the round trip, `"` `\` `'` made fromString rc 2 (S1b);
#   * saveObjects preferred the unescaped toString (S2);
#   * loadObjects ignored the from* rc, restarted its names at _loaded_0 on
#     every call (aliasing the first call's instances), bound its output array
#     through a nameref that collided with its own locals, sent a JSON line with
#     leading blanks to fromString, let bash print "command not found" for a
#     missing from* method and printed "Loaded N objects" on a direct call (S3);
#   * fromJSON/fromString printed the instance name on a direct call, RESULT
#     stayed empty, and a refusal kept the caller's old RESULT (S4).
#
# Pinned here (the contract after P10):
#   * defineSerializableClass = validate (>= 4 args, format, separator) BEFORE
#     defineClass, then defineClass + addSerializable: one generator per
#     format; fields = ${CLASS}_class_properties (inherited + own, lazy incl.);
#   * SEPARATOR: exactly one character, not alnum/_, none of " $ \ ' ` * ? [ ],
#     not LF -> rc 1 + error, nothing generated / built;
#   * saveObjects prefers toJSON;
#   * loadObjects: unique names, kk._outName (rc 2), JSON = first non-blank
#     char '{', a refused line is deleted + warned FILE:LINE, final rc 1,
#     direct call silent, RESULT = number loaded;
#   * fromJSON/fromString: kk._return "$this"; a refusal leaves RESULT=''.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "SerializationContract" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_serializable.sh"

TMPD="$(kt_fixture_tmpdir)"
OUT="$TMPD/out.txt"
ERR="$TMPD/err.txt"
LF=$'\n'

# Exact reader: the instance store, no $( ) trimming. V = the value.
val() { local -n __t_d="${1}_data"; V="${__t_d[$2]-}"; }
# Is CLASS built (has a constructor)?
built() { declare -F "$1.new" >/dev/null; }

# ===========================================================================
# 1. defineSerializableClass (S1 / DR4)
# ===========================================================================
kt_test_start "defineSerializableClass json builds toJSON/fromJSON and round-trips"
defineSerializableClass TDJ "" ":" json property a property b > "$OUT" 2> "$ERR"; rc=$?
ok=0
if [[ $rc -eq 0 ]] && built TDJ; then
    TDJ.new dj1; dj1.a = 'x,"y"'; dj1.b = 'z'
    TDJ.new dj2
    js="$(dj1.toJSON 2>/dev/null)"
    dj2.fromJSON "$js" >/dev/null 2>&1; frc=$?
    val dj2 a; a="$V"; val dj2 b; b="$V"
    [[ $frc -eq 0 && "$a" == 'x,"y"' && "$b" == z && "$js" == '{"__class__":"TDJ","a":"x,\"y\"","b":"z"}' ]] && ok=1
fi
[[ $ok -eq 1 ]] && kt_test_pass "ok" || kt_test_fail "rc=$rc js='${js:-}' frc=${frc:-} a='${a:-}' b='${b:-}'"

kt_test_start "defineSerializableClass json defines no string methods"
if ! declare -p TDJ_method_body_toString >/dev/null 2>&1 && ! declare -p TDJ_method_body_fromString >/dev/null 2>&1; then
    kt_test_pass "none"
else
    kt_test_fail "string bodies defined"
fi

kt_test_start "defineSerializableClass string round-trips through the shared generator"
defineSerializableClass TDS "" ";" string property id property name method hi 'echo hi' 2>"$ERR"; rc=$?
TDS.new ds1; ds1.id = 7; ds1.name = 'a b'
s="$(ds1.toString)"
TDS.new ds2; ds2.fromString "$s" >/dev/null
val ds2 id; i="$V"; val ds2 name; n="$V"
[[ $rc -eq 0 && "$s" == 'TDS;7;a b' && "$i" == 7 && "$n" == 'a b' && "$(ds1.hi)" == hi ]] \
    && kt_test_pass "ok" || kt_test_fail "rc=$rc s='$s' id='$i' name='$n'"

kt_test_start "an unknown format is refused, rc 1 + error, nothing built"
defineSerializableClass TDY "" ":" yaml property a > "$OUT" 2> "$ERR"; rc=$?
[[ $rc -eq 1 && -s "$ERR" ]] && ! built TDY && ! declare -p TDY_class_properties >/dev/null 2>&1 \
    && kt_test_pass "refused" || kt_test_fail "rc=$rc built=$(built TDY && echo yes) err='$(<"$ERR")'"

kt_test_start "a short call (< 4 arguments) is refused, nothing built"
defineSerializableClass TDShort "" ":" > "$OUT" 2> "$ERR"; rc=$?
[[ $rc -eq 1 && -s "$ERR" ]] && ! built TDShort \
    && kt_test_pass "refused" || kt_test_fail "rc=$rc built=$(built TDShort && echo yes)"

# The DR4 format change: fields = ${CLASS}_class_properties (inherited first,
# then own, lazy included) — pinned field order.
defineClass TPBase "" property p0
kt_test_start "string format serializes inherited and lazy properties (DR4 field set)"
defineSerializableClass TDChild TPBase ":" string property a lazy_property lz initLz method initLz 'lz=LAZY' 2>"$ERR"; rc=$?
TDChild.new dc1; dc1.p0 = P; dc1.a = x
s="$(dc1.toString)"
[[ $rc -eq 0 && "${TDChild_class_properties[*]}" == "p0 a lz" && "$s" == 'TDChild:P:x:' ]] \
    && kt_test_pass "$s" || kt_test_fail "rc=$rc props='${TDChild_class_properties[*]}' s='$s'"

kt_test_start "the inherited property round-trips through fromString"
TDChild.new dc2; dc2.fromString 'TDChild:Q:y:' >/dev/null
val dc2 p0; p="$V"; val dc2 a; a="$V"
[[ "$p" == Q && "$a" == y ]] && kt_test_pass "p0=$p a=$a" || kt_test_fail "p0='$p' a='$a'"

# ===========================================================================
# 2. Separator rule (S1b / DR4b)
# ===========================================================================
PWN="$TMPD/pwn"
kt_test_start "separator \$(touch …) is refused by defineSerializableClass and never executed"
rm -f "$PWN"
defineSerializableClass TSepX "" "\$(touch $PWN)" string property a property b > "$OUT" 2> "$ERR"; rc=$?
if built TSepX; then TSepX.new sx 2>/dev/null; sx.a = 1 2>/dev/null; sx.toString >/dev/null 2>&1; sx.fromString 'TSepX:1:2' >/dev/null 2>&1; fi
[[ $rc -eq 1 && ! -e "$PWN" ]] && ! built TSepX \
    && kt_test_pass "refused" || kt_test_fail "rc=$rc pwn=$([[ -e $PWN ]] && echo YES) built=$(built TSepX && echo yes)"

kt_test_start "every forbidden separator is refused by defineSerializableClass (rc 1, not built)"
bad=()
k=0
for sep in '"' '$' '\' "'" '`' '*' '?' '[' ']' "$LF" '::' 'a' 'Z' '5' '_' '#$'; do
    k=$((k+1))
    defineSerializableClass "TSepBad$k" "" "$sep" string property a > "$OUT" 2> "$ERR"; rc=$?
    if [[ $rc -ne 1 || ! -s "$ERR" ]] || built "TSepBad$k"; then bad+=("[$sep]rc=$rc"); fi
done
[[ ${#bad[@]} -eq 0 ]] && kt_test_pass "16 refused" || kt_test_fail "accepted: ${bad[*]}"

# Measured (worker P10, both bashes): space TAB VT FF act as IFS whitespace in
# `read` (empty fields collapse, values trimmed) and a raw CR is lost by the
# method-body rebuild (toString printed no separator) -> refused as well.
kt_test_start "whitespace separators (space TAB CR VT FF) are refused by both entry points"
bad=()
k=0
for code in 32 9 13 11 12; do
    k=$((k+1))
    printf -v esc '\\x%02x' "$code"; printf -v sep "$esc"
    [[ ${#sep} -eq 1 ]] || bad+=("fixture$code")
    defineSerializableClass "TSepWs$k" "" "$sep" string property a property b > "$OUT" 2> "$ERR"; rc=$?
    if [[ $rc -ne 1 || ! -s "$ERR" ]] || built "TSepWs$k"; then bad+=("def[$code]rc=$rc"); fi
    defineClass "TSepWsA$k" "" property a property b
    addSerializable "TSepWsA$k" "$sep" string > "$OUT" 2> "$ERR"; rc=$?
    if [[ $rc -ne 1 ]] || declare -p "TSepWsA${k}_method_body_toString" >/dev/null 2>&1; then bad+=("add[$code]rc=$rc"); fi
done
[[ ${#bad[@]} -eq 0 ]] && kt_test_pass "5 x 2 refused" || kt_test_fail "${bad[*]}"

kt_test_start "every forbidden separator is refused by addSerializable (rc 1, nothing generated)"
defineClass TSepAdd "" property a property b
bad=()
for sep in '"' '$' '\' "'" '`' '*' '?' '[' ']' "$LF" '::' 'a' '_' "\$(touch $PWN)"; do
    addSerializable TSepAdd "$sep" string > "$OUT" 2> "$ERR"; rc=$?
    if [[ $rc -ne 1 || ! -s "$ERR" ]] || declare -p TSepAdd_method_body_toString >/dev/null 2>&1; then
        bad+=("[$sep]rc=$rc"); unset TSepAdd_method_body_toString
    fi
done
[[ ${#bad[@]} -eq 0 && ! -e "$PWN" ]] && kt_test_pass "14 refused" || kt_test_fail "accepted: ${bad[*]} pwn=$([[ -e $PWN ]] && echo YES)"

kt_test_start "allowed punctuation separators round-trip (string format)"
bad=()
k=0
for sep in ':' '|' ';' ',' '#' '%' '&' '{' '}' '~' '!' '^' '-' '/' '@' '=' '+' '.' '<' '>' '(' ')'; do
    k=$((k+1))
    defineSerializableClass "TSepOk$k" "" "$sep" string property a property b 2>"$ERR"; rc=$?
    if [[ $rc -ne 0 ]]; then bad+=("[$sep]def"); continue; fi
    "TSepOk$k.new" "so$k"; "so$k.a" = 'v 1'; "so$k.b" = 'w'
    s="$("so$k.toString")"
    "TSepOk$k.new" "sr$k"; "sr$k.fromString" "$s" >/dev/null 2>&1; frc=$?
    val "sr$k" a; a="$V"; val "sr$k" b; b="$V"
    [[ $frc -eq 0 && "$s" == "TSepOk$k${sep}v 1${sep}w" && "$a" == 'v 1' && "$b" == w ]] || bad+=("[$sep]s=$s a=$a b=$b")
done
[[ ${#bad[@]} -eq 0 ]] && kt_test_pass "22 ok" || kt_test_fail "${bad[*]}"

# ===========================================================================
# 3. fromJSON / fromString return through RESULT (S4 / DR7)
# ===========================================================================
defineClass TRet "" property a property b
addSerializable TRet ":" json
addSerializable TRet ":" string
TRet.new r1
for m in fromJSON fromString; do
    if [[ $m == fromJSON ]]; then in='{"__class__":"TRet","a":"x","b":"y"}'; else in='TRet:x:y'; fi
    kt_test_start "$m direct call is silent and sets RESULT to the instance"
    RESULT=before; r1.$m "$in" > "$OUT" 2> "$ERR"; rc=$?
    [[ $rc -eq 0 && ! -s "$OUT" && ! -s "$ERR" && "$RESULT" == r1 ]] \
        && kt_test_pass "ok" || kt_test_fail "rc=$rc out='$(<"$OUT")' RESULT='$RESULT'"
    kt_test_start "$m inside \$( ) prints the instance name exactly once"
    out="$(r1.$m "$in"; printf '|')"
    [[ "$out" == 'r1|' ]] && kt_test_pass "ok" || kt_test_fail "out='$out'"
done

kt_test_start "a refused fromJSON leaves RESULT empty (rc 1, instance unchanged)"
RESULT=before; r1.fromJSON '{"__class__":"Other","a":"z"}' > "$OUT" 2> "$ERR"; rc=$?
val r1 a
[[ $rc -eq 1 && -z "$RESULT" && ! -s "$OUT" && ! -s "$ERR" && "$V" == x ]] \
    && kt_test_pass "ok" || kt_test_fail "rc=$rc RESULT='$RESULT' a='$V'"

kt_test_start "a malformed fromJSON leaves RESULT empty"
RESULT=before; r1.fromJSON '{"a":' > "$OUT" 2> "$ERR"; rc=$?
[[ $rc -eq 1 && -z "$RESULT" && ! -s "$OUT" ]] && kt_test_pass "ok" || kt_test_fail "rc=$rc RESULT='$RESULT'"

# ===========================================================================
# 4. saveObjects prefers toJSON (S2 / DR5)
# ===========================================================================
defineClass TBoth "" property a property b
addSerializable TBoth ":" string
addSerializable TBoth ":" json
TBoth.new bo1; bo1.a = 'x:y'; bo1.b = "l1${LF}l2"
TBoth.new bo2; bo2.a = 'p'; bo2.b = 'q:r'
F="$TMPD/both.txt"
saveObjects "$F" bo1 bo2
mapfile -t LINES < "$F"
kt_test_start "saveObjects writes a both-formats instance as JSON, one line per object"
[[ ${#LINES[@]} -eq 2 && "${LINES[0]}" == '{"__class__":"TBoth",'* && "${LINES[1]}" == '{"__class__":"TBoth",'* ]] \
    && kt_test_pass "2 JSON lines" || kt_test_fail "${#LINES[@]} lines: ${LINES[*]}"

kt_test_start "the both-formats file reloads intact (separator and LF in values)"
declare -a LB=()
loadObjects "$F" TBoth LB > "$OUT" 2> "$ERR"; rc=$?
ok=0
if [[ $rc -eq 0 && ${#LB[@]} -eq 2 ]]; then
    val "${LB[0]}" a; a0="$V"; val "${LB[0]}" b; b0="$V"; val "${LB[1]}" b; b1="$V"
    [[ "$a0" == 'x:y' && "$b0" == "l1${LF}l2" && "$b1" == 'q:r' ]] && ok=1
fi
[[ $ok -eq 1 ]] && kt_test_pass "exact" || kt_test_fail "rc=$rc n=${#LB[@]} a0='${a0:-}' b0='${b0:-}' b1='${b1:-}'"

# ===========================================================================
# 5. loadObjects (S3 / DR6)
# ===========================================================================
defineClass TL "" property a property b
addSerializable TL ":" json
addSerializable TL ":" string
F1="$TMPD/f1.txt"; F2="$TMPD/f2.txt"
printf '%s\n' '{"__class__":"TL","a":"1","b":"2"}' '{"__class__":"TL","a":"3","b":"4"}' > "$F1"
printf '%s\n' '{"__class__":"TL","a":"9"}' > "$F2"

kt_test_start "a direct call is silent and RESULT = number loaded"
declare -a L1=()
RESULT=x; loadObjects "$F1" TL L1 > "$OUT" 2> "$ERR"; rc=$?
[[ $rc -eq 0 && "$RESULT" == 2 && ${#L1[@]} -eq 2 && ! -s "$OUT" && ! -s "$ERR" ]] \
    && kt_test_pass "ok" || kt_test_fail "rc=$rc RESULT='$RESULT' n=${#L1[@]} out='$(<"$OUT")' err='$(<"$ERR")'"

kt_test_start "the 'Loaded N objects' line goes to stderr only under VERBOSE_KKLASS=debug"
declare -a LD=()
VERBOSE_KKLASS=debug loadObjects "$F2" TL LD > "$OUT" 2> "$ERR"; rc=$?
[[ $rc -eq 0 && ! -s "$OUT" && "$(<"$ERR")" == *"Loaded 1 objects"* ]] \
    && kt_test_pass "ok" || kt_test_fail "rc=$rc out='$(<"$OUT")' err='$(<"$ERR")'"

kt_test_start "a second call in the same shell keeps the first array intact (unique names)"
declare -a L2=()
loadObjects "$F2" TL L2 >/dev/null 2>&1
val "${L1[0]}" a; a="$V"; val "${L1[0]}" b; b="$V"
[[ ${#L2[@]} -eq 1 && "${L2[0]}" != "${L1[0]}" && "${L2[0]}" != "${L1[1]}" && "$a" == 1 && "$b" == 2 ]] \
    && kt_test_pass "L1[0]=${L1[0]} L2[0]=${L2[0]}" || kt_test_fail "L1=(${L1[*]}) L2=(${L2[*]}) a=$a b=$b"

kt_test_start "an existing instance with a generated name is skipped, its data untouched"
TL.new TL_loaded_50 2>/dev/null
# make every name below 50 taken so the next free is >= 50
for (( k = 0; k < 50; k++ )); do declare -p "TL_loaded_${k}_class" >/dev/null 2>&1 || TL.new "TL_loaded_$k"; done
TL_loaded_50.a = keep
declare -a L3=()
loadObjects "$F2" TL L3 >/dev/null 2>&1
val TL_loaded_50 a
# TL_loaded_0..50 are all live: the counter must continue to the first free name.
[[ ${#L3[@]} -eq 1 && "${L3[0]}" == TL_loaded_51 && "$V" == keep ]] \
    && kt_test_pass "got ${L3[0]}" || kt_test_fail "L3=(${L3[*]}) TL_loaded_50.a='$V'"

F3="$TMPD/f3.txt"
printf '%s\n' '{"__class__":"TL","a":"g1"}' '{"__class__":"Other","a":"z"}' '{"__class__":"TL","a":"g2"}' > "$F3"
kt_test_start "a refused JSON line: rc 1, RESULT = loaded count, instance deleted, warning names FILE:LINE"
declare -a L4=()
RESULT=x; loadObjects "$F3" TL L4 > "$OUT" 2> "$ERR"; rc=$?
err="$(<"$ERR")"
ok=0
if [[ $rc -eq 1 && "$RESULT" == 2 && ${#L4[@]} -eq 2 && ! -s "$OUT" && "$err" == *"$F3:2"* ]]; then
    val "${L4[0]}" a; a0="$V"; val "${L4[1]}" a; a1="$V"
    [[ "$a0" == g1 && "$a1" == g2 ]] && ok=1
fi
[[ $ok -eq 1 ]] && kt_test_pass "ok" || kt_test_fail "rc=$rc RESULT='$RESULT' L4=(${L4[*]}) err='$err'"

kt_test_start "the refused line leaves no instance behind"
n0=0
for (( k = 0; k < 200; k++ )); do declare -p "TL_loaded_${k}_class" >/dev/null 2>&1 && n0=$((n0+1)); done
# L1 0-1, LD 2, L2 3, pre-made 4-50, L3 1, L4 2 = 54 live generated names
[[ $n0 -eq 54 ]] && kt_test_pass "54 live" || kt_test_fail "$n0 live generated instances"

kt_test_start "the warning is silenced by VERBOSE_KKLASS=quiet (rc still 1)"
declare -a L5=()
VERBOSE_KKLASS=quiet loadObjects "$F3" TL L5 > "$OUT" 2> "$ERR"; rc=$?
[[ $rc -eq 1 && ! -s "$ERR" && ! -s "$OUT" && ${#L5[@]} -eq 2 ]] && kt_test_pass "ok" || kt_test_fail "rc=$rc err='$(<"$ERR")'"

kt_test_start "under set -e a refused line does not abort the load (every line processed)"
( set -e; declare -a LE=(); trap 'printf "%s" "${#LE[@]}" > "$TMPD/se.txt"' EXIT; loadObjects "$F3" TL LE ) > /dev/null 2>&1; rc=$?
got="$(<"$TMPD/se.txt")"
[[ $rc -eq 1 && "$got" == 2 ]] && kt_test_pass "2 loaded, rc 1" || kt_test_fail "rc=$rc loaded='$got'"

defineClass TJO "" property a
addSerializable TJO ":" json
F4="$TMPD/f4.txt"
printf '%s\n' 'TJO:x' > "$F4"
kt_test_start "a JSON-only class given a string line: refused, no bash diagnostic"
declare -a L6=()
RESULT=x; loadObjects "$F4" TJO L6 > "$OUT" 2> "$ERR"; rc=$?
err="$(<"$ERR")"
[[ $rc -eq 1 && "$RESULT" == 0 && ${#L6[@]} -eq 0 && "$err" != *"command not found"* && "$err" == *"$F4:1"* ]] \
    && ! declare -p TJO_loaded_0_class >/dev/null 2>&1 \
    && kt_test_pass "ok" || kt_test_fail "rc=$rc RESULT='$RESULT' L6=(${L6[*]}) err='$err'"

F5="$TMPD/f5.txt"
printf '%s\n' '  {"__class__":"TL","a":"ws","b":"v"}' "$(printf '\t')"'{"a":"tab"}' > "$F5"
kt_test_start "a JSON line with leading blanks goes to fromJSON"
declare -a L7=()
loadObjects "$F5" TL L7 > "$OUT" 2> "$ERR"; rc=$?
a0=""; a1=""
if [[ ${#L7[@]} -eq 2 ]]; then val "${L7[0]}" a; a0="$V"; val "${L7[1]}" a; a1="$V"; fi
[[ $rc -eq 0 && "$a0" == ws && "$a1" == tab ]] && kt_test_pass "ok" || kt_test_fail "rc=$rc L7=(${L7[*]}) a0='$a0' a1='$a1'"

F6="$TMPD/f6.txt"
printf '%s\n' '{"__class__":"TL","a":"u"}' '   ' '' 'TL:s1:s2' > "$F6"
kt_test_start "blank and whitespace-only lines are skipped; string lines go to fromString"
declare -a L8=()
loadObjects "$F6" TL L8 > "$OUT" 2> "$ERR"; rc=$?
a1=""; b1=""
if [[ ${#L8[@]} -eq 2 ]]; then val "${L8[1]}" a; a1="$V"; val "${L8[1]}" b; b1="$V"; fi
[[ $rc -eq 0 && "$RESULT" == 2 && "$a1" == s1 && "$b1" == s2 && ! -s "$ERR" ]] \
    && kt_test_pass "ok" || kt_test_fail "rc=$rc RESULT=$RESULT L8=(${L8[*]}) a1='$a1' err='$(<"$ERR")'"

kt_test_start "output arrays named line / count / file / instances_array are filled"
bad=()
for nm in line count file instances_array class_name inst_name; do
    unset "$nm"; declare -a "$nm=()"
    loadObjects "$F1" TL "$nm" > "$OUT" 2> "$ERR"; rc=$?
    declare -n __t_arr="$nm"
    [[ $rc -eq 0 && ${#__t_arr[@]} -eq 2 && "${__t_arr[0]}" == TL_loaded_* && ! -s "$ERR" ]] || bad+=("$nm:rc=$rc:n=${#__t_arr[@]}")
    unset -n __t_arr
done
[[ ${#bad[@]} -eq 0 ]] && kt_test_pass "6 names" || kt_test_fail "${bad[*]}"

kt_test_start "a hostile or reserved output name is rc 2, nothing loaded, nothing executed"
bad=()
rm -f "$PWN"
for nm in '1bad' "a[\$(touch $PWN)]" '' 'RESULT' 'this' '__kk_x' 'state' 'a b'; do
    RESULT=x; loadObjects "$F1" TL "$nm" > "$OUT" 2> "$ERR"; rc=$?
    [[ $rc -eq 2 && -z "$RESULT" && ! -s "$OUT" && ! -s "$ERR" ]] || bad+=("[$nm]rc=$rc:R=$RESULT")
done
[[ ${#bad[@]} -eq 0 && ! -e "$PWN" ]] && kt_test_pass "8 refused" || kt_test_fail "${bad[*]} pwn=$([[ -e $PWN ]] && echo YES)"

kt_test_start "a missing file is rc 1, RESULT empty, silent"
declare -a L9=()
RESULT=x; loadObjects "$TMPD/nope.txt" TL L9 > "$OUT" 2> "$ERR"; rc=$?
[[ $rc -eq 1 && -z "$RESULT" && ! -s "$OUT" && ! -s "$ERR" && ${#L9[@]} -eq 0 ]] \
    && kt_test_pass "ok" || kt_test_fail "rc=$rc RESULT='$RESULT' err='$(<"$ERR")'"

kt_test_start "loadObjects inside \$( ) prints the count exactly once"
out="$(declare -a LS=(); loadObjects "$F1" TL LS; printf '|')"
[[ "$out" == '2|' ]] && kt_test_pass "ok" || kt_test_fail "out='$out'"

# ===========================================================================
# 6. Review remarks R1-R3 (P10 review)
# ===========================================================================
# R1: a last line without a trailing newline is loaded.
F7="$TMPD/f7.txt"
printf '%s\n%s' '{"__class__":"TL","a":"n1"}' '{"__class__":"TL","a":"n2"}' > "$F7"
kt_test_start "R1: a last object without a trailing newline is loaded"
declare -a LR1=()
loadObjects "$F7" TL LR1 > "$OUT" 2> "$ERR"; rc=$?
a1=""; [[ ${#LR1[@]} -eq 2 ]] && { val "${LR1[1]}" a; a1="$V"; }
[[ $rc -eq 0 && "$RESULT" == 2 && "$a1" == n2 ]] && kt_test_pass "ok" || kt_test_fail "rc=$rc RESULT=$RESULT n=${#LR1[@]} a1='$a1'"

# R2: fromString refuses a line without the serializer's CLASS+SEP prefix.
defineClass TPre "" property a property b
addSerializable TPre ":" string
TPre.new pr1; pr1.a = keepA; pr1.b = keepB
kt_test_start "R2: fromString refuses another class's line (rc 1, RESULT='', silent, untouched)"
bad=()
for in in 'Other:p:q' 'TPreX:p:q' 'TPre' 'TPre;p;q' '' ' TPre:p:q'; do
    RESULT=before; pr1.fromString "$in" > "$OUT" 2> "$ERR"; rc=$?
    val pr1 a; a="$V"; val pr1 b; b="$V"
    [[ $rc -eq 1 && -z "$RESULT" && ! -s "$OUT" && ! -s "$ERR" && "$a" == keepA && "$b" == keepB ]] || bad+=("[$in]rc=$rc:R=$RESULT:a=$a")
done
[[ ${#bad[@]} -eq 0 ]] && kt_test_pass "6 refused" || kt_test_fail "${bad[*]}"

kt_test_start "R2: a refused fromString writes exactly one kk.debug line under debug"
VERBOSE_KKLASS=debug pr1.fromString 'Other:p:q' > "$OUT" 2> "$ERR"; rc=$?
mapfile -t ERRL < "$ERR"
[[ $rc -eq 1 && ! -s "$OUT" && ${#ERRL[@]} -eq 1 && "${ERRL[0]}" == Error:* ]] && kt_test_pass "ok" || kt_test_fail "rc=$rc lines=${#ERRL[@]}"

kt_test_start "R2: fromString with no argument under set -u is a refusal, not an abort"
out="$( set -u; pr1.fromString 2>/dev/null; printf 'rc=%s' "$?" )"
[[ "$out" == 'rc=1' ]] && kt_test_pass "ok" || kt_test_fail "out='$out'"

kt_test_start "R2: the class prefix accepts an empty-valued line and a value holding the separator in the last field"
pr1.fromString 'TPre::x:y' >/dev/null; rc=$?
val pr1 a; a="$V"; val pr1 b; b="$V"
[[ $rc -eq 0 && -z "$a" && "$b" == 'x:y' ]] && kt_test_pass "ok" || kt_test_fail "rc=$rc a='$a' b='$b'"

kt_test_start "R2: a subclass inheriting the serializer round-trips (toString writes the serializer's class)"
defineClass TPreSub TPre property c
TPreSub.new ps1; ps1.a = s1; ps1.b = s2; ps1.c = s3
TPreSub.new ps2
s="$(ps1.toString)"
ps2.fromString "$s" >/dev/null; rc=$?
val ps2 a; a="$V"; val ps2 b; b="$V"
[[ $rc -eq 0 && "$s" == 'TPre:s1:s2' && "$a" == s1 && "$b" == s2 ]] && kt_test_pass "$s" || kt_test_fail "rc=$rc s='$s' a='$a' b='$b'"

F8="$TMPD/f8.txt"
printf '%s\n' 'TL:a1:b1' 'Other:p:q' 'TL:a2:b2' 'garbage-no-sep' > "$F8"
kt_test_start "R2: loadObjects of a mixed string file loads only the matching lines, warns for the others"
declare -a LR2=()
loadObjects "$F8" TL LR2 > "$OUT" 2> "$ERR"; rc=$?
err="$(<"$ERR")"
a0=""; a1=""
if [[ ${#LR2[@]} -eq 2 ]]; then val "${LR2[0]}" a; a0="$V"; val "${LR2[1]}" a; a1="$V"; fi
[[ $rc -eq 1 && "$RESULT" == 2 && "$a0" == a1 && "$a1" == a2 && "$err" == *"$F8:2"* && "$err" == *"$F8:4"* ]] \
    && kt_test_pass "ok" || kt_test_fail "rc=$rc RESULT=$RESULT LR2=(${LR2[*]}) err='$err'"

# R3: the addSerializable debug note goes through kk.debug (stderr, one line).
# (defineMethod's own "Method 'X' added to class" debug note is kklass.sh's; it
# goes to stderr since P11 — pinned by test 135 §D, not asserted here.)
defineClass TDbg "" property a
kt_test_start "R3: addSerializable's debug note is one stderr line, never on stdout"
VERBOSE_KKLASS=debug addSerializable TDbg ":" string > "$OUT" 2> "$ERR"; rc=$?
nout=$(grep -c "Serialization methods added" "$OUT")
nerr=$(grep -c "^Serialization methods added to TDbg (format: string)$" "$ERR")
[[ $rc -eq 0 && $nout -eq 0 && $nerr -eq 1 ]] \
    && kt_test_pass "ok" || kt_test_fail "rc=$rc nout=$nout nerr=$nerr out='$(<"$OUT")' err='$(<"$ERR")'"
