#!/bin/bash
# ParentMethodWithProperties
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ParentMethodWithProperties" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 18: Method calling parent and using properties
kt_test_start "Method calling parent and using properties"
defineClass "Shape" "" \
    "property" "name" \
    "method" "describe" 'kl.write "Shape: $name"'

defineClass "Rectangle" "Shape" \
    "property" "width" \
    "property" "height" \
    "method" "describe" 'kl.write "Rectangle "; $this.parent describe; kl.write " ($width x $height)"'

Rectangle.new rect1
rect1.name = "MyRect"
rect1.width = "10"
rect1.height = "5"
result=$(rect1.describe)
expected="Rectangle Shape: MyRect (10 x 5)"
if [[ "$result" == "$expected" ]]; then
    kt_test_pass "Method calling parent and using properties"
else
    kt_test_fail "Method calling parent and using properties (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
