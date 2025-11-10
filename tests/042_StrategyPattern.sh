#!/bin/bash
# 042_strategy_pattern.sh - Test strategy pattern

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 42: Strategy pattern
test_start "Strategy pattern"
defineClass "SortStrategy" "" \
    "property" "name" \
    "method" "sort" 'echo "[$name] Generic sorting strategy"'

defineClass "BubbleSort" "SortStrategy" \
    "method" "sort" 'echo "[$name] Using bubble sort algorithm"'

defineClass "QuickSort" "SortStrategy" \
    "method" "sort" 'echo "[$name] Using quick sort algorithm"'

defineClass "MergeSort" "SortStrategy" \
    "method" "sort" 'echo "[$name] Using merge sort algorithm"'

defineClass "Sorter" "" \
    "property" "strategy" \
    "property" "data" \
    "method" "setStrategy" 'strategy="$1"' \
    "method" "setData" 'data="$1"' \
    "method" "performSort" 'echo "Sorting data: $data"; eval "${strategy}.sort"' \
    "method" "getStrategyName" 'eval "${strategy}.name"'

Sorter.new sorter_test
BubbleSort.new bubbleSort_test
bubbleSort_test.name = "BubbleSort"
QuickSort.new quickSort_test
quickSort_test.name = "QuickSort"
MergeSort.new mergeSort_test
mergeSort_test.name = "MergeSort"

# Test strategy switching
sorter_test.setStrategy "bubbleSort_test"
sorter_test.setData "5 3 8 1 9 2"
result1=$(sorter_test.getStrategyName)
result2=$(sorter_test.performSort)

sorter_test.setStrategy "quickSort_test"
result3=$(sorter_test.getStrategyName)

sorter_test.setStrategy "mergeSort_test"
result4=$(sorter_test.getStrategyName)

if [[ "$result1" == "BubbleSort" ]] && [[ "$result2" == *"Sorting data: 5 3 8 1 9 2"* ]] && \
   [[ "$result2" == *"bubble sort algorithm"* ]] && \
   [[ "$result3" == "QuickSort" ]] && [[ "$result4" == "MergeSort" ]]; then
    test_pass "Strategy pattern"
else
    test_fail "Strategy pattern (result1: '$result1', result3: '$result3', result4: '$result4')"
fi

sorter_test.delete
bubbleSort_test.delete
quickSort_test.delete
mergeSort_test.delete