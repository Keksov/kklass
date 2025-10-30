#!/bin/bash
# Example 31: Deep Inheritance Chain with Properties
# Demonstrates a deep inheritance hierarchy with properties at each level

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Deep Inheritance Chain with Properties Example ==="
echo

# Define a four-level inheritance hierarchy
defineClass "A" "" \
    "property" "propA" \
    "method" "showA" 'echo "A:$propA"'

defineClass "B" "A" \
    "property" "propB" \
    "method" "showB" 'echo "B:$propB"'

defineClass "C" "B" \
    "property" "propC" \
    "method" "showAll" '$this.showA; $this.showB; echo "C:$propC"'

# Create instance of the deepest class
C.new obj_c

# Set properties at all levels
obj_c.propA = "1"
obj_c.propB = "2"
obj_c.propC = "3"

echo "✓ Properties set at all inheritance levels:"
echo "  propA: $(obj_c.propA)"
echo "  propB: $(obj_c.propB)"
echo "  propC: $(obj_c.propC)"

# Test the showAll method that calls up the inheritance chain
echo "Calling showAll() method:"
result=$(obj_c.showAll)
echo "Result: $result"

# Verify the inheritance chain works correctly
expected="A:1B:2C:3"
if [[ "$result" == "$expected" ]]; then
    echo "✓ Deep inheritance chain working correctly"
else
    echo "✗ Deep inheritance chain failed (expected: '$expected', got: '$result')"
    exit 1
fi

# Test individual methods from each level
echo "Testing individual level methods:"
echo "  Level A: $(obj_c.showA)"
echo "  Level B: $(obj_c.showB)"
echo "  Level C: $(obj_c.propC)"

# Test property access from all levels
echo "Property access from all levels:"
echo "  A.propA = $(obj_c.propA)"
echo "  B.propB = $(obj_c.propB)"
echo "  C.propC = $(obj_c.propC)"

# Clean up
obj_c.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="