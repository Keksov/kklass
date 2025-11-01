#!/bin/bash
# 032_functional_test_compiled.sh - Test functional test with compiled classes

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Setup: Ensure test_system.kk exists
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

# Test 32: Functional test with compiled classes
test_start "Functional test with compiled classes"
bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload test_system.kk --force-compile" >/dev/null 2>&1
result=$(bash -c "source .ckk/test_system.ckk.sh && Counter.new cnt && cnt.value = 7 && cnt.increment")
if [[ "$result" == "8" ]]; then
    test_pass "Functional test with compiled classes"
else
    test_fail "Functional test with compiled classes (expected: 8, got: $result)"
fi