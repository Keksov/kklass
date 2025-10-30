#!/bin/bash
# Example 34: Composition Patterns
# Demonstrates objects containing other objects as properties (composition over inheritance)

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Composition Patterns Example ==="
echo

# Define component classes
defineClass "Engine" "" \
    "property" "type" \
    "property" "horsepower" \
    "method" "start" 'echo "Engine $type started ($horsepower HP)"' \
    "method" "stop" 'echo "Engine $type stopped"' \
    "method" "getInfo" 'echo "Engine: $type ($horsepower HP)"'

defineClass "Wheel" "" \
    "property" "position" \
    "property" "size" \
    "method" "rotate" 'echo "Wheel at $position rotating"' \
    "method" "getInfo" 'echo "Wheel $position: $size inches"'

defineClass "Car" "" \
    "property" "make" \
    "property" "model" \
    "property" "engine" \
    "property" "wheels" \
    "method" "assemble" 'echo "Assembling $make $model"; Engine.new engine; Wheel.new wheel1; Wheel.new wheel2; Wheel.new wheel3; Wheel.new wheel4; engine.type = "V8"; engine.horsepower = "350"; wheel1.position = "front-left"; wheel2.position = "front-right"; wheel3.position = "rear-left"; wheel4.position = "rear-right"; wheel1.size = "18"; wheel2.size = "18"; wheel3.size = "18"; wheel4.size = "18"; engine="engine"; wheels="wheel1 wheel2 wheel3 wheel4"' \
    "method" "start" 'echo "Starting $make $model"; $engine.start' \
    "method" "drive" 'echo "Driving $make $model"; for wheel in $wheels; do $wheel.rotate; done' \
    "method" "getInfo" 'echo "Car: $make $model"; $engine.getInfo; for wheel in $wheels; do $wheel.getInfo; done'

# Create a car instance
Car.new myCar

echo "✓ Car class defined with composition"

# Assemble the car (create engine and wheels)
myCar.assemble

echo "✓ Car assembled"

# Test the composed functionality
echo
echo "=== Testing Composed Object Functionality ==="
echo "Car info:"
myCar.getInfo

echo
echo "Starting car:"
myCar.start

echo
echo "Driving car:"
myCar.drive

# Verify composition is working
car_info=$(myCar.getInfo)
if [[ "$car_info" == *"V8"* ]] && [[ "$car_info" == *"18 inches"* ]]; then
    echo "✓ Composition working correctly - car contains engine and wheels"
else
    echo "✗ Composition failed"
    exit 1
fi

# Demonstrate that composed objects maintain their independence
echo
echo "=== Component Independence ==="
echo "Engine can be accessed independently:"
engine=$(myCar.engine)
$engine.getInfo

echo "Individual wheel access:"
wheels=($(myCar.wheels))
${wheels[0]}.getInfo

# Clean up (need to delete all composed objects)
myCar.delete
echo "✓ Car and all composed objects cleaned up"

echo
echo "=== Example completed successfully ==="