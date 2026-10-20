#!/usr/bin/env bash
# Example 28: Inheritance in Compiled Classes
# Demonstrates that inheritance works correctly in compiled classes

# Load kbool, then the kklass unit(s) it needs (the canonical way)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../kbool.sh" || exit 1
kk.uses kklass_autoload || exit 1

# Work in a temp dir of our own: the example creates and deletes .ckk and its
# test files there, never in the caller's cwd; removed on exit, also on
# TERM / INT / HUP
workdir="$(mktemp -d "${TMPDIR:-/tmp}/kklass_example28.XXXXXX")" || exit 1
trap 'cd / && rm -rf "$workdir"' EXIT
trap 'exit 143' TERM; trap 'exit 130' INT; trap 'exit 129' HUP
cd "$workdir" || exit 1

echo "=== Inheritance in Compiled Classes Example ==="
echo

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true

# Create test class file with inheritance
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

echo "✓ Created test_system.kk with inheritance hierarchy"

# Force compile the classes
echo "Force compiling classes:"
"$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && kk.uses kklass_autoload && kkload test_system.kk --force-compile" >/dev/null 2>&1

# Test that inheritance works in compiled classes
echo "Testing inheritance in compiled classes:"

# Test Timer can access Counter methods
result=$("$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && source .ckk/test_system.ckk.sh && Timer.new tmr && tmr.value = 5 && tmr.increment")

if [[ "$result" == "6" ]]; then
    echo "✓ Inheritance in compiled classes working correctly"
    echo "  Timer inherited increment method from Counter"
    echo "  Incremented value from 5 to 6"
else
    echo "✗ Inheritance in compiled classes failed (expected: 6, got: $result)"
    exit 1
fi

# Test that Timer has both its own methods and inherited methods
echo "Testing Timer-specific methods:"
"$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && source .ckk/test_system.ckk.sh && Timer.new tmr2 && tmr2.startTimer && sleep 1 && echo 'Timer elapsed: '; tmr2.elapsed"

echo "Testing inherited methods:"
"$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && source .ckk/test_system.ckk.sh && Timer.new tmr3 && tmr3.value = 10 && echo 'Timer value: '; tmr3.getValue && echo 'Timer increment: '; tmr3.increment"

# Clean up
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="
