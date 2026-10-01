#!/bin/bash
# JsonEscaping (kklass round 2 / P7, finding K3, decision DR2).
#
# toJSON embedded property values UNESCAPED: a quote, a backslash or a newline
# made JSON.parse reject the output. fromJSON was broken independently (C3):
# it split the object on every ',' and every ':', so a value holding a comma
# lost data even in valid JSON, whitespace-formatted input produced empty
# values, a foreign __class__ loaded silently, and no unescape order is right
# for a naive global replace (`C:\new` comes back as `C:` + LF + `ew`).
#
# Pinned here:
#   * toJSON escapes `\` `"`, names \n \r \t \b \f, writes the other
#     U+0001..U+001F as \u00XX, leaves DEL / C1 / multi-byte UTF-8 raw;
#     every hostile value is accepted by node's JSON.parse with the exact bytes;
#   * fromJSON is a string-aware scanner: commas/colons/braces inside strings,
#     whitespace between tokens, bare tokens (numbers, true/false/null),
#     the eight named escapes + \uXXXX (BMP and surrogate pairs) — and it is
#     atomic: any error is rc 1 with the instance untouched;
#   * \u0000, a lone surrogate, an invalid escape, a nested object/array value
#     and trailing garbage are rc 1;
#   * a __class__ that names neither the receiving instance's class nor the
#     class whose serializer runs is rc 1 + exactly one kk.debug line;
#   * saveObjects/loadObjects stay one line per object (escaped \n).

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "JsonEscaping" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_serializable.sh"

TMPD="$(kt_fixture_tmpdir)"

# Exact readers: a function getter returns through RESULT on a direct call, so
# trailing newlines and option-like values survive (no $( ) involved).
defineClass TJ "" \
    property a \
    property b \
    function getA 'RESULT="$a"' \
    function getB 'RESULT="$b"'
addSerializable TJ "" json

TJ.new j1
TJ.new j2

# label + value pairs. LABELS spell control bytes out so a failure report
# never prints them raw.
# NB: a CR inside $'..' is DROPPED in a compound array assignment on the
# MSYS/cygwin bashes (both 5.2.37 and 5.3.9: `a=($'x\ry')` gives "xy"), so CR
# values are built by expansion from $CR instead.
CR=$'\r'
HV=(  'x,y' 'k:v' 'a}b{c' 'say "hi"' 'C:\new\table' '\'  'end\'   $'l1\nl2' "cr${CR}x" $'t\tx' $'b\bx' $'f\fx' $'c\x01x' $'c\x1fx' $'del\x7fx' 'é€😀ü'  '  pad  ' ''      '-n' '%s&x' 'a\"b'    '\u0041' $'\n\n' )
HL=(  'comma' 'colon' 'braces' 'quotes' 'C:<bs>new<bs>table' '<bs>' 'end<bs>' 'l1<LF>l2' 'cr<CR>x' 't<TAB>x' 'b<BS>x' 'f<FF>x' 'c<01>x' 'c<1F>x' 'del<7F>x' 'utf8-multibyte' 'pad-spaces' 'empty' '-n' '%s&x' 'a<bs>"b' '<bs>u0041' '<LF><LF>' )

read_a() { "$1.getA"; GOT_A="$RESULT"; }
read_b() { "$1.getB"; GOT_B="$RESULT"; }

# ---------------------------------------------------------------------------
# 1. Round trip of every hostile value through toJSON -> fromJSON.
JSONS=()
for i in "${!HV[@]}"; do
    v="${HV[$i]}"
    kt_test_start "round trip: ${HL[$i]} [K3]"
    j1.a = "$v"; j1.b = "B"
    js="$(j1.toJSON)"
    JSONS+=("$js")
    j2.a = "SENTINEL"; j2.b = "SENTINEL"
    j2.fromJSON "$js" >/dev/null; rc=$?
    read_a j2; read_b j2
    if [[ $rc -eq 0 && "$GOT_A" == "$v" && "$GOT_B" == "B" && "$js" != *$'\n'* ]]; then
        kt_test_pass "exact"
    else
        kt_test_fail "${HL[$i]}: rc=$rc a-bytes=${#GOT_A} expected=${#v} b='$GOT_B' one-line=$([[ $js != *$'\n'* ]] && echo yes || echo no)"
    fi
done

# ---------------------------------------------------------------------------
# 2. node's JSON.parse accepts every toJSON output and yields the exact bytes.
# Records are NUL-separated (json, expected-bytes) pairs read from a file, so
# no value ever travels through a Windows command line.
if command -v node >/dev/null 2>&1; then
    rec="$TMPD/node_in.bin"
    : > "$rec"
    for i in "${!HV[@]}"; do printf '%s\0%s\0' "${JSONS[$i]}" "${HV[$i]}" >> "$rec"; done
    mapfile -t NODE_OUT < <(node -e '
        const b = require("fs").readFileSync(0); const r = []; let s = 0;
        for (let i = 0; i < b.length; i++) if (b[i] === 0) { r.push(b.subarray(s, i)); s = i + 1; }
        for (let i = 0; i + 1 < r.length; i += 2) {
            let out;
            try { const o = JSON.parse(r[i].toString("utf8"));
                  out = (o.__class__ === "TJ" && o.b === "B" && Buffer.from(String(o.a), "utf8").equals(r[i + 1])) ? "OK" : "DIFF"; }
            catch (e) { out = "INVALID"; }
            console.log(out);
        }' < "$rec")
    for i in "${!HV[@]}"; do
        kt_test_start "node JSON.parse accepts toJSON of ${HL[$i]} with the exact bytes [K3]"
        [[ "${NODE_OUT[$i]%$'\r'}" == "OK" ]] && kt_test_pass "OK" || kt_test_fail "${HL[$i]}: node says '${NODE_OUT[$i]:-<none>}'"
    done
else
    kt_test_start "node JSON.parse validation"
    kt_test_pass "node not installed - validation skipped"
fi

# ---------------------------------------------------------------------------
# 3. The exact escaped form (DR2).
kt_test_start "toJSON escapes backslash and quote, names LF CR TAB BS FF [DR2]"
j1.a = $'q"b\\n\nr\rt\tb\bf\f'; j1.b = "B"
js="$(j1.toJSON)"
exp='{"__class__":"TJ","a":"q\"b\\n\nr\rt\tb\bf\f","b":"B"}'
[[ "$js" == "$exp" ]] && kt_test_pass "exact" || kt_test_fail "got: ${js//[$'\x01'-$'\x1f']/?}"

kt_test_start "toJSON writes other U+0001..U+001F as <bs>u00XX (lower-case hex) [DR2]"
j1.a = $'\x01\x02\x1b\x1f'; j1.b = "B"
js="$(j1.toJSON)"
exp='{"__class__":"TJ","a":"\u0001\u0002\u001b\u001f","b":"B"}'
[[ "$js" == "$exp" ]] && kt_test_pass "exact" || kt_test_fail "got: ${js//[$'\x01'-$'\x1f']/?}"

kt_test_start "toJSON leaves DEL, C1 and multi-byte UTF-8 raw [DR2]"
j1.a = $'\x7f\xc2\x85é😀'; j1.b = "B"
js="$(j1.toJSON)"
exp=$'{"__class__":"TJ","a":"\x7f\xc2\x85é😀","b":"B"}'
[[ "$js" == "$exp" ]] && kt_test_pass "exact" || kt_test_fail "got: $js"

kt_test_start "a clean object serializes exactly as before (fast path, unchanged format)"
j1.a = "plain value"; j1.b = "42"
js="$(j1.toJSON)"
[[ "$js" == '{"__class__":"TJ","a":"plain value","b":"42"}' ]] && kt_test_pass "exact" || kt_test_fail "got: $js"

kt_test_start "kk._jsonEscape is callable directly and returns through RESULT"
RESULT=""
kk._jsonEscape $'a"\\\x1f'; rc=$?
[[ $rc -eq 0 && "$RESULT" == 'a\"\\\u001f' ]] && kt_test_pass "RESULT=$RESULT" || kt_test_fail "rc=$rc RESULT=$RESULT"

# ---------------------------------------------------------------------------
# 4. Parser: foreign but valid JSON.
from() {   # JSON -> rc in RC, values in GOT_A/GOT_B (j2 preset to sentinels)
    j2.a = "SA"; j2.b = "SB"
    j2.fromJSON "$1" >/dev/null 2>&1; RC=$?
    read_a j2; read_b j2
}
expect_ok() {   # LABEL JSON A B
    kt_test_start "fromJSON accepts $1 [C3]"
    from "$2"
    if [[ $RC -eq 0 && "$GOT_A" == "$3" && "$GOT_B" == "$4" ]]; then kt_test_pass "a/b ok"
    else kt_test_fail "$1: rc=$RC a='$GOT_A' b='$GOT_B' (expected '$3' / '$4')"; fi
}
expect_rejected() {   # LABEL JSON
    kt_test_start "fromJSON rejects $1 (rc 1, instance untouched) [C3]"
    from "$2"
    if [[ $RC -eq 1 && "$GOT_A" == "SA" && "$GOT_B" == "SB" ]]; then kt_test_pass "rc=1 untouched"
    else kt_test_fail "$1: rc=$RC a='$GOT_A' b='$GOT_B'"; fi
}

expect_ok "a comma inside a value"             '{"__class__":"TJ","a":"x,y","b":"z"}'           'x,y' 'z'
expect_ok "a colon and braces inside a value"   '{"a":"k:v}{","b":"z"}'                          'k:v}{' 'z'
expect_ok "whitespace between tokens"           '{ "a" : "b" , "b" : "c" }'                      'b' 'c'
expect_ok "multi-line pretty-printed input"     $'{\n  "a": "p",\r\n\t"b": "q"\n}\n'             'p' 'q'
expect_ok "backslash sequences (C:<bs>new<bs>table)" '{"a":"C:\\new\\table","b":"\\\\"}'             'C:\new\table' '\\'
expect_ok "the eight named escapes"             '{"a":"\"\\\/\b\f\n\r\t","b":"z"}'              $'"\\/\b\f\n\r\t' 'z'
expect_ok "BMP <bs>u escapes (any hex case)" '{"a":"\u00e9\u20AC\u0041","b":"\u00E9"}'        'é€A' 'é'
expect_ok "a surrogate pair"                    '{"a":"\ud83d\ude00!","b":"z"}'                  '😀!' 'z'
expect_ok "<bs>u escapes of control characters" '{"a":"\u0001\u001f\u000a","b":"z"}'            $'\x01\x1f\n' 'z'
expect_ok "<bs>u0025 and <bs>u005c stay literal" '{"a":"\u0025s\u005cn","b":"z"}'                 '%s\n' 'z'
expect_ok "bare tokens (number / true)"         '{"a":42,"b":true}'                              '42' 'true'
expect_ok "bare tokens with spaces around"      '{"a": -1.5e3 ,"b":null }'                       '-1.5e3' 'null'
expect_ok "unknown keys (ignored)"              '{"zzz":"1","a":"v","__x":"y"}'                  'v' 'SB'
expect_ok "a missing __class__"                 '{"a":"v","b":"w"}'                              'v' 'w'
expect_ok "an empty object"                     '{}'                                              'SA' 'SB'
expect_ok "duplicate keys (last wins)"          '{"a":"1","a":"2","b":"3"}'                      '2' '3'
expect_ok "an empty key (ignored)"              '{"":"x","a":"v"}'                               'v' 'SB'
expect_ok "raw UTF-8 in keys and values"        '{"ключ":"x","a":"значение"}'                    'значение' 'SB'

# ---------------------------------------------------------------------------
# 5. Parser: malformed / unsupported input is rc 1 and atomic.
expect_rejected "<bs>u0000 (NUL cannot live in a bash string)" '{"a":"x\u0000y","b":"z"}'
expect_rejected "a lone high surrogate"            '{"a":"\ud83dx","b":"z"}'
expect_rejected "a high surrogate + non-low"       '{"a":"\ud83d\u0041","b":"z"}'
expect_rejected "a lone low surrogate"             '{"a":"\ude00","b":"z"}'
expect_rejected "a short <bs>u escape"          '{"a":"\u12","b":"z"}'
expect_rejected "a non-hex <bs>u escape"        '{"a":"\u12g4","b":"z"}'
expect_rejected "an invalid escape <bs>x"       '{"a":"\x41","b":"z"}'
expect_rejected "an unterminated string"           '{"a":"abc}'
expect_rejected "garbage after a string value"     '{"a":"abc,"b":"z"}'
expect_rejected "a missing colon"                  '{"a" "x","b":"z"}'
expect_rejected "a missing value"                  '{"a":,"b":"z"}'
expect_rejected "a nested object value"            '{"a":{"x":"1"},"b":"z"}'
expect_rejected "an array value"                   '{"a":["x"],"b":"z"}'
expect_rejected "a trailing comma"                 '{"b":"z","a":"x",}'
expect_rejected "trailing garbage"                 '{"a":"x","b":"z"} junk'
expect_rejected "a missing closing brace"          '{"a":"x","b":"z"'
expect_rejected "not an object"                    '["a","b"]'
expect_rejected "an empty string"                  ''
expect_rejected "an unquoted key"                  '{a:"x","b":"z"}'
expect_rejected "a bare token with a quote"        '{"a":1"2","b":"z"}'

# ---------------------------------------------------------------------------
# 6. __class__ mismatch: rc 1, untouched, silent by default, one debug line.
kt_test_start "__class__ mismatch is rc 1 and leaves the instance untouched [DR2]"
from '{"__class__":"Other","a":"x","b":"y"}'
[[ $RC -eq 1 && "$GOT_A" == "SA" && "$GOT_B" == "SB" ]] && kt_test_pass "rc=1 untouched" \
    || kt_test_fail "rc=$RC a='$GOT_A' b='$GOT_B'"

kt_test_start "__class__ mismatch prints nothing without VERBOSE_KKLASS=debug"
j2.fromJSON '{"__class__":"Other","a":"x"}' > "$TMPD/mm.out" 2> "$TMPD/mm.err"; rc=$?
[[ $rc -eq 1 && ! -s "$TMPD/mm.out" && ! -s "$TMPD/mm.err" ]] && kt_test_pass "silent" \
    || kt_test_fail "rc=$rc out=$(<"$TMPD/mm.out") err=$(<"$TMPD/mm.err")"

kt_test_start "__class__ mismatch emits exactly one kk.debug line under debug"
VERBOSE_KKLASS=debug j2.fromJSON '{"__class__":"Other","a":"x"}' > "$TMPD/mm.out" 2> "$TMPD/mm.err"; rc=$?
mapfile -t ERRL < "$TMPD/mm.err"
[[ $rc -eq 1 && ! -s "$TMPD/mm.out" && ${#ERRL[@]} -eq 1 && "${ERRL[0]}" == *Other* ]] \
    && kt_test_pass "${ERRL[0]}" || kt_test_fail "rc=$rc lines=${#ERRL[@]} err=$(<"$TMPD/mm.err")"

kt_test_start "a malformed input is silent by default and one kk.debug line under debug"
j2.fromJSON '{"a":' > "$TMPD/mf.out" 2> "$TMPD/mf.err"; rc1=$?
VERBOSE_KKLASS=debug j2.fromJSON '{"a":' > "$TMPD/mf2.out" 2> "$TMPD/mf2.err"; rc2=$?
mapfile -t ERRL < "$TMPD/mf2.err"
[[ $rc1 -eq 1 && $rc2 -eq 1 && ! -s "$TMPD/mf.out" && ! -s "$TMPD/mf.err" && ! -s "$TMPD/mf2.out" && ${#ERRL[@]} -eq 1 ]] \
    && kt_test_pass "ok" || kt_test_fail "rc1=$rc1 rc2=$rc2 lines=${#ERRL[@]}"

kt_test_start "a successful fromJSON still prints the instance name (unchanged contract)"
out="$(j2.fromJSON '{"__class__":"TJ","a":"x"}')"; rc=$?
[[ $rc -eq 0 && "$out" == "j2" ]] && kt_test_pass "printed '$out'" || kt_test_fail "rc=$rc out='$out'"

# Inheritance: a subclass that inherits the serializer writes the serializer's
# class (unchanged) and must read its own output back.
defineClass TJSub TJ property c
TJSub.new s1
TJSub.new s2
kt_test_start "a subclass round-trips through the inherited serializer"
s1.a = 'sub,"v"'; s1.b = "B"
js="$(s1.toJSON)"
s2.fromJSON "$js" >/dev/null; rc=$?
read_a s2
[[ $rc -eq 0 && "$GOT_A" == 'sub,"v"' && "$js" == '{"__class__":"TJ",'* ]] && kt_test_pass "ok" \
    || kt_test_fail "rc=$rc a='$GOT_A' json=$js"

kt_test_start "the subclass accepts its own class name in __class__"
s2.fromJSON '{"__class__":"TJSub","a":"own"}' >/dev/null; rc=$?
read_a s2
[[ $rc -eq 0 && "$GOT_A" == "own" ]] && kt_test_pass "ok" || kt_test_fail "rc=$rc a='$GOT_A'"

defineClass TJOther "" property a property b
addSerializable TJOther "" json
TJOther.new o1
kt_test_start "an unrelated class's JSON is refused"
o1.a = "x"
js="$(o1.toJSON)"
from "$js"
[[ $RC -eq 1 && "$GOT_A" == "SA" ]] && kt_test_pass "rc=1" || kt_test_fail "rc=$RC a='$GOT_A'"

# ---------------------------------------------------------------------------
# 7. A full toJSON string stored in a property and round-tripped (C3).
kt_test_start "a nested toJSON string round-trips byte-exactly and decodes again [C3]"
j1.a = $'in "q" C:\\new\n,x:y}'; j1.b = "inner"
inner="$(j1.toJSON)"
TJ.new outer;  outer.a = "$inner"; outer.b = "outer"
outer_js="$(outer.toJSON)"
TJ.new outer2
outer2.fromJSON "$outer_js" >/dev/null; rc1=$?
read_a outer2; stored="$GOT_A"
TJ.new inner2
inner2.fromJSON "$stored" >/dev/null; rc2=$?
read_a inner2; read_b inner2
if [[ $rc1 -eq 0 && $rc2 -eq 0 && "$stored" == "$inner" && "$GOT_A" == $'in "q" C:\\new\n,x:y}' && "$GOT_B" == "inner" ]]; then
    kt_test_pass "two levels exact"
else
    kt_test_fail "rc1=$rc1 rc2=$rc2 stored-equal=$([[ $stored == "$inner" ]] && echo y || echo n) a-len=${#GOT_A} b='$GOT_B'"
fi

# ---------------------------------------------------------------------------
# 7b. Edges: the CR fixture, invalid UTF-8, the C locale, a long value, and
# the escaper with its fast-path guard missing.
kt_test_start "test sanity: the CR fixture really holds a CR"
[[ "${HV[8]}" == "cr${CR}x" && ${#HV[8]} -eq 4 ]] && kt_test_pass "4 chars" || kt_test_fail "HV[8] has ${#HV[8]} chars"

kt_test_start "invalid UTF-8 bytes next to escaped characters round-trip byte-exactly"
bad=$'\xff"\x01\xfe\\\xc3'
j1.a = "$bad"; j1.b = "B"
j2.fromJSON "$(j1.toJSON)" >/dev/null; rc=$?
read_a j2
[[ $rc -eq 0 && "$GOT_A" == "$bad" ]] && kt_test_pass "exact" || kt_test_fail "rc=$rc"

kt_test_start "the C locale: escaping and <bs>u decoding give the same bytes as in UTF-8"
out="$(
    export LC_ALL=C
    j1.a = $'é"\x01\n€'; j1.b = "B"
    js="$(j1.toJSON)"
    j2.fromJSON "$js" >/dev/null || exit 3
    j2.getA >/dev/null; a1="$RESULT"
    j2.fromJSON '{"a":"é€😀"}' >/dev/null || exit 4
    j2.getA >/dev/null
    [[ "$a1" == $'é"\x01\n€' && "$RESULT" == 'é€😀' ]] && printf ok
)"; rc=$?
[[ $rc -eq 0 && "$out" == ok ]] && kt_test_pass "ok" || kt_test_fail "rc=$rc out=$out"

kt_test_start "a long value (4000 chars, 1000 quotes and backslashes) round-trips"
long=""; for (( q = 0; q < 500; q++ )); do long+='ab"c\'; done; long+=$'\n'"$long"
j1.a = "$long"; j1.b = "B"
js="$(j1.toJSON)"
j2.fromJSON "$js" >/dev/null; rc=$?
read_a j2
[[ $rc -eq 0 && "$GOT_A" == "$long" && "$js" != *$'\n'* ]] && kt_test_pass "exact" || kt_test_fail "rc=$rc"

kt_test_start "without the fast-path guard (child shell case) toJSON is still correct"
out="$(
    unset __KK_JSON_SPECIAL
    j1.a = 'plain'; j1.b = $'q"\t'
    j1.toJSON
)"
[[ "$out" == '{"__class__":"TJ","a":"plain","b":"q\"\t"}' ]] && kt_test_pass "exact" || kt_test_fail "got: $out"

# ---------------------------------------------------------------------------
# 8. saveObjects / loadObjects: one line per object (DR2).
defineClass TJFile "" property name property note
addSerializable TJFile "" json
TJFile.new f1; f1.name = "one";   f1.note = $'line1\nline2'
TJFile.new f2; f2.name = 'two,"2"'; f2.note = $'tab\there\r'
TJFile.new f3; f3.name = "three"; f3.note = 'C:\new'
file="$TMPD/objects.jsonl"
saveObjects "$file" f1 f2 f3
mapfile -t LINES < "$file"
kt_test_start "saveObjects writes exactly one line per object with a newline in a value"
[[ ${#LINES[@]} -eq 3 ]] && kt_test_pass "3 lines" || kt_test_fail "${#LINES[@]} lines"

declare -a LOADED=()
loadObjects "$file" TJFile LOADED >/dev/null
kt_test_start "loadObjects restores every value byte-exactly"
ok=1
exp_names=("one" 'two,"2"' "three"); exp_notes=($'line1\nline2' $'tab\there'"$CR" 'C:\new')
for k in 0 1 2; do
    inst="${LOADED[$k]:-}"
    [[ -n "$inst" ]] || { ok=0; break; }
    declare -n chk="${inst}_data"          # exact bytes, no $( ) trimming
    [[ "${chk[name]}" == "${exp_names[$k]}" && "${chk[note]}" == "${exp_notes[$k]}" ]] || ok=0
    unset -n chk
done
[[ ${#LOADED[@]} -eq 3 && $ok -eq 1 ]] && kt_test_pass "3 objects exact" || kt_test_fail "loaded=${#LOADED[@]} ok=$ok"

# ---------------------------------------------------------------------------
# 9. Helper locals never shadow property names (cf. test 049).
defineClass TJShadow "" property s property r property e property j property i property c property h property n property k property v
addSerializable TJShadow "" json
TJShadow.new sh1; TJShadow.new sh2
for p in s r e j i c h n k v; do "sh1.$p" = "val-$p,\"$p\""; done
kt_test_start "short property names (s r e j i c h n k v) survive toJSON/fromJSON"
sh2.fromJSON "$(sh1.toJSON)" >/dev/null; rc=$?
ok=1
for p in s r e j i c h n k v; do [[ "$("sh2.$p")" == "val-$p,\"$p\"" ]] || ok=0; done
[[ $rc -eq 0 && $ok -eq 1 ]] && kt_test_pass "all 10 exact" || kt_test_fail "rc=$rc"

# A property called `state` shadows the frame's `state` nameref onto the
# instance store; the generated bodies then bind their own.
defineClass TJState "" property state property x
addSerializable TJState "" json
TJState.new st1; TJState.new st2
st1.state = $'on,"1"\n'; st1.x = 'C:\x'
kt_test_start "a class with a property named 'state' round-trips hostile values"
js="$(st1.toJSON)"
st2.fromJSON "$js" >/dev/null; rc=$?
declare -n chk=st2_data
[[ $rc -eq 0 && "${chk[state]}" == $'on,"1"\n' && "${chk[x]}" == 'C:\x' \
   && "$js" == '{"__class__":"TJState","state":"on,\"1\"\n","x":"C:\\x"}' ]] \
    && kt_test_pass "exact" || kt_test_fail "rc=$rc json=$js"
unset -n chk

# ---------------------------------------------------------------------------
# 10. set -u: an unset property and both directions.
kt_test_start "toJSON and fromJSON under set -u"
out="$(
    set -u
    TJ.new uu
    js="$(uu.toJSON)"
    uu.fromJSON '{"a":"x\ty","b":"z"}' >/dev/null || exit 3
    uu.getA >/dev/null
    printf '%s|%s' "$js" "$RESULT"
)"; rc=$?
[[ $rc -eq 0 && "$out" == $'{"__class__":"TJ","a":"","b":""}|x\ty' ]] && kt_test_pass "ok" || kt_test_fail "rc=$rc out=$out"

for o in j1 j2 s1 s2 o1 outer outer2 inner2 f1 f2 f3 sh1 sh2 st1 st2 "${LOADED[@]}"; do "$o.delete"; done
