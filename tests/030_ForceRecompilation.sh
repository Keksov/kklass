#!/bin/bash
# ForceRecompilation
# Auto-migrated from kklass test framework
#
# Hermetic since 2026-09-06 (kcl review finding "task 6" / decision R15): the
# fixture and the compiled cache live in this test's private temp dir via
# KKLASS_CKK_DIR. Before that the test wrote `.ckk/` into $PWD, so a sweep
# started from a kcl unit directory left a stray `kcl/<unit>/.ckk` behind —
# four of them were still in the tree in July.
#
# The assert was also "output contains Force OR Compiling", which passes on the
# failure path too; it now pins the force marker, a successful compile, and a
# compiled file that is actually newer than the one the first load produced.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ForceRecompilation" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

TMP_DIR="$(cd "$(kt_fixture_tmpdir)" && pwd)"
CKK_DIR="$TMP_DIR/ckk"
TEST_FILE="$TMP_DIR/force_counter.kk"
COMPILED_FILE="$CKK_DIR/force_counter.ckk.sh"

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

# First load compiles; then age the artefact so "recompiled" is observable.
KKLASS_CKK_DIR="$CKK_DIR" bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" >/dev/null 2>&1
touch -d '2001-01-01 00:00:00' "$COMPILED_FILE"

# Test 30: Force compilation
kt_test_start "Force recompilation"
output=$(KKLASS_CKK_DIR="$CKK_DIR" bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkrecompile \"$TEST_FILE\"" 2>&1)
if [[ "$output" == *"Force compilation requested"* \
      && "$output" == *"Compilation successful"* \
      && -s "$COMPILED_FILE" \
      && "$COMPILED_FILE" -nt "$TEST_FILE" ]]; then
    kt_test_pass "Force recompilation"
else
    kt_test_fail "Force recompilation"
    kt_test_log "output: $output"
fi
