#!/bin/bash
# ParentMethodWithProperties
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "ParentMethodWithProperties" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 18: Method calling parent and using properties
kk_test_start "Method calling parent and using properties"
defineClass "Shape" "" \
    "property" "name" \
    "method" "describe" 'kk.write "Shape: $name"'

defineClass "Rectangle" "Shape" \
    "property" "width" \
    "property" "height" \
    "method" "describe" 'kk.write "Rectangle "; $this.parent describe; kk.write " ($width x $height)"'

Rectangle.new rect1
rect1.name = "MyRect"
rect1.width = "10"
rect1.height = "5"
result=$(rect1.describe)
expected="Rectangle Shape: MyRect (10 x 5)"
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Method calling parent and using properties"
else
    kk_test_fail "Method calling parent and using properties (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
