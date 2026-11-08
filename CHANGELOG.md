# Changelog — kklass

kklass is the object system of kbool: classes, instances with dot notation,
inheritance, properties, static members, serialization and a Pascal-style
syntax, all in bash. This file groups the whole
history by phase, newest first. The user guide is
[docs/kklass_book.md](docs/kklass_book.md). Commit hashes in parentheses point
at the change for readers who want the diff.

## 0.1.1 — 2026-11-08

### Faster method calls (2026-11-08, round K)

* **A method call is about 1.8 times faster and `inherited` about 2.2 times**, on
  every platform CI covers. Time relative to 0.1.0, measured on 11 rows (Linux
  bash 5.1 to 5.3, macOS, Git-bash, MSYS2, Cygwin): a call with one field
  0.56–0.60, a class with 14 fields 0.46–0.51, a long body 0.33–0.50, `inherited`
  0.44–0.48, a nested call 0.53–0.58; property reads and `new`/`delete` are
  unchanged. A call takes 61 µs instead of 103 on Debian (bash 5.2) and 105 µs
  instead of 183 on Git-bash.
* How: method and constructor bodies are real functions defined once, when the
  class is built (`__kkm.OWNER.METHOD`, `__kkc.CLASS`), instead of texts run by
  `eval` on every call; all fields are bound by one `local -n` from a per-class
  template; one dispatcher runs between the wrapper and the body instead of
  three functions; `inherited` reads the frame arrays directly (2c3cdfb, cc05eb4,
  04bb9e6, 870b92a, 16c5f44, 4bb2f9c).
* **What code can notice:**
  * Inside a body `FUNCNAME[0]` is the body function `__kkm.OWNER.METHOD` and
    `FUNCNAME[1]` the dispatcher (`kk._exec`, `kk._parent` or `kk._invoke`);
    code that walks `FUNCNAME` or `caller` sees different frames.
  * A body is parsed when the class is built, not when it first runs: the
    aliases and the `extglob` setting in effect at build time apply to it. A body
    that does not parse falls back to the old `eval` on every call.
  * Under `set -T` a RETURN trap fires 3 times per call instead of 5; under
    `set -E` an ERR trap fires a different number of times on a call of a missing
    method and on `return N`.
  * `__kkm` and `__kkc` are reserved namespaces.
  * The compiled-cache format is 6: older caches are rebuilt.
* **Fixed:** after `inherited X` a body saw its class name in `RESULT`; it now
  keeps the value it had. `return N` from a body could give the wrong status
  when `IFS` contained digits.

### Maintenance (2026-11-01)

* `autoload` and `kkp` declare and assign separately, so the core passes the
  strict checks of kbool's CI ShellCheck guard (7691162).

## 0.1.0 — 2026-11-01

### Control bytes in method bodies on MSYS2 and Git-bash (2026-10-31, launch L7.2)

* **A `$'\r'` in a Pascal-DSL method body is a carriage return again** on MSYS2 and
  Git-bash. Their bash drops every raw CR when it parses text, and `declare -f`
  prints `$'\r'` as a raw CR, so every path that rebuilds a function from its text
  (the Pascal DSL `build`, static method registration, namespace snapshots, compiled
  caches) turned it into an empty string — `[[ $x == *$'\r'* ]]` then matched every
  string. Such texts are now rewritten with `$'\r'` words before they are parsed
  again; Linux, macOS and BSD are untouched. Test 149 pins all control bytes on
  every path. The compiled-cache format is 4: older caches are rebuilt.

### Launch: CI and the bash 5.1 floor (2026-10-27 .. 2026-10-30, launch L3.5, L4.5, L5.4, L5.6, L5.7)

* **Minimum bash is 5.1**: unquoted file-descriptor targets in the function-text
  capture (`kk._fn_text`, `_open`) no longer break 5.1; the book states the floor
  and a static check (test 148) keeps 5.1 hazards out (498bdd5, bd45591).
* **FreeBSD and busybox**: the function-text capture is turned off where the
  descriptor directory is `/dev/fd`; class sites ignore a sourced FIFO
  process-substitution pseudo file (`sh-np.*`) (b245f66, 0626d32).
* **macOS**: sourcing through a FIFO survives `Interrupted system call`; the
  writer retries its own open, the reader re-sources while its writer lives, and
  a read-write-open watchdog bounds every wait, so a block is a test failure and
  not a hang (test 139).
* Test 140 takes the best of up to three timing runs on slow CI runners and
  compares against an A-B-A baseline.
* Tests call `"$KT_TIMEOUT"` and SKIP when neither `timeout` nor `gtimeout` exists.
* CI workflow that runs the 13-row kbool matrix with this commit as kklass
  (a8e74b6); `CONTRIBUTING.md` (bd45591).

### Linux first: line endings, shebangs, locales (2026-10-20 .. 2026-10-22, launch L0, L2)

* All text files are LF; every script starts with `#!/usr/bin/env bash` and has its
  exec bit (a0421b4, c79f61c).
* Comma-locale-safe `EPOCHREALTIME` in the bench and test 120.
* Tests 027, 032 and 033 no longer inherit a caller's `KKLASS_CKK_DIR`.
* Internal plans, ledgers and notes moved to `docs/dev/` (0cace33); the book links
  the unit header shapes in the kbool reference.

### Rounds 5 and 6 (2026-10-16 .. 2026-10-19)

* **Class building forks nothing** (P14): a unit with many classes loads 17 to 32
  times faster (for example `dateutils` 10.8 s to 0.42 s, `math` 7.9 s to 0.25 s); a
  Pascal-DSL class costs about 16 ms to build instead of about 486 ms.
* **Scope isolation** (P15): a method body no longer sees or clobbers the
  properties of its caller; a callee's `unset NAME` can no longer reveal or destroy the caller's
  variable. The cost is about 1.4 microseconds per caller property name (stated
  in the book).
* A `nocasematch` guard and strict token checking at declaration time; a class
  named like a live instance is refused; the `KKLASS_EXPORT_FUNCTIONS` mode was
  **removed** (**Breaking** for scripts that set it).
* Export-safe property binding, more reserved names, `frameReset` and `set -u`
  safety (P16); a cheaper class build (P17); the compiler's temp directory is named,
  cleaned on signals and swept for dead pids.
* All 49 examples run via `kbool.sh` and `kk.uses`.

### Units and `uses` (2026-10-05 .. 2026-10-15, uses U2-U5)

* The design is [docs/dev/USES_PLAN.md](docs/dev/USES_PLAN.md): a Pascal-like
  `uses` directive for kbool, with its decisions and reasons.
* Declaration sites are recorded, a second declaration of a name reports
  `Duplicate identifier` and a re-sourced file is a clean replacement, not a
  collision (ba9c51d).
* Taken names, `.ckk` cache registration, `uses` as a synonym in declarative files
  and `.kkp` `unit`/`uses` (8011ca5); kklass modules are themselves units (1ba0ea5).
* A new book chapter "Units and uses"; examples load through `kbool.sh`.

### Round 4 (2026-10-05)

* An instance property and a static property of one name are refused at
  declaration time (the static used to shadow the instance silently).
* The compiler no longer prints a stray `source: filename argument required`, no
  longer dumps kkore's `kv` as a class, and recompiles a cache when
  `kklass_compiler.sh` or `kklass.sh` is newer.
* One shared, locale-exact identifier check (moved to kkore) with no locale
  switch: under a UTF-8 locale `kk.derivesFrom` went from 217 to 64 microseconds.

### Round 3 (2026-10-02)

* Serialization: one generator per format, separator validation, and a defined
  `loadObjects` / `fromX` contract.
* **Breaking** for saved data and serializer callers: `defineSerializableClass`
  writes the full property list (inherited first, lazy and computed included), so
  strings saved for a class with a parent or a lazy property must be re-saved;
  `saveObjects` prefers `toJSON`; a direct `fromJSON` call sets `RESULT` to the
  instance name instead of printing it; `fromString` refuses input that does not
  start with the class prefix (round 2 already made `fromJSON` refuse a foreign
  `__class__`).
* **A refused member fails its class**: a bad member in an open class poisons it,
  `endClass` / `endImplementation` / Pascal `build` answer rc 1 naming class and
  member, and a refused redefinition keeps the old class intact.
* Reserved static names (`new`, `constructor`, `__static_*`, ...) and a method and
  property of one name are refused on every declaration path; constructor and
  destructor names are validated before any `eval`; a locale-exact identifier
  guard replaces the `=~` check, which aborted under `nocasematch`.

### Round 2 (2026-10-01 .. 2026-10-02)

* **Serializable**: JSON escaping fixed and a string-aware `fromJSON` scanner (R2_P7).
* **The `$this.NAME` text rewrite is removed** (R2_P8). `$this.Method` is now the
  instance wrapper, virtual as of `.new`; an empty method body is a silent
  success; the names `call delete property parent new` are refused as instance
  members. **Breaking** for code that relied on the old prefix rewrite. Internal
  calls are about 11 percent faster.
* Public `kk.isAbstract` and `kk.derivesFrom`; the bash 5.2 nameref traps are
  documented (R2_P9).

### Review and performance round (2026-09-05 .. 2026-09-08)

* A review closed 12 findings. Class templates share one runtime; measured
  against the starting point: `.new` 4.8 times faster, a method call 1.9 times,
  a property read 2.9 times, a computed property read 25 times; `.delete` went
  from 0.4-1.5 s with 1000 live instances to about 0.2 ms.
* Value fidelity (values that look like `echo` options, newlines, backslashes
  round-trip), the `set -u` contract for a stored property read, the builder's
  locals (kcl review P0, P4).
* A computed property keeps its getter's exit status (kcl review P6).
* The book and `docs/dev/OPTIMIZATION.md` describe the runtime as it behaves.

### Pascal DSL and class safety (2026-07-08 .. 2026-07-12)

* Pascal front-end with real function bodies: `class ... end` blocks with methods,
  properties, constructors and `inherited`.
* A class name already defined in a **different** file is refused (the error names
  the owner file); re-sourcing the same file is allowed.
* Hardening and speed-up of the runtime; JSON escaping and a visibility example
  fixed; `kklass_book.md` corrected and extended with access control and method
  modifiers.

### Pascal-style API, static members and early design (2025-10-30 .. 2026-06-01)

* First version: `defineClass`, properties with change detection, methods,
  inheritance with parent constructor calls, `kk.result` / `kk.var` helpers,
  `defineProcedure` / `defineFunction`, dynamic method definition.
* `kk._return` detects subshells and prints only there; methods may call each
  other in constructor bodies.
* The Pascal-style `declare` / `implement` API and `.kkp` unit files (2026-05-24);
  static methods and properties with conditional exporting; `kk.call_silent`;
  identifier validation and faster method resolution.
* The tests were split into one file per case, got verbosity, range selection and a
  parallel worker pool, then moved onto the ktests framework.
* Function prefixes and library dependencies were reorganised several times during
  the first month before the current `kk.*` naming settled.
