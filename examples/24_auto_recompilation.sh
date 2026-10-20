#!/usr/bin/env bash
# Example 24: Auto-recompilation on Source Change
# Demonstrates automatic recompilation when source files are modified

# Load kbool, then the kklass unit(s) it needs (the canonical way)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../kbool.sh" || exit 1
kk.uses kklass_autoload || exit 1

# Work in a temp dir of our own: the example creates and deletes .ckk and its
# test files there, never in the caller's cwd; removed on exit, also on
# TERM / INT / HUP
workdir="$(mktemp -d "${TMPDIR:-/tmp}/kklass_example24.XXXXXX")" || exit 1
trap 'cd / && rm -rf "$workdir"' EXIT
trap 'exit 143' TERM; trap 'exit 130' INT; trap 'exit 129' HUP
cd "$workdir" || exit 1

echo "=== Auto-recompilation on Source Change Example ==="
echo

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true

# Create initial test class file
cat > test_system.kk << 'EOF'
defineClass Counter "" \
    property value \
    method getValue 'echo $value'
EOF

echo "✓ Created initial test_system.kk"

# First load (should compile)
echo "First load:"
output1=$("$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && kk.uses kklass_autoload && kkload test_system.kk" 2>&1)
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
output2=$("$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && kk.uses kklass_autoload && kkload test_system.kk" 2>&1)
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
"$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && source .ckk/test_system.ckk.sh && Counter.new cnt && cnt.value = 5 && cnt.increment"

# Clean up
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="
