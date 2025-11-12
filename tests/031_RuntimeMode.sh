#!/bin/bash
# 031_runtime_mode.sh - Test runtime mode (--no-compile)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

TEST_NUM=$(basename "${BASH_SOURCE[0]}" | cut -d'_' -f1)
TEST_FILE=".ckk/test_${TEST_NUM}.kk"

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

# Test 31: Runtime mode (--no-compile)
test_start "Runtime mode (--no-compile)"
rm -f .ckk/\"$TEST_FILE\".sh
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\" --no-compile" 2>&1)
if echo "$output" | grep -q "runtime\|No compiled"; then
    test_pass "Runtime mode (--no-compile)"
else
    test_fail "Runtime mode (--no-compile)"
fi