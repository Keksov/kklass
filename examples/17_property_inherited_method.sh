#!/bin/bash
# Example 17: Property Used in Inherited Method
# Demonstrates accessing inherited properties within methods

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Property Used in Inherited Method Example ==="
echo

# Define base class
defineClass "Vehicle" "" \
    "property" "speed" \
    "property" "make" \
    "method" "getSpeed" 'echo "Speed: $speed km/h"' \
    "method" "getMake" 'echo "Make: $make"'

# Define derived class that uses inherited properties in its methods
defineClass "Car" "Vehicle" \
    "property" "brand" \
    "property" "model" \
    "method" "info" 'echo "Brand: $brand, Model: $model"; $this.getSpeed; $this.getMake' \
    "method" "fullDescription" 'echo "This is a $brand $model made by $make, traveling at $speed km/h"'

# Create car instance
Car.new car1

# Set properties from both base and derived class
car1.brand = "Toyota"
car1.model = "Camry"
car1.speed = "120"
car1.make = "Toyota Motor Corporation"

echo "✓ Properties set:"
echo "  brand: $(car1.brand)"
echo "  model: $(car1.model)"
echo "  speed: $(car1.speed)"
echo "  make: $(car1.make)"

# Test method that uses inherited properties
echo "Car info:"
result=$(car1.info)
echo "Result: $result"

# Test more complex method
echo "Full description:"
result2=$(car1.fullDescription)
echo "Result: $result2"

# Verify expected vs actual results
expected="Brand: Toyota, Model: CamrySpeed: 120 km/hMake: Toyota Motor Corporation"
if [[ "$result" == "$expected" ]]; then
    echo "✓ Property access in inherited methods working correctly"
else
    echo "✗ Property access in inherited methods failed (expected: '$expected', got: '$result')"
    exit 1
fi

# Clean up
car1.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="