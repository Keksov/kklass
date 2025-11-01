#!/bin/bash
# 029_autorecompilation_on_source_change.sh - Test auto-recompilation on source change

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 29: Modify source and auto-recompile
test_start "Auto-recompilation on source change"
sleep 1
touch test_system.kk
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload test_system.kk" 2>&1)
if echo "$output" | grep -q "newer\|Compiling"; then
    test_pass "Auto-recompilation on source change"
else
    test_fail "Auto-recompilation on source change"
fi