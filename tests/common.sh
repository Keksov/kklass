#!/bin/bash
# common.sh - Shared setup code for kklass tests

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KKLASS_DIR="$SCRIPT_DIR/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test result functions
test_start() {
    if [[ "$VERBOSITY" == "info" ]]; then
        echo -e "${BLUE}[TEST]${NC} $1"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

test_pass() {
    if [[ "$VERBOSITY" == "info" ]]; then
        echo -e "${GREEN}[PASS]${NC} $1"
    fi
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_info() {
    if [[ "$VERBOSITY" == "info" ]]; then
        echo -e "${YELLOW}[INFO]${NC} $1"
    fi
}

test_section() {
    if [[ "$VERBOSITY" == "info" ]]; then
        echo ""
        echo -e "${CYAN}========================================${NC}"
        echo -e "${CYAN}$1${NC}"
        echo -e "${CYAN}========================================${NC}"
        echo ""
    fi
}

# Cleanup function
cleanup() {
    # Clean up any remaining instances
    for cleanup_func in $(declare -F | grep -E '\.delete$' | sed 's/ declare -f //' | head -20); do
        instance_name=$(echo "$cleanup_func" | sed 's/\.delete$//')
        if declare -F | grep -q "^declare -f $instance_name\."; then
            if [[ "${VERBOSITY:-1}" == "info" ]]; then echo "Cleaning up $instance_name"; fi
            $instance_name.delete 2>/dev/null || true
        fi
    done

    # Clean up test files
    rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
    rm -rf .ckk 2>/dev/null || true
}

# Set up cleanup trap
trap cleanup EXIT
trap 'echo "Error occurred at line $LINENO: $BASH_COMMAND"' ERR

# Source the class system
source "$KKLASS_DIR/kklass.sh"