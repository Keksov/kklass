#!/bin/bash
# AutorecompilationOnSourceChange
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "AutorecompilationOnSourceChange" "$(dirname "$0")" "$@"

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
kt_test_start "Auto-recompilation on source change"
sleep 1
touch "$TEST_FILE"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" 2>&1)
if echo "$output" | grep -q "newer\|Compiling"; then
    kt_test_pass "Auto-recompilation on source change"
else
    kt_test_fail "Auto-recompilation on source change"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
