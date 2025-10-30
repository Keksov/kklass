#!/bin/bash
# Example 39: Strategy Pattern
# Demonstrates encapsulating algorithms that can be swapped at runtime

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Strategy Pattern Example ==="
echo

# Define strategy interface (base class)
defineClass "SortStrategy" "" \
    "property" "name" \
    "method" "sort" 'echo "[$name] Generic sorting strategy"'

# Define concrete strategies
defineClass "BubbleSort" "SortStrategy" \
    "method" "sort" 'echo "[$name] Using bubble sort algorithm"'

defineClass "QuickSort" "SortStrategy" \
    "method" "sort" 'echo "[$name] Using quick sort algorithm"'

defineClass "MergeSort" "SortStrategy" \
    "method" "sort" 'echo "[$name] Using merge sort algorithm"'

# Define context class that uses strategies
defineClass "Sorter" "" \
    "property" "strategy" \
    "property" "data" \
    "method" "setStrategy" 'strategy="$1"' \
    "method" "setData" 'data="$1"' \
    "method" "performSort" 'echo "Sorting data: $data"; eval "${strategy}.sort"' \
    "method" "getStrategyName" 'eval "${strategy}.name"'

echo "✓ Strategy pattern classes defined"

# Create sorter instance
Sorter.new sorter

echo "✓ Sorter created"

# Create different sorting strategies
BubbleSort.new bubbleSort
bubbleSort.name = "BubbleSort"

QuickSort.new quickSort
quickSort.name = "QuickSort"

MergeSort.new mergeSort
mergeSort.name = "MergeSort"

echo "✓ Sorting strategies created"

# Test different strategies
echo
echo "=== Testing Different Sorting Strategies ==="

# Use bubble sort
sorter.setStrategy "bubbleSort"
sorter.setData "5 3 8 1 9 2"
echo "Using strategy: $(sorter.getStrategyName)"
sorter.performSort

echo

# Switch to quick sort
sorter.setStrategy "quickSort"
sorter.setData "7 2 9 4 1 6 3"
echo "Using strategy: $(sorter.getStrategyName)"
sorter.performSort

echo

# Switch to merge sort
sorter.setStrategy "mergeSort"
sorter.setData "4 7 2 9 1 8 3 5"
echo "Using strategy: $(sorter.getStrategyName)"
sorter.performSort

# Verify strategy pattern working
echo
echo "=== Strategy Pattern Benefits ==="
echo "Demonstrating runtime strategy switching..."

# Show that we can switch strategies dynamically
sorter.setData "3 1 4 1 5 9 2 6"
echo "Same data, different strategies:"

sorter.setStrategy "bubbleSort"
echo "Bubble sort: $(sorter.performSort)"

sorter.setStrategy "quickSort"
echo "Quick sort: $(sorter.performSort)"

sorter.setStrategy "mergeSort"
echo "Merge sort: $(sorter.performSort)"

echo "✓ Strategy pattern working correctly - algorithms are interchangeable"

# Demonstrate strategy encapsulation
echo
echo "=== Strategy Encapsulation ==="
echo "Each strategy encapsulates its own algorithm:"
echo "  - BubbleSort: Simple but potentially slow"
echo "  - QuickSort: Fast average-case performance"
echo "  - MergeSort: Stable and consistent performance"

# Clean up
sorter.delete
bubbleSort.delete
quickSort.delete
mergeSort.delete
echo "✓ All strategies and sorter cleaned up"

echo
echo "=== Example completed successfully ==="