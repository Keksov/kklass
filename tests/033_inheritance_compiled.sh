#!/bin/bash
# 033_inheritance_compiled.sh - Test inheritance in compiled classes

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

TEST_NUM=$(basename "${BASH_SOURCE[0]}" | cut -d'_' -f1)
TEST_FILE="test_${TEST_NUM}.kk"

# Setup: Ensure $TEST_FILE exists and is compiled
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
test_start "Inheritance in compiled classes"
result=$(bash -c "source .ckk/\"${TEST_FILE%.*}\".ckk.sh && Timer.new tmr && tmr.value = 5 && tmr.increment")
if [[ "$result" == "6" ]]; then
    test_pass "Inheritance in compiled classes"
else
    test_fail "Inheritance in compiled classes (expected: 6, got: $result)"
fi