#!/bin/bash
# 028_using_cached_compiled_version.sh - Test using cached compiled version

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

TEST_NUM=$(basename "${BASH_SOURCE[0]}" | cut -d'_' -f1)
TEST_FILE="test_${TEST_NUM}.kk"

# Setup: Ensure $TEST_FILE exists and is already compiled
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

# Compile it first
bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" >/dev/null 2>&1

# Test 28: Second load (use cached)
test_start "Using cached compiled version"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" 2>&1)
if echo "$output" | grep -q "cached"; then
    test_pass "Using cached compiled version"
else
    test_fail "Using cached compiled version"
fi