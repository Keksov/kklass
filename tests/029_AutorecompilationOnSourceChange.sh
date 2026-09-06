#!/bin/bash
# AutorecompilationOnSourceChange
# Auto-migrated from kklass test framework
#
# Hermetic since 2026-09-05: private fixture + KKLASS_CKK_DIR, rebuilt on every
# run; the compiled file is aged with touch instead of `sleep 1`. The old
# fixture lacked the line continuations, so it never compiled and the test
# passed through the "Compilation failed" path; it now checks a real recompile.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "AutorecompilationOnSourceChange" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

TMP_DIR="$(cd "$(kt_fixture_tmpdir)" && pwd)"
CKK_DIR="$TMP_DIR/ckk"
TEST_FILE="$TMP_DIR/changing_counter.kk"
COMPILED_FILE="$CKK_DIR/changing_counter.ckk.sh"

rm -rf "$CKK_DIR"
mkdir -p "$CKK_DIR"
cat > "$TEST_FILE" <<'EOF'
defineClass Counter "" \
    property value \
    method increment 'value=$((value + 1)); echo $value' \
    method getValue 'echo $value'
EOF

kkload_here() {
    KKLASS_CKK_DIR="$CKK_DIR" bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" 2>&1
}

first_output="$(kkload_here)"
# Age the compiled file, then change the source: the source is now strictly newer.
touch -d '2001-01-01 00:00:00' "$COMPILED_FILE"
printf '\n' >> "$TEST_FILE"

# Test 29: Modify source and auto-recompile
kt_test_start "Auto-recompilation on source change"
output="$(kkload_here)"
if [[ "$first_output" == *"Compilation successful"* && "$output" == *"Source file is newer"* && "$output" == *"Compilation successful"* && ! "$COMPILED_FILE" -ot "$TEST_FILE" ]]; then
    kt_test_pass "Auto-recompilation on source change"
else
    kt_test_fail "Auto-recompilation on source change"
    kt_test_log "first load: $first_output"
    kt_test_log "second load: $output"
fi
