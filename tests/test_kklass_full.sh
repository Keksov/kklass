#!/bin/bash
# test_kklass_full.sh - Comprehensive test suite for kklass system
# Tests both core functionality and autoload/compilation features

set -e  # Exit on any error

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

# Parse command line arguments
VERBOSITY="error"
TEST_PREFIX=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbosity|--verbosity=*)
            if [[ $1 == --verbosity=* ]]; then
                VERBOSITY="${1#*=}"
            else
                VERBOSITY="$2"
                shift
            fi
            ;;
        -v)
            VERBOSITY="$2"
            shift
            ;;
        -n|--number)
            TEST_PREFIX="$2"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-v|--verbosity info|error] [-n|--number X]"
            echo "  -n X: Execute only tests with prefix X (e.g., 1, 01, 001, 0001)"
            exit 1
            ;;
    esac
    shift
done

# Validate verbosity
if [[ "$VERBOSITY" != "info" && "$VERBOSITY" != "error" ]]; then
    echo "Error: verbosity must be 'info' or 'error'"
    exit 1
fi

# Set kklass verbosity based on our verbosity
export VERBOSE_KKLASS="$VERBOSITY"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to expand test prefix (e.g., "1" becomes "1_ 01_ 001_ 0001_")
expand_prefix() {
    local prefix="$1"
    local expanded=""
    local len=${#prefix}
    for ((i=4; i>=len; i--)); do
        expanded+="$(printf '%0*d' $((i-len)) 0)$prefix "
    done
    echo "$expanded"
}

# Normalize and deduplicate file list (Windows-safe, no external sort)
unique_and_clean() {
    local -n in_arr=$1
    local -n out_arr=$2
    declare -A seen=()
    local f
    for f in "${in_arr[@]}"; do
        f="${f%$'\r'}"
        if [[ -f "$f" && -z "${seen[$f]}" ]]; then
            out_arr+=("$f")
            seen[$f]=1
        fi
    done
}

# Function to find and execute test files
run_tests() {
    local test_files=()
    local pattern="*.sh"
    # Enable nullglob so unmatched globs expand to nothing
    shopt -s nullglob

    if [[ -n "$TEST_PREFIX" ]]; then
        # Build glob patterns for the given prefix
        local patterns=()

        # Always include the raw prefix form like "X_*.sh"
        patterns+=("$SCRIPT_DIR/${TEST_PREFIX}_*.sh")

        # If the prefix is purely numeric, include zero-padded variants: 01_, 001_, 0001_
        if [[ "$TEST_PREFIX" =~ ^[0-9]+$ ]]; then
            patterns+=("$SCRIPT_DIR/0${TEST_PREFIX}_*.sh")
            patterns+=("$SCRIPT_DIR/00${TEST_PREFIX}_*.sh")
            patterns+=("$SCRIPT_DIR/000${TEST_PREFIX}_*.sh")
            # Also include explicit 3-digit pad (covers e.g. 1 -> 001_)
            patterns+=("$SCRIPT_DIR/$(printf '%03d' "$TEST_PREFIX")_*.sh")
        fi

        # Verbose debug info
        if [[ "$VERBOSITY" == "info" ]]; then
            echo -e "${YELLOW}[INFO]${NC} TEST_PREFIX='$TEST_PREFIX'"
            echo -e "${YELLOW}[INFO]${NC} Searching in: $SCRIPT_DIR"
            echo -e "${YELLOW}[INFO]${NC} Patterns to try:"
            for _p in "${patterns[@]}"; do echo " - $_p"; done
        fi

        # Collect matching files using globbing (safe with nullglob)
        for pat in "${patterns[@]}"; do
            for f in $pat; do
                if [[ -f "$f" ]]; then
                    test_files+=("$f")
                fi
            done
        done

        if [[ "$VERBOSITY" == "info" ]]; then
            echo -e "${YELLOW}[INFO]${NC} Matched ${#test_files[@]} file(s):"
            for _m in "${test_files[@]}"; do echo " - ${_m}"; done
        fi
    else
        # Run all test files
        for f in "$SCRIPT_DIR"/[0-9][0-9][0-9]_*.sh; do
            if [[ -f "$f" ]]; then
                test_files+=("$f")
            fi
        done
    fi
    # Revert nullglob
    shopt -u nullglob

    # Normalize and deduplicate without relying on external sort (Windows-safe)
    local unique_files=()
    unique_and_clean test_files unique_files
    test_files=("${unique_files[@]}")

    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo "No test files found matching criteria."
        exit 1
    fi

    if [[ "$VERBOSITY" == "info" ]]; then
        echo ""
        echo -e "${CYAN}========================================${NC}"
        echo -e "${CYAN}Comprehensive Kklass Test Suite${NC}"
        echo -e "${CYAN}========================================${NC}"
        echo "Running ${#test_files[@]} test file(s)..."
        echo ""
    fi

    # Execute each test file in isolated bash, aggregate counters
    for test_file in "${test_files[@]}"; do
        if [[ "$VERBOSITY" == "info" ]]; then
            echo -e "${YELLOW}[EXEC]${NC} $(basename "$test_file")"
        fi
        local clean_file="${test_file%$'\r'}"
        local run_output counts_line __tag __t __p __f

        # Run the test in a separate bash process to avoid sourcing path issues on Windows
        run_output="$(
            bash -c "export VERBOSITY='$VERBOSITY'; source \"$clean_file\"; echo __COUNTS__:\$TESTS_TOTAL:\$TESTS_PASSED:\$TESTS_FAILED" 2>&1 || true
        )"

        # Show output except the counters line when verbose
        if [[ "$VERBOSITY" == "info" ]]; then
            echo "$run_output" | sed -e 's/\r$//' | grep -v '^__COUNTS__:' || true
        fi

        # Parse counters
        counts_line="$(printf '%s\n' "$run_output" | sed -e 's/\r$//' | grep '^__COUNTS__:' | tail -n 1)"
        if [[ -n "$counts_line" ]]; then
            IFS=':' read -r __tag __t __p __f <<<"$counts_line"
            __t=${__t:-0}; __p=${__p:-0}; __f=${__f:-0}
            TESTS_TOTAL=$((TESTS_TOTAL + __t))
            TESTS_PASSED=$((TESTS_PASSED + __p))
            TESTS_FAILED=$((TESTS_FAILED + __f))
        else
            # If no counters reported, assume the test file represents 1 test that failed hard
            TESTS_TOTAL=$((TESTS_TOTAL + 1))
            TESTS_FAILED=$((TESTS_FAILED + 1))
            echo -e "${RED}[FAIL]${NC} $(basename "$test_file") (no counters reported)"
        fi
    done
}

# Execute tests
run_tests

# =============================================================================
# FINAL RESULTS
# =============================================================================
total=$(cat <<-EOT
Total tests: $TESTS_TOTAL
Passed: ${GREEN}$TESTS_PASSED${NC}
Failed: ${RED}$TESTS_FAILED${NC}
EOT
)

if [[ "${VERBOSITY:-1}" == "info" ]]; then
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Test Results Summary${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "$total"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed.${NC}"
        exit 1
    fi
else
    echo -e $total
fi

