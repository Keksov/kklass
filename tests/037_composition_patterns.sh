#!/bin/bash
# 037_composition_patterns.sh - Test composition patterns

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 37: Composition patterns
test_start "Composition patterns"
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
    test_pass "Composition patterns"
else
    test_fail "Composition patterns (expected car with engine and wheels, got: '$result')"
fi

mycar.delete