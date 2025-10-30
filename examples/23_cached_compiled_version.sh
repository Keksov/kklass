#!/bin/bash
# Example 23: Using Cached Compiled Version
# Demonstrates using cached compiled versions instead of recompiling

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass_autoload.sh"

echo "=== Using Cached Compiled Version Example ==="
echo

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf .ckk 2>/dev/null || true

# Create a test class file
cat > test_system.kk << 'EOF'
defineClass Simple "" \
    property name \
    method greet 'echo "Hello, $name!"'
EOF

echo "✓ Created test_system.kk"

# First load (should compile)
echo "First load (compilation):"
output1=$(bash -c "source '$SCRIPT_DIR/../kklass_autoload.sh' && kkload test_system.kk" 2>&1)
echo "Output: $output1"

# Second load (should use cache)
echo "Second load (should use cache):"
output2=$(bash -c "source '$SCRIPT_DIR/../kklass_autoload.sh' && kkload test_system.kk" 2>&1)
echo "Output: $output2"

# Check if second load used cache
if echo "$output2" | grep -q "cached"; then
    echo "✓ Second load used cached version"
else
    echo "✗ Second load did not use cache"
    exit 1
fi

# Verify the cached version works
echo "Testing cached class functionality:"
bash -c "source .ckk/test_system.ckk.sh && Simple.new s && s.name = 'World' && s.greet"

# Clean up
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf .ckk 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="