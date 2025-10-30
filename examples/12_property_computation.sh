#!/bin/bash
# Example 12: Property Access and Computation in Methods
# Demonstrates how methods can access and perform computations with instance properties

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Property Access and Computation in Methods Example ==="
echo

# Define a Calculator class that uses properties in computations
defineClass "Calculator2" "" \
    "property" "value" \
    "property" "multiplier" \
    "method" "double" 'echo $((value * 2))' \
    "method" "triple" 'echo $((value * 3))' \
    "method" "multiply" 'echo $((value * multiplier))' \
    "method" "add" 'echo $((value + $1))' \
    "method" "getValue" 'echo "$value"'

# Create calculator instance
Calculator2.new calc2

# Set initial value
calc2.value = "7"
calc2.multiplier = "5"

echo "✓ Calculator initialized with value=7, multiplier=5"

# Test computations using properties
echo "Current value: $(calc2.getValue)"
echo "Double the value: $(calc2.double)"
echo "Triple the value: $(calc2.triple)"
echo "Value multiplied by multiplier: $(calc2.multiply)"
echo "Add 10 to value: $(calc2.add 10)"

# Verify specific results
result1=$(calc2.double)
result2=$(calc2.triple)

if [[ "$result1" == "14" ]] && [[ "$result2" == "21" ]]; then
    echo "✓ Property-based computations working correctly"
else
    echo "✗ Property-based computations failed (expected: '14' and '21', got: '$result1' and '$result2')"
    exit 1
fi

# Change the value and see computations update
calc2.value = "10"
echo "Changed value to: $(calc2.getValue)"
echo "New double: $(calc2.double)"
echo "New triple: $(calc2.triple)"

# Clean up
calc2.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="