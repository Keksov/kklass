#!/bin/bash
# Example 26: Runtime Mode (--no-compile)
# Demonstrates runtime mode that skips compilation and uses direct interpretation

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass_autoload.sh"

echo "=== Runtime Mode (--no-compile) Example ==="
echo

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf .ckk 2>/dev/null || true

# Create a test class file
cat > test_system.kk << 'EOF'
defineClass RuntimeTest "" \
    property message \
    method sayHello 'echo "$message"' \
    method getMessage 'echo "$message"'
EOF

echo "✓ Created test_system.kk"

# Remove compiled version to force runtime mode
rm -f .ckk/test_system.ckk.sh

# Load in runtime mode (no compilation)
echo "Loading in runtime mode (--no-compile):"
output=$(bash -c "source '$SCRIPT_DIR/../kklass_autoload.sh' && kkload test_system.kk --no-compile" 2>&1)
echo "Output: $output"

# Check if runtime mode was used
if echo "$output" | grep -q "runtime\|No compiled"; then
    echo "✓ Runtime mode working correctly"
else
    echo "✗ Runtime mode failed"
    exit 1
fi

# Test that runtime mode works (this would fail if compilation was required)
echo "Testing runtime mode functionality:"
bash -c "source '$SCRIPT_DIR/../kklass_autoload.sh' && kkload test_system.kk --no-compile && RuntimeTest.new rt && rt.message = 'Hello from runtime mode!' && rt.sayHello"

# Clean up
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf .ckk 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="