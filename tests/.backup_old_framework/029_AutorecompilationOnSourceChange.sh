#!/bin/bash
# 029_autorecompilation_on_source_change.sh - Test auto-recompilation on source change

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

TEST_NUM=$(basename "${BASH_SOURCE[0]}" | cut -d'_' -f1)
TEST_FILE=".ckk/test_${TEST_NUM}.kk"

# Setup: Ensure $TEST_FILE exists and is compiled
mkdir -p .ckk
if [[ ! -f "$TEST_FILE" ]]; then
cat > "$TEST_FILE" <<'EOF'
defineClass Counter "" 
    property value 
    method increment 'value=$((value + 1)); echo $value' 
    method getValue 'echo $value'
EOF
    bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" >/dev/null 2>&1
fi

# Test 29: Modify source and auto-recompile
test_start "Auto-recompilation on source change"
sleep 1
touch "$TEST_FILE"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload \"$TEST_FILE\"" 2>&1)
if echo "$output" | grep -q "newer\|Compiling"; then
    test_pass "Auto-recompilation on source change"
else
    test_fail "Auto-recompilation on source change"
fi