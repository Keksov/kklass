#!/bin/bash
# InheritanceCompiled
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "InheritanceCompiled" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



TEST_NUM=$(basename "${BASH_SOURCE[0]}" | cut -d'_' -f1)
TEST_FILE="$SCRIPT_DIR/.ckk/test_${TEST_NUM}.kk"

# Setup: Ensure $TEST_FILE exists and is compiled
mkdir -p .ckk
if [[ ! -f "$TEST_FILE" ]]; then
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
fi

# Ensure it's compiled
bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" >/dev/null 2>&1

# Test 33: Inheritance in compiled classes
kt_test_start "Inheritance in compiled classes"
result=$(bash -c "source \"${TEST_FILE%.*}\".ckk.sh && Timer.new tmr && tmr.value = 5 && tmr.increment")
if [[ "$result" == "6" ]]; then
    kt_test_pass "Inheritance in compiled classes"
else
    kt_test_fail "Inheritance in compiled classes (expected: 6, got: $result)"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
