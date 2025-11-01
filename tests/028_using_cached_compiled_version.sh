#!/bin/bash
# 028_using_cached_compiled_version.sh - Test using cached compiled version

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Setup: Ensure test_system.kk exists and is already compiled
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

# Compile it first
bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload test_system.kk" >/dev/null 2>&1

# Test 28: Second load (use cached)
test_start "Using cached compiled version"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload test_system.kk" 2>&1)
if echo "$output" | grep -q "cached"; then
    test_pass "Using cached compiled version"
else
    test_fail "Using cached compiled version"
fi