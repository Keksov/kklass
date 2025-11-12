#!/bin/bash
# Example 22: Auto-compilation (First Load)
# Demonstrates automatic compilation of .kk files on first load

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass_autoload.sh"

echo "=== Auto-compilation (First Load) Example ==="
echo

# Clean up any previous test files
rm -f .ckk/test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf .ckk 2>/dev/null || true

echo "✓ Cleaned up previous test files"

# Create .ckk directory if not exists
mkdir -p .ckk

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
output=$(bash -c "source '$SCRIPT_DIR/../kklass_autoload.sh' && kkload .ckk/test_system.kk" 2>&1)

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
bash -c "source .ckk/test_system.ckk.sh && Counter.new cnt && cnt.value = 5 && cnt.increment"

echo "Testing compiled Timer class:"
bash -c "source .ckk/test_system.ckk.sh && Timer.new tmr && tmr.value = 10 && tmr.increment"

# Clean up
rm -f .ckk/test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf .ckk 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="