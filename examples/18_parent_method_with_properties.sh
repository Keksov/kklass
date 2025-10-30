#!/bin/bash
# Example 18: Method Calling Parent and Using Properties
# Demonstrates methods that call parent methods while accessing instance properties

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Method Calling Parent and Using Properties Example ==="
echo

# Define base class
defineClass "Shape" "" \
    "property" "name" \
    "property" "color" \
    "method" "describe" 'echo "Shape: $name (Color: $color)"'

# Define derived class with method that calls parent and uses properties
defineClass "Rectangle" "Shape" \
    "property" "width" \
    "property" "height" \
    "method" "describe" 'echo -n "Rectangle "; $this.parent describe; echo -n " ($width x $height)"' \
    "method" "area" 'echo $((width * height))' \
    "method" "perimeter" 'echo $((2 * (width + height)))'

# Create rectangle instance
Rectangle.new rect1

# Set properties
rect1.name = "MyRect"
rect1.color = "Blue"
rect1.width = "10"
rect1.height = "5"

echo "✓ Properties set:"
echo "  name: $(rect1.name)"
echo "  color: $(rect1.color)"
echo "  width: $(rect1.width)"
echo "  height: $(rect1.height)"

# Test the describe method that calls parent
echo "Rectangle description:"
result=$(rect1.describe)
echo "Result: $result"

# Test other methods
echo "Area: $(rect1.area)"
echo "Perimeter: $(rect1.perimeter)"

# Verify expected vs actual results
expected="Rectangle Shape: MyRect (Color: Blue) (10 x 5)"
if [[ "$result" == "$expected" ]]; then
    echo "✓ Parent method calls with properties working correctly"
else
    echo "✗ Parent method calls with properties failed (expected: '$expected', got: '$result')"
    exit 1
fi

# Clean up
rect1.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="