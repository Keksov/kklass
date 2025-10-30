#!/bin/bash
# Example 15: Nested Method Calls with $this
# Demonstrates method chaining and nested method calls using $this

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Nested Method Calls with \$this Example ==="
echo

# Define a class with methods that call each other
defineClass "Nested" "" \
    "property" "name" \
    "method" "a" 'echo "A"' \
    "method" "b" 'echo -n "B:"; $this.a' \
    "method" "c" 'echo -n "C:"; $this.b' \
    "method" "d" 'echo -n "D:"; $this.c; echo " (from $name)"'

# Create instance
Nested.new nested1
nested1.name = "TestObject"

echo "Calling individual methods:"
echo "Method a: $(nested1.a)"
echo "Method b: $(nested1.b)"
echo "Method c: $(nested1.c)"

echo "Method d (chained call):"
result=$(nested1.d)
echo "Result: $result"

# Verify the nested calls work correctly
expected="D:C:B:A (from TestObject)"
if [[ "$result" == "$expected" ]]; then
    echo "✓ Nested method calls working correctly"
else
    echo "✗ Nested method calls failed (expected: '$expected', got: '$result')"
    exit 1
fi

# Demonstrate more complex nesting
defineClass "ChainDemo" "" \
    "method" "one" 'echo "1"' \
    "method" "two" 'echo -n "2:"; $this.one' \
    "method" "three" 'echo -n "3:"; $this.two' \
    "method" "four" 'echo -n "4:"; $this.three; echo " (done)"'

ChainDemo.new chain1
echo "Complex chain:"
chain_result=$(chain1.four)
echo "Final result: $chain_result"

# Clean up
nested1.delete
chain1.delete
echo "✓ Instances cleaned up"

echo
echo "=== Example completed successfully ==="