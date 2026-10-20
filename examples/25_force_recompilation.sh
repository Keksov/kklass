#!/usr/bin/env bash
# Example 25: Force Recompilation
# Demonstrates forcing recompilation of source files

# Load kbool, then the kklass unit(s) it needs (the canonical way)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../kbool.sh" || exit 1
kk.uses kklass_autoload || exit 1

# Work in a temp dir of our own: the example creates and deletes .ckk and its
# test files there, never in the caller's cwd; removed on exit, also on
# TERM / INT / HUP
workdir="$(mktemp -d "${TMPDIR:-/tmp}/kklass_example25.XXXXXX")" || exit 1
trap 'cd / && rm -rf "$workdir"' EXIT
trap 'exit 143' TERM; trap 'exit 130' INT; trap 'exit 129' HUP
cd "$workdir" || exit 1

echo "=== Force Recompilation Example ==="
echo

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true

# Create a test class file
cat > test_system.kk << 'EOF'
defineClass Test "" \
    property name \
    method hello 'echo "Hello, $name!"'
EOF

echo "✓ Created test_system.kk"

# Initial compilation
echo "Initial compilation:"
output1=$("$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && kk.uses kklass_autoload && kkload test_system.kk" 2>&1)
echo "Output: $output1"

# Force recompilation
echo "Force recompilation:"
output2=$("$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && kk.uses kklass_autoload && kkrecompile test_system.kk" 2>&1)
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
"$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && source .ckk/test_system.ckk.sh && Test.new t && t.name = 'World' && t.hello"

# Clean up
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="
