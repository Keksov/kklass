#!/bin/bash
# Example 27: Functional Test with Compiled Classes
# Demonstrates functional testing of compiled classes

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass_autoload.sh"

echo "=== Functional Test with Compiled Classes Example ==="
echo

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf .ckk 2>/dev/null || true

# Create test class file
cat > test_system.kk << 'EOF'
defineClass Counter "" \
    property value \
    method increment 'value=$((value + 1)); echo $value' \
    method getValue 'echo $value'

defineClass Timer Counter \
    property start_time \
    method startTimer 'start_time=$(date +%s); echo "Timer started"' \
    method elapsed 'local now=$(date +%s); echo $((now - start_time))'
EOF

echo "✓ Created test_system.kk with Counter and Timer classes"

# Force compile the classes
echo "Force compiling classes:"
bash -c "source '$SCRIPT_DIR/../kklass_autoload.sh' && kkload test_system.kk --force-compile" >/dev/null 2>&1

# Test Counter functionality
echo "Testing Counter class:"
result=$(bash -c "source .ckk/test_system.ckk.sh && Counter.new cnt && cnt.value = 7 && cnt.increment")

if [[ "$result" == "8" ]]; then
    echo "✓ Counter class working correctly (incremented 7 to 8)"
else
    echo "✗ Counter class failed (expected: 8, got: $result)"
    exit 1
fi

# Test Timer functionality (inherits from Counter)
echo "Testing Timer class (inherits from Counter):"
result2=$(bash -c "source .ckk/test_system.ckk.sh && Timer.new tmr && tmr.value = 5 && tmr.increment")

if [[ "$result2" == "6" ]]; then
    echo "✓ Timer class inheritance working correctly (incremented 5 to 6)"
else
    echo "✗ Timer class inheritance failed (expected: 6, got: $result2)"
    exit 1
fi

# Test Timer-specific methods
echo "Testing Timer-specific methods:"
bash -c "source .ckk/test_system.ckk.sh && Timer.new tmr2 && tmr2.startTimer && sleep 1 && echo 'Elapsed: '; tmr2.elapsed"

echo "✓ All compiled class tests passed"

# Clean up
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf .ckk 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="