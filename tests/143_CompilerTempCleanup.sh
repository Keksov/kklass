#!/usr/bin/env bash
# CompilerTempCleanup (ktests round 5, E1 / DE1, 2026-10-16).
#
# kklass_compiler.sh translates a .kkp into a temporary folder made by a bare
# `mktemp -d` (a default `tmp.XXXXXXXXXX`), removed on its return paths only:
# a source that `exit`s (a used unit ending the process) or a TERM/INT/HUP left
# it in TMPDIR. Now the folder is named kklass_compiler.<pid>.* and an EXIT
# trap removes it, with TERM/INT/HUP exiting 128+N so the trap also runs on a
# signal (bash 5.2 runs no EXIT trap on a signal by itself).

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "CompilerTempCleanup" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPD="$(cd "$(kt_fixture_tmpdir)" && pwd)"
mkdir -p "$TMPD/home" "$TMPD/u"
printf 'unitpath = u\n' > "$TMPD/kb.conf"
cat > "$TMPD/Ex.kkp" <<'EOF'
unit Ex;
uses Boom;
interface
type
  TEx143 = class
  public
    function Hi;
  end;
implementation
function TEx143.Hi;
begin
RESULT=hi
end;
end.
EOF

# k143_compile NAME BOOM-BODY [timeout args...] — compile Ex.kkp with a used
# unit Boom whose body is BOOM-BODY, TMPDIR = $TMPD/NAME; RC, LEFT
k143_compile() {
    local name="$1" body="$2"; shift 2
    rm -rf "$TMPD/$name"; mkdir -p "$TMPD/$name"
    printf 'kk.unit Boom || return $__kk_unit_rc\n%s\n' "$body" > "$TMPD/u/Boom.sh"
    RC=0
    ( cd "$TMPD" && env -u KBOOL_HOME -u USERPROFILE -u ProgramData -u PROGRAMDATA \
        -u KKLASS_CKK_DIR -u KK_UNIT_DIR -u VERBOSE_KKLASS \
        HOME="$TMPD/home" TMPDIR="$TMPD/$name" KBOOL_CONFIG="$TMPD/kb.conf" \
        "$@" "$BASH" "$KKLASS_DIR/kklass_compiler.sh" Ex.kkp "Ex.$name.sh" >/dev/null 2>&1 ) || RC=$?
    LEFT="$(cd "$TMPD/$name" && ls -A)"
}

kt_test_start "the translation folder is named kklass_compiler.<pid>.* and removed after a compile [DE1]"
k143_compile ok 'ls -A "$TMPDIR" > "$TMPDIR/../seen.ok"'
seen="$(<"$TMPD/seen.ok")"
if [[ "$RC" == 0 && "$seen" == kklass_compiler.*.* && -z "$LEFT" && -s "$TMPD/Ex.ok.sh" ]]; then
    kt_test_pass "saw '$seen'; nothing left"
else
    kt_test_fail "rc=$RC seen='$seen' left='$LEFT'"
fi

kt_test_start "a used unit that exits the compiler: the translation folder is removed [DE1]"
k143_compile exit 'exit 7'
if [[ "$RC" == 7 && -z "$LEFT" ]]; then
    kt_test_pass "rc 7, nothing left"
else
    kt_test_fail "rc=$RC left='$LEFT'"
fi

kt_test_start "a compiler killed with TERM: the translation folder is removed, rc 143 [DE1]"
k143_compile term 'sleep 20' timeout -s TERM --preserve-status 3
if [[ "$RC" == 143 && -z "$LEFT" ]]; then
    kt_test_pass "rc 143, nothing left"
else
    kt_test_fail "rc=$RC left='$LEFT'"
fi

# review R4: a translation folder whose cleanup never ran (a used unit that
# drops the EXIT trap and exits; a SIGKILL) is swept by the NEXT compile: only
# kklass_compiler.<pid>.* of a pid that is not alive (and not this process).
# Review round 2, N5: only one older than an hour — another MSYS runtime
# sharing TMPDIR has pids `kill -0` cannot see; its LIVE compile's folder
# would go. A fresh folder of a dead-looking pid is kept.
kt_test_start "a compile sweeps an hour-old kklass_compiler.<dead pid>.*; a fresh one, a live pid's and other names are kept [R4, N5]"
k143_compile drop 'trap - EXIT; exit 3'
dropped="$LEFT"
fresh="kklass_compiler.$(bash -c 'echo $$').fresh"
mkdir -p "$TMPD/drop/kklass_compiler.$$.keep" "$TMPD/drop/kklass_compiler.abc.keep" "$TMPD/drop/other"
mkdir -p "$TMPD/drop/$fresh"
: > "$TMPD/drop/kklass_compiler.$$.keep/f"
[[ -n "$dropped" ]] && touch -d '2 hours ago' "$TMPD/drop/$dropped"
touch -d '2 hours ago' "$TMPD/drop/kklass_compiler.$$.keep" "$TMPD/drop/kklass_compiler.abc.keep"
# a second, normal compile into the SAME TMPDIR (k143_compile would empty it)
printf 'kk.unit Boom || return $__kk_unit_rc\n:\n' > "$TMPD/u/Boom.sh"
( cd "$TMPD" && env -u KBOOL_HOME -u USERPROFILE -u ProgramData -u PROGRAMDATA \
    -u KKLASS_CKK_DIR -u KK_UNIT_DIR -u VERBOSE_KKLASS \
    HOME="$TMPD/home" TMPDIR="$TMPD/drop" KBOOL_CONFIG="$TMPD/kb.conf" \
    "$BASH" "$KKLASS_DIR/kklass_compiler.sh" Ex.kkp Ex.drop2.sh >/dev/null 2>&1 )
left="$(cd "$TMPD/drop" && ls -A | sort | tr '\n' ' ')"
want="$(printf '%s\n' "kklass_compiler.$$.keep" kklass_compiler.abc.keep "$fresh" other | sort | tr '\n' ' ')"
if [[ "$dropped" == kklass_compiler.*.* && "$left" == "$want" ]]; then
    kt_test_pass "left by the dropped trap: $dropped; after the next compile: $left"
else
    kt_test_fail "dropped='$dropped' left='$left' want='$want'"
fi

kt_test_log "143_CompilerTempCleanup.sh completed"
