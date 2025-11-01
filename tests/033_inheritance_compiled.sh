#!/bin/bash
# 033_inheritance_compiled.sh - Test inheritance in compiled classes

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Setup: Ensure test_system.kk exists and is compiled
if [[ ! -f test_system.kk ]]; then
    cat > test_system.kk <<'EOF'
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
bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload test_system.kk" >/dev/null 2>&1

# Test 33: Inheritance in compiled classes
test_start "Inheritance in compiled classes"
result=$(bash -c "source .ckk/test_system.ckk.sh && Timer.new tmr && tmr.value = 5 && tmr.increment")
if [[ "$result" == "6" ]]; then
    test_pass "Inheritance in compiled classes"
else
    test_fail "Inheritance in compiled classes (expected: 6, got: $result)"
fi