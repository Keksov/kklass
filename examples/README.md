# Kklass Usage Examples

This directory contains comprehensive examples demonstrating the features and capabilities of the kklass object-oriented programming system for Bash.

## Quick Start

### Run All Examples
```bash
cd lib/kklass
bash examples/demo.sh
```

The demo script will run through all 43 examples sequentially, showing the progress and results. Use `bash examples/demo.sh --help` for more options.

### Example Runner Features

- **Simple execution**: Easy-to-use scripts that run examples sequentially
- **Manual control**: Run all examples or select specific ones as needed
- **Clear output**: Each example shows its progress and results
- **Error handling**: Individual examples handle their own errors gracefully
- **Automatic cleanup**: Each example cleans up its own instances and files
- **Progress tracking**: Clear indicators show which examples are running

## Overview

The examples are organized into four main sections:

- **Section 1 (Examples 01-21)**: Core functionality tests
- **Section 2 (Examples 22-28)**: Autoload and compilation features
- **Section 3 (Examples 29-31)**: Edge cases and error handling
- **Section 4 (Examples 32-43)**: Advanced design patterns and capabilities

## Examples Index

### Section 1: Core Functionality

| Example | Title | Description |
|---------|-------|-------------|
| [01_basic_class_creation.sh](01_basic_class_creation.sh) | Basic Class Creation | How to define a simple class with properties and methods |
| [02_instance_creation.sh](02_instance_creation.sh) | Instance Creation | Creating instances of classes and verifying their existence |
| [03_property_assignment_access.sh](03_property_assignment_access.sh) | Property Assignment and Access | Setting and getting property values on class instances |
| [04_method_calls.sh](04_method_calls.sh) | Method Calls | Calling methods on class instances |
| [05_single_inheritance.sh](05_single_inheritance.sh) | Single Inheritance | Class inheritance where a derived class inherits from a base class |
| [06_method_overriding.sh](06_method_overriding.sh) | Method Overriding | Derived classes overriding methods from their parent class |
| [07_parent_method_calls.sh](07_parent_method_calls.sh) | Parent Method Calls | Calling parent class methods from derived classes using `$this.parent` |
| [08_multiple_inheritance_levels.sh](08_multiple_inheritance_levels.sh) | Multiple Inheritance Levels | Deep inheritance chain with multiple levels |
| [09_resource_cleanup.sh](09_resource_cleanup.sh) | Resource Cleanup | Proper cleanup of class instances and their associated functions |
| [10_method_parameters.sh](10_method_parameters.sh) | Method with Parameters | Methods that accept parameters and perform calculations |
| [11_property_inheritance.sh](11_property_inheritance.sh) | Property Inheritance | How properties are inherited from base classes to derived classes |
| [12_property_computation.sh](12_property_computation.sh) | Property Access and Computation in Methods | Methods accessing and performing computations with instance properties |
| [13_multiple_instances.sh](13_multiple_instances.sh) | Multiple Instances of Same Class | Creating and using multiple instances of the same class |
| [14_property_values_with_spaces.sh](14_property_values_with_spaces.sh) | Property Values with Spaces | Handling property values that contain spaces and special characters |
| [15_nested_method_calls.sh](15_nested_method_calls.sh) | Nested Method Calls with `$this` | Method chaining and nested method calls using `$this` |
| [16_constructor_functionality.sh](16_constructor_functionality.sh) | Constructor Functionality | Class constructors and initialization |
| [17_property_inherited_method.sh](17_property_inherited_method.sh) | Property Used in Inherited Method | Accessing inherited properties within methods |
| [18_parent_method_with_properties.sh](18_parent_method_with_properties.sh) | Method Calling Parent and Using Properties | Methods that call parent methods while accessing instance properties |
| [19_this_method_context.sh](19_this_method_context.sh) | `$this.method` Ensures Current Class Context | `$this.method` calls methods in the current class context |
| [20_multiple_parameters_property_access.sh](20_multiple_parameters_property_access.sh) | Method with Multiple Parameters and Property Access | Methods that accept multiple parameters and access instance properties |
| [21_property_method_access.sh](21_property_method_access.sh) | Property Access via `.property` Method | Accessing properties using the `.property` method syntax |

### Section 2: Autoload and Compilation

| Example | Title | Description |
|---------|-------|-------------|
| [22_autocompilation_first_load.sh](22_autocompilation_first_load.sh) | Auto-compilation (First Load) | Automatic compilation of `.kk` files on first load |
| [23_cached_compiled_version.sh](23_cached_compiled_version.sh) | Using Cached Compiled Version | Using cached compiled versions instead of recompiling |
| [24_auto_recompilation.sh](24_auto_recompilation.sh) | Auto-recompilation on Source Change | Automatic recompilation when source files are modified |
| [25_force_recompilation.sh](25_force_recompilation.sh) | Force Recompilation | Forcing recompilation of source files |
| [26_runtime_mode.sh](26_runtime_mode.sh) | Runtime Mode (`--no-compile`) | Runtime mode that skips compilation and uses direct interpretation |
| [27_functional_test_compiled.sh](27_functional_test_compiled.sh) | Functional Test with Compiled Classes | Functional testing of compiled classes |
| [28_inheritance_compiled.sh](28_inheritance_compiled.sh) | Inheritance in Compiled Classes | Inheritance works correctly in compiled classes |

### Section 3: Edge Cases and Error Handling

| Example | Title | Description |
|---------|-------|-------------|
| [29_error_handling.sh](29_error_handling.sh) | Error Handling - Non-existent Method | Error handling when calling non-existent methods |
| [30_complex_property_names.sh](30_complex_property_names.sh) | Complex Property Names | Using property names with underscores and numbers |
| [31_deep_inheritance_chain.sh](31_deep_inheritance_chain.sh) | Deep Inheritance Chain with Properties | Deep inheritance hierarchy with properties at each level |

### Section 4: Advanced Design Patterns

| Example | Title | Description |
|---------|-------|-------------|
| [32_static_methods_properties.sh](32_static_methods_properties.sh) | Static/Class Methods and Properties | Class-level methods and properties that belong to the class itself |
| [33_introspection_capabilities.sh](33_introspection_capabilities.sh) | Introspection Capabilities | Getting information about classes, instances, methods, and properties |
| [34_composition_patterns.sh](34_composition_patterns.sh) | Composition Patterns | Objects containing other objects as properties (composition over inheritance) |
| [35_factory_pattern.sh](35_factory_pattern.sh) | Factory Pattern | Creating objects through factory methods |
| [36_singleton_pattern.sh](36_singleton_pattern.sh) | Singleton Pattern | Ensuring only one instance of a class exists |
| [37_computed_and_lazy_properties.sh](37_computed_and_lazy_properties.sh) | Computed and Lazy Properties | Properties computed on-demand and lazy evaluation |
| [38_observer_pattern.sh](38_observer_pattern.sh) | Observer Pattern | Event-driven programming with observers and notifications |
| [39_strategy_pattern.sh](39_strategy_pattern.sh) | Strategy Pattern | Encapsulating algorithms that can be swapped at runtime |
| [40_builder_pattern.sh](40_builder_pattern.sh) | Builder Pattern | Step-by-step construction of complex objects |
| [41_string_serialization.sh](41_string_serialization.sh) | String Serialization | Converting objects to/from string format |
| [42_json_serialization.sh](42_json_serialization.sh) | JSON Serialization | Converting objects to/from JSON format |
| [43_nested_serialization.sh](43_nested_serialization.sh) | Nested Serialization | Serialization of nested objects and complex structures |

## Running the Examples

### Using the Demo Script (Recommended)

The easiest way to run all examples is using the provided demo script:

```bash
# Make sure you're in the kklass directory
cd lib/kklass

# Run all examples (recommended)
bash examples/demo.sh

# Or run all examples manually
for file in examples/[0-9]*.sh; do
    echo "=== $(basename "$file") ==="
    bash "$file"
    echo
done
```

**Note**: The demo script runs all 43 examples sequentially and shows:
- ✅ **Progress indicators** for each example
- ✅ **Success/failure status** for each example
- ✅ **Automatic cleanup** after each example
- ✅ **Summary report** at the end

### Manual Execution

To run individual examples:

```bash
# Make sure you're in the kklass directory
cd lib/kklass

# Run a specific example
bash examples/01_basic_class_creation.sh

# Or run all examples manually
for example in examples/*.sh; do
    echo "=== Running $example ==="
    bash "$example"
    echo
done
```

## Prerequisites

- All examples require the kklass system to be sourced
- Some examples (22-28) require both `kklass.sh` and `kklass_autoload.sh`
- Examples create temporary files and clean them up automatically

## Notes

- All examples are self-contained and include cleanup code
- Examples demonstrate both successful execution and error conditions
- Each example focuses on a specific feature or concept
- Examples are designed to be run independently
- All comments and output are in English as requested

## Learning Path

For new users, we recommend following this learning sequence:

1. **Start with basics**: 01, 02, 03, 04
2. **Learn inheritance**: 05, 06, 07, 08
3. **Explore advanced features**: 09-21
4. **Try compilation features**: 22-28
5. **Handle edge cases**: 29-31
6. **Master design patterns**: 32-43

Each example builds on previous concepts while being standalone.

### Advanced Pattern Deep Dive

For users interested in advanced OOP patterns, consider this specialized sequence:

- **Static/class concepts**: 32 (Static Methods/Properties)
- **Runtime inspection**: 33 (Introspection)
- **Object composition**: 34 (Composition Patterns)
- **Creational patterns**: 35 (Factory), 36 (Singleton), 40 (Builder)
- **Advanced properties**: 37 (Computed and Lazy Properties)
- **Behavioral patterns**: 38 (Observer), 39 (Strategy)
- **Data management**: 41 (String Serialization), 42 (JSON Serialization), 43 (Nested Serialization)