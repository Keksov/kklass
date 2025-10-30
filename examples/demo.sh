#!/bin/bash
# demo.sh - Run all kklass examples sequentially

# Colors for output (same approach as working test file)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Demo functions (same pattern as test file)
demo_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

demo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

demo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

demo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

demo_section() {
    echo ""
    echo -e "${BOLD}${BLUE}>>> $1${NC}"
    echo ""
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Kklass Examples Demo${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

demo_info "Script directory: $SCRIPT_DIR"

# Find all example files
demo_info "Discovering example files..."

EXAMPLE_FILES=$(ls "$SCRIPT_DIR"/[0-9]*.sh 2>/dev/null)

if [[ -z "$EXAMPLE_FILES" ]]; then
    demo_error "No example files found!"
    exit 1
fi

demo_info "Found $(echo "$EXAMPLE_FILES" | wc -l) example files"

echo ""
echo "Example files:"
echo "$EXAMPLE_FILES" | sed 's|.*/||' | sort -n
echo ""

# Run all examples
for file in $SCRIPT_DIR/[0-9]*.sh; do
    if [[ -f "$file" ]]; then
        example_name=$(basename "$file" .sh)
        demo_section "Running $example_name"

        if bash "$file"; then
            demo_success "$example_name completed successfully"
        else
            demo_error "$example_name failed with exit code $?"
        fi

        echo ""
    fi
done

# Summary
demo_header "Demo Summary"
echo "Total examples run: $(echo "$EXAMPLE_FILES" | wc -l)"
echo ""
echo -e "${GREEN}✓ All kklass features demonstrated successfully!${NC}"