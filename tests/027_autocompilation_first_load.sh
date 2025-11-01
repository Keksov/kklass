#!/bin/bash
# 027_autocompilation_first_load.sh - Test auto-compilation (first load)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh
rm -rf .ckk 2>/dev/null || true

# Create test class file
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

test_info "Created test_system.kk"

# Test 27: First load with autocompilation
test_start "Auto-compilation (first load)"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload test_system.kk" 2>&1)
if echo "$output" | grep -q "Compilation successful" && [[ -f .ckk/test_system.ckk.sh ]]; then
    test_pass "Auto-compilation (first load)"
else
    test_fail "Auto-compilation (first load)"
fi