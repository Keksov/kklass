#!/bin/bash
# Example 40: Builder Pattern
# Demonstrates step-by-step construction of complex objects

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Builder Pattern Example ==="
echo

# Define the complex product class
defineClass "Computer" "" \
    "property" "cpu" \
    "property" "ram" \
    "property" "storage" \
    "property" "gpu" \
    "property" "os" \
    "property" "accessories" \
    "method" "getSpecs" 'echo "CPU: $cpu, RAM: $ram, Storage: $storage, GPU: $gpu, OS: $os, Accessories: $accessories"'

# Define the builder class
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

echo "✓ Builder pattern classes defined"

# Demonstrate builder pattern
echo "=== Building Computers with Builder Pattern ==="

# Create builder instance
ComputerBuilder.new builder

echo "✓ Computer builder created"

# Build a gaming computer step by step
echo
echo "=== Building Gaming Computer ==="
builder.createComputer
builder.setCPU "Intel i9-12900K"
builder.setRAM "32GB DDR5"
builder.setStorage "2TB NVMe SSD"
builder.setGPU "NVIDIA RTX 4080"
builder.setOS "Windows 11"
builder.addAccessory "Gaming Keyboard"
builder.addAccessory "Gaming Mouse"
builder.addAccessory "4K Monitor"
gaming_computer=$(builder.build)

echo "Gaming computer specs: $($gaming_computer.getSpecs)"

# Build a workstation computer
echo
echo "=== Building Workstation Computer ==="
builder.createComputer
builder.setCPU "AMD Ryzen 9 5950X"
builder.setRAM "64GB DDR4"
builder.setStorage "4TB NVMe SSD + 8TB HDD"
builder.setGPU "NVIDIA RTX A6000"
builder.setOS "Ubuntu Linux"
builder.addAccessory "Professional Monitor"
builder.addAccessory "Ergonomic Keyboard"
workstation_computer=$(builder.build)

echo "Workstation computer specs: $($workstation_computer.getSpecs)"

# Build a basic office computer
echo
echo "=== Building Basic Office Computer ==="
builder.createComputer
builder.setCPU "Intel i5-12400"
builder.setRAM "16GB DDR4"
builder.setStorage "512GB SSD"
builder.setGPU "Integrated Graphics"
builder.setOS "Windows 10"
builder.addAccessory "Standard Keyboard"
builder.addAccessory "Standard Mouse"
office_computer=$(builder.build)

echo "Office computer specs: $($office_computer.getSpecs)"

# Verify builder pattern working
echo
echo "=== Builder Pattern Benefits ==="
echo "Each computer was built step-by-step with different configurations:"
echo "  - Gaming: High-end CPU, GPU, and gaming accessories"
echo "  - Workstation: Professional-grade components for work"
echo "  - Office: Basic components for office use"

# Demonstrate that builder can be reused
echo
echo "=== Builder Reusability ==="
echo "Builder can be reused to create multiple computers with different specs"

# Clean up
builder.delete
eval "$gaming_computer.delete"
eval "$workstation_computer.delete"
eval "$office_computer.delete"
echo "✓ All computers and builder cleaned up"

echo
echo "=== Example completed successfully ==="