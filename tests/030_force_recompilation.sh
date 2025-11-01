#!/bin/bash
# 030_force_recompilation.sh - Test force recompilation

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

TEST_NUM=$(basename "${BASH_SOURCE[0]}" | cut -d'_' -f1)
TEST_FILE="test_${TEST_NUM}.kk"

# Setup: Ensure $TEST_FILE exists
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

# Test 30: Force compilation
test_start "Force recompilation"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkrecompile \"$TEST_FILE\"" 2>&1)
if echo "$output" | grep -q "Force\|Compiling"; then
    test_pass "Force recompilation"
else
    test_fail "Force recompilation"
fi