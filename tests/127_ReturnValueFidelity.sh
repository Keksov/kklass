#!/bin/bash
# ReturnValueFidelity (kcl review 2026-09-06: findings G1-13 / G2-03, X-ECHO).
#
# `kk._return` is the single value channel of the framework: every `func`, every
# `function`-kind computed property and (through them) every kcl container
# getter returns through it. Under `$( )` it used `echo -n "$value"`, so any
# value that bash's echo builtin parses as an OPTION was swallowed:
#
#   L.Add -e;  c="$(L.Get 0)"    -> c=''      (expected '-e')
#   Q.Enqueue -n; "$(Q.Peek)"    -> ''        (expected '-n')
#
# The direct-call path (RESULT) was always correct, so the whole test corpus
# stayed green while `$( )` — the form the tdictionary README advertises — lost
# data silently. `printf '%s'` is the fix. The static-method dispatcher and the
# computed-property reader already print with printf; they are pinned here too
# so a future edit cannot regress them back to echo.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ReturnValueFidelity" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"

defineClass TRvf "" \
    property v \
    property echoed getV \
    function getV 'RESULT="$v"' \
    function get 'RESULT="$1"' \
    static_method sget 'kk._return "$1"'

TRvf.new r

# Values bash's `echo` builtin treats as options, plus escapes `echo -e` (or a
# shell with xpg_echo on) would rewrite. LABELS mirror VALUES with the escapes
# spelled out, so the framework's own `echo -e` logging cannot eat the report.
VALUES=( '-e'  '-n'  '-E'  '-en'  '-neE'  '-nEe'  '-e -n'  'a\tb'    'a\nb'    '\'    '-e\c'    '-n0' )
LABELS=( '-e'  '-n'  '-E'  '-en'  '-neE'  '-nEe'  '-e -n'  'a<bs>tb' 'a<bs>nb' '<bs>'  '-e<bs>c' '-n0' )

# ---------------------------------------------------------------------------
for i in "${!VALUES[@]}"; do
    val="${VALUES[$i]}"
    kt_test_start "func value '${LABELS[$i]}' survives \$(obj.m) verbatim [G1-13]"
    got="$(r.get "$val")"
    if [[ "$got" == "$val" ]]; then
        kt_test_pass "round-tripped"
    else
        kt_test_fail "captured ${#got} bytes, expected ${#val}: '${got//\/<bs>}'"
    fi
done

# ---------------------------------------------------------------------------
for val in '-e' '-n' '-neE'; do
    kt_test_start "func value '$val' also reaches RESULT on a direct call [G1-13]"
    RESULT=""
    r.get "$val" >/dev/null
    [[ "$RESULT" == "$val" ]] && kt_test_pass "RESULT='$RESULT'" \
        || kt_test_fail "RESULT='$RESULT', expected '$val'"
done

# ---------------------------------------------------------------------------
for val in '-e' '-n' '-neE'; do
    kt_test_start "computed property value '$val' survives \$(obj.prop) [G1-13]"
    r.v = "$val"
    got="$(r.echoed)"
    [[ "$got" == "$val" ]] && kt_test_pass "captured '$got'" \
        || kt_test_fail "captured '$got', expected '$val'"
done

# ---------------------------------------------------------------------------
for val in '-e' '-n' '-neE'; do
    kt_test_start "static method value '$val' survives \$(Class.m) [G2-03]"
    got="$(TRvf.sget "$val")"
    [[ "$got" == "$val" ]] && kt_test_pass "captured '$got'" \
        || kt_test_fail "captured '$got', expected '$val'"
done

# ---------------------------------------------------------------------------
kt_test_start "a value that only LOOKS like an option prefix is untouched"
got="$(r.get -- -e)"
[[ "$got" == "--" ]] && kt_test_pass "captured '--'" || kt_test_fail "captured '$got'"

# ---------------------------------------------------------------------------
kt_test_start "\$( ) still prints the value exactly once (no double emit)"
got="$(r.get X)"
[[ "$got" == "X" ]] && kt_test_pass "captured 'X'" || kt_test_fail "captured '$got'"

# ---------------------------------------------------------------------------
kt_test_start "a direct call still prints nothing"
out_file="$(kt_fixture_tmpdir)/direct.out"
r.get -e >"$out_file"
bytes=$(wc -c <"$out_file")
[[ "$bytes" -eq 0 ]] && kt_test_pass "0 bytes" || kt_test_fail "$bytes bytes on a direct call"

r.delete
kt_test_log "127_ReturnValueFidelity.sh completed"
