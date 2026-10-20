#!/usr/bin/env bash
# Example 26: Runtime Mode (--no-compile)
# Demonstrates runtime mode that skips compilation and uses direct interpretation

# Load kbool, then the kklass unit(s) it needs (the canonical way)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../kbool.sh" || exit 1
kk.uses kklass_autoload || exit 1

# Work in a temp dir of our own: the example creates and deletes .ckk and its
# test files there, never in the caller's cwd; removed on exit, also on
# TERM / INT / HUP
workdir="$(mktemp -d "${TMPDIR:-/tmp}/kklass_example26.XXXXXX")" || exit 1
trap 'cd / && rm -rf "$workdir"' EXIT
trap 'exit 143' TERM; trap 'exit 130' INT; trap 'exit 129' HUP
cd "$workdir" || exit 1

echo "=== Runtime Mode (--no-compile) Example ==="
echo

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true

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
output=$("$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && kk.uses kklass_autoload && kkload test_system.kk --no-compile" 2>&1)
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
"$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && kk.uses kklass_autoload && kkload test_system.kk --no-compile && RuntimeTest.new rt && rt.message = 'Hello from runtime mode!' && rt.sayHello"

# Clean up
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="
