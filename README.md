# kklass — classes for bash

> Part of [kbool](https://github.com/Keksov/kbool): installation, quick start and the other components are there.

kklass is an object-oriented programming system for Bash. It gives shell
scripts classes and objects: properties and methods, single inheritance, dot
notation such as `object.method` and `object.property`, static members,
computed properties, compiled classes for faster execution, and serialization
of object state. A Pascal-flavoured `class ... end` syntax with real function
bodies is part of it.

Requires bash 5.1 or later. kklass is one folder of the kbool tree and is not
installed on its own: clone kbool
(`git clone --recurse-submodules https://github.com/Keksov/kbool.git`), source
`kbool.sh`, then load the unit with `kk.uses kklass`.

## A first class

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

Output, run on Git-bash 5.3.15 and on MSYS2 bash 5.3.9:

```
Hello, World!
```

## Where to go next

* [docs/kklass_book.md](docs/kklass_book.md) — the full guide: classes,
  inheritance, the Pascal DSL, compilation and autoloading, units, serialization.
* [examples/README.md](examples/README.md) — 48 runnable examples and a demo
  runner.
* [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md),
  [LICENSE](LICENSE).

## Running the tests

The tests need the whole kbool tree. From the root of a kbool checkout:

```bash
bash ktests/tools/gate.sh kklass
```

Every kcl unit is built on kklass, so a kklass change is checked with every
suite: `bash ktests/tools/gate.sh all`. The details are in
[CONTRIBUTING.md](CONTRIBUTING.md).
