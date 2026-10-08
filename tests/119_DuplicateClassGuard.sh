#!/bin/bash
# DuplicateClassGuard - kklass refuses to build over a class name that a
# DIFFERENT declaration site already registered (an accidental second definition,
# or a user class colliding with a library one): "Duplicate identifier", rc 1, one
# error naming both sites. A re-source of the SAME file (the same site — the
# diamond-include case of a file without a unit header) is ignored with one
# WARNING (uses U20/U21): the class is not rebuilt. Sites: _KKLASS_CLASS_SITE;
# file parts compared with -ef, so one file reached two ways (a .. spelling) is
# the same site. Full matrix: test 139.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "DuplicateClassGuard" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass_pascal.sh"

# --- workspace: separate files that define the same class name differently ---
# NOTE: helper files are sourced in the CURRENT shell (never via $(...)), so the
# classes they build persist and so does the guard's process-wide ownership
# registry. stderr is captured to a file instead — a $() around `source` would
# run the whole file in a subshell and lose every class it builds.
TMPD="${TMPDIR:-/tmp}/kk119_$$"
mkdir -p "$TMPD/sub"
ERRF="$TMPD/err.txt"
# Cleanup via the framework (never `trap … EXIT`: it would replace kt_test_init's
# trap, so the fixture teardown would not run).
kk119_cleanup() { rm -rf "$TMPD"; }
kt_fixture_cleanup_register kk119_cleanup

cat > "$TMPD/orig.sh" <<'EOF'
class TDupGuard
    public
        func Who
end
TDupGuard.Who() { RESULT="ORIGINAL"; }
build TDupGuard
EOF

cat > "$TMPD/imposter.sh" <<'EOF'
class TDupGuard
    public
        func Who
end
TDupGuard.Who() { RESULT="IMPOSTER"; }
build TDupGuard

class TDupGuardTail
    public
        func Tag
end
TDupGuardTail.Tag() { RESULT="tail"; }
build TDupGuardTail
EOF

# ---------------------------------------------------------------------------
kt_test_start "first definition builds and works"
source "$TMPD/orig.sh"; rc=$?
TDupGuard.new g1; g1.Who >/dev/null; who=$RESULT; g1.delete
if [[ $rc -eq 0 && "$who" == "ORIGINAL" ]]; then
    kt_test_pass "first definition builds and works"
else
    kt_test_fail "rc=$rc who=$who (expected ORIGINAL)"
fi

# ---------------------------------------------------------------------------
kt_test_start "re-source of the SAME file (same declaration site, no unit header): ignored with ONE WARNING (U20)"
: >"$ERRF"
source "$TMPD/orig.sh" 2>"$ERRF"; rc=$?
err="$(<"$ERRF")"
TDupGuard.new g2; g2.Who >/dev/null; who=$RESULT; g2.delete
if [[ $rc -eq 0 && "$err" == *WARNING* && "$err" == *"'TDupGuard'"* && "$err" != *$'\n'* && "$who" == "ORIGINAL" ]]; then
    kt_test_pass "re-source of the same file ignored, one WARNING"
else
    kt_test_fail "rc=$rc err='$err' who=$who"
fi

# ---------------------------------------------------------------------------
kt_test_start "redefinition from a DIFFERENT file is refused with a locating message"
: >"$ERRF"
source "$TMPD/imposter.sh" 2>"$ERRF"      # current shell: TDupGuardTail must persist
err="$(<"$ERRF")"
if [[ "$err" == *"Duplicate identifier"* && "$err" == *"TDupGuard"* \
      && "$err" == *"orig.sh:1"* && "$err" == *"imposter.sh:1"* && "$err" != *$'\n'* ]]; then
    kt_test_pass "collision refused with ONE error naming both sites"
else
    kt_test_fail "message did not locate the collision: '$err'"
fi

# ---------------------------------------------------------------------------
kt_test_start "original class survives a refused redefinition (not clobbered)"
TDupGuard.new g3; g3.Who >/dev/null; who=$RESULT; g3.delete
if [[ "$who" == "ORIGINAL" ]]; then
    kt_test_pass "still ORIGINAL after the imposter was refused"
else
    kt_test_fail "original clobbered to '$who'"
fi

# ---------------------------------------------------------------------------
kt_test_start "collision is per-NAME: a later class in the same file still builds"
# imposter.sh defined TDupGuardTail AFTER the refused TDupGuard build; the
# refusal must not abort the rest of that file.
if declare -F TDupGuardTail.new >/dev/null; then
    TDupGuardTail.new t1; t1.Tag >/dev/null; tag=$RESULT; t1.delete
    [[ "$tag" == "tail" ]] && kt_test_pass "TDupGuardTail built and works" \
        || kt_test_fail "TDupGuardTail tag=$tag"
else
    kt_test_fail "TDupGuardTail was not built (collision aborted the file)"
fi

# ---------------------------------------------------------------------------
kt_test_start "-ef identity (U18'): the same file via a .. path is the same site (WARNING), NOT a false collision"
: >"$ERRF"
source "$TMPD/sub/../orig.sh" 2>"$ERRF"; rc=$?
err="$(<"$ERRF")"
if [[ $rc -eq 0 && "$err" == *WARNING* && "$err" != *Duplicate* ]]; then
    kt_test_pass "'..' spelling of the owner path is the same site"
else
    kt_test_fail "false collision on a .. path: rc=$rc err='$err'"
fi

kt_test_log "119_DuplicateClassGuard.sh completed"
