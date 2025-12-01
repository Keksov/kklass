#!/bin/bash
# CompositionPatterns
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "CompositionPatterns" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 37: Composition patterns
kt_test_start "Composition patterns"
defineClass "Engine" "" \
    "property" "type" \
    "property" "horsepower" \
    "method" "getInfo" 'echo "Engine: $type ($horsepower HP)"'

defineClass "Wheel" "" \
    "property" "position" \
    "property" "size" \
    "method" "getInfo" 'echo "Wheel $position: $size inches"'

defineClass "CarComposition" "" \
    "property" "make" \
    "property" "model" \
    "property" "engine" \
    "property" "wheels" \
    "method" "assemble" 'Engine.new engine; Wheel.new wheel1; Wheel.new wheel2; engine.type = "V8"; engine.horsepower = "350"; wheel1.position = "front"; wheel2.position = "rear"; wheel1.size = "18"; wheel2.size = "18"; engine="engine"; wheels="wheel1 wheel2"' \
    "method" "getInfo" 'echo "$make $model"; $engine.getInfo; for w in $wheels; do $w.getInfo; done'

CarComposition.new mycar
mycar.make = "Toyota"
mycar.model = "Camry"
mycar.assemble

result=$(mycar.getInfo)
if [[ "$result" == *"Toyota Camry"* ]] && [[ "$result" == *"V8"* ]] && [[ "$result" == *"18 inches"* ]]; then
    kt_test_pass "Composition patterns"
else
    kt_test_fail "Composition patterns (expected car with engine and wheels, got: '$result')"
fi

mycar.delete

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
