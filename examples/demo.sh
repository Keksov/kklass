#!/bin/bash
# demo.sh - Run all kklass examples sequentially

# Colors for output (same approach as working test file)
KT_RED='\033[0;31m'
KT_GREEN='\033[0;32m'
KT_YELLOW='\033[1;33m'
KT_BLUE='\033[0;34m'
KT_CYAN='\033[0;36m'
BOLD='\033[1m'
KT_NC='\033[0m' # No Color

# Demo functions (same pattern as test file)
demo_header() {
    echo ""
    echo -e "${KT_CYAN}========================================${KT_NC}"
    echo -e "${KT_CYAN}$1${KT_NC}"
    echo -e "${KT_CYAN}========================================${KT_NC}"
    echo ""
}

demo_info() {
    echo -e "${KT_BLUE}[INFO]${KT_NC} $1"
}

demo_success() {
    echo -e "${KT_GREEN}[SUCCESS]${KT_NC} $1"
}

demo_error() {
    echo -e "${KT_RED}[ERROR]${KT_NC} $1"
}

demo_section() {
    echo ""
    echo -e "${BOLD}${KT_BLUE}>>> $1${KT_NC}"
    echo ""
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${KT_CYAN}========================================${KT_NC}"
echo -e "${KT_CYAN}Kklass Examples Demo${KT_NC}"
echo -e "${KT_CYAN}========================================${KT_NC}"
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
echo -e "${KT_GREEN}✓ All kklass features demonstrated successfully!${KT_NC}"