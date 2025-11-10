#!/bin/bash
# 027_autocompilation_first_load.sh - Test auto-compilation (first load)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

TEST_NUM=$(basename "${BASH_SOURCE[0]}" | cut -d'_' -f1)
TEST_FILE="test_${TEST_NUM}.kk"

# Clean up any previous test files
rm -f "$TEST_FILE" .ckk/"${TEST_FILE%.*}".ckk.sh

# Create test class file
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

test_info "Created $TEST_FILE"

# Test 27: First load with autocompilation
test_start "Auto-compilation (first load)"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" 2>&1)
if echo "$output" | grep -q "Compilation successful" && [[ -f .ckk/${TEST_FILE%.*}.ckk.sh ]]; then
    test_pass "Auto-compilation (first load)"
else
    test_fail "Auto-compilation (first load)"
fi