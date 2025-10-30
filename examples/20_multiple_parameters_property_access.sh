#!/bin/bash
# Example 20: Method with Multiple Parameters and Property Access
# Demonstrates methods that accept multiple parameters and access instance properties

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Method with Multiple Parameters and Property Access Example ==="
echo

# Define a MathOps class
defineClass "MathOps" "" \
    "property" "base" \
    "property" "name" \
    "method" "addToBase" 'echo $((base + $1))' \
    "method" "multiplyBase" 'echo $((base * $1))' \
    "method" "addMultiple" 'echo $((base + $1 + $2))' \
    "method" "powerBase" 'echo $((base ** $1))' \
    "method" "getBase" 'echo "$base"'

# Create math instance
MathOps.new math1
math1.base = "10"
math1.name = "Calculator"

echo "✓ MathOps instance created with base=10"

# Test single parameter methods
echo "Base value: $(math1.getBase)"
echo "Add 5 to base: $(math1.addToBase 5)"
echo "Multiply base by 3: $(math1.multiplyBase 3)"
echo "Base to the power of 2: $(math1.powerBase 2)"

# Test multiple parameter method
echo "Add 5 and 3 to base: $(math1.addMultiple 5 3)"

# Verify specific results
result1=$(math1.addToBase 5)
result2=$(math1.multiplyBase 3)

if [[ "$result1" == "15" ]] && [[ "$result2" == "30" ]]; then
    echo "✓ Multiple parameters and property access working correctly"
else
    echo "✗ Multiple parameters and property access failed"
    exit 1
fi

# Test with different base values
math1.base = "20"
echo "Changed base to: $(math1.getBase)"
echo "New add 5 result: $(math1.addToBase 5)"
echo "New multiply by 3 result: $(math1.multiplyBase 3)"

# Clean up
math1.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="