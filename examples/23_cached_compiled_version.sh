#!/bin/bash
# Example 23: Using Cached Compiled Version
# Demonstrates using cached compiled versions instead of recompiling

# Load kbool, then the kklass unit(s) it needs (the canonical way)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../kbool.sh" || exit 1
kk.uses kklass_autoload || exit 1

# Work in a temp dir of our own: the example creates and deletes .ckk and its
# test files there, never in the caller's cwd; removed on exit, also on
# TERM / INT / HUP
workdir="$(mktemp -d "${TMPDIR:-/tmp}/kklass_example23.XXXXXX")" || exit 1
trap 'cd / && rm -rf "$workdir"' EXIT
trap 'exit 143' TERM; trap 'exit 130' INT; trap 'exit 129' HUP
cd "$workdir" || exit 1

echo "=== Using Cached Compiled Version Example ==="
echo

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true

# Create a test class file
cat > test_system.kk << 'EOF'
defineClass Simple "" \
    property name \
    method greet 'echo "Hello, $name!"'
EOF

echo "✓ Created test_system.kk"

# First load (should compile)
echo "First load (compilation):"
output1=$("$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && kk.uses kklass_autoload && kkload test_system.kk" 2>&1)
echo "Output: $output1"

# Second load (should use cache)
echo "Second load (should use cache):"
output2=$("$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && kk.uses kklass_autoload && kkload test_system.kk" 2>&1)
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
"$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && source .ckk/test_system.ckk.sh && Simple.new s && s.name = 'World' && s.greet"

# Clean up
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="
