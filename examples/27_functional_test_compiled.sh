#!/bin/bash
# Example 27: Functional Test with Compiled Classes
# Demonstrates functional testing of compiled classes

# Load kbool, then the kklass unit(s) it needs (the canonical way)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../kbool.sh" || exit 1
kk.uses kklass_autoload || exit 1

# Work in a temp dir of our own: the example creates and deletes .ckk and its
# test files there, never in the caller's cwd; removed on exit, also on
# TERM / INT / HUP
workdir="$(mktemp -d "${TMPDIR:-/tmp}/kklass_example27.XXXXXX")" || exit 1
trap 'cd / && rm -rf "$workdir"' EXIT
trap 'exit 143' TERM; trap 'exit 130' INT; trap 'exit 129' HUP
cd "$workdir" || exit 1

echo "=== Functional Test with Compiled Classes Example ==="
echo

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true

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
"$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && kk.uses kklass_autoload && kkload test_system.kk --force-compile" >/dev/null 2>&1

# Test Counter functionality
echo "Testing Counter class:"
result=$("$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && source .ckk/test_system.ckk.sh && Counter.new cnt && cnt.value = 7 && cnt.increment")

if [[ "$result" == "8" ]]; then
    echo "✓ Counter class working correctly (incremented 7 to 8)"
else
    echo "✗ Counter class failed (expected: 8, got: $result)"
    exit 1
fi

# Test Timer functionality (inherits from Counter)
echo "Testing Timer class (inherits from Counter):"
result2=$("$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && source .ckk/test_system.ckk.sh && Timer.new tmr && tmr.value = 5 && tmr.increment")

if [[ "$result2" == "6" ]]; then
    echo "✓ Timer class inheritance working correctly (incremented 5 to 6)"
else
    echo "✗ Timer class inheritance failed (expected: 6, got: $result2)"
    exit 1
fi

# Test Timer-specific methods
echo "Testing Timer-specific methods:"
"$BASH" -c "source '$SCRIPT_DIR/../../kbool.sh' && source .ckk/test_system.ckk.sh && Timer.new tmr2 && tmr2.startTimer && sleep 1 && echo 'Elapsed: '; tmr2.elapsed"

echo "✓ All compiled class tests passed"

# Clean up
rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
rm -rf "$workdir/.ckk" 2>/dev/null || true
echo "✓ Test files cleaned up"

echo
echo "=== Example completed successfully ==="
