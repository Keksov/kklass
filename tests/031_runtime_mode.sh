#!/bin/bash
# 031_runtime_mode.sh - Test runtime mode (--no-compile)

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

# Test 31: Runtime mode (--no-compile)
test_start "Runtime mode (--no-compile)"
rm -f .ckk/test_system.ckk.sh
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload test_system.kk --no-compile" 2>&1)
if echo "$output" | grep -q "runtime\|No compiled"; then
    test_pass "Runtime mode (--no-compile)"
else
    test_fail "Runtime mode (--no-compile)"
fi