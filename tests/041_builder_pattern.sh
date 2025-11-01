#!/bin/bash
# 041_builder_pattern.sh - Test builder pattern

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 41: Builder pattern
test_start "Builder pattern"
defineClass "Computer" "" \
    "property" "cpu" \
    "property" "ram" \
    "property" "storage" \
    "property" "gpu" \
    "property" "os" \
    "property" "accessories" \
    "method" "getSpecs" 'echo "CPU: $cpu, RAM: $ram, Storage: $storage, GPU: $gpu, OS: $os, Accessories: $accessories"'

defineClass "ComputerBuilder" "" \
    "property" "computer" \
    "property" "counter" \
    "method" "createComputer" 'counter=$((counter + 1)); local name="comp_$counter"; Computer.new "$name"; computer="$name"' \
    "method" "setCPU" 'eval "$computer.cpu = \"\$1\""' \
    "method" "setRAM" 'eval "$computer.ram = \"\$1\""' \
    "method" "setStorage" 'eval "$computer.storage = \"\$1\""' \
    "method" "setGPU" 'eval "$computer.gpu = \"\$1\""' \
    "method" "setOS" 'eval "$computer.os = \"\$1\""' \
    "method" "addAccessory" 'local acc="$(eval "$computer.accessories")"; eval "$computer.accessories = \"\$acc \$1\""' \
    "method" "build" 'echo "$computer"'

ComputerBuilder.new builder_test
builder_test.createComputer
builder_test.setCPU "Intel i9-12900K"
builder_test.setRAM "32GB DDR5"
builder_test.setStorage "2TB NVMe SSD"
builder_test.setGPU "NVIDIA RTX 4080"
builder_test.setOS "Windows 11"
builder_test.addAccessory "Gaming Keyboard"
builder_test.addAccessory "Gaming Mouse"
gaming_computer=$(builder_test.build)

specs=$(eval "$gaming_computer.getSpecs")
if [[ "$specs" == *"Intel i9-12900K"* ]] && [[ "$specs" == *"32GB DDR5"* ]] && [[ "$specs" == *"Gaming Mouse"* ]]; then
    # Build second computer to test reusability
    builder_test.createComputer
    builder_test.setCPU "AMD Ryzen 9"
    builder_test.setRAM "64GB DDR4"
    workstation_computer=$(builder_test.build)
    
    specs2=$(eval "$workstation_computer.getSpecs")
    if [[ "$specs2" == *"AMD Ryzen 9"* ]] && [[ "$specs2" == *"64GB DDR4"* ]] && [[ "$specs2" != *"Gaming Mouse"* ]]; then
        test_pass "Builder pattern"
    else
        test_fail "Builder pattern - second build failed (got: '$specs2')"
    fi
    
    eval "$workstation_computer.delete" 2>/dev/null || true
else
    test_fail "Builder pattern - first build failed (got: '$specs')"
fi

builder_test.delete
eval "$gaming_computer.delete" 2>/dev/null || true