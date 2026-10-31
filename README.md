# kklass — classes for bash

> Part of [kbool](https://github.com/Keksov/kbool): installation, quick start and the other components are there.

kklass is an object-oriented programming system for Bash. It gives shell
scripts classes and objects: properties and methods, single inheritance, dot
notation such as `object.method` and `object.property`, static members,
computed properties, compiled caches that load faster, and serialization
of object state. A Pascal-flavoured `class ... end` syntax with real function
bodies is part of it.

Requires bash 5.1 or later. kklass is one folder of the kbool tree and is not
installed on its own: clone kbool
(`git clone --recurse-submodules https://github.com/Keksov/kbool.git`), source
`kbool.sh`, then load the unit with `kk.uses kklass`.

## A first class

A class in the Pascal DSL: the structure first, the bodies as plain bash
functions, then `build`:

```bash
source /path/to/kbool/kbool.sh || exit
kk.uses kklass_pascal || exit         # the Pascal DSL; it loads the kklass core itself

class TCounter
    public
        var         Name
        var         Count
        constructor Create
        proc        Add
        func        Report
end

TCounter.Create() { Name="$1"; Count=0; }
TCounter.Add()    { Count=$(( Count + ${1:-1} )); }
TCounter.Report() { RESULT="$Name: $Count"; }
build TCounter

TCounter.new basket apples
basket.Add
basket.Add 2
basket.Report; echo "$RESULT"         # => apples: 3
basket.Count                          # => 3
basket.Count = 10
echo "$(basket.Report)"               # => apples: 10
basket.delete
```

Its output:

```
apples: 3
3
apples: 10
```

A `func` answers in `$RESULT` and prints only inside `$( )`; reading a property
(`basket.Count`) prints it; inside a body the fields are plain variables
(`Name`, `Count`).

The same kind of class can also be written in one call, with the bodies as
strings:

```bash
kk.uses kklass || exit
defineClass Greeter "" property name method greet 'echo "Hello, $name!"'
Greeter.new greeter
greeter.name = "World"
greeter.greet            # => Hello, World!
greeter.delete
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
