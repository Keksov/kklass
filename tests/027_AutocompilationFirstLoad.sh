#!/bin/bash
# AutocompilationFirstLoad
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "AutocompilationFirstLoad" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



TEST_NUM=$(basename "${BASH_SOURCE[0]}" | cut -d'_' -f1)
TEST_FILE="$SCRIPT_DIR/.ckk/test_${TEST_NUM}.kk"

# Clean up any previous test files
mkdir -p "$SCRIPT_DIR/.ckk"
rm -f "$TEST_FILE" "$SCRIPT_DIR/.ckk/${TEST_FILE%.*}.ckk.sh"

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

kk_test_log "Created $TEST_FILE"

# Test 27: First load with autocompilation
kk_test_start "Auto-compilation (first load)"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" 2>&1)
if echo "$output" | grep -q "Compilation successful" && [[ -f "${TEST_FILE%.*}.ckk.sh" ]]; then
    kk_test_pass "Auto-compilation (first load)"
else
    kk_test_fail "Auto-compilation (first load)"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
