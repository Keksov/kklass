#!/bin/bash
# 030_force_recompilation.sh - Test force recompilation

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

# Test 30: Force compilation
test_start "Force recompilation"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkrecompile test_system.kk" 2>&1)
if echo "$output" | grep -q "Force\|Compiling"; then
    test_pass "Force recompilation"
else
    test_fail "Force recompilation"
fi