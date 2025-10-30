#!/bin/bash
# Example 21: Property Access via .property Method
# Demonstrates accessing properties using the .property method syntax

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Property Access via .property Method Example ==="
echo

# Define a TestProp class
defineClass "TestProp" "" \
    "property" "data" \
    "property" "name" \
    "property" "value" \
    "method" "getData" 'echo "$data"' \
    "method" "setData" 'data="$1"'

# Create instance
TestProp.new testprop

# Set property using .property method
testprop.property "data" = "test_value"
testprop.property "name" = "TestObject"
testprop.property "value" = "42"

echo "✓ Properties set using .property method"

# Access properties using .property method
echo "Accessing properties:"
echo "  data: $(testprop.property "data")"
echo "  name: $(testprop.property "name")"
echo "  value: $(testprop.property "value")"

# Verify the property access works
result=$(testprop.property "data")
if [[ "$result" == "test_value" ]]; then
    echo "✓ Property access via .property method working correctly"
else
    echo "✗ Property access via .property method failed (expected: 'test_value', got: '$result')"
    exit 1
fi

# Compare with direct property access
echo "Direct property access:"
echo "  data: $(testprop.data)"
echo "  name: $(testprop.name)"

# Both methods should return the same values
direct_data=$(testprop.data)
method_data=$(testprop.property "data")

if [[ "$direct_data" == "$method_data" ]]; then
    echo "✓ Direct and .property access methods are equivalent"
else
    echo "✗ Direct and .property access methods differ"
fi

# Clean up
testprop.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="