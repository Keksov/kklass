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
7. [Pascal DSL: class ... end with Real Function Bodies](#pascal-dsl-class--end-with-real-function-bodies)
8. [Compilation and Autoloading](#compilation-and-autoloading)
9. [Serialization](#serialization)
10. [Design Patterns](#design-patterns)
11. [Best Practices](#best-practices)
12. [API Reference](#api-reference)
13. [Troubleshooting](#troubleshooting)

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

- Bash 4.3 or higher (for name references). Tested on 5.2 and 5.3. Static
  methods of a class WITH static properties capture their output with a
  fork-free function substitution on Bash 5.3+ and with a scratch file on 5.2;
  everything else (object creation, dispatch, property access, `.delete`,
  computed properties) is pure Bash with no fork on any version.
- Standard Unix utilities: `stat` (autoloader freshness check), `mktemp` (only
  when compiling a `.kkp` unit), `rm` (the 5.2 static-method scratch file).
- Optional: `md5sum`/`sha256sum` (only for some serialization examples)

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

### Pascal-style Declare/Implement API

Kklass also supports a Pascal-flavoured two-phase API where declaration and implementation are split explicitly:

```bash
source "kklass.sh"

declareClass "CounterPascal" ""
privateSection
field "FValue"
publicSection
property "Value" read "FValue" write "FValue"
classVar "TotalCreated"
constructor "Create"
procedure "Increment"
classFunction "GetTotalCreated"
endClass

implementConstructor "CounterPascal" 'FValue="${1:-0}"; TotalCreated=$((TotalCreated + 1))'
implement "CounterPascal.Increment" 'FValue=$((FValue + ${1:-1}))'
implement "CounterPascal.GetTotalCreated" 'RESULT="$TotalCreated"'
endImplementation "CounterPascal"
```

This API keeps the existing runtime model, but makes class structure explicit. `defineClass` still works and is now implemented on top of the same declarative core.

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

#### Internal Dispatch Note

Method dispatch is frame-aware internally. Nested `$this.method`, `call`, and `parent` calls track the active class on a per-call frame stack, while property variables such as `$balance`, `$name`, or `$value` stay bound to the live instance state.

That means the existing method syntax does not change: reading or assigning `balance` inside a method still works directly on the real property, including nested calls and inherited dispatch.

### Deleting Instances

Always clean up instances when done:

```bash
person1.delete
person2.delete
account.delete
calc.delete
```

This removes all functions and data associated with the instance. Precisely,
`obj.delete`:

1. runs the destructor first, if the class declares one (Pascal DSL
   `destructor`, inherited by subclasses);
2. unsets the data array `obj_data`, the class variable `obj_class` and every
   lazy-property cache `obj_lazy_<name>`;
3. unsets every per-instance function: one per property, one per method
   (including methods added later with `defineMethod`), plus `obj.property`,
   `obj.call`, `obj.parent` and `obj.delete` itself.

The list of functions comes from the class tables, so `.delete` costs the same
whether the shell holds ten objects or ten thousand — no fork, no scan of the
shell's function table. After `.delete` the name is free: `obj.anything` is
"command not found", and a second `obj.delete` fails the same way (guard it with
`declare -F obj.delete` if double-free must be a no-op, as `TObjectList` does).

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

**Return channels and exit status of a static method.** The body's stdout is
the method's stdout, and the body's exit status (`return N`, or the status of
its last command) is the method's exit status — a static method that fails
propagates its failure. A `func`-style static method may also set `RESULT`
via `kk._return`; that value is appended to the output.

Two dispatcher shapes exist and you never choose them by hand:

- A class with **no** static properties gets a thin pass-through wrapper: the
  body's stdout flows straight to the caller, nothing is captured.
- A class **with** static properties gets a capturing wrapper: the body's
  stdout is captured into `REPLY` and then printed. `REPLY` matters because a
  *stateful* static method cannot be called as `$(Class.method)` — the
  substitution runs it in a subshell and the state mutation is lost. Call it
  directly and read `REPLY` (or `RESULT` for a `func`):

```bash
Database.incrementConnections           # state mutated in THIS shell
Database.getConnectionCount >/dev/null  # direct call: output also lands in REPLY
echo "Connections: $REPLY"              # Output: Connections: 3
```

The Singleton pattern below is the canonical use of that channel.

### Class Variables with `classVar`

In the Pascal-style API, class-level state can be declared with `classVar`:

```bash
declareClass "SessionTracker" ""
classVar "ActiveSessions"
classProcedure "OpenSession"
classFunction "GetCount"
endClass

implement "SessionTracker.OpenSession" 'ActiveSessions=$((ActiveSessions + 1))'
implement "SessionTracker.GetCount" 'RESULT="$ActiveSessions"'
endImplementation "SessionTracker"

SessionTracker.ActiveSessions = "0"
SessionTracker.OpenSession
echo "Sessions: $(SessionTracker.GetCount)"
```

`classVar` maps to the same shared class storage used by `static_property` in the legacy API.

### Access Control and Method Modifiers

The declarative API adds Pascal-style access-control sections and method
modifiers that the runtime is aware of.

#### Visibility: private / protected / public

`privateSection`, `protectedSection`, and `publicSection` set the visibility of
every member declared after them (the default is public). Accessing a `private`
or `protected` member from **outside** its class prints a warning to stderr — it
is a diagnostic, not a hard block (the value is still returned), so existing code
keeps working while misuse is surfaced. Accessing the same member from within a
method of the owning class produces no warning (dispatch is frame-aware and knows
the active class).

```bash
declareClass "BankAccount" ""
privateSection
    field "balance"
publicSection
    constructor "Create"
    procedure "deposit"
    func "getBalance"
endClass

implementConstructor "BankAccount" 'balance="${1:-0}"'
implement "BankAccount.deposit" 'balance=$((balance + $1))'
implement "BankAccount.getBalance" 'RESULT="$balance"'
endImplementation "BankAccount"

BankAccount.new account 100
account.deposit 50
echo "$(account.getBalance)"   # 150 — public method, no warning
account.balance                # prints 150 AND warns on stderr:
                               # [kk] warning: private property 'BankAccount.balance' accessed from 'external'
```

- `private`: intended for use only from methods of the same class.
- `protected`: also available to descendant classes.
- `public` (default): available from anywhere.

See `examples/46_visibility_modifiers.sh` for a complete runnable example.

#### Method modifiers: virtual / override / abstract

`virtual`, `override`, and `abstract` are written on their own line immediately
before the method they modify:

- `abstract` — declares a method with no body. A class that still has an
  unimplemented abstract method is **abstract** and cannot be instantiated
  (`ClassName.new` fails). Implement it in a descendant to make the class concrete.
  `kk.isAbstract ClassName` asks without trying `.new` (rc 0 abstract, 1
  concrete, 2 not a built class — see the [API reference](#kkisabstract)).
- `virtual` — marks a method as overridable.
- `override` — overrides a `virtual`/`abstract` parent method. Overriding a
  non-virtual parent method is rejected at `endClass`.

```bash
declareClass "Shape" ""
publicSection
    virtual
    func "area"
    abstract
    procedure "draw"
endClass
implement "Shape.area" 'RESULT="0"'
endImplementation "Shape"

Shape.new s        # Error: Abstract class 'Shape' cannot be instantiated

declareClass "Circle" "Shape"
publicSection
    property "radius"
    override
    func "area"
    override
    procedure "draw"
endClass
implement "Circle.area" 'RESULT=$(( radius * radius * 3 ))'
implement "Circle.draw" 'echo "drawing circle r=$radius"'
endImplementation "Circle"

Circle.new c       # OK — the abstract method is now implemented
c.radius = "5"
echo "$(c.area)"   # 75
c.draw             # drawing circle r=5
```

### Computed Properties

Computed properties calculate their value on-the-fly. A property becomes computed
when it is followed by getter/setter method names — a name starting with `get`/`_get`
is used as the read accessor and one starting with `set`/`_set` as the write accessor:

```bash
defineClass "Rectangle" "" \
    "property" "width" \
    "property" "height" \
    "property" "area" "getArea" \
    "method" "getArea" 'echo $((width * height))'

Rectangle.new rect
rect.width = "10"
rect.height = "5"

echo "Area: $(rect.area)"  # Output: Area: 50

rect.height = "8"
echo "Area: $(rect.area)"  # Output: Area: 80 (automatically recalculated)

rect.delete
```

**How a computed property returns its value.** It follows the same contract as
a `function`/`func` method (`kk._return`), which every kcl unit relies on:

| Call form | Prints | Sets `RESULT` |
|---|---|---|
| `$(rect.area)` (subshell capture) | the value, exactly once | — (subshell) |
| `rect.area` (direct call) | nothing | yes |

So inside a method body you read a computed property of the same object with
`$this.area; echo "$RESULT"`, with no stdout pollution; from the shell you
either capture it with `$(...)` or call it directly and use `$RESULT`. This is
deliberately *different* from a plain stored property, whose direct call prints
the value (`rect.width` prints `10`).

**Getter kinds and cost.** If the getter is declared as a `function`/`func`
(returns through `RESULT`), the read runs in the current shell: no subshell,
no fork, and side effects inside the getter (counters, caches) persist. If the
getter is an echo-style `method`/`proc`, its stdout has to be captured, which
costs a subshell per read. Prefer `RESULT`-returning getters for anything read
in a loop.

### Computed Properties with Getters and Setters

```bash
defineClass "User" "" \
    "property" "first_name" \
    "property" "last_name" \
    "property" "full_name" "get_full_name" "set_full_name" \
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

### Adding Methods After Definition: defineMethod

`defineMethod`, `defineProcedure` and `defineFunction` add — or replace — a
method on an already built class. New instances get the method; the class's
dispatch tables and instance template are updated in place:

```bash
defineClass "Greeter" "" \
    "property" "name" \
    "method" "greet" 'echo "Hello, $name"'

defineFunction "Greeter" "shout" 'RESULT="${name^^}!"'   # new method

defineClass "PoliteGreeter" "Greeter" "property" "title"
defineMethod "PoliteGreeter" "greet" 'echo "Good day, $title $name"'   # overrides the INHERITED greet

PoliteGreeter.new pg
pg.title = "Dr."; pg.name = "Who"
pg.greet         # Output: Good day, Dr. Who   (the override wins, also via $this.greet and pg.call greet)
pg.shout; echo "$RESULT"   # Output: WHO!
pg.delete
```

Two limitations:

- **Instances created *before* the `defineMethod` call see it through `.call`
  only.** An instance's wrapper functions are made at `.new`, each naming the
  class that defined the method at that moment, and `$this.Method` inside a
  body *is* that wrapper (see [Dispatch Semantics](#dispatch-semantics-virtual-calls-vs-inherited)).
  So for a pre-existing instance `obj`: a method **added** later has no
  `obj.m` wrapper (`command not found`, rc 127 — also from `$this.m` in any
  body); an **inherited** method overridden later still runs the parent's body
  through `obj.m` and `$this.m`; `obj.call m` resolves at call time and sees
  both. Replacing a method the class *itself* defines is seen everywhere (the
  wrapper reads the body by name). Create instances after the class is
  complete.
- A **subclass that was built before** `defineMethod` ran on its parent keeps
  its own copy of the method table and does not see the addition or override
  (reported as a `[kk] warning`). Define methods top-down: finish a class
  before deriving from it.

### Reserved Member Names

A method body runs with a few names already bound, so they cannot be used as
property, field, method or class names — the declaration fails with a clear
error:

| Name | Meaning inside a body |
|---|---|
| `this`, `__inst__` | the instance name (`$this.method`, `$__inst__.call`) |
| `__class__` | the class whose body is running (frame class) |
| `RESULT`, `REPLY` | the return channels |
| `IFS` | word splitting — shadowing it would break every `read` in the runtime |
| `__kk_*` | prefix of the runtime's own locals |

Instance members — methods, properties, fields, lazy properties and their init
methods, accessors — additionally cannot be named after the built-in instance
functions, because every instance already carries them (since round 2 / R2_P8):

| Name | Built-in it would collide with |
|---|---|
| `call` | `obj.call NAME ...` — dynamic dispatch |
| `delete` | `obj.delete` — destroys the instance |
| `property` | `obj.property NAME [= VALUE]` |
| `parent` | `obj.parent NAME ...` / `$this.parent` (what `inherited` becomes) |
| `new` | `Class.new` — the constructor verb |

A member with one of these names used to be accepted and then either replaced
the built-in or was silently replaced by it (`$this.delete` ran the user
method while `obj.delete` destroyed the instance). Names that merely *start*
with one of them (`recall`, `delete2`, `parentId`, `callback`, `newest`) are
fine. Static members (`classVar`, `static_method`, `classProcedure`, ...) are
class-level and are not affected by this table — they have their own (below).

#### Reserved static member names

A static member is the class-level function `CLASS.NAME` (a static property
is its accessor, a static method its dispatcher). kklass generates a few
class-level functions of its own for every class, so a static member cannot
take their names (since round 3 / P11; before, such a member was silently lost
with rc 0, or hijacked `.new`):

| Name | Generated function it would collide with |
|---|---|
| `new` | `CLASS.new` — the constructor verb |
| `constructor` | `CLASS.constructor` — parent-constructor chaining |
| `__decl_new_impl` | the real constructor behind the abstract-class guard |
| `__static_*` | `CLASS.__static_NAME` — the body of every static method |
| `__decl_*` | the declarative layer's own names |
| `method_body_*` | the *storage* of static method bodies: a static property SP lives in the variable `CLASS_static_SP` and the body of a static method M in `CLASS_static_method_body_M`, so a static property `method_body_M` would overwrite M's body |

Four more rules:

- **A static property and a static method cannot share a name** — both would
  be `CLASS.NAME` (the method dispatcher used to replace the property accessor
  silently). This includes an inherited static of the other kind; a static
  method may still override an inherited static *method*. A static member may
  share its name with an instance *method* (`CLASS.x` vs `obj.x`), and a static
  *method* also with an instance property — but a static *property* never with
  an instance property or field (next rule).
- **An instance property and a static property cannot share a name** (since
  round 4 / P12). Inside a member body both are the plain variable `x` — the
  instance property a nameref onto the instance's storage, the static one a
  nameref onto the class's — and the static one is bound last, so it *hid* the
  instance property: `x=v` in a body wrote the static and the instance's `x`
  never changed. Refused for every instance property kind (`property`,
  `field`, Pascal `var`, `.kkp` field, lazy, computed / read-write) against
  every static property kind (`static_property`, `classVar`, Pascal
  `static var`, `.kkp` `class var`), own or inherited, in either declaration
  order; the error names both (`'x' is both an instance property and a static
  property`) and the class is poisoned (below). Pairs that involve a method do
  not collide and are still accepted: a method `x` next to a static property
  `x` (`$this.x` runs the method, a bare `x` in a body is the static), and a
  property `x` next to a static method `x` (`x` in a body is the instance's,
  `CLASS.x` the static method).
- **`kk.register_static_methods`** also refuses `__impl_*` (it keeps each
  registered body in `PREFIX.__impl_NAME`), and checks every name *before*
  generating anything.
- **Pascal DSL:** a `static` member named like the class's constructor
  (`constructor` without a name means `Create`) is refused — `CLASS.Create()`
  is the constructor body that `build` extracts, and the static used to
  consume it, leaving the constructor empty. Use `constructor Init` (or rename
  the static).
- **Declarative API: an instance and a class method cannot share a name.**
  `procedure x` and `classProcedure x` (or Pascal `proc x` + `static proc x`)
  in one class are refused: the declaration tables keep one entry per method
  name, so one of the two used to be lost silently. (`defineClass` keeps
  `method x` and `static_method x` apart and still accepts both.)

Every static entry path applies these rules: `defineClass` `static_property` /
`static_method`, `kk._build_class_runtime`, `classVar`, `classProcedure`,
`classFunction`, the Pascal `static var/proc/func`, `kk.register_static_methods`
and `.kkp` `class var` / `class procedure` / `class function`.

#### A refused member fails its class

A refused member name (any rule above, a non-identifier, an unsupported
modifier, an `override` of a non-virtual method, ...) does not just print an
error: it **poisons the class being declared** (since round 3 / P11). The
declaration verb returns 1 and records the member in `${CLASS}_decl_refused`;
then

- `endClass` (and the Pascal `end`) returns 1 naming the class and the member,
  and **closes** the class — a stray `field`/`procedure` afterwards is refused
  with "No active class declaration" instead of attaching to it;
- `endImplementation` and the Pascal `build` refuse the class *first* (before
  any other check), naming the member — the class is not built;
- `defineClass` returns 1 and leaves no open class behind;
- a refused **re**definition of a class that is already built leaves the old
  class completely intact: its runtime, its declaration tables and its
  abstract flag (an abstract class stays abstract);
- `kklass_compiler.sh` fails (rc 1, nothing written) when any class of the
  input was refused — a `.kkp` unit's status would otherwise be that of its
  last `endImplementation` only.

The next `declareClass` of the same name clears the mark, so a corrected
declaration builds normally; other classes in the same script are unaffected.
Before P11 the class was silently built *without* the refused member, rc 0.
Under `set -e` the refused verb itself already ends the script, as before.

`state` is *not* reserved: it is the name of the data-array reference
(`${state[key]}` reads any property by name, as `TCustomApplication` does), and
a property called `state` simply shadows it inside that class. Internal locals
of the dispatcher are all `__kk_`-prefixed, so ordinary names such as
`method_body` or `frame_id` are safe.

### Taken Class and Instance Names

A class `X` and an instance `X` both create functions `X.*`, so some names are
taken (uses phase U2b, USES_PLAN.md U22 / U35 / U40):

| Taken name | Why | As a class | As an instance (`T.new X`) |
|---|---|---|---|
| a DSL verb (`class`, `end`, `var`, `build`, `uses`, `declareClass`, `defineClass`, …) | it would shadow the DSL | refused | refused |
| a built class | `X.new`, `X.<static>` | the site rules (*Duplicate identifier* from another place) | refused |
| a **declared namespace** | someone's functions `X.*` | refused (unless declared by its owner) | refused |

Declared namespaces are kkore's `kk kl ke kv kc`, kklass's `kkp`, the name of
every unit (`kk.unit tlist` declares `tlist`) and every `kk.namespace X [Y …]`
a file calls (`kk.namespace ths` in a unit that defines `ths.*` helpers). The
check is one table lookup — nothing lists bash's function table. A unit may
declare a class with its own name (`class dateutils` in `dateutils.sh`), and
`kk.unit` / `kk.namespace` refuse a name that already is a class or a live
instance.

```bash
defineClass kv "" property a     # kklass: Duplicate identifier: 'kv' is a function namespace (kv.* of unit kvar (...kkore/kvar.sh)); ...
TList.new kc                     # Invalid instance name: kc (a function namespace: kc.* of unit kcfg (...))
```

**Not protected:** a plain library that has neither a unit header nor a
`kk.namespace` line declares nothing — `source libns.sh; TB.new libns` still
replaces its `libns.*` functions. Give such a library a header or a
`kk.namespace libns` line. (kcl's own helper namespaces — tawk, tpipe, tsed,
tutil, ths, tca — are declared when the kcl units get their headers, phase U4.)

### Silent Calls: kk.call_silent

A `function` method echoes its `RESULT` when it runs in a subshell (that is how
`$(obj.method)` works). When you call a method *from inside another method
that is itself being captured* and only want the `RESULT`, wrap the call:

```bash
kk.call_silent obj methodName arg1 arg2   # runs obj.call methodName; RESULT set, nothing echoed
```

It saves and restores the silent flag, so nesting is safe.

## Pascal DSL: class ... end with Real Function Bodies

### Why a Second Front-End?

The classic `defineClass` API stores method bodies inside quoted strings. That
works, but strings have three practical costs:

1. **No syntax highlighting** — the editor sees one long string, not code.
2. **Quote nesting** — a body that itself uses quotes needs careful escaping.
3. **Structure and code are interleaved** — Pascal programmers expect the
   *interface* first and the *implementation* after it.

`kklass_pascal.sh` is a thin, opt-in front-end that removes all three costs.
You declare the class STRUCTURE first (the Pascal "interface"), then write the
method BODIES as **real bash functions**, then `build` the class:

```bash
source "kklass/kklass_pascal.sh"      # pulls in kklass.sh itself

class TGreeter
    public
        var         Name
        constructor Create
        proc        Greet
        func        Salutation
end

TGreeter.Create()     { Name="${1:-World}"; }
TGreeter.Greet()      { echo "Hello, $Name!"; }
TGreeter.Salutation() { RESULT="Greetings from $Name"; }
build TGreeter

TGreeter.new g "Alice"
g.Greet                       # Hello, Alice!
echo "$(g.Salutation)"        # Greetings from Alice
g.delete
```

`build` extracts each body with `declare -f`, feeds it to the normal kklass
runtime (the same declarative core that `defineClass` uses), and removes the
scratch functions. Everything you know about instances, properties and dispatch
still applies — the DSL changes how classes are *written*, not how they *run*.

### Grammar Reference

```text
class N [: P] ... end            class, optional inheritance (: Parent)
public | private | protected     visibility sections (repeatable, any order)
var X                            stored field                ->  obj.X
property X read G write S        computed property (G/S are declared members)
proc X                           method with no return value
func X                           method returning via RESULT
constructor [C]                  constructor (default name Create)
destructor  [D]                  destructor (default Destroy); runs on obj.delete
static <var|proc|func> X         class-level (shared) member, not per-instance
abstract <proc|func> X           no body; class not instantiable until overridden
override <proc|func> X           guard: build errors unless an ancestor has X
build N                          extract bodies + finalize the class
```

Notes:

- **`proc` vs `func`**: a `func` returns through `RESULT` (and is echoed when
  called in a `$(...)` subshell); a `proc` returns nothing (or just an exit
  status). Mapping from the old API: `method` → `proc`, `function` → `func`.
- **`property X read G write S`**: `read`/`write` targets are declared members
  (or the property name itself for a stored read — see below). A property with
  only `read` is read-only: writes print an error and fail.
- **Stored read + computed write** (the TList pattern):
  `property capacity read capacity write _setCapacity` — reading returns the
  stored value directly; writing goes through the `_setCapacity` method.
- **`static var`**: exactly one shared slot per class. IMPORTANT: a class with
  NO static vars gets thin, capture-free static dispatchers (fast on every
  bash); a class WITH static vars needs stdout-capturing dispatchers so that
  `$(Class.method)` still persists mutations (funsub on bash 5.3+, a scratch
  file on 5.2). Do not declare constants as `static var` — keep them as plain
  file-scope globals (see kcl/tpath/tpath.sh for the worked example).
- **`static` names**: a static member cannot be named like the class's
  constructor (`Create` unless `constructor OtherName`), nor `new`,
  `constructor`, `__decl_new_impl`, `__static_*`, `__decl_*`, `method_body_*`; a `static var`
  and a `static proc/func` cannot share a name (see *Reserved static member
  names*).
- **A refused member fails the class**: `end` returns 1 and closes the class,
  `build` refuses it; the next `class` in the file is unaffected (see *A
  refused member fails its class*).
- **`override`** is a build-time typo-guard only — all kklass dispatch is
  already dynamic. `virtual` does not exist: every method is virtual.
- Bodies are extracted with `declare -f`, which normalizes formatting and
  **strips comments** — write comments freely; they just don't survive into
  the stored body (the source file keeps them, and that is what people read).

### inherited — Pascal-Style Parent Calls

Inside a body, `inherited` calls the parent's implementation — in methods,
constructors and destructors, just like Pascal:

```bash
class TAnimal
    public
        var         Name
        constructor Create
        proc        Speak
        func        Describe
end
TAnimal.Create()   { Name="$1"; }
TAnimal.Speak()    { echo "$Name makes a sound"; }
TAnimal.Describe() { RESULT="$Name"; }
build TAnimal

class TDog : TAnimal
    public
        var           Breed
        constructor   Create
        override proc Speak
        override func Describe
end
TDog.Create()   { inherited; Breed="${2:-mutt}"; }   # parent ctor, args forwarded
TDog.Speak()    { echo "$Name barks"; inherited Speak; }
TDog.Describe() { inherited; RESULT="$RESULT, a $Breed"; }  # func chain
build TDog
```

- **Bare `inherited`** calls the parent's version of the *current* member.
  In a constructor it becomes `parent.constructor "$@"` (all arguments
  forwarded); in a method/destructor it becomes `inherited <Name>`.
- **`inherited Name args...`** calls a specific parent method with arguments.
- **Constructors are inherited** (Pascal semantics): a class that declares no
  constructor uses its parent's.
- **Destructors run on `obj.delete`** and are inherited; an overriding
  destructor chains to the parent with `inherited`.

### Dispatch Semantics: Virtual Calls vs inherited

kklass follows the Delphi `virtual; override;` model — with two complementary
resolution rules:

- **`$this.Method` is VIRTUAL, as of `.new`**: inside a body `this` holds the
  instance name, so `$this.Method args` is simply a call of the instance's own
  wrapper function `obj.Method`. `.new` builds those wrappers from the
  instance's *actual* class, each naming the class that defines the method
  there, so subclass overrides win — even when the call happens inside an
  inherited body (the template-method pattern). `${this}.Method` is the same
  call.
- **`$this.call Method` is VIRTUAL, at call time**: it looks the method up
  through the class's method cache on every call. The two forms agree for
  every class that is complete before its instances are made; they differ only
  after a `defineMethod` on an existing class (see [defineMethod](#adding-methods-after-definition-definemethod)):
  a pre-existing instance sees a later-added or later-overridden method through
  `.call` only.
- **`inherited` / `$this.parent` is STATIC**: it resolves upward from the class
  where the *currently executing body* is defined — not from the instance's
  class. This is what makes `inherited` chains terminate correctly even when a
  subclass does not override the intermediate method.

```bash
# TBase.Run calls $this.Step        ->  child's Step wins (virtual)
# TMid.Describe calls inherited     ->  TBase.Describe, one level up (static)
# leaf.Describe (no leaf override)  ->  runs TMid's body; its inherited still
#                                       goes to TBase — the body never re-runs.
```

Both call forms run the body in a frame of its defining class (so
`__class__`, visibility checks and `inherited` behave identically), set
`RESULT` the same way, and neither makes the callee silent: under `$( )` a
`function` callee prints its value — use `kk.call_silent "$__inst__" NAME`
for an internal call whose `RESULT` is all you want.

**The body text is never rewritten.** Up to round 2 / R2_P8 kklass replaced
the *text* `$this.NAME` / `${this}.NAME` of every member and constructor body
with `$__inst__.call NAME`, for every method NAME of the class — inside quoted
strings too (`local s="$this.Home"` became `obj.call Home`) and as a prefix
(with a method `count`, `$this.counter` became `.call counter`). That rewrite
is gone: `"$this.Home"` is now the plain string `obj.Home`, the same as
`"$__inst__.Home"`, and a handler registered that way calls the method. An
empty method body is a valid no-op through every call form (silent, rc 0).

Compiled caches: until round 4 / P12 a `.ckk` file was rebuilt only when its
`.kk`/`.kkp` source was newer (see [Autoloading](#autoloading-with-kklass_autoloadsh);
now also when `kklass.sh` or the compiler is newer), so a cache compiled before
R2_P8 could still hold `$__inst__.call NAME` bodies. They keep
working — `.call` dispatch is unchanged — but keep the old quoted-text and
prefix behaviour until the cache is rebuilt (`kkload FILE --force-compile`,
or touch the source).

### Porting from defineClass

The translation is mechanical (all seven kcl classes were ported this way):

| old string API                          | Pascal DSL                              |
|-----------------------------------------|-----------------------------------------|
| `defineClass N ""`                      | `class N ... end` + `build N`           |
| `defineClass N P`                       | `class N : P ... end` + `build N`       |
| `"property" "x"`                        | `var x`                                 |
| `"property" "x" "_setX"`                | `property x read x write _setX`         |
| `"method" "M" '...'`                    | `proc M` + `N.M() { ... }`              |
| `"function" "F" '...'`                  | `func F` + `N.F() { ... }`              |
| `"constructor" '...'`                   | `constructor Create` + `N.Create()`     |
| `"static_method" "S" '...'`             | `static proc S` (or `static func S`)    |
| `$this.parent M ...` in a body          | `inherited M ...`                       |
| `parent.constructor "$@"` in a ctor     | `inherited`                             |

A pure static-utility namespace (every member `static`, no state) ports to
`class name ... static proc ... end` + `build name` and keeps the exact
same `name.method` public API — see kcl/tstringhelper, tpath, tfile,
tdirectory for real examples; kcl/tlist and tstringlist show instantiable
classes with properties, overrides and `inherited`.

### Worked Examples and Tests

- `examples/47_pascal_dsl.sh` — every DSL feature in eight short sections.
- `examples/48_deep_inheritance_scopes.sh` — a four-level hierarchy with
  constructor/func chains, independent instances across scopes, cross-instance
  calls and shared static state.
- `tests/116..118_PascalDsl*.sh` — the regression suite for the DSL;
  `tests/114..115` pin the static-dispatch fast path and build status fixes.

---

## Compilation and Autoloading

### Why Compile?

"Compiling" a `.kk`/`.kkp` file means: build the classes once with the normal
runtime, then **dump** everything the build produced — every `<Class>_*`
table (method bodies, owner maps, pre-filled caches, the instance template,
static state, declarative metadata) with `declare -p` and every `<Class>.*`
function (`.new`, `.constructor`, static accessors and methods) with
`declare -f` — into one bash file. Loading that file is a plain `source`.

- **Loads faster**: the class-definition code (parsing, inheritance
  resolution, template generation, DSL processing) does not run again.
- **Identical behaviour**: there is no second code generator. Compiled classes
  use exactly the same `kk._*` runtime as classes defined at run time, so a
  runtime-vs-compiled parity test (`tests/123_CompiledParity.sh`) holds by
  construction. Method calls are not faster in compiled mode — dispatch is the
  same.
- **Distributes easily**: single file (it still `source`s `kklass.sh`).

What is dumped is exactly the classes the runtime **built** while the input
was sourced: every `X` with a function `X.new` *and* a table
`${X}_class_methods` — abstract classes, empty raw builds, and the parent
classes the input loaded itself (a compiled child needs them: its inherited
methods resolve through them, so the file loads on its own). A function that
is merely *named* `X.new` (a user factory, kkore's `kv.new`) is not a class
and is not dumped (since round 4 / P12; before, every compile dumped a class
"kv" — all ten `kv.*` functions — which then redefined kkore's when the
compiled file was sourced), and neither is a class that was declared but
never built. The compile prints nothing on stderr when the input is clean.

Compile files that only *define* classes; instances created inside the input
would be dumped too, as bare data arrays without their functions.

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

1. **First Load**: Compiles `.kk` file to `.ckk/filename.ckk.sh`. The cache
   directory is `$(pwd)/.ckk` by default; set `KKLASS_CKK_DIR=/some/dir` to
   put it elsewhere (for example a private directory per test run, so two
   runs never race on the same compiled file).
2. **Subsequent Loads**: Uses cached compiled version
3. **Smart Recompilation**: Recompiles if the source is newer than the cache,
   and (since round 4 / P12) also when `kklass_compiler.sh` or `kklass.sh` is
   newer than the cache — a cache is a dump of what the runtime built, so one
   made by an older compiler or runtime is stale too (two `-nt` stats, no
   fork; ≈0.4 ms on msys next to ≈0.26 s for a cached `kkload`)
4. **Force Compilation**: `kkload "file.kk" --force-compile`
5. **Runtime Mode**: `kkload "file.kk" --no-compile` (skip compilation)
6. **Loud failures**: a source file that fails to `source` (syntax error, a
   refused class redefinition, an unknown command) aborts the compile with the
   original error on stderr; the autoloader then falls back to runtime mode.

### Pascal-style `.kkp` Units

`kkload`, `kkrecompile`, and `kklass_compiler.sh` can also consume Pascal-style `.kkp` unit files. The parser is intentionally class-only and supports multi-line class headers, multi-line method declarations, multi-line implementation signatures, `class var`, `class procedure`, and `class function`.

```pascal
unit CounterPascal;

interface

type
    CounterUnit = class
    private
        FValue: Integer;
    public
        class var TotalCreated: Integer;
        constructor Create(
            InitialValue: Integer
        );
        procedure Increment(
            Step: Integer
        );
        function GetValue(
        ): Integer;
    end;

implementation

constructor CounterUnit.Create(
    InitialValue: Integer
);
begin
FValue="${1:-0}"
TotalCreated=$((TotalCreated + 1))
end;

procedure CounterUnit.Increment(
    Step: Integer
);
begin
FValue=$((FValue + ${1:-1}))
end;

function CounterUnit.GetValue(
): Integer;
begin
RESULT="$FValue"
end;

end.
```

Load it exactly like a `.kk` file:

```bash
source "kklass_autoload.sh"
kkload "CounterPascal.kkp"
```

`--no-compile` works for `.kkp` as well and routes through the same translated runtime path instead of the compiled cache.

**Units (`unit X;`, `uses A, B;`).** `unit X;` must be the first statement and `X` the file's stem (`unit CounterPascal;` lives in `CounterPascal.kkp`); otherwise the translation fails. It becomes the two unit header lines of a unit outside the kbool tree (`kk.unit X`, the user form of USES_PLAN.md §7.4), so the translated file is a unit: loaded once, registered with kbool, which it loads from `KBOOL_HOME` when kbool is not loaded yet (`kkload` and `kklass_compiler.sh` set `KBOOL_HOME` to their own kbool when it is unset; a translation sourced by hand needs kbool loaded or `KBOOL_HOME` set). `uses A, B;` (outside a class, may span lines) becomes `kk.uses A B`. Put comments on their own lines: text after a `unit` / `uses` statement's `;` is an error naming FILE:LINE. A translated unit only loads from a file named `X.sh`: the runtime translation is `<cache>/X.sh`. A compiled cache names such a unit by its unit name (`# Source unit: X`) and registers its classes like a build does.

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

### Serialization Helper Names

Generated serialization methods reserve the `__kk_` prefix for internal helper locals. Avoid using property names or temporary locals with that prefix in your own code. The JSON helpers (`kk._jsonEscape`, `kk._jsonObject`, `kk._jsonParse`, `kk._jsonString`, `kk._jsonInit`) and their tables (`__KK_JSON_*`) live in the same reserved space.

Regular names such as `key`, `value`, `input`, or other domain terms remain safe to use in your classes and methods.

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
- `":"`: Field separator (empty = `:`)
- `"string"`: Serialization format, `string` or `json` (empty = `string`)

`defineSerializableClass` is exactly `defineClass` followed by
`addSerializable` — one generator per format, so `FORMAT=json` gives the class
`toJSON`/`fromJSON` (before round 3 / P10 it silently built a class with empty
`toString`/`fromString` bodies and no JSON methods). The four leading
arguments are mandatory; the format and the separator are checked **before**
`defineClass` runs, so a refused call builds nothing (rc 1 and one `Error:`
line on stderr).

**Which properties are serialized (format change, round 3 / P10).** The
fields are the class's full property list, `${CLASS}_class_properties`:
**inherited properties first, then the class's own, lazy and computed ones
included**, in definition order — the same list `addSerializable` and
`toJSON` use. Earlier versions of `defineSerializableClass` wrote only the
class's own `property` arguments (a child of a class with property `p0`
serialized as `TChild:x` and lost `p0`). A string written by the old version
for a class with a parent or a lazy property has a different field layout and
must be re-saved.

```bash
defineClass TBase "" property p0
defineSerializableClass TChild TBase ":" string property a lazy_property lz initLz \
    method initLz 'lz=LAZY'
TChild.new c; c.p0 = P; c.a = x
c.toString          # TChild:P:x:      (p0, a, lz)
```

**The separator rule** (`defineSerializableClass` and `addSerializable`, both
formats): exactly **one** character that is not a letter, digit or `_`, not
whitespace (space, TAB, LF, CR, VT, FF) and none of `"` `$` `\` `'` `` ` ``
`*` `?` `[` `]`. Anything else is refused (rc 1, nothing generated). Letters,
digits and `_` would split class names and values; the quote, expansion and
pattern characters used to be spliced into the generated code unquoted (a
separator `$(touch x)` executed); space/TAB/VT/FF are IFS whitespace for
`read` (empty fields collapse, values are trimmed) and a CR does not survive
the method-body rebuild. Typical choices: `:` `|` `;` `,` `#` `%` `~` `@`.

**The string format does not escape.** A value must not contain the separator
(except in the last field, which receives the rest of the line) or a newline
(everything after it is lost). Use the JSON format for arbitrary values;
`saveObjects` writes JSON whenever a class has both formats.

`fromString` (like `fromJSON`) returns through `RESULT`: a direct call prints
nothing and sets `RESULT` to the instance name; inside `$( )` it prints the
name once. It refuses an input of another class (see the class-prefix check
under JSON Format Rules).

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

### JSON Format Rules

`toJSON` writes **one flat object on one line**: `"__class__"` first, then
every property of the class in definition order, every value as a JSON
**string**. The output is valid JSON (RFC 8259) whatever the values hold:

| In the value | Written as |
|---|---|
| `\` and `"` | `\\` and `\"` |
| LF, CR, TAB, backspace, form feed | `\n` `\r` `\t` `\b` `\f` |
| any other U+0001–U+001F | `\u00XX` (lower-case hex), e.g. `\u001b` |
| DEL, C1 controls, multi-byte UTF-8 | raw (valid JSON) |
| NUL | cannot occur — a bash string cannot hold a NUL byte |

A value with none of `"`, `\` or a control character is copied verbatim (a
single glob test decides; the cost is one test per call, not per property).

```bash
book1.title = $'Say "hi"\n\tC:\\new'
book1.toJSON
# {"__class__":"Book","isbn":"...","title":"Say \"hi\"\n\tC:\\new",...}
```

`fromJSON` is a left-to-right scanner for **one flat JSON object**:

* whitespace (space, TAB, LF, CR) between tokens is ignored, so
  pretty-printed input such as `{ "title" : "x" }` loads;
* string values decode the eight escapes `\" \\ \/ \b \f \n \r \t` and
  `\uXXXX` (either hex case; a surrogate pair is combined into one 4-byte
  UTF-8 character). The UTF-8 bytes are produced arithmetically, so decoding
  does not depend on the locale;
* a bare token (`42`, `-1.5e3`, `true`, `null`) is stored **verbatim as text**
  (`null` becomes the four characters `null`);
* keys that are not properties of the class are ignored, a missing property
  keeps its current value, and for a duplicate key the last one wins.

It returns **rc 1 and leaves the instance completely untouched** (nothing is
assigned until the whole input has been parsed) for: malformed JSON (unterminated
string, missing `:` or value, trailing comma, text after the closing `}`), a
nested object or array as a value, an unknown escape, `\u0000` (a NUL cannot
live in a bash string), a lone surrogate, and a `"__class__"` mismatch (below).
Nothing is printed on failure and `RESULT` is empty (it used to keep the
caller's old value); with `VERBOSE_KKLASS=debug` exactly one `kk.debug` line
goes to stderr. On success `fromJSON` returns through `RESULT` (round 3 / P10):
a direct call prints **nothing** and sets `RESULT` to the instance name;
inside `$( )` the name is printed once. (Before P10 a direct call printed the
instance name on stdout and left `RESULT` empty.)

**`__class__` check (behaviour change, round 2 / P7).** Earlier versions
ignored `"__class__"`, so another class's JSON loaded silently. `fromJSON` now
accepts a `"__class__"` only if it names the receiving instance's own class or
the class `addSerializable` was called on (which is what `toJSON` writes, also
for subclasses that inherit the serializer). Anything else is rc 1. Input
without `"__class__"` is still accepted.

```bash
Book.new b3
b3.fromJSON '{"__class__":"Magazine","title":"x"}' || echo "refused"   # refused, b3 unchanged
```

**Class-prefix check in the string format (round 3 / P10, review remark R2).**
The string-format counterpart of the `__class__` rule: `fromString` accepts an
input only if it starts with the class name `addSerializable` was called on
followed by the separator — exactly what `toString` writes, so a subclass that
inherits the serializer reads its own output. Anything else (another class's
line, `CX:...` for class `C`, a bare `C`, a leading blank, no argument at all —
also under `set -u`) is rc 1 with `RESULT=''`, nothing printed (one `kk.debug`
line under `VERBOSE_KKLASS=debug`) and the instance untouched. Earlier versions
split any input, so `Other:p:q` loaded into a `C` instance as `a=Other`.

```bash
Product.new p2
p2.fromString "Other:x:y" || echo "refused"   # refused, p2 unchanged
```

**One line per object.** Because a newline is always written as `\n`,
`toJSON` output never contains a raw newline, and `saveObjects` / `loadObjects`
can keep their one-object-per-line file format for JSON objects with any
values. `saveObjects` **prefers `toJSON`** when a class has both formats
(round 3 / P10; it used to prefer `toString`, which does not escape, so a
value holding a newline or the separator broke the file).

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

**`saveObjects FILE INSTANCE...`** truncates FILE and writes one line per
instance: `toJSON` when the instance has it, else `toString`; an instance with
neither gets a `Warning:` line on stderr and is skipped.

**`loadObjects FILE CLASS ARRAY_NAME`** — the contract (round 3 / P10):

* every non-blank line becomes a **new** instance `CLASS_loaded_<n>`; a name
  that is already a live instance is skipped, so a second call never re-uses
  (and silently merges into) the instances of the first;
* a line whose first non-blank character is `{` goes to `fromJSON`, any other
  line to `fromString`; blank and whitespace-only lines are skipped;
* a **refused** line — the `from*` method returned rc ≠ 0, including rc 127
  when the class has no such method (e.g. a JSON-only class given a string
  line; no bash "command not found" is printed) — is not loaded: its instance
  is deleted, one warning names the line, and loading continues:

  ```
  Warning: loadObjects: data.txt:2: refused by Contact.fromJSON (rc 1), line not loaded
  ```

  (a `kk.warn` line: printed unless `VERBOSE_KKLASS=quiet`);
* the instance names are **appended** to the caller's array ARRAY_NAME, which
  goes through `kk._outName` (kcl §1.7): a name that is not an identifier or
  is reserved (`RESULT`, `this`, `state`, `__kk_*`, …) is rc 2 and nothing is
  loaded. Any other name works, including `line`, `count` or `file`;
* a **direct call prints nothing**: `RESULT` = the number of objects loaded by
  this call, rc 0 — or rc 1 when at least one line was refused (`RESULT` is
  still the count). Inside `$( )` the count is printed once. The former
  `Loaded N objects from FILE` line is now a `kk.debug` line
  (`VERBOSE_KKLASS=debug`);
* rc 2 (`RESULT=''`) also for a CLASS that is not a built class; rc 1
  (`RESULT=''`, silent) when FILE does not exist.

`loadObjects` creates instances of **one** class: keep one file per class
(a line of another class is refused — by `fromJSON`'s `__class__` check or by
`fromString`'s class-prefix check — warned and skipped).

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
            echo "New connection created" >&2
        else
            echo "Using existing connection" >&2
        fi
        echo "$instance"
    ' \
    "method" "connect" 'echo "Connected to $host:$port"'

# Initialize
DatabaseConnection.exists = "false"

# Get instance (creates new). NOT $(DatabaseConnection.getInstance): that would
# run the method in a subshell and lose the `instance`/`exists` mutation, so
# every call would create a fresh object. Call it directly and read REPLY
# (a class with static properties captures its stdout into REPLY).
DatabaseConnection.getInstance >/dev/null; conn1=$REPLY
$conn1.host = "localhost"
$conn1.port = "5432"
$conn1.connect

# Get instance again (returns existing)
DatabaseConnection.getInstance >/dev/null; conn2=$REPLY
$conn2.connect  # Uses same connection

$conn1.delete
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

### Trap: Inside a Body, a Property Is a Nameref

Inside a member body every property / field / `var` of the instance is a
local nameref onto one element of the instance's storage
(`local -n v="${inst}_data[v]"`). Reading and assigning work as with a plain
variable, but a few expansions see the nameref, not the value (measured on
bash 5.2.37 and 5.3.9, round 2 / K2):

- `${#v}` is **0 on bash 5.2.37** (correct on 5.3.9) — take a length from a
  local copy: `local c="$v"; n=${#c}`;
- on **both** bashes `[[ -v v ]]` is false even when `v` is set, and
  `${#v[@]}` is 0 — test `[[ -n "$v" ]]` instead;
- `unset v` inside a member deletes the instance's storage element (the
  property then reads as empty) — assign `v=""` to clear it;
- these all work: `${v:1:2}`, `${v%x}`, `${v@Q}`, `${v^^}`, `v+=x`,
  `printf -v v …`, `read -r v`.

```bash
defineClass TK2 "" property v method probe '
    local c="$v"
    printf "len=%s copylen=%s\n" "${#v}" "${#c}"
    [[ -v v ]] && echo "-v=true" || echo "-v=false"
    printf "nelem=%s\n" "${#v[@]}"'
TK2.new o; o.v = hello; o.probe
# bash 5.2.37: len=0 copylen=5   -v=false   nelem=0
# bash 5.3.9:  len=5 copylen=5   -v=false   nelem=0
```

### Trap: A Body Called From a Body Sees the Caller's Properties

Those namerefs are bash *locals*, and bash scopes locals **dynamically**: a
function called from a member body sees every name the body has bound,
unless it binds the same name itself. A member body of another class binds
only *its own* class's members — so a **static method** (it binds no instance
properties at all) or a method of **another class** that has no property `y`,
called from an instance method of a class with a property `y`, sees the
caller's `y` and **writes it** with a plain `y=…` (measured on bash 5.2.37 and
5.3.9, round 4 critic C3; not fixed yet — a separate research round):

```bash
defineClass SThin "" static_method bump 'y=fromStatic'
defineClass B     "" method m 'y=fromB'
defineClass A     "" property y method go1 'SThin.bump' method go2 'b.m'
A.new a; B.new b
a.y = orig; a.go1; a.y     # -> fromStatic   (the static method wrote a.y)
a.y = orig; a.go2; a.y     # -> fromB        (B's method wrote a.y)
echo "${y-unset}"          # -> unset        (no global was created)
```

The same holds for plain shell functions called from a body. Until this is
closed: in a static method, or in a method that may be called from another
class's method, declare every scratch variable `local` (`local y=…`), and do
not rely on a bare name being "global" there.

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
- `"property" NAME GETTER [SETTER]`: Define a computed property. Accessor names
  are detected by prefix — `get*`/`_get*` is the read accessor, `set*`/`_set*` the
  write accessor. (There is no `computed_property` keyword.)
- `"method" NAME BODY`: Define a method
- `"constructor" BODY`: Define constructor
- `"static_property" NAME`: Define static property
- `"static_method" NAME BODY`: Define static method
- `"lazy_property" NAME INIT`: Define lazy property (computed once, on first access)

Static names follow *Reserved static member names*; instance names follow
*Reserved Member Names*.

**Returns:** rc 0, silent (a `VERBOSE_KKLASS=debug` note goes to stderr). A
refused token prints its error and returns 1: the class is not built, no class
is left open, and a refused redefinition keeps the already-built class intact
(see *A refused member fails its class*).

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
- `INSTANCE_NAME`: Name for the instance (an ASCII identifier, checked by
  `kk._is_ident` — see *Identifier checks*; the caller's `BASH_REMATCH` is not
  touched)
- `CONSTRUCTOR_ARGS`: Optional arguments passed to constructor

**Returns:** Creates instance functions. An invalid name: rc 1 +
"Invalid instance name: NAME" on stderr, nothing created.

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

Call method from within another method. `this` holds the instance name, so
this is a direct call of the instance's wrapper `obj.method_name` (virtual as
of `.new`, see [Dispatch Semantics](#dispatch-semantics-virtual-calls-vs-inherited));
the text is not rewritten, so `"$this.method_name"` in quotes is just the
string `obj.method_name`.

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

### kk.isAbstract

Ask whether `CLASS.new` would refuse because the class is still abstract.
Use it instead of reading the internal `${CLASS}_class_abstract` flag, whose
states are subtle (it is unset for a never-declared name and for a class
built directly by `kk._build_class_runtime`, and 0 for a declared class that
is not finalized yet).

```bash
kk.isAbstract CLASS
```

| rc | meaning |
|---|---|
| 0 | a built class with an unresolved `abstract` member — `CLASS.new` refuses it |
| 1 | a built, instantiable class |
| 2 | not an identifier, never declared, or declared but not finalized (`endImplementation` / `build` not run — no `CLASS.new` yet) |

Silent on every path (also under `VERBOSE_KKLASS=debug`), fork-free, safe
under `set -eu` when called from an `if`, `||` or `!`. A hostile name such as
`'a[$(cmd)]'` is refused with rc 2 before any expansion. The identifier check
is exact in every locale and shell option (see *Identifier checks* below) and
leaves the caller's `BASH_REMATCH` untouched (since round 3 / P11; it used a
`[[ =~ ]]` before). "Concrete" therefore is rc 1 — not "rc ≠ 0":

```bash
if kk.isAbstract "$cls" || (( $? != 1 )); then
    echo "$cls is abstract or not a built class" >&2
fi
```

### kk.derivesFrom

Ask whether CHILD is ANCESTOR or descends from it (the public form of the
internal `kk._class_derives_from`).

```bash
kk.derivesFrom CHILD ANCESTOR
```

rc 0 — CHILD is ANCESTOR (reflexive) or one of its descendants; rc 1 — not
(including a CHILD that was never declared; there is no existence check);
rc 2 — either argument is not an identifier. Silent, fork-free. Unlike the
internal, a malformed name never aborts the caller (`kk._class_derives_from
'a b' X` is a fatal "invalid variable name" for the caller's whole command).
`BASH_REMATCH` is left alone.

```bash
kk.derivesFrom TCircle TShape && echo "a shape"
```

### Identifier checks

Every name kklass turns into a variable or function name — class, member and
instance names (`defineClass` and the other builders, `CLASS.new`), and the
arguments of `kk.isAbstract` / `kk.derivesFrom` / `loadObjects` — must be an
ASCII identifier `[A-Za-z_][A-Za-z0-9_]*`. Since round 3 / P11 one helper,
`kk._is_ident NAME` (rc 0/1, silent, fork-free), makes that check
everywhere. Since round 4 / P12 it lives in kkore (`kkore/klib.sh`, which
kklass sources first; kkore's `kk._outName` and `kc.alias` follow the same
rule): the range glob plus a `*[![:ascii:]]*` guard, and under
`shopt -s nocasematch` the check runs with nocasematch switched off and the
caller's setting restored. It is exact in every locale × `globasciiranges` ×
`nocasematch` combination and never touches `BASH_REMATCH`. The `[[ =~ ]]` it
replaced overwrote the caller's `BASH_REMATCH` on every `.new`, and under
`shopt -s nocasematch` in a UTF-8 locale accepted the Turkish dotless `ı` /
dotted `İ` — whose later indirect expansion aborted the caller's whole
command (`kk.derivesFrom ı X`, `defineClass ı`) or produced a half-made
instance (`CLASS.new ı`). (Round 3 got exactness from a function-local
`LC_ALL=C`, which cost ≈4.5× under a UTF-8 caller locale — `kk.derivesFrom`
70 → 213 µs; the helper no longer touches the locale.)

The reserved names (the tables in [Reserved Member Names](#reserved-member-names))
are case-sensitive, as bash names are: under `nocasematch` a property
`result`, a method `Delete` or a static method `New` is accepted, `RESULT`,
`delete` and `new` are still refused.

`CLASS.new` itself carries an inline copy of the rule (the hottest path: in
round 3 the function call plus two locale switches cost ~18 µs per `.new` on
bash 5.2): an explicit-letter glob — every allowed character listed, no
ranges, so it is matched by character equality in every locale — and
`kk._is_ident` only when `shopt -s nocasematch` is on (its case folding is the
one way a non-ASCII letter can match an explicit list). Test 135 keeps the two
equivalent.

Constructor and destructor names (`constructor NAME`, the Pascal
`destructor NAME`) and the class name of `implementConstructor` are
identifiers too, checked before anything uses them; a refused one fails the
class like any other refused member.

### defineSerializableClass

Define a class with automatic serialization.

```bash
defineSerializableClass CLASS_NAME PARENT_CLASS SEPARATOR FORMAT DEFINITIONS...
```

**Parameters:**
- `CLASS_NAME`: Name of the class
- `PARENT_CLASS`: Parent class name
- `SEPARATOR`: Field separator (e.g., ":", "|"; empty = ":"), see the separator rule in [Serialization](#serialization)
- `FORMAT`: "string" or "json" (empty = "string")
- `DEFINITIONS`: Property/method definitions

**Returns:** rc 0, or rc 1 + one `Error:` line when fewer than four arguments
are given, the format is unknown, the separator is refused (nothing is built)
or `defineClass` fails. Equivalent to `defineClass` + `addSerializable`; the
serialized fields are `${CLASS}_class_properties` (inherited, then own, lazy
included).

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
- `SEPARATOR`: Field separator (default: ":"); validated for both formats — one character, not a letter/digit/`_`/whitespace, none of `` " $ \ ' ` * ? [ ] `` (rc 1 otherwise, nothing generated)
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

**Returns:** rc 0; a direct call prints nothing and sets `RESULT` to the instance name (inside `$( )` the name is printed once). rc 1, `RESULT=''`, instance untouched when the input does not start with CLASS + SEPARATOR (the class the serializer was added to). Values must not contain the separator (except the last field) or a newline.

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

**Returns:** rc 0 with `RESULT` = the instance name (a direct call prints nothing; inside `$( )` the name is printed once); rc 1 with `RESULT=''` and the instance untouched for malformed input or a `__class__` mismatch (see JSON Format Rules).

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

`toJSON` is used when the instance has it, else `toString` (one line per object).

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

**Returns:** a direct call prints nothing; `RESULT` = number of objects loaded; rc 0, rc 1 if a line was refused (deleted, one warning naming FILE:LINE) or FILE is missing, rc 2 for a bad ARRAY_VAR or an unknown class. Names are appended to ARRAY_VAR. See the loadObjects contract in [Serialization](#serialization).

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
- `INPUT.kk`: Source class definition file (`.kk` or a `.kkp` unit)
- `OUTPUT.sh`: Output compiled file

**Returns:** rc 0 and the summary lines on success. The `Classes:` line lists the
built classes that were dumped (see [Why Compile?](#why-compile)).
 rc 1 and nothing written
when sourcing the input fails, when no class was built, or (since round 3 /
P11) when any class of the input refused a member — the error names each such
class and member.

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

- Check examples in `kklass/examples/` (run them all with `bash examples/demo.sh`)
- Review the test suite in `kklass/tests/` (numbered `NNN_*.sh` files, run via `bash tests/tests.sh`)
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
2. **Read tests**: See `tests/` (numbered `NNN_*.sh` files) for comprehensive usage
3. **Build something**: Create your own classes
4. **Optimize**: Use compilation for production scripts

### Resources

- **Examples**: `kklass/examples/` (48 examples; `demo.sh` runs them all)
- **Tests**: `kklass/tests/` (numbered `NNN_*.sh`; run with `tests/tests.sh`)
- **Core Library**: `kklass/kklass.sh`
- **Declarative API**: `kklass/kklass_decl.sh`
- **Pascal DSL front-end**: `kklass/kklass_pascal.sh`
- **Compiler**: `kklass/kklass_compiler.sh`
- **Autoloader**: `kklass/kklass_autoload.sh`
- **Serialization**: `kklass/kklass_serializable.sh`
- **`.kkp` unit translator**: `kklass/kklass_kkp.sh`

---

**Happy Bash OOP Programming!** 🎉

---

*Document Version: 1.1*  
*Last Updated: 2026-07-09*  
*For Kklass System v1.0+*
