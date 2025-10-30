#!/bin/bash
# Example 13: Multiple Instances of Same Class
# Demonstrates creating and using multiple instances of the same class

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Multiple Instances Example ==="
echo

# Define a Point class
defineClass "Point" "" \
    "property" "x" \
    "property" "y" \
    "method" "coordinates" 'echo "($x,$y)"' \
    "method" "distance" 'local dx=$((x - $1)); local dy=$((y - $2)); echo "sqrt($((dx*dx + dy*dy)))"'

# Create multiple instances
Point.new point1
Point.new point2
Point.new point3

echo "✓ Three Point instances created"

# Set different coordinates for each point
point1.x = "10"
point1.y = "20"

point2.x = "30"
point2.y = "40"

point3.x = "50"
point3.y = "60"

echo "✓ Coordinates set for all points"

# Display coordinates for each point
echo "Point coordinates:"
echo "  Point 1: $(point1.coordinates)"
echo "  Point 2: $(point2.coordinates)"
echo "  Point 3: $(point3.coordinates)"

# Verify each instance has independent state
if [[ "$(point1.coordinates)" == "(10,20)" ]] && [[ "$(point2.coordinates)" == "(30,40)" ]]; then
    echo "✓ Multiple instances maintain independent state"
else
    echo "✗ Multiple instances state isolation failed"
    exit 1
fi

# Test method calls on different instances
echo "Distance from Point 1 to origin: $(point1.distance 0 0)"
echo "Distance from Point 2 to origin: $(point2.distance 0 0)"

# Clean up all instances
point1.delete
point2.delete
point3.delete
echo "✓ All instances cleaned up"

echo
echo "=== Example completed successfully ==="