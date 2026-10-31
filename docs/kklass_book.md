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
9. [Units and uses](#units-and-uses)
10. [Serialization](#serialization)
11. [Design Patterns](#design-patterns)
12. [Best Practices](#best-practices)
13. [API Reference](#api-reference)
14. [Troubleshooting](#troubleshooting)
15. [Internals](#internals)

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
- **Encapsulation**: visibility sections (`public`, `private`, `protected`)
- **Performance**: compiled caches load faster
- **Modern Patterns**: Implement design patterns in bash

### System Requirements

- Bash 5.1 or higher (`kbool.sh` refuses an older one). Tested on 5.1, 5.2 and
  5.3 on Linux, FreeBSD, macOS and Windows (CI). Static
  methods of a class WITH static properties capture their output with a
  fork-free function substitution on Bash 5.3+ and with a scratch file on 5.1/5.2;
  everything else (object creation, dispatch, property access, `.delete`,
  computed properties) is pure Bash with no fork on any version.
- Standard Unix utilities: `stat` (autoloader freshness check), `mktemp` (only
  when compiling a `.kkp` unit), `rm` (the 5.1/5.2 static-method scratch file).
- Optional: `md5sum`/`sha256sum` (only for some serialization examples)

---

## Getting Started

### Installation

kklass is one folder of the kbool tree (`kbool.sh`, `kkore/`, `kklass/`,
`kcl/`, `ktests/` — see the [kbool README](https://github.com/Keksov/kbool/blob/main/README.md)); it is not
installed on its own. Its modules are **units** loaded through kbool's
`kk.uses`:

| unit | what it adds |
|---|---|
| `kklass` | the core: `defineClass`, instances, dispatch, `defineMethod`, `kk.class` |
| `kklass_decl` | the declarative API (`declareClass` … `endImplementation`); loaded by `kklass` itself |
| `kklass_pascal` | the Pascal DSL (`class … end`, `build`, `uses`); loads `kklass` |
| `kklass_serializable` | `defineSerializableClass`, `toString`/`toJSON`, `saveObjects`; loads `kklass` |
| `kklass_autoload` | `kkload` / `autoloadClasses`: compiled caches; loads `kklass` |

`kklass_compiler.sh` and `kklass_kkp.sh` are tools run with `bash`, not units.

### Your First Class

Create a file `hello_world.sh`:

<!-- doctest -->
```bash
#!/usr/bin/env bash
# Load kbool, then the kklass unit
source /path/to/kbool/kbool.sh || exit
kk.uses kklass || exit

# Define a simple class
defineClass "Greeter" "" \
    "property" "name" \
    "method" "greet" 'echo "Hello, $name!"'

# Create an instance
Greeter.new greeter

# Use the instance
greeter.name = "World"
greeter.greet            # => Hello, World!

# Clean up
greeter.delete
```

Run it:

```bash
bash hello_world.sh
# Output: Hello, World!
```

`source kbool.sh` is found through `$PATH` too when the kbool folder is on it.
Sourcing a module directly — `source path/to/kklass/kklass.sh` — still works:
its unit header loads `kbool.sh` first. The rest of this book writes the
canonical `source …/kbool.sh` + `kk.uses`; the chapter [Units and
uses](#units-and-uses) covers what being a unit means for your classes.

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
source /path/to/kbool/kbool.sh
kk.uses kklass

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
source /path/to/kbool/kbool.sh
kk.uses kklass

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
#!/usr/bin/env bash
source /path/to/kbool/kbool.sh
kk.uses kklass

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
functions, because every instance already carries them:

| Name | Built-in it would collide with |
|---|---|
| `call` | `obj.call NAME ...` — dynamic dispatch |
| `delete` | `obj.delete` — destroys the instance |
| `property` | `obj.property NAME [= VALUE]` |
| `parent` | `obj.parent NAME ...` / `$this.parent` (what `inherited` becomes) |
| `new` | `Class.new` — the constructor verb |

Accepted, such a member would either replace the built-in or be silently
replaced by it (`$this.delete` would run the user method while `obj.delete`
destroys the instance). Names that merely *start*
with one of them (`recall`, `delete2`, `parentId`, `callback`, `newest`) are
fine. Static members (`classVar`, `static_method`, `classProcedure`, ...) are
class-level and are not affected by this table — they have their own (below).

#### Reserved static member names

A static member is the class-level function `CLASS.NAME` (a static property
is its accessor, a static method its dispatcher). kklass generates a few
class-level functions of its own for every class, so a static member cannot
take their names (accepted, such a member would be silently lost, or would
hijack `.new`):

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
- **An instance property and a static property cannot share a name.** Inside
  a member body both would be the plain variable `x` — the instance property a
  nameref onto the instance's storage, the static one a nameref onto the
  class's — and the static one is bound last, so it would *hide* the instance
  property: `x=v` in a body would write the static and the instance's `x`
  would never change. Refused for every instance property kind (`property`,
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

#### Reserved variable-like member names

A property, static property, lazy property or field is a **variable** of
that name inside every method body of its class (a nameref onto its storage,
see "Trap: Inside a Body, a Property Is a Nameref"), and the methods of other
classes and the static methods they call see it as an unset shadow (the
Isolation Rule). So it cannot take a name whose binding **breaks or changes
bash or kklass itself** (measured on bash 5.2.37 and 5.3.9):

| Refused | Why (the message says it) |
|---|---|
| bash's special variables: `_ BASH BASHOPTS BASHPID COMPREPLY COPROC DIRSTACK EPOCHREALTIME EPOCHSECONDS EUID FUNCNAME GROUPS HISTCMD LINENO MAPFILE OPTARG OPTERR OPTIND PIPESTATUS PPID RANDOM SECONDS SHELLOPTS SRANDOM UID` | readonly (`BASHOPTS`, `EUID`, … print an error on every method call), "may not be assigned" (`FUNCNAME`, `GROUPS`, …), dynamic (`SECONDS`, `RANDOM`, `LINENO`, …), or written by bash or a builtin (`_` after every command, `PIPESTATUS`, `OPTIND`, `MAPFILE`, …); kklass itself reads `BASH` |
| names starting with `BASH_`, `COMP_`, `READLINE_` | bash's own variables (shell state, programmable completion, readline) |
| `PATH EXECIGNORE HOME PWD OLDPWD CDPATH GLOBIGNORE GLOBSORT FIGNORE LANG LC_* PS0 PS1 PS2 PS3 PS4 PROMPT_COMMAND POSIXLY_CORRECT FUNCNEST TIMEFORMAT TMOUT` and the seven history variables `HISTCMD HISTCONTROL HISTFILE HISTFILESIZE HISTIGNORE HISTSIZE HISTTIMEFORMAT` | bash's own behaviour depends on them, and bound as a property they hide the shell's value in the class's bodies: `PATH` — command lookup fails even with the property set; `LANG` / `LC_*` — the bodies run in the C locale; `POSIXLY_CORRECT` — posix mode is off; `FUNCNEST` — the limit is lifted; a global `CDPATH`, `TMOUT`, `TIMEFORMAT`, `PS4` stops applying |
| `TZ`, `TMPDIR`, `TEMP`, `TMP` | read by the code of the bodies and the functions they call (time zone code, `${TMPDIR:-/tmp}`, the `TMPDIR` / `TEMP` / `TMP` fallbacks of temp-path code such as kcl `tpath`): they would read the property, or nothing in other classes' methods, while the children of the method keep the real value |
| `IFS`, `REPLY` | refused by the general reserved names above |

**Allowed:** plain environment and informational names — `USER`, `LOGNAME`,
`TERM`, `HOSTNAME`, `SHELL`, `COLUMNS`, `LINES`, `MAIL`, `OSTYPE`, `ENV`
(bash reads `ENV` only when an interactive shell starts in posix mode),
`HISTORY`, `HISTOGRAM`, and any name of your own. Inside the class's bodies
such a name is the property, the commands the body runs see the real value
(the binding is export-safe, `local -n +x`), and a method of another class
called from the body sees it unset. Code that is not a method sees the
property too: a plain function called from the body, and the file-scope
code of a unit that a body loads first with `kk.uses` (kcl `tpath` reads
`$OSTYPE` when it loads; kbool's configuration lookup reads
`$USERPROFILE`). Name such a property differently if the class's bodies
load units or call such functions.

The check is case-sensitive, as bash names are (`path`, `Home`, `tz`,
`Lang` are fine, also under `shopt -s nocasematch`), and runs at the
declaration only — the method call path carries no check. It applies on
every declaration path: `defineClass` `property` / `static_property` /
`lazy_property`, `defineSerializableClass`, the declarative `field` /
`property` / `classVar`, the Pascal `var` / `static var` / `property`, `.kkp`
fields, properties and `class var` — and so to every compiled `.ckk` cache
(the compiler runs the source; a refused name compiles nothing). Class and
**method** names are not variables and are not checked (`method PATH` is
fine). The error names the class and the reason:

```
Reserved property name: 'PATH' (class 'Shell': a property, static property, lazy property or field is a variable of that name inside every method body of the class, and bash uses PATH for command lookup, and in the class's bodies (and in the methods of other classes and the static methods they call) it would see the property or nothing instead of the shell's PATH; choose another name)
```

A **readonly global** named like one of your properties (`readonly x=1`
next to a class with a property `x`) cannot be caught at declaration: every
method call of that class then fails with `local: x: readonly variable`.
Do not make globals readonly under property names.

#### A refused member fails its class

A refused member name (any rule above, a non-identifier, an unsupported
modifier, an `override` of a non-virtual method, ...) does not just print an
error: it **poisons the class being declared**. The
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
Under `set -e` the refused verb itself already ends the script.

`state` is *not* reserved: it is the name of the data-array reference
(`${state[key]}` reads any property by name, as `TCustomApplication` does), and
a property called `state` simply shadows it inside that class. Internal locals
of the dispatcher are all `__kk_`-prefixed, so ordinary names such as
`method_body` or `frame_id` are safe.

### Taken Class and Instance Names

A class `X` and an instance `X` both create functions `X.*`, so some names are
taken:

| Taken name | Why | As a class | As an instance (`T.new X`) |
|---|---|---|---|
| a DSL verb (`class`, `end`, `var`, `build`, `uses`, `declareClass`, `defineClass`, …) | it would shadow the DSL | refused | refused |
| a built class | `X.new`, `X.<static>` | the site rules (*Duplicate identifier* from another place) | refused |
| a **declared namespace** | someone's functions `X.*` | refused (unless declared by its owner) | refused |
| a **live instance** | the instance's functions `X.*` and variables `X_*` | refused (*Duplicate identifier*: `'X' is a live instance of class C`), on every path — `defineClass`, `declareClass`, Pascal `class`, a `.ckk` cache; free again after `X.delete` | re-created (`T.new X` again) |

A **live instance** is a name whose `X_class` names a registered class *and*
whose `X_data` is an associative array — exactly what `CLASS.new X` creates
and `X.delete` removes, of a class that is still registered (after `kk.class
--forget C` the instances of C keep working but their names are no longer
protected — the forget says so in a WARNING). A plain variable of yours that happens to be called
`X_class` (`css_class=btn`) does not make `X` an instance: `kk.unit css` and
`kk.namespace css` still work.

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
`kk.namespace libns` line. (kcl's helper namespaces are declared: `tawk`,
`tpipe`, `tsed`, `tutil` are unit names, `ths`, `tca`, `TSet`, `TDict`,
`TQueueStack` are `kk.namespace` lines.) The whole unit picture — sites,
caches, forgetting — is the chapter [Units and uses](#units-and-uses).

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

<!-- doctest -->
```bash
source /path/to/kbool/kbool.sh || exit
kk.uses kklass_pascal || exit         # loads the kklass core itself

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
g.Greet                       # => Hello, Alice!
echo "$(g.Salutation)"        # => Greetings from Alice
g.delete
```

`build` extracts each body with `declare -f`, feeds it to the normal kklass
runtime (the same declarative core that `defineClass` uses), and removes the
scratch functions. Everything you know about instances, properties and dispatch
still applies — the DSL changes how classes are *written*, not how they *run*.

**Building a class forks nothing.** `build`, the declarative API and
`defineClass` run inside your shell without `$( )` subshells, so even a large
unit loads quickly: a fresh `kk.uses dateutils` (one class, 185 methods) takes
about 0.36 s on Windows (msys), where a fork is expensive. Where the shell has no `/proc/PID/fd`
(FreeBSD's pkg bash, which emulates `/dev/fd`), the one capture `build` needs —
the `declare -f` text of a method — falls back to a plain `$( )`, silently.
How the fork-free capture works and what it guarantees is described in
[Internals: fork-free class building](#fork-free-class-building).

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
uses A B ...                     load units once (= kk.uses, names resolved from this file)
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
  file on 5.1/5.2). Do not declare constants as `static var` — keep them as plain
  file-scope globals (see kcl/tpath/tpath.sh for the worked example). In a
  unit, assign `readonly` constants once per process — wrap the assignments
  and the `readonly` statement in
  `if [[ -z ${X+x} || ${X@a} != *r* ]]; then … fi`, keyed on one of the names
  (kcl/README.md §1.10, rule 7) — otherwise `kk.unit --forget` + a re-source
  prints `readonly variable` and, under `set -e`, exits the caller.
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

**The body text is never rewritten.** `$this.NAME` in a member or constructor
body is plain bash: `"$this.Home"` is the string `obj.Home`, the same as
`"$__inst__.Home"`, and a handler registered that way calls the method. An
empty method body is a valid no-op through every call form (silent, rc 0).

Compiled caches made by an old kklass that still rewrote body text (it turned
`$this.NAME` into `$__inst__.call NAME` for every method NAME of the class,
inside quoted strings too and as a prefix: with a method `count`,
`$this.counter` became `.call counter`) keep working — `.call` dispatch is
unchanged — but keep that behaviour until the cache is rebuilt. The autoloader
rebuilds a `.ckk` file when its `.kk`/`.kkp` source, `kklass.sh` or the
compiler is newer (see [Autoloading](#autoloading-with-kklass_autoloadsh));
`kkload FILE --force-compile` rebuilds it at once.

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
  resolution, template generation, DSL processing) does not run again. That
  code forks nothing (see *Pascal DSL*: ≈0.36 s for a class of 185 methods),
  so the gain is modest; the cache still skips it.
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
and is not dumped (so a compiled file never redefines kkore's `kv.*`
functions when it is sourced), and neither is a class that was declared but
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
#!/usr/bin/env bash
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
#!/usr/bin/env bash
source /path/to/kbool/kbool.sh
kk.uses kklass_autoload

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
   and also when `kklass_compiler.sh` or `kklass.sh` is newer than the cache — a cache is a dump of what the runtime built, so one
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
source /path/to/kbool/kbool.sh
kk.uses kklass_autoload
kkload "CounterPascal.kkp"
```

`--no-compile` works for `.kkp` as well and routes through the same translated runtime path instead of the compiled cache.

**Units (`unit X;`, `uses A, B;`).** `unit X;` must be the first statement and `X` the file's stem (`unit CounterPascal;` lives in `CounterPascal.kkp`); otherwise the translation fails. It becomes the two unit header lines of a unit outside the kbool tree (`kk.unit X`, the user form of USES_PLAN.md §7.4), so the translated file is a unit: loaded once, registered with kbool, which it loads from `KBOOL_HOME` when kbool is not loaded yet (`kkload` and `kklass_compiler.sh` set `KBOOL_HOME` to their own kbool when it is unset; a translation sourced by hand needs kbool loaded or `KBOOL_HOME` set). `uses A, B;` (outside a class, may span lines) becomes `kk.uses A B || return`. Put comments on their own lines: text after a `unit` / `uses` statement's `;` is an error naming FILE:LINE. A translated unit only loads from a file named `X.sh`: the runtime translation is `<cache>/X.sh`. A compiled cache names such a unit by its unit name (`# Source unit: X`) and registers its classes like a build does.

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
#!/usr/bin/env bash
source /path/to/kbool/kbool.sh
kk.uses kklass_autoload

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

## Units and uses

kbool has Pascal-like **units**: a file that starts with a two-line header is
loaded once per shell, has a unique name (its file stem), and names its
dependencies with `kk.uses`. The unit system itself — header shapes,
`kk.uses` lookup, configuration, projects — is described in the
[kbool README](https://github.com/Keksov/kbool/blob/main/README.md) and the [kkore reference](https://github.com/Keksov/kkore/blob/main/README.md);
the design and its reasons in [USES_PLAN.md](dev/USES_PLAN.md). This chapter is
what it means for classes: where a class is *declared*, what happens when the
same class is declared again, which names are taken, and how compiled caches
and `.kkp` units fit in.

### kklass Is a Unit

`kklass`, `kklass_decl`, `kklass_pascal`, `kklass_serializable` and
`kklass_autoload` are units (see the table in [Installation](#installation)):

```bash
source /path/to/kbool/kbool.sh || exit
kk.uses kklass_pascal || exit        # once per shell, however many units ask for it
```

A direct `source kklass/kklass_pascal.sh` still works — its header loads
`kbool.sh` first — and a later `kk.uses kklass_pascal` is then a no-op.

### Writing a Class Unit

Give the file the header (the user form below; units inside the kbool tree use
a relative path, see the [kbool reference](https://github.com/Keksov/kbool/blob/main/docs/reference.md#units)), load the
kklass module it needs, then declare classes as usual. In the Pascal DSL,
`uses A B …` is a synonym of `kk.uses A B …` that resolves names from the
calling file, like Pascal's `uses A, B;`.

<!-- doctest -->
```bash
mkdir -p geo
cat > geo/point.sh <<'EOF'
#!/usr/bin/env bash
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit point || return $__kk_unit_rc
kk.uses kklass_pascal || return

class TPoint
    public
        var X
        var Y
end
build TPoint
EOF
cat > geo/segment.sh <<'EOF'
#!/usr/bin/env bash
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit segment || return $__kk_unit_rc
kk.uses kklass_pascal || return
uses point || return                 # the Pascal-DSL synonym of kk.uses

class TSegment
    public
        var  Len
        func Twice
end
TSegment.Twice() { RESULT=$(( 2 * Len )); }
build TSegment
EOF
source /path/to/kbool/kbool.sh || exit
kk.uses geo/segment.sh || exit
TSegment.new s; s.Len = 21; s.Twice; echo "$RESULT"   # => 42
kk.uses geo/point.sh geo/segment.sh                   # no-ops: loaded once
kk._unit_classes segment; echo "segment: $RESULT"     # => segment: TSegment
```

A class built while a unit loads is filed under that unit, so
`kk.unit --forget segment` drops `TSegment`'s declaration site too and the next
load rebuilds it (live instances of the old class are yours to delete).

### Declaration Sites and *Duplicate identifier*

The **site** of a class declaration is where it happens: the chain of
`FILE:LINE` call positions from the innermost one outside kklass outward, up to
the position inside the sourced file (or the script itself). `declareClass` —
and so every builder: the Pascal `class`, `defineClass`,
`defineSerializableClass` — compares a new declaration of a BUILT class with
the site it was built from:

| the new declaration comes from | result |
|---|---|
| **another site** — another file, another line, a wrapper function called twice | `kklass: Duplicate identifier: class 'X' is already declared at SITE; refusing to redeclare it at SITE` on stderr, rc 1. The built class is kept and **poisoned** against a rebuild from that block, the rest of the block (`end`, members, `build`, `endImplementation`) is swallowed silently with rc 1, and the unit being loaded is tainted (its next load runs it again) |
| **the same site** — a file *without* a unit header sourced again, a loop, two declarations on one line, two different `source <(…)` declaring it on the same line (both are the file `/dev/fd/63`) | one `kklass: WARNING: class 'X' declared again from the same place (SITE); ignored, the class is not rebuilt` (silenced by `VERBOSE_KKLASS=quiet`), rc 0. The class is **not rebuilt**: instances, `defineMethod` changes and static values survive; the block is swallowed, and a swallowed Pascal `build` restores the static methods the re-run redefined and drops its body functions; `defineClass` is ignored as a whole. File-scope `defineMethod` / `addSerializable` calls of such a file still run |
| **the unit's own file run again** — after `kk.unit --forget UNIT`, or because its earlier load was tainted (a failed `kk.uses`, a *Duplicate identifier*, … inside it) | **rebuilt**, no WARNING: dropping the unit's registration drops the sites of every class it declared, so the run builds them from the file as it is now (an edited property list included) |
| an **interactive prompt** (`$-` has `i`) and no file position at all | allowed: the class is rebuilt (a file sourced at a prompt is still checked; `bash -c`, `bash -s` and a pipe are files named "(no file)", judged by line) |

A file **with** a unit header is not run twice while it is registered and
complete, so it never meets the same-site rule; when it does run again (the
row above) its classes are rebuilt. File parts of two sites are compared with
`[[ -ef ]]`: `C:/x`, `C:\x`, `/c/x` and a `..` spelling of one file are one site. A class is
"declared" once it is built; a refused or still-open declaration can be
declared again from anywhere.

<!-- doctest -->
```bash
cat > shapes.sh <<'EOF'
class TCircle
    public
        var  R
        func Diameter
end
TCircle.Diameter() { RESULT=$(( 2 * R )); }
build TCircle
EOF
cat > imposter.sh <<'EOF'
class TCircle
    public
        var  Radius
end
build TCircle
EOF
source /path/to/kbool/kbool.sh || exit
kk.uses kklass_pascal || exit
source ./shapes.sh
TCircle.new c; c.R = 3
source ./shapes.sh; echo "the same file again: rc=$?"   # => the same file again: rc=0
# 2> kklass: WARNING: class 'TCircle' declared again from the same place
source ./imposter.sh; echo "another file: rc=$?"        # => another file: rc=1
# 2> kklass: Duplicate identifier: class 'TCircle' is already declared at
c.Diameter; echo "diameter=$RESULT"                     # => diameter=6
```

<!-- doctest -->
```bash
source /path/to/kbool/kbool.sh || exit
kk.uses kklass || exit
mk() { defineClass "$1" "" property "$2"; }      # a wrapper: its callers are the site
mk TPair left;  echo "first: rc=$?"               # => first: rc=0
mk TPair right; echo "second: rc=$?"              # => second: rc=1
# 2> Duplicate identifier: class 'TPair'
for i in 1 2; do defineClass TLoop "" property x; done; echo "loop: rc=$?"   # => loop: rc=0
# 2> WARNING: class 'TLoop' declared again from the same place
```

A *Duplicate identifier* inside a unit's load taints the unit even when the
unit carries on and returns 0: `kk.uses` reports it (rc 2), and the next load
runs the unit again instead of counting it complete.

<!-- doctest -->
```bash
cat > fake.sh <<'EOF'
#!/usr/bin/env bash
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit fake || return $__kk_unit_rc
defineClass TShape "" property area
echo "fake: body ends"
EOF
source /path/to/kbool/kbool.sh || exit
kk.uses kklass || exit
defineClass TShape "" property name
kk.uses fake; echo "rc=$?"     # => fake: body ends
                               # => rc=2
# 2> kklass: Duplicate identifier: class 'TShape'
# 2> kbool: error: kk.uses: unit 'fake' is not completely loaded
```

### Taken Names in Units

A unit's name is a declared function namespace (`kk.unit tlist` declares
`tlist`), and so is every `kk.namespace X` — see [Taken Class and Instance
Names](#taken-class-and-instance-names). The rule works in both directions: a
class or an instance may not take a declared namespace, a DSL verb or a class
name, and a unit (or `kk.namespace`) may not take the name of a built class or
a live instance — `kk.unit` fails the load with rc 2. A unit may declare a
class with its own name (kcl's `class dateutils` in the unit `dateutils`).

<!-- doctest -->
```bash
cat > TBox.sh <<'EOF'
#!/usr/bin/env bash
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit TBox || return $__kk_unit_rc
TBox.helper() { :; }
EOF
source /path/to/kbool/kbool.sh || exit
kk.uses kklass || exit
defineClass TBox "" property side
kk.uses TBox; echo "unit named like a class: rc=$?"    # => unit named like a class: rc=2
# 2> 'TBox' is already a class declared at
# 2> kk.uses: loading unit 'TBox' failed
TBox.new uses; echo "instance named like a verb: rc=$?"   # => instance named like a verb: rc=1
# 2> Invalid instance name: uses (a kklass DSL verb)
```

### Forgetting a Class or a Unit

| command | effect |
|---|---|
| `kk.class --forget CLASS` | drops CLASS's declaration site (and closes an open swallowed block), so the next declaration from anywhere builds it again; one WARNING names CLASS's live instances (their names lose the taken-name protection). rc 0 forgotten; 1 not a built class; 2 malformed (no or extra arguments, not an identifier; silent) |
| `kk.unit --forget UNIT` | drops the unit's registration and the sites of every class it declared, so the next `source` / `kk.uses` loads and rebuilds them (rc 0 / 1 / 2, kkore) |

Neither deletes the class functions or any instance: they are development
hatches for a prompt, not a reload. `kk.class --forget CLASS` prints one
WARNING naming CLASS's live instances, if it has any:
they keep working, but once their class is forgotten their names are no
longer protected — a class may then be declared with an instance's name
(see *Taken Class and Instance Names*); delete them first. A recompiled `.ckk` cache of a class that
is already loaded is ignored in the same shell (the same site) — forget the
class first.

<!-- doctest -->
```bash
cat > box.sh <<'EOF'
defineClass TBox2 "" property side
EOF
source /path/to/kbool/kbool.sh || exit
kk.uses kklass || exit
source ./box.sh
echo 'defineClass TBox2 "" property side property depth' > box.sh   # edit the file
source ./box.sh 2>/dev/null                 # the same site: ignored
kk.class --forget TBox2; echo "rc=$?"       # => rc=0
source ./box.sh                             # rebuilt from the edited file
TBox2.new b; b.depth = 7; echo "depth=$(b.depth)"   # => depth=7
kk.class --forget TBox2      # 2> 1 live instance(s) of TBox2 (b) keep working
kk.class --forget TBox2; echo "rc=$?"   # => rc=1
```

The REPL flow for a unit: edit it, forget it, load it again — its classes are
rebuilt from the edited file, without a WARNING:

<!-- doctest -->
```bash
cat > shape.sh <<'EOF2'
#!/usr/bin/env bash
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit shape || return $__kk_unit_rc
kk.uses kklass || return
defineClass TShape "" property p
EOF2
source /path/to/kbool/kbool.sh || exit
kk.uses shape || exit
sed 's/property p/property q/' shape.sh > shape.new && mv shape.new shape.sh   # edit the unit
kk.uses shape                                   # still loaded: a no-op
kk.unit --forget shape; echo "forget: rc=$?"    # => forget: rc=0
kk.uses shape || exit                           # runs again: TShape is rebuilt
TShape.new s; s.q = 5; echo "q=$(s.q)"          # => q=5
```

### Compiled Caches and Units

A `.ckk` cache (see [Autoloading](#autoloading-with-kklass_autoloadsh)) loads
kklass with `kk.uses kklass`, and **registers the classes** it holds like a
build does — at the site of the source they were compiled from (its path
relative to the cache folder, so a project moved together with its cache keeps
working; else the source unit found by name; else the absolute path at compile
time). So a class from a cache declared again from another file is a
*Duplicate identifier*, and a cache whose class is already built from another
place — or is named like a verb or a namespace — skips that class instead of
overwriting it.

A cache holds the unit's **classes only** — not its other file-scope code: its
`kk.uses` lines, helper functions, variables. It therefore does not register
the unit: a later `kk.uses` / `source` of the unit runs the unit body
normally (helpers, dependencies), and its declaration of a class the cache
already built is skipped silently once. The cache folder is `KKLASS_CKK_DIR`,
else the configuration's `ckkdir` (`kk.config ckkdir`), else `./.ckk`.

<!-- doctest -->
```bash
cat > shapes.sh <<'EOF'
#!/usr/bin/env bash
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit shapes || return $__kk_unit_rc
kk.uses kklass_pascal || return

shapes.describe() { printf 'a %s\n' "$1"; }

class TSquare
    public
        var  Side
        func Area
end
TSquare.Area() { RESULT=$(( Side * Side )); }
build TSquare
EOF
source /path/to/kbool/kbool.sh || exit
kk.uses kklass_autoload || exit
kkload shapes.sh >/dev/null 2>&1 || exit        # compiles .ckk/shapes.ckk.sh, loads it
TSquare.new sq; sq.Side = 4; sq.Area; echo "area=$RESULT"   # => area=16
declare -F shapes.describe >/dev/null || echo "the cache has no helper"   # => the cache has no helper
kk.uses shapes || exit                          # runs the unit body; TSquare is not rebuilt
shapes.describe square                          # => a square
```

### `.kkp` Units

A `.kkp` file is a unit when it starts with `unit X;` (X = the file stem); its
`uses A, B;` becomes `kk.uses A B || return`. The translation, its rules and
its errors are in [Pascal-style `.kkp` Units](#pascal-style-kkp-units).

### Child Shells

kklass exports nothing to a child `bash`. A child shell loads kbool itself,
the way a script does — `source /path/to/kbool/kbool.sh` and `kk.uses kklass`
(or `kklass_pascal`, `kklass_serializable`, `kklass_autoload`), or through a
unit header — and builds its classes there:

<!-- doctest -->
```bash
"$BASH" -c 'source /path/to/kbool/kbool.sh && kk.uses kklass_pascal || exit
    declareClass TJob ""; property id; endClass; endImplementation TJob
    TJob.new j; j.id = 7; echo "$(j.id)"'               # => 7
```

`KKLASS_EXPORT_FUNCTIONS=1` has been removed: it exported the public
verbs but not the internals, the class functions or the registries, so a child
could not even `declareClass`; a shell where it is still set gets one WARNING
when kklass loads, and nothing is exported. kklass's tables are associative
arrays and are never inherited by a child even when you export its functions
yourself (`set -a`, `export -f`): such a child starts with empty site and
taken-name tables, so loading the same files there again is harmless — and its
classes must be built there anyway. A `( … )` or `$( … )` subshell shares the
parent's tables.

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
source /path/to/kbool/kbool.sh
kk.uses kklass_serializable          # loads kklass too

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
`toJSON`/`fromJSON`. The four leading
arguments are mandatory; the format and the separator are checked **before**
`defineClass` runs, so a refused call builds nothing (rc 1 and one `Error:`
line on stderr).

**Which properties are serialized.** The
fields are the class's full property list, `${CLASS}_class_properties`:
**inherited properties first, then the class's own, lazy and computed ones
included**, in definition order — the same list `addSerializable` and
`toJSON` use. Earlier versions of `defineSerializableClass` wrote only the
class's own `property` arguments (a child of a class with property `p0`
serialized as `TChild:x` and lost `p0`); a string they wrote for a class with
a parent or a lazy property has a different field layout and must be re-saved
(see the [CHANGELOG](../CHANGELOG.md)).

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
source /path/to/kbool/kbool.sh
kk.uses kklass_serializable          # loads kklass too

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
source /path/to/kbool/kbool.sh
kk.uses kklass_serializable          # loads kklass too

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
Nothing is printed on failure and `RESULT` is empty; with
`VERBOSE_KKLASS=debug` exactly one `kk.debug` line goes to stderr. On success
`fromJSON` returns through `RESULT`: a direct call prints **nothing** and sets
`RESULT` to the instance name; inside `$( )` the name is printed once.

**`__class__` check.** `fromJSON` accepts a `"__class__"` only if it names
the receiving instance's own class or the class `addSerializable` was called
on (which is what `toJSON` writes, also for subclasses that inherit the
serializer), so another class's JSON is never loaded silently. Anything else
is rc 1. Input without `"__class__"` is accepted.

```bash
Book.new b3
b3.fromJSON '{"__class__":"Magazine","title":"x"}' || echo "refused"   # refused, b3 unchanged
```

**Class-prefix check in the string format.**
The string-format counterpart of the `__class__` rule: `fromString` accepts an
input only if it starts with the class name `addSerializable` was called on
followed by the separator — exactly what `toString` writes, so a subclass that
inherits the serializer reads its own output. Anything else (another class's
line, `CX:...` for class `C`, a bare `C`, a leading blank, no argument at all —
also under `set -u`) is rc 1 with `RESULT=''`, nothing printed (one `kk.debug`
line under `VERBOSE_KKLASS=debug`) and the instance untouched: `Other:p:q`
never loads into a `C` instance as `a=Other`.

```bash
Product.new p2
p2.fromString "Other:x:y" || echo "refused"   # refused, p2 unchanged
```

**One line per object.** Because a newline is always written as `\n`,
`toJSON` output never contains a raw newline, and `saveObjects` / `loadObjects`
can keep their one-object-per-line file format for JSON objects with any
values. `saveObjects` **prefers `toJSON`** when a class has both formats
(`toString` does not escape, so a value holding a newline or the separator
would break the file).

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
source /path/to/kbool/kbool.sh
kk.uses kklass_serializable          # loads kklass too

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

**`loadObjects FILE CLASS ARRAY_NAME`** — the contract:

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
source /path/to/kbool/kbool.sh
kk.uses kklass_serializable          # loads kklass too

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
source /path/to/kbool/kbool.sh
kk.uses kklass

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
source /path/to/kbool/kbool.sh
kk.uses kklass

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
source /path/to/kbool/kbool.sh
kk.uses kklass

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
source /path/to/kbool/kbool.sh
kk.uses kklass

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
source /path/to/kbool/kbool.sh
kk.uses kklass

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
source /path/to/kbool/kbool.sh
kk.uses kklass

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

### EXIT Handlers and `set -e`: kk.frameReset

When the script stops through `set -e` **inside a method body** (a failing
command in the body, not caught by `||` / `if`), bash unwinds the body's
locals but kklass's own bookkeeping of the call never runs. The EXIT trap then
starts with a **stale frame** (measured on bash 5.2.37 and 5.3.9):
`${#__KLIB_FRAME_STACK[@]}` is 1, a private method called from the
handler is not reported as an access from outside, and bash's
`localvar_unset` option — which the outermost method call turns on for its
duration (Isolation Rule) — is still on, so an `unset` in the handler's own
helper functions hides a variable instead of revealing the outer one.

Make `kk.frameReset` the **first command of such a handler**. It clears the stale frames and turns `localvar_unset` back off — only
when kklass turned it on (a script that had it on keeps it). It is a no-op
(rc 0) when nothing is stale: at the top level, inside a running body, and in
an EXIT trap that runs inside the body — an explicit `exit` in a body and a
`set -u` abort run the trap in the body's scope, where its frame is still
live. Methods called from the handler work either way; `FUNCNAME` still lists
the dead call chain (bash's own). On bash 5.1 the EXIT trap of a `set -e` exit
inside a method runs in the method's scope (5.2 and later unwind the body's
locals first), so the frame is still live there and `kk.frameReset` is the
documented no-op, as for an explicit `exit`.

```bash
cleanup() {
    kk.frameReset                  # first: drop what a set -e exit in a body left
    user.delete 2>/dev/null || true
}
trap cleanup EXIT
set -e
user.save                          # a failing command in save's body ends the script here
```

On **bash 5.2** a `set -e` exit from a **nested** method call (a method
called from a method body) may also print
`pop_var_context: head of shell_variables not a function context` a few
times. That is a bash 5.2 bug — plain nested functions that `eval` their
body reproduce it without kklass — and it is harmless; bash 5.3 is silent.

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
source /path/to/kbool/kbool.sh
kk.uses kklass
source "my_classes_dev.sh"

# Production: Use compiled classes
bash kklass_compiler.sh my_classes.kk my_classes.sh
source "my_classes.sh"

# Or use autoload (best of both)
kk.uses kklass_autoload
kkload "my_classes.kk"
```

### Document Your Classes

```bash
#!/usr/bin/env bash
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
bash 5.2.37 and 5.3.9):

- `${#v}` is **0 on bash 5.2.37** (correct on 5.3.9) — take a length from a
  local copy: `local c="$v"; n=${#c}`;
- on **both** bashes `[[ -v v ]]` is false even when `v` is set, and
  `${#v[@]}` is 0 — test `[[ -n "$v" ]]` instead;
- `unset v` inside a member deletes the instance's storage element (the
  property then reads as empty) — assign `v=""` to clear it;
- these all work: `${v:1:2}`, `${v%x}`, `${v@Q}`, `${v^^}`, `v+=x`,
  `printf -v v …`, `read -r v`;
- **`set -u`:** a declared property that was never assigned is UNSET, not
  empty. The accessors `obj.v`, `obj.property v` and the static `Class.sp`
  read it as `""` with rc 0, and the
  serializers write it as empty, but a body reading it under `set -u` differs
  between the bashes: `$v` aborts with "v: unbound variable" on **5.3.9** and
  reads `""` on **5.2.37**, and arithmetic on it (`n=$((n+1))`) aborts on
  **both** (`inst_data: unbound variable`). Write method code that may run
  under `set -u` with a default: `"${v-}"` for text, `$(( ${n:-0} + 1 ))` for
  numbers;
- **exported variables:** every bind of a frame — the property and
  static-property namerefs, `state`, `this`, `__inst__`, `__class__` — is
  export-safe (`local -n +x` / `local +x`), so a property that hides an
  exported variable of the same name does not leak into the environment of
  the commands the body runs: they see the variable's **global** value, never
  the nameref's target name (`MYENV=inst_data[MYENV]`). The same holds
  under **`set -a`** (allexport): kklass turns it off while it sets up a call
  and back on right before the body, so the body's own assignments are
  exported as usual, and neither the binds nor kklass's private `__kk_*`
  call locals are (the method body text never reaches a child's
  environment). Names bash
  itself depends on are refused as member names (Reserved Member Names);
- **a body cannot export a property:** `export v` is refused by bash
  ("`inst_data[v]`: not a valid identifier") and `declare -x v=new` changes
  what the body reads as `$v` but neither exports it nor updates the
  property's storage (measured, both bashes). To hand a property to a
  command, put it in that command's environment: `v="$v" cmd` or
  `env v="$v" cmd`.

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

### Isolation Rule: A Body Sees Only Its Own Names

Those namerefs are bash *locals*, and bash scopes locals **dynamically**: a
function called from a member body sees every name the body has bound,
unless it binds the same name itself. Left at that, a **static method**, or a
method of **another class** without a property `y`, called from an instance
method of a class with a property `y`, would read the caller's `y` and **write
it** with a plain `y=…`, and a static method would see the caller's `this`,
`__inst__`, `__class__` and `state` (so `$this.x` / `state[k]=…` in it would
act on the CALLER's instance).

So every member body is **isolated** from the kklass names of the body that
called it (measured on bash 5.2.37 and 5.3.9):

- a method / constructor / destructor / computed getter / lazy init of
  **another class** — reached directly (`b.m`), through `.call`, `$t.m`,
  `B.new`, `inherited` / `$this.parent` of another instance, or a chain of
  such calls — neither reads nor writes the caller's **properties** or
  **static properties**: the runtime declares them as unset locals of the
  callee's frame before the callee binds its own (a name both classes have is
  the callee's own);
- a **static method** (and a `kk.register_static_methods` function) called
  from a body sees none of the caller's properties, static properties,
  `this`, `__inst__`, `__class__` or `state`; its own static properties stay
  bound, and the bodies it calls in turn do not see them;
- an `unset NAME` in such a callee only unsets its own (shadow) copy: it
  neither reveals nor destroys the caller's NAME (`unset parts; read -r parts`,
  `unset y; y=…`, a static's `unset this`). The outermost method call turns
  bash's `localvar_unset` option on for the duration of the call (when it is
  off) and restores it afterwards — also after `return N` or a failing body;
  a caller that has it on keeps it. So every body, static method and **plain
  function called from a method runs with `localvar_unset` semantics**: an
  `unset` of a local of a calling function marks it unset instead of revealing
  the next outer variable of that name. A static method called from the top
  level is not affected;
- a call whose callee frame binds every name of the caller anyway takes no
  shadow at all: a body of the caller's own class (`$this.m`, another instance
  of the class, a subclass instance) and a body on the caller's own instance
  (`$this.m` of an inherited method, `inherited X`) — they see the caller's
  names, at the cost of one name comparison (under the caller's
  `shopt -s nocasematch` these calls take the shadow too: correct, only
  slower). The own instance is recognised by a marker private to the
  runtime, not by `this`: a helper's own `local this=$1` or a body's
  `for this in …` does not weaken the isolation. The RESULT / REPLY / `$( )`
  channels and everything a body binds itself are unchanged.

**Cost:** the isolation costs about **1.4 µs per
property and static property of the CALLER** on a call of another class's
method and about **1.1 µs per caller name** on a static method called from a
method, plus the `localvar_unset` handling of every method call. Measured
(bash 5.2.37 and 5.3.9, two in-process A/B runs each against kklass without
the isolation; µs added per call, ranges over the two runs per bash; the
A/A control — the old code against itself — spread −10.6..+5.4 µs, apart from
one −22 µs outlier on a 5.3 `$this.m` run). The base costs are ~190 µs (5.2) /
~170 µs (5.3) for a method call and ~22..26 µs for a static call:

| call | 5.2.37 | 5.3.9 |
|---|---|---|
| top level: `obj.m` | +24..+27 | +22..+23 |
| top level: `obj.call m` | +28 | +27..+32 |
| top level: a static method | +1.6..+2.1 | +1.2..+1.4 |
| from a method: own class (`$this.m`, `$this.call m`, another instance) | +16..+23 | +11..+24 |
| from a method: own instance, inherited body (6 names) | +15..+20 | +20..+24 |
| from a method: own instance, inherited body (30 names) | +19..+29 | +18..+25 |
| another class's method, caller with 6 names | +24..+33 | +19..+32 |
| … 15 names | +38..+41 | +39..+40 |
| … 30 names | +56..+59 | +57..+73 |
| static method from a method, caller with 6 names | +19 | +16 |
| … 15 names | +28..+29 | +24..+26 |
| … 30 names | +43..+45 | +42..+44 |

The top-level rows are mostly the `localvar_unset` switch (a `shopt` pair,
paid once per outermost call); every nested method call pays the check
(+3..+10 µs); the rest is one name comparison for own-class / own-instance
calls and the caller's names for the others.

What **cannot** be isolated (plain bash, unchanged by design): a **plain shell
function** called from a body still sees and writes the body's properties, and
a callee still sees and writes the **plain `local`s** of the body that called
it (the caller's `local tmp`, a static method's own `local y`) — declare a
callee's scratch variables `local` as usual. A bare `y=…` in a callee whose
caller binds `y` stays local to the callee (it is lost on return); called
from the top level it is a global, as always. To write a **global** from a
body, say so: `declare -g y=…` (a global that a caller's property hides cannot
be READ from a callee).

A property named like an **environment variable** is such a hiding name. The
variables bash itself depends on (`PATH`, `HOME`, `TMPDIR`, `PWD`, `LANG`,
`LC_*`, `TZ`, …) are refused as member names (Reserved Member Names). Any
other exported name a property hides (`USER`, `TERM`, an application's
`MYENV`) is, inside the class's own bodies, the property; the external
commands they run see the variable's global value (the binding is
`local -n +x`); and a callee of ANOTHER class or a static method called
from them sees it UNSET — not the environment's value — so under `set -u` such
a callee stops with "unbound variable". Do not name properties after
variables the code (or a callee) reads from the environment.

<!-- doctest -->
```bash
source /path/to/kbool/kbool.sh || exit
kk.uses kklass || exit
defineClass SThin "" static_method bump 'y=fromStatic' static_method peek 'echo "static sees y=${y-UNSET} this=${this-UNSET}"'
defineClass B     "" method m 'y=fromB' method g 'declare -g y=global'
defineClass A     "" property y method go1 'SThin.bump' method go2 'b.m' method go3 'SThin.peek' method go4 'b.g'
A.new a; B.new b
a.y = orig; a.go1; a.y     # => orig
a.go2; a.y                 # => orig
a.go3                      # => static sees y=UNSET this=UNSET
echo "${y-unset}"          # => unset
a.go4; echo "$y"           # => global
a.y                        # => orig
```

Compiled `.ckk` caches hold the static method dispatchers verbatim, so the
cache format carries a version (now 3: isolating dispatchers that bind their
static properties `local -n +x`): `autoloadClasses` rebuilds an older cache by itself,
and an older cache sourced directly loads no class, says why and returns 1 from
its `source` (recompile it with `bash kklass_compiler.sh SOURCE CACHE`);
`autoloadClasses SOURCE --no-compile` runs the source instead of an older
cache. Caches written before kklass learned to register cached classes
(before October 2026: they contain no `kk._ckk_begin` line) are NOT checked when
sourced directly and still install the old, non-isolating static methods —
recompile them.

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
(see *A refused member fails its class*). An **unknown token** (the keywords
are exact: `PROPERTY` is not `property`, also under `shopt -s nocasematch`) or
a token **missing its arguments** (`method m` without a body) returns **2**
with `defineClass: unknown token 'T' in the declaration of class 'X' …` /
`… token 'T' … is missing its arguments …`, and the class is not built. An
EMPTY word between tokens is skipped (an optional argument passed as `"$x"`
while empty). The low-level `kk._build_class_runtime`
refuses the same way, also under nocasematch.

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
leaves the caller's `BASH_REMATCH` untouched. "Concrete" therefore is rc 1 — not "rc ≠ 0":

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

### kk.frameReset

For an EXIT handler: clear the method-call frames a `set -e`
exit inside a body left behind and turn `localvar_unset` back off when the
outermost method call had turned it on (see "EXIT Handlers and `set -e`").

```bash
kk.frameReset
```

Always rc 0, prints nothing. A no-op when the frame stack is empty or a body
is still live in the dynamic scope (at the top level, inside a body, in an
EXIT trap that an explicit `exit` in a body runs). A `localvar_unset` the
script turned on itself is left on. Fork-free; not on the method call path.

### Identifier checks

Every name kklass turns into a variable or function name — class, member and
instance names (`defineClass` and the other builders, `CLASS.new`), and the
arguments of `kk.isAbstract` / `kk.derivesFrom` / `loadObjects` — must be an
ASCII identifier `[A-Za-z_][A-Za-z0-9_]*`. One helper, `kk._is_ident NAME`
(rc 0/1, silent, fork-free), makes that check everywhere. It lives in kkore
(`kkore/klib.sh`, which kklass sources first; kkore's `kk._outName` and
`kc.alias` follow the same rule): the range glob plus a `*[![:ascii:]]*`
guard, and under `shopt -s nocasematch` the check runs with nocasematch
switched off and the caller's setting restored. It is exact in every locale ×
`globasciiranges` × `nocasematch` combination, never touches the locale and
never touches `BASH_REMATCH`. (A `[[ =~ ]]` check would overwrite the caller's
`BASH_REMATCH` on every `.new`, and under `shopt -s nocasematch` in a UTF-8
locale accepts the Turkish dotless `ı` / dotted `İ` — whose later indirect
expansion aborts the caller's whole command (`kk.derivesFrom ı X`,
`defineClass ı`) or produces a half-made instance (`CLASS.new ı`). A
function-local `LC_ALL=C` would be exact too, but costs ≈4.5× under a UTF-8
caller locale — `kk.derivesFrom` 70 → 213 µs.)

The reserved names (the tables in [Reserved Member Names](#reserved-member-names))
are case-sensitive, as bash names are: under `nocasematch` a property
`result`, a method `Delete` or a static method `New` is accepted, `RESULT`,
`delete` and `new` are still refused.

**`nocasematch` and names.** Under the caller's
`shopt -s nocasematch` every bash comparison folds case — a quoted right-hand
side of `[[ == ]]` too, and `case` and `${x//pat/}` — so unguarded, kklass
would answer `kk.derivesFrom Foo foo` with 0, let a class `foo` touch a
private member of `Foo` without a warning, drop a property `A` declared next
to `a`, take `PROPERTY` for `property` and rewrite a Pascal body's
`echo Inherited;`. Every public verb (all three DSLs, `defineClass` / `defineMethod` / …, the
serializable and autoload verbs, `kk.derivesFrom`, `kk.isAbstract`,
`kk.class`, a compiled cache's class check) and the runtime check of a
non-public access start with an entry guard: with nocasematch on they run
with it switched off and give the caller's setting back. Class, member and
token names are therefore always exact. Cost: with nocasematch OFF there is
none worth measuring — one `[[ ]]` / `case` probe per verb (≈1–2 µs on MSYS,
inside the noise of a declaration; `kk.derivesFrom` ≈60 → ≈61 µs), and method
and property calls carry no guard at all (they compare no names). With
nocasematch ON, every call that touches a private or protected member re-runs
the visibility check with nocasematch off: such calls are ≈20 % slower (bash
5.2 ≈830 → ≈1000 µs, 5.3 ≈720 → ≈870 µs); public members and `.new` are
unaffected. `uses` is `kk.uses`, which has its own guard.

`CLASS.new` itself carries an inline copy of the rule (the hottest path: a
function call plus two locale switches would cost ~18 µs per `.new` on
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
when sourcing the input fails, when no class was built, or when any class of
the input refused a member — the error names each such
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
source /path/to/kbool/kbool.sh
kk.uses kklass
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
source /path/to/kbool/kbool.sh
kk.uses kklass_serializable   # Required! (it loads kklass too)
```

### Debugging Tips

#### Enable Bash Debugging

```bash
#!/usr/bin/env bash
set -x  # Enable debug output
source /path/to/kbool/kbool.sh
kk.uses kklass
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
#!/usr/bin/env bash
source /path/to/kbool/kbool.sh
kk.uses kklass

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
- Verify Bash version: `bash --version` (need 5.1 or later)

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

## Internals

Implementation notes for readers who want to know how kklass does what the
chapters above promise. Nothing here is needed to use kklass.

### Fork-free class building

Building a class runs no `$( )`. The string helpers of the builders return
through a variable, and the one real capture, `declare -f`, goes through
`kk._fn_text`: the shell keeps two READ descriptors on a scratch file that
is deleted right after it is created; a capture appends a random marker, the
`declare -f` text and the marker again (the write side is opened through
`/proc/PID/fd` or `/dev/fd` for one `build` at most) and reads exactly that
back — anything else (descriptors the caller reopened, data a process added)
makes that capture a plain `$( )`. It reads back with `read -N` (block reads —
`read -d ''` reads one byte per `read()` on msys; a text over 16 M characters
is captured with `$( )` instead), the `inherited` rewrites skip the parent
walk for a body without `inherited`, and a valid, unreserved name passes the
name checks at once.

What that saves: with forks, every Pascal method cost four `$( )` subshells
(the body extraction, its inner `declare -f`, the bare-`inherited` rewrite,
the `inherited` → `$this.parent` rewrite of `implement`), every accessor
property two, every class one. On msys/cygwin a fork costs 12–30 ms, so a
fresh `kk.uses dateutils` (one class, 185 methods) took ~10.5 s, ~86 % of it
in forks. Without them, per class (2 fields, 2 accessor properties, a
constructor, 5 methods): Pascal 486 → 17.0 ms, declarative 181 → 9.9 ms,
`defineClass` 122 → 8.4 ms on bash 5.2 (14.6 / 8.2 / 6.9 ms on 5.3), msys; a fresh `kk.uses dateutils` ≈0.36 s, math ≈0.23 s,
thttpapplication ≈0.34 s on both bashes.

The setup — one `rm`, the system one by absolute path — is paid once per shell
(a subshell that builds a class opens its own pair), and again after ~256 KB of
captured text. Where the descriptor directory is `/dev/fd` and not
`/proc/PID/fd` (FreeBSD's pkg bash emulates `/dev/fd`), the fast capture is
switched off before it creates anything and classes build through `$( )`.
What it does and does not guarantee:

- The name is `kbool_fntext.PID.<SRANDOM>.<SRANDOM>` (never your `$RANDOM`
  stream); a name where anything exists is skipped, the created descriptor
  must be a regular file. noclobber alone refuses only an existing *regular*
  file, hence those checks; a planted FIFO or device is never opened. A
  `.u` probe next to it holds nothing but your umask (bash cannot read the
  umask without a fork) and goes with the same `rm`.
- The file is removed at once. If the `rm` fails (an ACL, a lock) that ONE
  file stays, kklass says so on stderr (`kk.warn`) and the shell builds with
  `$( )` from then on; three out-of-step captures or 16 setups in one shell
  switch the fast path off too.
- Processes started by the shell inherit the two read descriptors of the
  deleted file, never a write descriptor kept open after a `build`. The trust
  boundary is the USER: a child running as the same user could change your
  scripts anyway — it can reopen the file and add data, but the per-capture
  marker (it must occur exactly twice, nothing after it) makes the parent
  notice and fall back, so it cannot make the parent read a forged function
  text; it can read the function texts captured after it started. A child
  running as ANOTHER user (`runuser`, `setpriv` keep descriptors) cannot open
  the file for writing: it is created mode 0600 (`umask 077`, your umask is
  restored right after). On MSYS/Cygwin `noacl` mounts (the default) the
  POSIX mode is not stored; the file carries the Windows ACL of `$TMPDIR` —
  keep `TMPDIR` private (the per-user `%TEMP%` is). A child keeps the (small,
  capped) file allocated until it exits.
- Opening the pair is not free of the caller's descriptor table: it takes
  three numbers ≥ 10 for a moment and keeps two; a caller that reopens them
  (`exec 12>file`) is detected before every capture and is never written to
  or read from — the pair is simply forgotten.

---

**Happy Bash OOP Programming!** 🎉

---

*Document Version: 1.1*  
*Last Updated: 2026-07-09*  
*For Kklass System v1.0+*
