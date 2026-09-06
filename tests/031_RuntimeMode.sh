#!/bin/bash
# RuntimeMode
# Auto-migrated from kklass test framework
#
# Hermetic since 2026-09-06 (kcl review "task 6" / decision R15): fixture and
# cache live in this test's private temp dir via KKLASS_CKK_DIR. The old version
# wrote `.ckk/` into $PWD (and its `rm -f .ckk/\"$TEST_FILE\".sh` never removed
# anything, because of the literal quotes in the name), so a sweep run from a
# unit directory left `<unit>/.ckk` behind.
#
# The assert accepted "runtime" OR "No compiled", both of which the message
# "[autoload] No compiled file found, using runtime mode" satisfies at once; it
# now pins that message, checks NO compiled file was produced, and checks the
# class really is usable after a runtime-mode load.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "RuntimeMode" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

TMP_DIR="$(cd "$(kt_fixture_tmpdir)" && pwd)"
CKK_DIR="$TMP_DIR/ckk"
TEST_FILE="$TMP_DIR/runtime_counter.kk"
COMPILED_FILE="$CKK_DIR/runtime_counter.ckk.sh"

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

# Test 31: Runtime mode (--no-compile)
kt_test_start "Runtime mode (--no-compile)"
output=$(KKLASS_CKK_DIR="$CKK_DIR" bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\" --no-compile" 2>&1)
usable=$(KKLASS_CKK_DIR="$CKK_DIR" bash -c "source '$KKLASS_DIR/kklass_autoload.sh'; kkload \"$TEST_FILE\" --no-compile >/dev/null 2>&1; Timer.new t; t.value = 4; t.increment" 2>&1)
if [[ "$output" == *"No compiled file found, using runtime mode"* \
      && ! -f "$COMPILED_FILE" \
      && "$usable" == "5" ]]; then
    kt_test_pass "Runtime mode (--no-compile)"
else
    kt_test_fail "Runtime mode (--no-compile)"
    kt_test_log "output: $output"
    kt_test_log "instance check: '$usable' (expected 5), compiled file present: $([[ -f "$COMPILED_FILE" ]] && echo yes || echo no)"
fi
