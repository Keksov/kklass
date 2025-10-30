#!/bin/bash
# Example 25: Force Recompilation
# Demonstrates forcing recompilation of source files

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass_autoload.sh"

echo "=== Force Recompilation Example ==="
echo

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf .ckk 2>/dev/null || true

# Create a test class file
cat > test_system.kk << 'EOF'
defineClass Test "" \
    property name \
    method hello 'echo "Hello, $name!"'
EOF

echo "✓ Created test_system.kk"

# Initial compilation
echo "Initial compilation:"
output1=$(bash -c "source '$SCRIPT_DIR/../kklass_autoload.sh' && kkload test_system.kk" 2>&1)
echo "Output: $output1"

# Force recompilation
echo "Force recompilation:"
output2=$(bash -c "source '$SCRIPT_DIR/../kklass_autoload.sh' && kkrecompile test_system.kk" 2>&1)
echo "Output: $output2"

# Check if force recompilation was successful
if echo "$output2" | grep -q "Force\|Compiling"; then
    echo "✓ Force recompilation working correctly"
else
    echo "✗ Force recompilation failed"
    exit 1
fi

# Verify the recompiled version works
echo "Testing recompiled class:"
bash -c "source .ckk/test_system.ckk.sh && Test.new t && t.name = 'World' && t.hello"

# Clean up
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf .ckk 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="