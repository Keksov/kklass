#!/bin/bash
# AutorecompilationOnSourceChange
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "AutorecompilationOnSourceChange" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



TEST_NUM=$(basename "${BASH_SOURCE[0]}" | cut -d'_' -f1)
TEST_FILE=".ckk/test_${TEST_NUM}.kk"

# Setup: Ensure $TEST_FILE exists and is compiled
mkdir -p .ckk
if [[ ! -f "$TEST_FILE" ]]; then
cat > "$TEST_FILE" <<'EOF'
defineClass Counter "" 
    property value 
    method increment 'value=$((value + 1)); echo $value' 
    method getValue 'echo $value'
EOF
    bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" >/dev/null 2>&1
fi

# Test 29: Modify source and auto-recompile
kk_test_start "Auto-recompilation on source change"
sleep 1
touch "$TEST_FILE"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" 2>&1)
if echo "$output" | grep -q "newer\|Compiling"; then
    kk_test_pass "Auto-recompilation on source change"
else
    kk_test_fail "Auto-recompilation on source change"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
