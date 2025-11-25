#!/bin/bash
# FunctionalTestCompiled
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "FunctionalTestCompiled" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



TEST_NUM=$(basename "${BASH_SOURCE[0]}" | cut -d'_' -f1)
TEST_FILE="$SCRIPT_DIR/.ckk/test_${TEST_NUM}.kk"

# Setup: Ensure $TEST_FILE exists
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

# Test 32: Functional test with compiled classes
kk_test_start "Functional test with compiled classes"
bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\" --force-compile" >/dev/null 2>&1
 result=$(bash -c "source \"${TEST_FILE%.*}\".ckk.sh && Counter.new cnt && cnt.value = 7 && cnt.increment")
if [[ "$result" == "8" ]]; then
    kk_test_pass "Functional test with compiled classes"
else
kk_test_fail "Functional test with compiled classes (expected: 8, got: $result)"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
