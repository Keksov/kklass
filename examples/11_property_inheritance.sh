#!/bin/bash
# Example 11: Property Inheritance
# Demonstrates how properties are inherited from base classes to derived classes

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Property Inheritance Example ==="
echo

# Define base class with properties
defineClass "BaseWithProps" "" \
    "property" "baseProp" \
    "property" "sharedProp" \
    "method" "getBaseProp" 'echo "$baseProp"'

# Define derived class that adds its own properties
defineClass "DerivedWithProps" "BaseWithProps" \
    "property" "derivedProp" \
    "property" "sharedProp" \
    "method" "getDerivedProp" 'echo "$derivedProp"' \
    "method" "getAllProps" 'echo "base: $baseProp, derived: $derivedProp, shared: $sharedProp"'

# Create instance of derived class
DerivedWithProps.new derived

# Set properties from both base and derived class
derived.baseProp = "inherited"
derived.derivedProp = "own"
derived.sharedProp = "overridden"

echo "✓ Properties set:"
echo "  baseProp: $(derived.baseProp)"
echo "  derivedProp: $(derived.derivedProp)"
echo "  sharedProp: $(derived.sharedProp)"

# Verify inheritance works
if [[ "$(derived.baseProp)" == "inherited" ]] && [[ "$(derived.derivedProp)" == "own" ]]; then
    echo "✓ Property inheritance working correctly"
else
    echo "✗ Property inheritance failed"
    exit 1
fi

# Test method calls that access inherited properties
echo "Base property via method: $(derived.getBaseProp)"
echo "Derived property via method: $(derived.getDerivedProp)"
echo "All properties: $(derived.getAllProps)"

# Clean up
derived.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="