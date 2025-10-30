#!/bin/bash
# Example 32: Static/Class Methods and Properties
# Demonstrates class-level methods and properties that belong to the class itself

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Static/Class Methods and Properties Example ==="
echo

# Define a class with static methods and properties
defineClass "Counter" "" \
    "static_property" "instance_count" \
    "static_property" "class_name" \
    "property" "id" \
    "static_method" "getInstanceCount" 'echo "$instance_count"' \
    "static_method" "getClassName" 'echo "$class_name"' \
    "static_method" "incrementCount" 'instance_count=$((instance_count + 1))' \
    "method" "initialize" 'id=$((instance_count + 1)); Counter.incrementCount'

# Set static properties
Counter.class_name = "Counter"

echo "✓ Counter class defined with static methods and properties"

# Test static method calls
echo "Class name: $(Counter.getClassName)"
echo "Initial instance count: $(Counter.getInstanceCount)"

# Create instances
Counter.new counter1
Counter.new counter2

# Initialize instances (this will increment the static counter)
counter1.initialize
counter2.initialize

echo "✓ Two instances created and initialized"

# Check static properties after creating instances
echo "Instance count after creating instances: $(Counter.getInstanceCount)"
echo "Counter1 ID: $(counter1.id)"
echo "Counter2 ID: $(counter2.id)"

# Verify static properties are shared across all instances
if [[ "$(Counter.getInstanceCount)" == "2" ]] && [[ "$(counter1.id)" == "1" ]] && [[ "$(counter2.id)" == "2" ]]; then
    echo "✓ Static properties working correctly - shared across class and instances"
else
    echo "✗ Static properties failed"
    exit 1
fi

# Create another instance to show counter increments
Counter.new counter3
counter3.initialize
echo "After creating third instance:"
echo "  Instance count: $(Counter.getInstanceCount)"
echo "  Counter3 ID: $(counter3.id)"

# Clean up
counter1.delete
counter2.delete
counter3.delete
echo "✓ Instances cleaned up"

echo
echo "=== Example completed successfully ==="