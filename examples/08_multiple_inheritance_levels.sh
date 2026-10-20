#!/usr/bin/env bash
# Example 08: Multiple Inheritance Levels
# Demonstrates a deep inheritance chain with multiple levels

# Load kbool, then the kklass unit(s) it needs (the canonical way)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../kbool.sh" || exit 1
kk.uses kklass || exit 1

echo "=== Multiple Inheritance Levels Example ==="
echo

# Define a three-level inheritance hierarchy
defineClass "GrandParent" "" \
    "property" "grandparent_prop" \
    "method" "generation" 'echo -n "GrandParent"'

defineClass "Parent" "GrandParent" \
    "property" "parent_prop" \
    "method" "generation" 'echo -n "Parent"; $this.parent generation'

defineClass "Child" "Parent" \
    "property" "child_prop" \
    "method" "generation" 'echo -n "Child"; $this.parent generation'

# Create instance of the deepest derived class
Child.new child1

# Set properties at all levels
child1.grandparent_prop = "From GrandParent"
child1.parent_prop = "From Parent"
child1.child_prop = "From Child"

echo "✓ Properties set at all inheritance levels:"
echo "  grandparent_prop: $(child1.grandparent_prop)"
echo "  parent_prop: $(child1.parent_prop)"
echo "  child_prop: $(child1.child_prop)"

# Call the generation method that chains up the inheritance hierarchy
echo "Calling generation() method:"
result=$(child1.generation)
echo "Result: $result"

# Verify the inheritance chain works correctly
expected="ChildParentGrandParent"
if [[ "$result" == "$expected" ]]; then
    echo "✓ Multi-level inheritance working correctly"
else
    echo "✗ Multi-level inheritance failed (expected: '$expected', got: '$result')"
    exit 1
fi

# Clean up
child1.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="
