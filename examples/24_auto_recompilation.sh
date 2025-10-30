#!/bin/bash
# Example 24: Auto-recompilation on Source Change
# Demonstrates automatic recompilation when source files are modified

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass_autoload.sh"

echo "=== Auto-recompilation on Source Change Example ==="
echo

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf .ckk 2>/dev/null || true

# Create initial test class file
cat > test_system.kk << 'EOF'
defineClass Counter "" \
    property value \
    method getValue 'echo $value'
EOF

echo "✓ Created initial test_system.kk"

# First load (should compile)
echo "First load:"
output1=$(bash -c "source '$SCRIPT_DIR/../kklass_autoload.sh' && kkload test_system.kk" 2>&1)
echo "Output: $output1"

# Wait a moment and modify the source file
sleep 1
cat > test_system.kk << 'EOF'
defineClass Counter "" \
    property value \
    method getValue 'echo $value' \
    method increment 'value=$((value + 1)); echo $value'
EOF

echo "✓ Modified test_system.kk to add increment method"

# Load again (should detect change and recompile)
echo "Second load (should detect changes and recompile):"
output2=$(bash -c "source '$SCRIPT_DIR/../kklass_autoload.sh' && kkload test_system.kk" 2>&1)
echo "Output: $output2"

# Check if recompilation was triggered
if echo "$output2" | grep -q "newer\|Compiling"; then
    echo "✓ Auto-recompilation triggered by source change"
else
    echo "✗ Auto-recompilation not triggered"
    exit 1
fi

# Test that the new compiled version has the increment method
echo "Testing new increment method:"
bash -c "source .ckk/test_system.ckk.sh && Counter.new cnt && cnt.value = 5 && cnt.increment"

# Clean up
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf .ckk 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="