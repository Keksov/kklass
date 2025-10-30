#!/bin/bash
# Example 10: Method with Parameters
# Demonstrates methods that accept parameters and perform calculations

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Method with Parameters Example ==="
echo

# Define a Calculator class with methods that take parameters
defineClass "Calculator" "" \
    "property" "name" \
    "method" "add" 'echo $(($1 + $2))' \
    "method" "multiply" 'echo $(($1 * $2))' \
    "method" "subtract" 'echo $(($1 - $2))' \
    "method" "divide" 'echo $(($1 / $2))' \
    "method" "power" 'echo $(($1 ** $2))'

# Create calculator instance
Calculator.new calc
calc.name = "MyCalculator"

echo "✓ Calculator instance created"

# Test various mathematical operations
echo "Testing mathematical operations:"
echo "5 + 3 = $(calc.add 5 3)"
echo "5 * 3 = $(calc.multiply 5 3)"
echo "5 - 3 = $(calc.subtract 5 3)"
echo "15 / 3 = $(calc.divide 15 3)"
echo "2 ^ 3 = $(calc.power 2 3)"

# Verify specific results
result_add=$(calc.add 5 3)
result_multiply=$(calc.multiply 5 3)

if [[ "$result_add" == "8" ]] && [[ "$result_multiply" == "15" ]]; then
    echo "✓ Parameterized methods working correctly"
else
    echo "✗ Parameterized methods failed"
    exit 1
fi

# Test with different parameter types
echo "Testing with decimal numbers:"
echo "10.5 + 2.3 = $(calc.add 10.5 2.3)"
echo "7 * 3.5 = $(calc.multiply 7 3.5)"

# Clean up
calc.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="