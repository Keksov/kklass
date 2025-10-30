# The Complete Kklass Guide
## Object-Oriented Programming in Bash

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Core Concepts](#core-concepts)
4. [Basic Class Operations](#basic-class-operations)
5. [Inheritance](#inheritance)
6. [Advanced Features](#advanced-features)
7. [Compilation and Autoloading](#compilation-and-autoloading)
8. [Serialization](#serialization)
9. [Design Patterns](#design-patterns)
10. [Best Practices](#best-practices)
11. [API Reference](#api-reference)
12. [Troubleshooting](#troubleshooting)

---

## Introduction

### What is Kklass?

Kklass is a comprehensive object-oriented programming (OOP) system for Bash that brings modern OOP concepts to shell scripting. It provides:

- **Classes and Objects**: Define reusable classes and create instances
- **Properties and Methods**: Encapsulate data and behavior
- **Inheritance**: Build class hierarchies with single inheritance
- **Dot Notation**: Natural syntax like `object.method()` and `object.property`
- **Compilation**: Optimize classes for faster execution
- **Serialization**: Save and restore object state
- **Advanced Features**: Static members, computed properties, lazy loading, and more

### Why Use Kklass?

- **Better Code Organization**: Structure complex bash scripts with classes
- **Reusability**: Write once, use everywhere
- **Maintainability**: Clear separation of concerns
- **Type Safety**: Method and property encapsulation
- **Performance**: Compiled classes run faster than interpreted code
- **Modern Patterns**: Implement design patterns in bash

### System Requirements

- Bash 4.3 or higher (for name references)
- Standard Unix utilities (sed, mktemp, stat)
- Optional: bc (for computed properties with arithmetic)
- Optional: md5sum/sha256sum (for serialization examples)

---

## Getting Started

### Installation

1. **Clone or download the kklass system:**

```bash
# If part of a repository
cd your-project/lib/kklass

# Or download standalone
wget https://example.com/kklass.tar.gz
tar -xzf kklass.tar.gz
```

2. **Verify installation:**

```bash
# Check that files exist
ls -la kklass.sh kklass_compiler.sh kklass_autoload.sh kklass_serializable.sh
```

### Your First Class

Create a file `hello_world.sh`:

```bash
#!/bin/bash
# Load the kklass system
source "path/to/kklass.sh"

# Define a simple class
defineClass "Greeter" "" \
    "property" "name" \
    "method" "greet" 'echo "Hello, $name!"'

# Create an instance
Greeter.new greeter

# Use the instance
greeter.name = "World"
greeter.greet

# Clean up
greeter.delete
```

Run it:

```bash
bash hello_world.sh
# Output: Hello, World!
```

---

## Core Concepts

### Classes

A **class** is a blueprint for creating objects. It defines:
- **Properties**: Data that objects will hold
- **Methods**: Functions that objects can perform
- **Constructors**: Initialization code
- **Static members**: Class-level data and functions

### Objects (Instances)

An **object** (or instance) is a concrete realization of a class with its own property values.

### Properties

**Properties** are variables that belong to an object. Each instance has its own property values.

### Methods

**Methods** are functions that belong to a class. They can access and modify the object's properties.

### Inheritance

**Inheritance** allows a class to inherit properties and methods from a parent class, enabling code reuse and hierarchical relationships.

---

## Basic Class Operations

### Defining a Class

Use `defineClass` to create a class:

```bash
defineClass "ClassName" "ParentClass" \
    "property" "propertyName" \
    "method" "methodName" 'method body' \
    "constructor" 'constructor body'
```

**Parameters:**
- `ClassName`: Name of the class (must be valid identifier)
- `ParentClass`: Parent class name (empty string `""` for no parent)
- Followed by property, method, and constructor definitions

**Example:**

```bash
source "kklass.sh"

defineClass "Person" "" \
    "property" "name" \
    "property" "age" \
    "method" "introduce" 'echo "I am $name, $age years old"' \
    "method" "birthday" 'age=$((age + 1)); echo "Happy birthday! Now $age years old"'
```

### Creating Instances

Use `ClassName.new` to create an instance:

```bash
Person.new person1
Person.new person2
```

This creates two separate instances, each with their own property values.

### Setting Properties

Use the assignment syntax `instance.property = value`:

```bash
person1.name = "Alice"
person1.age = "30"

person2.name = "Bob"
person2.age = "25"
```

### Getting Properties

Call the property without assignment:

```bash
echo "Name: $(person1.name)"
echo "Age: $(person1.age)"
```

### Calling Methods

Use `instance.method` syntax:

```bash
person1.introduce
# Output: I am Alice, 30 years old

person1.birthday
# Output: Happy birthday! Now 31 years old
```

### Method Parameters

Methods can accept parameters:

```bash
defineClass "Calculator" "" \
    "method" "add" 'echo $(($1 + $2))' \
    "method" "multiply" 'echo $(($1 * $2))'

Calculator.new calc
calc.add 5 3        # Output: 8
calc.multiply 4 7   # Output: 28
```

### Accessing Properties in Methods

Properties are automatically available as variables inside method bodies:

```bash
defineClass "BankAccount" "" \
    "property" "balance" \
    "method" "deposit" 'balance=$((balance + $1)); echo "New balance: $balance"' \
    "method" "withdraw" 'balance=$((balance - $1)); echo "New balance: $balance"' \
    "method" "getBalance" 'echo "$balance"'

BankAccount.new account
account.balance = "1000"
account.deposit 500    # Output: New balance: 1500
account.withdraw 200   # Output: New balance: 1300
```

### Deleting Instances

Always clean up instances when done:

```bash
person1.delete
person2.delete
account.delete
calc.delete
```

This removes all functions and data associated with the instance.

### Complete Example

```bash
#!/bin/bash
source "kklass.sh"

# Define a Counter class
defineClass "Counter" "" \
    "property" "value" \
    "method" "increment" 'value=$((value + 1)); echo $value' \
    "method" "decrement" 'value=$((value - 1)); echo $value' \
    "method" "reset" 'value=0; echo "Counter reset"' \
    "method" "getValue" 'echo $value'

# Create and use an instance
Counter.new counter
counter.value = "0"

echo "Initial: $(counter.getValue)"
counter.increment  # Output: 1
counter.increment  # Output: 2
counter.increment  # Output: 3
counter.decrement  # Output: 2
echo "Current: $(counter.getValue)"
counter.reset
echo "After reset: $(counter.getValue)"

# Clean up
counter.delete
```

---

## Inheritance

### Single Inheritance

A class can inherit from one parent class:

```bash
defineClass "Animal" "" \
    "property" "species" \
    "property" "name" \
    "method" "speak" 'echo "Some sound"' \
    "method" "identify" 'echo "I am a $species named $name"'

defineClass "Dog" "Animal" \
    "property" "breed" \
    "method" "speak" 'echo "Woof! Woof!"' \
    "method" "wagTail" 'echo "$name wags tail happily"'

Dog.new mydog
mydog.species = "Canine"
mydog.name = "Buddy"
mydog.breed = "Golden Retriever"

mydog.identify   # Output: I am a Canine named Buddy
mydog.speak      # Output: Woof! Woof! (overridden method)
mydog.wagTail    # Output: Buddy wags tail happily
```

**Key Points:**
- Child class inherits all properties and methods from parent
- Child can add new properties and methods
- Child can override parent methods
- Use parent class name as second parameter to `defineClass`

### Method Overriding

Child classes can override parent methods:

```bash
defineClass "Shape" "" \
    "property" "name" \
    "method" "draw" 'echo "Drawing a generic shape"'

defineClass "Circle" "Shape" \
    "property" "radius" \
    "method" "draw" 'echo "Drawing a circle with radius $radius"'

defineClass "Rectangle" "Shape" \
    "property" "width" \
    "property" "height" \
    "method" "draw" 'echo "Drawing a rectangle ${width}x${height}"'

Circle.new circle
circle.name = "MyCircle"
circle.radius = "5"
circle.draw  # Output: Drawing a circle with radius 5

Rectangle.new rect
rect.width = "10"
rect.height = "20"
rect.draw  # Output: Drawing a rectangle 10x20
```

### Calling Parent Methods

Use `$this.parent methodName` to call the parent's version:

```bash
defineClass "Vehicle" "" \
    "property" "brand" \
    "method" "start" 'echo "$brand vehicle starting..."'

defineClass "Car" "Vehicle" \
    "property" "model" \
    "method" "start" 'echo "Checking fuel..."; $this.parent start; echo "Car ready!"'

Car.new mycar
mycar.brand = "Toyota"
mycar.model = "Camry"
mycar.start
# Output:
# Checking fuel...
# Toyota vehicle starting...
# Car ready!
```

### Multiple Inheritance Levels

You can create deep inheritance chains:

```bash
defineClass "LivingBeing" "" \
    "method" "breathe" 'echo "Breathing..."'

defineClass "Animal" "LivingBeing" \
    "property" "species" \
    "method" "move" 'echo "$species is moving"'

defineClass "Mammal" "Animal" \
    "property" "furColor" \
    "method" "nurse" 'echo "Nursing offspring"'

defineClass "Dog" "Mammal" \
    "property" "breed" \
    "method" "bark" 'echo "Woof!"'

Dog.new dog
dog.species = "Canine"
dog.furColor = "Brown"
dog.breed = "Labrador"

# Can use methods from all levels
dog.breathe    # From LivingBeing
dog.move       # From Animal
dog.nurse      # From Mammal
dog.bark       # From Dog
```

### Property Inheritance

Properties are inherited just like methods:

```bash
defineClass "Employee" "" \
    "property" "name" \
    "property" "salary"

defineClass "Manager" "Employee" \
    "property" "department" \
    "property" "teamSize"

Manager.new mgr
mgr.name = "Alice"        # Inherited from Employee
mgr.salary = "80000"      # Inherited from Employee
mgr.department = "IT"     # Own property
mgr.teamSize = "10"       # Own property
```

---

## Advanced Features

### Constructors

Constructors run automatically when an instance is created:

```bash
defineClass "User" "" \
    "property" "username" \
    "property" "id" \
    "property" "created_at" \
    "constructor" '
        username="$1"
        id="$2"
        created_at=$(date +%s)
        echo "User $username created with ID $id"
    ' \
    "method" "getInfo" 'echo "User: $username (ID: $id, created: $created_at)"'

# Constructor receives parameters after instance name
User.new user1 "alice" "1001"
# Output: User alice created with ID 1001

user1.getInfo
# Output: User: alice (ID: 1001, created: 1234567890)

user1.delete
```

### Static Properties and Methods

Static members belong to the class, not instances:

```bash
defineClass "Database" "" \
    "static_property" "connection_count" \
    "static_property" "max_connections" \
    "property" "name" \
    "static_method" "getConnectionCount" 'echo "$connection_count"' \
    "static_method" "incrementConnections" 'connection_count=$((connection_count + 1))' \
    "method" "connect" 'Database.incrementConnections; echo "$name connected"'

# Set static properties
Database.max_connections = "100"
Database.connection_count = "0"

# Call static methods
echo "Connections: $(Database.getConnectionCount)"  # Output: 0

# Create instances
Database.new db1
Database.new db2
db1.name = "UserDB"
db2.name = "LogDB"

db1.connect  # Output: UserDB connected
db2.connect  # Output: LogDB connected

echo "Connections: $(Database.getConnectionCount)"  # Output: 2

db1.delete
db2.delete
```

### Computed Properties

Computed properties calculate their value on-the-fly:

```bash
defineClass "Rectangle" "" \
    "property" "width" \
    "property" "height" \
    "computed_property" "area" "getArea" "-" \
    "method" "getArea" 'echo $((width * height))'

Rectangle.new rect
rect.width = "10"
rect.height = "5"

echo "Area: $(rect.area)"  # Output: Area: 50

rect.height = "8"
echo "Area: $(rect.area)"  # Output: Area: 80 (automatically recalculated)

rect.delete
```

### Computed Properties with Getters and Setters

```bash
defineClass "User" "" \
    "property" "first_name" \
    "property" "last_name" \
    "computed_property" "full_name" "get_full_name" "set_full_name" \
    "method" "get_full_name" 'echo "$first_name $last_name"' \
    "method" "set_full_name" '
        local full="$1"
        local f l
        IFS=" " read -r f l <<< "$full"
        first_name="$f"
        last_name="$l"
    '

User.new user
user.first_name = "John"
user.last_name = "Doe"

echo "Full name: $(user.full_name)"  # Output: Full name: John Doe

# Use setter
user.full_name = "Jane Smith"
echo "First: $(user.first_name)"  # Output: First: Jane
echo "Last: $(user.last_name)"    # Output: Last: Smith

user.delete
```

### Lazy Properties

Lazy properties compute their value only once, on first access:

```bash
defineClass "DataProcessor" "" \
    "property" "filename" \
    "lazy_property" "checksum" "compute_checksum" \
    "method" "compute_checksum" '
        echo "Computing checksum..." >&2
        if [[ -f "$filename" ]]; then
            sha256sum "$filename" 2>/dev/null | cut -d" " -f1
        else
            echo "unknown"
        fi
    '

# Create test file
echo "test data" > /tmp/test.txt

DataProcessor.new processor
processor.filename = "/tmp/test.txt"

# First access: computes the value
echo "Checksum: $(processor.checksum)"
# Output: Computing checksum...
#         Checksum: <hash>

# Second access: uses cached value (no "Computing..." message)
echo "Checksum again: $(processor.checksum)"
# Output: Checksum again: <hash>

rm /tmp/test.txt
processor.delete
```

### Method Chaining with $this

Use `$this.method` to call other methods from within a method:

```bash
defineClass "Logger" "" \
    "property" "prefix" \
    "method" "format" 'echo "[$prefix] $1"' \
    "method" "info" 'echo "$($this.format "$1")"' \
    "method" "error" 'echo "ERROR: $($this.format "$1")"' \
    "method" "warn" 'echo "WARNING: $($this.format "$1")"'

Logger.new logger
logger.prefix = "MyApp"

logger.info "Application started"
# Output: [MyApp] Application started

logger.error "Connection failed"
# Output: ERROR: [MyApp] Connection failed

logger.warn "Low memory"
# Output: WARNING: [MyApp] Low memory

logger.delete
```

### Property Access via .property Method

Alternative syntax for property access:

```bash
defineClass "Config" "" \
    "property" "host" \
    "property" "port"

Config.new config

# Standard syntax
config.host = "localhost"
config.port = "8080"

# Using .property method
config.property "host" = "192.168.1.1"
config.property "port" = "9000"

echo "Host: $(config.property "host")"
echo "Port: $(config.property "port")"

config.delete
```

---

## Compilation and Autoloading

### Why Compile?

Compilation converts class definitions into optimized bash code that:
- **Loads faster**: No runtime class definition overhead
- **Runs faster**: Optimized function calls
- **Distributes easily**: Single compiled file

### Manual Compilation

**Step 1:** Create a class definition file (`my_classes.kk`):

```bash
# my_classes.kk
defineClass Counter "" \
    property value \
    method increment 'value=$((value + 1)); echo $value' \
    method getValue 'echo $value'

defineClass Timer Counter \
    property start_time \
    method startTimer 'start_time=$(date +%s)' \
    method elapsed 'echo $(($(date +%s) - start_time))'
```

**Step 2:** Compile the file:

```bash
bash kklass_compiler.sh my_classes.kk my_classes_compiled.sh
```

**Step 3:** Use the compiled classes:

```bash
#!/bin/bash
source my_classes_compiled.sh

Counter.new counter
counter.value = "0"
counter.increment  # Output: 1
counter.increment  # Output: 2

counter.delete
```

### Autoloading with kklass_autoload.sh

Autoloading automatically compiles and caches classes:

```bash
#!/bin/bash
source "kklass_autoload.sh"

# Automatically compiles if needed, caches result
kkload "my_classes.kk"

# Use classes normally
Counter.new counter
counter.value = "10"
counter.increment

counter.delete
```

**Autoload Features:**

1. **First Load**: Compiles `.kk` file to `.ckk/filename.ckk.sh`
2. **Subsequent Loads**: Uses cached compiled version
3. **Smart Recompilation**: Recompiles if source is newer
4. **Force Compilation**: `kkload "file.kk" --force-compile`
5. **Runtime Mode**: `kkload "file.kk" --no-compile` (skip compilation)

### Autoload Helper Functions

```bash
# Load classes (auto-compile if needed)
kkload "my_classes.kk"

# Force recompilation
kkrecompile "my_classes.kk"

# Show autoload information
kkinfo
# Output:
# Mode: Compiled
# File: .ckk/my_classes.ckk.sh
# Classes: Counter Timer
```

### Compilation Workflow

```
┌─────────────────┐
│  my_classes.kk  │  (Source file)
└────────┬────────┘
         │
         │ kkload (first time)
         ▼
    ┌─────────┐
    │ Compile │
    └────┬────┘
         │
         ▼
┌─────────────────────────┐
│ .ckk/my_classes.ckk.sh  │  (Cached compiled file)
└─────────────────────────┘
         │
         │ kkload (subsequent times)
         ▼
    ┌─────────┐
    │  Load   │  (Fast!)
    └─────────┘
```

### Complete Autoload Example

**Create `person.kk`:**

```bash
defineClass Person "" \
    property name \
    property age \
    constructor 'name="$1"; age="$2"' \
    method introduce 'echo "I am $name, $age years old"' \
    method birthday 'age=$((age + 1)); echo "Now $age years old"'

defineClass Employee Person \
    property salary \
    property position \
    method promote 'echo "$name promoted to $1"; position="$1"' \
    method raise 'salary=$((salary + $1)); echo "Salary now: $salary"'
```

**Use with autoload (`main.sh`):**

```bash
#!/bin/bash
source "kklass_autoload.sh"

# Auto-compiles on first run
kkload "person.kk"

Employee.new emp "Alice" "30"
emp.salary = "50000"
emp.position = "Developer"

emp.introduce
emp.promote "Senior Developer"
emp.raise 10000

emp.delete
```

**First run:**
```bash
bash main.sh
# Output:
# [autoload] Compiled file not found: .ckk/person.ckk.sh
# [autoload] Compiling: person.kk -> .ckk/person.ckk.sh
# ✓ Compiled 2 classes to: .ckk/person.ckk.sh
#   Classes: Person Employee
# [autoload] Compilation successful
# I am Alice, 30 years old
# Alice promoted to Senior Developer
# Salary now: 60000
```

**Second run (uses cache):**
```bash
bash main.sh
# Output:
# [autoload] Using cached compiled file: .ckk/person.ckk.sh
# I am Alice, 30 years old
# Alice promoted to Senior Developer
# Salary now: 60000
```

---

## Serialization

### What is Serialization?

Serialization converts object state into a format that can be:
- Saved to files
- Transmitted over networks
- Restored later

Kklass supports:
- **String serialization**: Custom delimiter-separated format
- **JSON serialization**: Standard JSON format

### String Serialization with defineSerializableClass

**Define a serializable class:**

```bash
source "kklass.sh"
source "kklass_serializable.sh"

defineSerializableClass "User" "" ":" "string" \
    "property" "id" \
    "property" "username" \
    "property" "email" \
    "method" "getInfo" 'echo "User $username <$email>"'
```

**Parameters:**
- `"User"`: Class name
- `""`: Parent class (empty for none)
- `":"`: Field separator
- `"string"`: Serialization format

**Usage:**

```bash
# Create and populate
User.new user1
user1.id = "1"
user1.username = "alice"
user1.email = "alice@example.com"

# Serialize
serialized=$(user1.toString)
echo "$serialized"
# Output: User:1:alice:alice@example.com

# Deserialize
User.new user2
user2.fromString "$serialized"

echo "$(user2.getInfo)"
# Output: User alice <alice@example.com>

user1.delete
user2.delete
```

### Adding Serialization to Existing Classes

Use `addSerializable` to add serialization to a class after definition:

```bash
source "kklass.sh"
source "kklass_serializable.sh"

# Define class normally
defineClass "Product" "" \
    "property" "code" \
    "property" "name" \
    "property" "price" \
    "method" "getInfo" 'echo "$code: $name (\$$price)"'

# Add string serialization
addSerializable "Product" ":" "string"

# Use serialization
Product.new prod
prod.code = "A001"
prod.name = "Widget"
prod.price = "29.99"

data=$(prod.toString)
echo "$data"
# Output: Product:A001:Widget:29.99

prod.delete
```

### JSON Serialization

```bash
source "kklass.sh"
source "kklass_serializable.sh"

defineClass "Book" "" \
    "property" "isbn" \
    "property" "title" \
    "property" "author" \
    "property" "year"

# Add JSON serialization
addSerializable "Book" "" "json"

Book.new book1
book1.isbn = "978-0-123456-78-9"
book1.title = "Learning Bash"
book1.author = "John Doe"
book1.year = "2023"

# Serialize to JSON
json=$(book1.toJSON)
echo "$json"
# Output: {"__class__":"Book","isbn":"978-0-123456-78-9","title":"Learning Bash","author":"John Doe","year":"2023"}

# Deserialize from JSON
Book.new book2
book2.fromJSON "$json"

echo "Title: $(book2.title)"
echo "Author: $(book2.author)"

book1.delete
book2.delete
```

### Mixed Format Serialization

A class can support both string and JSON:

```bash
defineClass "Item" "" \
    "property" "id" \
    "property" "name" \
    "property" "quantity"

# Add both formats
addSerializable "Item" ":" "string"
addSerializable "Item" "" "json"

Item.new item
item.id = "101"
item.name = "Laptop"
item.quantity = "5"

# Both work
str_data=$(item.toString)
json_data=$(item.toJSON)

echo "String: $str_data"
echo "JSON: $json_data"

item.delete
```

### Saving Multiple Objects to File

Use utility functions to save/load multiple objects:

```bash
source "kklass.sh"
source "kklass_serializable.sh"

defineSerializableClass "Contact" "" "|" "string" \
    "property" "name" \
    "property" "phone" \
    "property" "email"

# Create contacts
Contact.new contact1
contact1.name = "Alice"
contact1.phone = "555-1234"
contact1.email = "alice@example.com"

Contact.new contact2
contact2.name = "Bob"
contact2.phone = "555-5678"
contact2.email = "bob@example.com"

# Save to file
saveObjects "contacts.dat" contact1 contact2
echo "Saved to contacts.dat"

# Clean up
contact1.delete
contact2.delete

# Load from file
declare -a loaded_contacts
loadObjects "contacts.dat" "Contact" loaded_contacts

echo "Loaded ${#loaded_contacts[@]} contacts:"
for contact in "${loaded_contacts[@]}"; do
    echo "  - $(${contact}.name): $(${contact}.phone)"
done

# Clean up loaded objects
for contact in "${loaded_contacts[@]}"; do
    ${contact}.delete
done

rm contacts.dat
```

### Nested Object Serialization

```bash
source "kklass.sh"
source "kklass_serializable.sh"

# Define classes
defineClass "Address" "" \
    "property" "street" \
    "property" "city" \
    "property" "zipcode"

defineClass "Person" "" \
    "property" "name" \
    "property" "address_data"

# Add serialization
addSerializable "Address" ":" "string"
addSerializable "Person" "|" "string"

# Create address
Address.new addr
addr.street = "123 Main St"
addr.city = "Springfield"
addr.zipcode = "12345"

# Create person with embedded address
Person.new person
person.name = "John Doe"
person.address_data = "$(addr.toString)"

# Serialize person
person_str=$(person.toString)
echo "$person_str"

# Deserialize person
Person.new person2
person2.fromString "$person_str"

# Deserialize nested address
Address.new addr2
addr2.fromString "$(person2.address_data)"

echo "Name: $(person2.name)"
echo "City: $(addr2.city)"

# Clean up
addr.delete
person.delete
person2.delete
addr2.delete
```

---

## Design Patterns

### Factory Pattern

Create objects through factory methods:

```bash
source "kklass.sh"

defineClass "Shape" "" \
    "property" "type" \
    "method" "draw" 'echo "Drawing $type"'

defineClass "ShapeFactory" "" \
    "static_property" "count" \
    "static_method" "createShape" '
        local shape_type="$1"
        local instance_name="shape_$count"
        Shape.new "$instance_name"
        eval "${instance_name}.type = \"$shape_type\""
        count=$((count + 1))
        echo "$instance_name"
    '

ShapeFactory.count = "0"

# Use factory
circle=$(ShapeFactory.createShape "Circle")
square=$(ShapeFactory.createShape "Square")

eval "$circle.draw"   # Output: Drawing Circle
eval "$square.draw"   # Output: Drawing Square

eval "$circle.delete"
eval "$square.delete"
```

### Singleton Pattern

Ensure only one instance exists:

```bash
source "kklass.sh"

defineClass "DatabaseConnection" "" \
    "static_property" "instance" \
    "static_property" "exists" \
    "property" "host" \
    "property" "port" \
    "static_method" "getInstance" '
        if [[ "$exists" != "true" ]]; then
            DatabaseConnection.new db_singleton
            instance="db_singleton"
            exists="true"
            echo "New connection created"
        else
            echo "Using existing connection"
        fi
        echo "$instance"
    ' \
    "method" "connect" 'echo "Connected to $host:$port"'

# Initialize
DatabaseConnection.exists = "false"

# Get instance (creates new)
conn1=$(DatabaseConnection.getInstance)
eval "$conn1.host = \"localhost\""
eval "$conn1.port = \"5432\""
eval "$conn1.connect"

# Get instance again (returns existing)
conn2=$(DatabaseConnection.getInstance)
eval "$conn2.connect"  # Uses same connection

eval "$conn1.delete"
```

### Observer Pattern

Event-driven programming with notifications:

```bash
source "kklass.sh"

defineClass "Observable" "" \
    "property" "observers" \
    "method" "attach" 'observers="$observers $1"' \
    "method" "notify" '
        for observer in $observers; do
            eval "$observer.update \"$1\""
        done
    '

defineClass "Observer" "" \
    "property" "name" \
    "method" "update" 'echo "[$name] Received: $1"'

# Create observable
Observable.new subject

# Create observers
Observer.new obs1
obs1.name = "Observer1"

Observer.new obs2
obs2.name = "Observer2"

# Attach observers
subject.attach "obs1"
subject.attach "obs2"

# Notify all
subject.notify "Important event occurred"
# Output:
# [Observer1] Received: Important event occurred
# [Observer2] Received: Important event occurred

subject.delete
obs1.delete
obs2.delete
```

### Strategy Pattern

Swap algorithms at runtime:

```bash
source "kklass.sh"

defineClass "SortStrategy" "" \
    "property" "name" \
    "method" "sort" 'echo "[$name] Sorting..."'

defineClass "BubbleSort" "SortStrategy" \
    "method" "sort" 'echo "[$name] Using bubble sort"'

defineClass "QuickSort" "SortStrategy" \
    "method" "sort" 'echo "[$name] Using quick sort"'

defineClass "Sorter" "" \
    "property" "strategy" \
    "method" "setStrategy" 'strategy="$1"' \
    "method" "performSort" 'eval "${strategy}.sort"'

# Create strategies
BubbleSort.new bubble
bubble.name = "Bubble"

QuickSort.new quick
quick.name = "Quick"

# Create sorter
Sorter.new sorter

# Use bubble sort
sorter.setStrategy "bubble"
sorter.performSort  # Output: [Bubble] Using bubble sort

# Switch to quick sort
sorter.setStrategy "quick"
sorter.performSort  # Output: [Quick] Using quick sort

sorter.delete
bubble.delete
quick.delete
```

### Builder Pattern

Construct complex objects step by step:

```bash
source "kklass.sh"

defineClass "Pizza" "" \
    "property" "size" \
    "property" "crust" \
    "property" "toppings" \
    "method" "describe" 'echo "$size pizza with $crust crust, toppings: $toppings"'

defineClass "PizzaBuilder" "" \
    "property" "pizza" \
    "method" "createPizza" 'Pizza.new built_pizza; pizza="built_pizza"' \
    "method" "setSize" 'eval "$pizza.size = \"$1\""' \
    "method" "setCrust" 'eval "$pizza.crust = \"$1\""' \
    "method" "addTopping" 'local current=$(eval "$pizza.toppings"); eval "$pizza.toppings = \"$current $1\""' \
    "method" "build" 'echo "$pizza"'

# Build pizza
PizzaBuilder.new builder
builder.createPizza
builder.setSize "Large"
builder.setCrust "Thin"
builder.addTopping "Pepperoni"
builder.addTopping "Mushrooms"
builder.addTopping "Olives"

my_pizza=$(builder.build)
eval "$my_pizza.describe"
# Output: Large pizza with Thin crust, toppings:  Pepperoni Mushrooms Olives

builder.delete
eval "$my_pizza.delete"
```

### Composition Pattern

Objects containing other objects:

```bash
source "kklass.sh"

defineClass "Engine" "" \
    "property" "type" \
    "property" "horsepower" \
    "method" "start" 'echo "Starting $type engine ($horsepower HP)"'

defineClass "Wheel" "" \
    "property" "size" \
    "method" "info" 'echo "$size inch wheel"'

defineClass "Car" "" \
    "property" "model" \
    "property" "engine" \
    "property" "wheel" \
    "method" "assemble" '
        Engine.new car_engine
        car_engine.type = "V8"
        car_engine.horsepower = "450"
        engine="car_engine"
        
        Wheel.new car_wheel
        car_wheel.size = "18"
        wheel="car_wheel"
    ' \
    "method" "start" '
        echo "Starting $model"
        eval "$engine.start"
    ' \
    "method" "info" '
        echo "Car: $model"
        eval "$wheel.info"
    '

Car.new mycar
mycar.model = "SportsCar"
mycar.assemble
mycar.start
mycar.info

mycar.delete
```

---

## Best Practices

### Naming Conventions

```bash
# Classes: PascalCase
defineClass "BankAccount" "" ...
defineClass "UserManager" "" ...

# Properties: snake_case
"property" "user_name"
"property" "account_balance"

# Methods: camelCase or snake_case (be consistent)
"method" "getBalance" ...
"method" "get_balance" ...

# Instances: camelCase or snake_case
BankAccount.new myAccount
UserManager.new user_manager
```

### Always Clean Up

```bash
# Good: Clean up instances
User.new user
# ... use user ...
user.delete

# Better: Use cleanup function
cleanup() {
    user.delete 2>/dev/null || true
    account.delete 2>/dev/null || true
}
trap cleanup EXIT
```

### Error Handling

```bash
defineClass "FileReader" "" \
    "property" "filename" \
    "method" "read" '
        if [[ ! -f "$filename" ]]; then
            echo "Error: File not found: $filename" >&2
            return 1
        fi
        cat "$filename"
    '

FileReader.new reader
reader.filename = "data.txt"

if reader.read; then
    echo "Success"
else
    echo "Failed to read file"
fi

reader.delete
```

### Composition Over Inheritance

```bash
# Avoid: Deep inheritance chains
defineClass "A" "" ...
defineClass "B" "A" ...
defineClass "C" "B" ...
defineClass "D" "C" ...  # Too deep!

# Prefer: Composition
defineClass "Component1" "" ...
defineClass "Component2" "" ...
defineClass "System" "" \
    "property" "comp1" \
    "property" "comp2" \
    "method" "init" '
        Component1.new my_comp1
        Component2.new my_comp2
        comp1="my_comp1"
        comp2="my_comp2"
    '
```

### Use Compilation for Production

```bash
# Development: Use runtime mode
source "kklass.sh"
source "my_classes_dev.sh"

# Production: Use compiled classes
bash kklass_compiler.sh my_classes.kk my_classes.sh
source "my_classes.sh"

# Or use autoload (best of both)
source "kklass_autoload.sh"
kkload "my_classes.kk"
```

### Document Your Classes

```bash
#!/bin/bash
# user_management.kk
# User management system classes
# Author: Your Name
# Date: 2023-12-01

# Class: User
# Description: Represents a user in the system
# Properties:
#   - id: Unique user identifier
#   - username: User's login name
#   - email: User's email address
# Methods:
#   - validate: Validates user data
#   - save: Saves user to database
defineClass "User" "" \
    "property" "id" \
    "property" "username" \
    "property" "email" \
    "method" "validate" '...' \
    "method" "save" '...'
```

### Keep Methods Small

```bash
# Bad: Large method doing everything
"method" "processUser" '
    # 100 lines of code
    # Validation
    # Database access
    # Email sending
    # Logging
    # Error handling
    '

# Good: Small, focused methods
"method" "validate" 'if [[ -z "$username" ]]; then return 1; fi'
"method" "save" '...'
"method" "sendWelcomeEmail" '...'
"method" "log" '...'
"method" "processUser" '
    $this.validate || return 1
    $this.save
    $this.sendWelcomeEmail
    $this.log "User processed"
'
```

---

## API Reference

### defineClass

Define a new class.

```bash
defineClass CLASS_NAME PARENT_CLASS DEFINITIONS...
```

**Parameters:**
- `CLASS_NAME`: Name of the class (string)
- `PARENT_CLASS`: Parent class name (empty string for none)
- `DEFINITIONS`: Variable-length list of definitions

**Definitions:**
- `"property" NAME`: Define a property
- `"method" NAME BODY`: Define a method
- `"constructor" BODY`: Define constructor
- `"static_property" NAME`: Define static property
- `"static_method" NAME BODY`: Define static method
- `"computed_property" NAME GETTER SETTER`: Define computed property
- `"lazy_property" NAME INIT`: Define lazy property

**Returns:** Echoes confirmation message

**Example:**
```bash
defineClass "MyClass" "ParentClass" \
    "property" "myProp" \
    "method" "myMethod" 'echo "Hello"'
```

### ClassName.new

Create an instance of a class.

```bash
ClassName.new INSTANCE_NAME [CONSTRUCTOR_ARGS...]
```

**Parameters:**
- `INSTANCE_NAME`: Name for the instance (must be valid identifier)
- `CONSTRUCTOR_ARGS`: Optional arguments passed to constructor

**Returns:** Creates instance functions

**Example:**
```bash
User.new user1 "alice" "alice@example.com"
```

### instance.property = value

Set a property value.

```bash
instance.property = VALUE
```

**Parameters:**
- `VALUE`: Value to assign to property

**Example:**
```bash
user1.name = "Alice"
user1.age = "30"
```

### instance.property

Get a property value.

```bash
$(instance.property)
```

**Returns:** Property value

**Example:**
```bash
name=$(user1.name)
echo "Name: $name"
```

### instance.method

Call an instance method.

```bash
instance.method [ARGS...]
```

**Parameters:**
- `ARGS`: Optional method arguments

**Returns:** Method output

**Example:**
```bash
user1.greet "Hello"
```

### instance.delete

Delete an instance and clean up resources.

```bash
instance.delete
```

**Example:**
```bash
user1.delete
```

### $this.method

Call method from within another method.

```bash
# Inside method body:
$this.method_name [ARGS...]
```

**Example:**
```bash
"method" "greet" '$this.format_name; echo "Hello"'
```

### $this.parent

Call parent class method.

```bash
# Inside method body:
$this.parent method_name [ARGS...]
```

**Example:**
```bash
"method" "speak" 'echo "Woof!"; $this.parent speak'
```

### defineSerializableClass

Define a class with automatic serialization.

```bash
defineSerializableClass CLASS_NAME PARENT_CLASS SEPARATOR FORMAT DEFINITIONS...
```

**Parameters:**
- `CLASS_NAME`: Name of the class
- `PARENT_CLASS`: Parent class name
- `SEPARATOR`: Field separator (e.g., ":", "|")
- `FORMAT`: "string" or "json"
- `DEFINITIONS`: Property/method definitions

**Example:**
```bash
defineSerializableClass "User" "" ":" "string" \
    "property" "id" \
    "property" "name"
```

### addSerializable

Add serialization to existing class.

```bash
addSerializable CLASS_NAME [SEPARATOR] [FORMAT]
```

**Parameters:**
- `CLASS_NAME`: Name of existing class
- `SEPARATOR`: Field separator (default: ":")
- `FORMAT`: "string" or "json" (default: "string")

**Example:**
```bash
addSerializable "User" ":" "string"
addSerializable "User" "" "json"
```

### instance.toString

Serialize instance to string.

```bash
$(instance.toString)
```

**Returns:** Serialized string

**Example:**
```bash
data=$(user.toString)
```

### instance.fromString

Deserialize instance from string.

```bash
instance.fromString STRING_DATA
```

**Parameters:**
- `STRING_DATA`: Serialized string

**Example:**
```bash
user.fromString "$data"
```

### instance.toJSON

Serialize instance to JSON.

```bash
$(instance.toJSON)
```

**Returns:** JSON string

**Example:**
```bash
json=$(user.toJSON)
```

### instance.fromJSON

Deserialize instance from JSON.

```bash
instance.fromJSON JSON_DATA
```

**Parameters:**
- `JSON_DATA`: JSON string

**Example:**
```bash
user.fromJSON "$json"
```

### saveObjects

Save multiple objects to file.

```bash
saveObjects FILE_PATH INSTANCE1 INSTANCE2 ...
```

**Parameters:**
- `FILE_PATH`: Output file path
- `INSTANCES`: List of instance names

**Example:**
```bash
saveObjects "data.txt" user1 user2 user3
```

### loadObjects

Load objects from file.

```bash
loadObjects FILE_PATH CLASS_NAME ARRAY_VAR
```

**Parameters:**
- `FILE_PATH`: Input file path
- `CLASS_NAME`: Class name for deserialization
- `ARRAY_VAR`: Variable name to receive loaded instance names

**Example:**
```bash
declare -a users
loadObjects "data.txt" "User" users
```

### compile_class_file

Compile class definitions to optimized bash code.

```bash
bash kklass_compiler.sh INPUT.kk OUTPUT.sh
```

**Parameters:**
- `INPUT.kk`: Source class definition file
- `OUTPUT.sh`: Output compiled file

**Example:**
```bash
bash kklass_compiler.sh my_classes.kk my_classes.sh
```

### kkload / autoloadClasses

Load classes with automatic compilation.

```bash
kkload FILE.kk [OPTIONS]
```

**Options:**
- `--force-compile`: Force recompilation
- `--no-compile`: Skip compilation, use runtime

**Example:**
```bash
kkload "my_classes.kk"
kkload "my_classes.kk" --force-compile
```

### kkrecompile

Force recompilation of classes.

```bash
kkrecompile FILE.kk
```

**Example:**
```bash
kkrecompile "my_classes.kk"
```

### kkinfo

Show information about loaded compiled classes.

```bash
kkinfo
```

**Output:**
```
Mode: Compiled
File: .ckk/my_classes.ckk.sh
Classes: Counter Timer
```

---

## Troubleshooting

### Common Issues

#### 1. "Invalid instance name" error

**Problem:**
```bash
MyClass.new "my-instance"
# Error: Invalid instance name: my-instance
```

**Solution:** Use valid identifier (letters, numbers, underscores only):
```bash
MyClass.new my_instance
```

#### 2. Properties not accessible in methods

**Problem:**
```bash
defineClass "Test" "" \
    "property" "value" \
    "method" "show" 'echo $val'  # Wrong: $val instead of $value
```

**Solution:** Use exact property name:
```bash
defineClass "Test" "" \
    "property" "value" \
    "method" "show" 'echo $value'
```

#### 3. Method not calling parent correctly

**Problem:**
```bash
"method" "greet" 'parent.greet'  # Wrong syntax
```

**Solution:**
```bash
"method" "greet" '$this.parent greet'
```

#### 4. Circular references in composition

**Problem:** Objects referencing each other causing issues.

**Solution:** Use careful cleanup and avoid cycles:
```bash
cleanup() {
    obj1.delete 2>/dev/null || true
    obj2.delete 2>/dev/null || true
}
trap cleanup EXIT
```

#### 5. Compilation fails silently

**Problem:** `.kk` file has syntax errors.

**Solution:** Test with runtime mode first:
```bash
source "kklass.sh"
source "my_classes.kk"  # Will show errors
```

#### 6. Static properties not shared

**Problem:** Static properties not initialized.

**Solution:** Always initialize static properties:
```bash
Counter.count = "0"  # Initialize before use
```

#### 7. Serialization doesn't work

**Problem:** Forgot to load `kklass_serializable.sh`.

**Solution:**
```bash
source "kklass.sh"
source "kklass_serializable.sh"  # Required!
```

### Debugging Tips

#### Enable Bash Debugging

```bash
#!/bin/bash
set -x  # Enable debug output
source "kklass.sh"
# ... your code ...
```

#### Check Instance Functions

```bash
# List all functions for an instance
declare -F | grep "^declare -f myinstance\."
```

#### Verify Class Metadata

```bash
# Check class properties
declare -p MyClass_class_properties

# Check class methods
declare -p MyClass_class_methods
```

#### Test in Isolation

```bash
# Create minimal test case
#!/bin/bash
source "kklass.sh"

defineClass "TestClass" "" \
    "property" "prop" \
    "method" "test" 'echo "Property: $prop"'

TestClass.new obj
obj.prop = "value"
obj.test
obj.delete
```

### Performance Tips

1. **Use compilation** for production code
2. **Minimize method chaining** - each call has overhead
3. **Cache property accesses** in local variables:
   ```bash
   "method" "compute" '
       local p="$prop"  # Cache property
       # Use $p multiple times
       echo $((p * p + p * 2))
   '
   ```
4. **Avoid excessive object creation** in loops
5. **Clean up unused instances** promptly

### Getting Help

- Check examples in `lib/kklass/examples/`
- Review test suite in `lib/kklass/tests/test_kklass_full.sh`
- Search for similar patterns in examples
- Verify Bash version: `bash --version` (need 4.3+)

---

## Conclusion

Kklass brings powerful object-oriented programming to Bash, enabling:

✅ **Clean, maintainable code** with proper encapsulation
✅ **Reusable components** through classes and inheritance
✅ **Modern patterns** like factories, observers, and strategies
✅ **Performance optimization** via compilation
✅ **Data persistence** through serialization
✅ **Familiar syntax** with dot notation

### Next Steps

1. **Explore examples**: Run `bash examples/demo.sh`
2. **Read tests**: See `tests/test_kklass_full.sh` for comprehensive usage
3. **Build something**: Create your own classes
4. **Optimize**: Use compilation for production scripts

### Resources

- **Examples**: `lib/kklass/examples/` (43 examples)
- **Tests**: `lib/kklass/tests/test_kklass_full.sh` (46 tests)
- **Core Library**: `lib/kklass/kklass.sh`
- **Compiler**: `lib/kklass/kklass_compiler.sh`
- **Autoloader**: `lib/kklass/kklass_autoload.sh`
- **Serialization**: `lib/kklass/kklass_serializable.sh`

---

**Happy Bash OOP Programming!** 🎉

---

*Document Version: 1.0*  
*Last Updated: 2024*  
*For Kklass System v1.0+*
