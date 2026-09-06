#!/bin/bash
# UsingCachedCompiledVersion
# Auto-migrated from kklass test framework
#
# Hermetic since 2026-09-05: the fixture and the compiled cache live in this
# test's private temp dir (KKLASS_CKK_DIR), are rebuilt on every run, and the
# freshness relation is pinned with explicit mtimes instead of relying on what
# an earlier run (or another bash version) left in tests/.ckk.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "UsingCachedCompiledVersion" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

TMP_DIR="$(cd "$(kt_fixture_tmpdir)" && pwd)"
CKK_DIR="$TMP_DIR/ckk"
TEST_FILE="$TMP_DIR/cached_counter.kk"
COMPILED_FILE="$CKK_DIR/cached_counter.ckk.sh"

rm -rf "$CKK_DIR"
mkdir -p "$CKK_DIR"
cat > "$TEST_FILE" <<'EOF'
defineClass Counter "" \
    property value \
    method increment 'value=$((value + 1)); echo $value' \
    method getValue 'echo $value'

defineClass Timer Counter \
    property start_time \
    method startTimer 'start_time=$(date +%s); echo "Timer started"' \
    method elapsed 'local now=$(date +%s); echo $((now - start_time))'
EOF

kkload_here() {
    KKLASS_CKK_DIR="$CKK_DIR" bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" 2>&1
}

# First load compiles. Then make the source strictly older than the compiled
# file so the second load cannot depend on same-second timestamps.
first_output="$(kkload_here)"
touch -d '2001-01-01 00:00:00' "$TEST_FILE"

# Test 28: Second load (use cached)
kt_test_start "Using cached compiled version"
output="$(kkload_here)"
if [[ "$first_output" == *"Compilation successful"* && -f "$COMPILED_FILE" && "$output" == *"Using cached compiled file"* ]]; then
    kt_test_pass "Using cached compiled version"
else
    kt_test_fail "Using cached compiled version"
    kt_test_log "first load: $first_output"
    kt_test_log "second load: $output"
fi
