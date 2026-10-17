#!/bin/bash
# Example 22: Auto-compilation (First Load)
# Demonstrates automatic compilation of .kk files on first load

# Load kbool, then the kklass unit(s) it needs (the canonical way)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../kbool.sh" || exit 1
kk.uses kklass_autoload || exit 1

# Work in a temp dir of our own: the example creates and deletes .ckk and its
# test files there, never in the caller's cwd; removed on exit, also on
# TERM / INT / HUP
workdir="$(mktemp -d "${TMPDIR:-/tmp}/kklass_example22.XXXXXX")" || exit 1
trap 'cd / && rm -rf "$workdir"' EXIT
trap 'exit 143' TERM; trap 'exit 130' INT; trap 'exit 129' HUP
cd "$workdir" || exit 1

echo "=== Auto-compilation (First Load) Example ==="
echo

# Clean up any previous test files
rm -f .ckk/test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true

echo "✓ Cleaned up previous test files"

# Create .ckk directory if not exists
mkdir -p "$workdir/.ckk"

# Create a test class file
cat > .ckk/test_system.kk << 'EOF'
defineClass Counter "" \
    property value \
    method increment 'value=$((value + 1)); echo $value' \
    method getValue 'echo $value'

defineClass Timer Counter \
    property start_time \
    method startTimer 'start_time=$(date +%s); echo "Timer started"' \
    method elapsed 'local now=$(date +%s); echo $((now - start_time))'
EOF

echo "✓ Created .ckk/test_system.kk with Counter and Timer classes"

# Load the file for the first time (should trigger compilation)
echo "Loading .ckk/test_system.kk for the first time:"
output=$("$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && kk.uses kklass_autoload && kkload .ckk/test_system.kk" 2>&1)

echo "Output: $output"

# Check if compilation was successful
if echo "$output" | grep -q "Compilation successful" && [[ -f .ckk/test_system.ckk.sh ]]; then
    echo "✓ Auto-compilation working correctly"
    echo "✓ Compiled file created: .ckk/test_system.ckk.sh"
else
    echo "✗ Auto-compilation failed"
    exit 1
fi

# Test that the compiled classes work
echo "Testing compiled Counter class:"
"$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && source .ckk/test_system.ckk.sh && Counter.new cnt && cnt.value = 5 && cnt.increment"

echo "Testing compiled Timer class:"
"$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && source .ckk/test_system.ckk.sh && Timer.new tmr && tmr.value = 10 && tmr.increment"

# Clean up
rm -f .ckk/test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="
