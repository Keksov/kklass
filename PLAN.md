# kklass — fix & optimization plan

**Created:** 2026-09-05 (from the 2026-09-05 review; all findings reproduced on this machine).
**Ledger:** `kklass/kklass_ledger.json` (single source of truth for status).
**Workflow:** phase → kklass suite (232 + new) → kcl suites that use kklass → bench vs baseline → STOP → owner "go"; commits gated.
**Baseline (P0, 2026-09-05):** 232 legacy assertions green on bash 5.2.37 (MSYS2) AND 5.3.9 (cygwin, `C:/bin/msys64/usr/bin/bash.exe`); new tests 120–126 RED by design (27 / 26 assertions).
`bench/kklass_bench.sh` (3 props incl. one computed + 10 methods), 5.2 / 5.3:
`.new` 0.79 / 0.37 ms · method call 0.38 / 0.33 ms · property read 0.12 / 0.11 ms · **computed read 16 / 16 ms @50 live, 39 / 29 ms @1000 live** · **`.delete` 17 / 16 ms @50 live, 1.8 / 1.7 s @1000 live** · template 6970 bytes · 1000 instances = 24 087 shell functions. Full numbers in the ledger.
**Running on 5.3:** `PATH="/c/bin/msys64/usr/bin:$PATH" /c/bin/msys64/usr/bin/bash.exe tests/tests.sh` — cygwin bin must be first in PATH, otherwise the runner's child `bash` is the msys 5.2 binary, exported functions vanish and the suite reports 0 tests.

---

## 0. Owner decisions (2026-09-05)

| # | Question | Decision |
|---|---|---|
| D1 | Computed property called bare (`obj.area`) | Decided: print like a plain property. **Amended at P3 (evidence, not taste):** kcl pins the opposite — `kcl/tstopwatch/tests/004_ZeroFork.sh` asserts a direct computed read prints 0 bytes and sets RESULT, and kcl code/tests use the `obj.x >/dev/null; use $RESULT` idiom 51 times. So a computed property follows the kk._return contract: **direct call = silent + RESULT, `$(obj.prop)` prints once.** The performance half of D1 stands: `function`-kind getters run without a subshell; `method`-kind getters keep the capture path. Plain fields still print on a direct call (unchanged, documented at P5). Owner may still override. |
| D2 | Reserved member names | **Minimal list:** `this __inst__ __class__ RESULT REPLY IFS` rejected by `kk.decl._validate_ident`. Internal `_run_frame_body` locals renamed to `__kk_*` (no need to reserve them). **Amended at P1:** `state` dropped from the list — `kcl/tcustomapplication` uses the `state[...]` nameref as an API and test 066 declares a property `state` (shadowing is well-defined); both contracts are pinned by test 125. |
| D3 | Compiled mode | **Keep; compiler becomes a dumper** (`declare -p` tables + `declare -f` functions). No second generator to keep in sync. |
| D4 | P4 scope | **Two steps:** P4a shrink the instance template (behaviour-preserving), then P4b trim the call path. Rollback point between them. |

---

## 1. Confirmed findings (review 2026-09-05)

| ID | Sev | Where | Symptom |
|---|---|---|---|
| F1 | high | `kklass.sh:866` `.delete` | `unset -f $(compgen -A function inst.)` — fork + scan of ALL shell functions; O(total functions). 1000 instances → 0.4–1.5 s per delete. kcl calls `.delete` 74× outside tests (TObjectList etc.). |
| F2 | high | `kklass_decl.sh:499` via `defineClass`→`declareClass` | Refused cross-file redefinition still resets `_decl_*`, `_method_visibility`, `_class_abstract=0` → abstract class becomes instantiable. Guard comment claims "left fully intact" — false. |
| F3 | medium | `kklass.sh:1206` `_defineMethodType` | `defineMethod` cannot override an inherited method: template wrapper + `_method_cache` still point at the parent owner. Silently ignored for both `inst.m` and `inst.call m`. |
| F4 | medium | `kklass_compiler.sh:133` | Cache pre-populated with class name, not owner; `_class_method_owner`, `_lazy_inits`, `_destructor_name`, `_has_dynamic_methods` not exported. Compiled `c.call hello` on a 3-level chain runs the middle body twice. Static methods emitted with the old `mktemp`/`cat` path. Input sourced with `>/dev/null 2>&1`. |
| F5 | medium | `kklass.sh` static-method wrappers (5.2 and 5.3 paths) | 5.2 brace-group path: `return N` propagates but leaves the scratch file behind; a failing last command yields 0. 5.3 funsub path: `return N` is swallowed entirely (`S.fail` → 0). Test 124 must cover both. |
| F6 | medium | `kklass.sh:635` `_run_frame_body` | Property named `method_body` gets its VALUE eval'd as code; `this` breaks `$this.call`. No reserved-name validation. |
| F7 | **high** (was low; P0 bench) | `kklass_decl.sh:261` | Computed getter via `RESULT="$($__inst__.call G)"` — a FORK per read, and a fork copies the whole shell: 45 ms/read (5.2) / 32 ms (5.3) with 1000 live instances vs 0.12 ms for a plain property. kcl's `count` on tqueuestack/tdictionary/… is a computed property. Bare `obj.computed` prints nothing while `obj.field` prints (→ D1). |
| F8 | low | `kklass.sh:597` lazy props | `inst_lazy_<p>` global survives `.delete`. |
| F9 | low | `kklass.sh:39` guard skip-list | `kklass_serializable.sh` not skipped → all `defineSerializableClass` classes register as owned by the library file. |
| F10 | low | `kklass_serializable.sh:243` `_regenerateConstructor` | Rewrites wrappers with class name instead of owner → `inherited` in inherited methods breaks; dead `sep_escaped`. |
| F11 | low | `kk._processMethodBody` | `$this.m` rewrite only sees methods declared BEFORE the current one (harmless today, inconsistent). |
| F12 | arch | template design | Every instance carries full copies of `_invoke/_exec/_run_frame_body/_find_method/.call/.parent` — see baseline. OPTIMIZATION.md prototype never adopted. |

---

## 2. Phases

### P0 — Safety net (S) — DONE 2026-09-05
Regression tests, each RED on both bash versions until its phase lands (sanity assertions inside them are GREEN):

| Test | Findings | RED assertions now (5.2 / 5.3) | Fixed by |
|---|---|---|---|
| `120_DeleteForkFree` | F1, F8 | 2 / 2 — lazy global survives; delete cost ×34 at 13.8k functions | P1 |
| `121_GuardKeepsMetadata` | F2, F9 | 4 / 4 — abstract flag, visibility, decl tables, serializable owner | P1 |
| `122_DefineMethodOverride` | F3 | 3 / 3 — direct, `.call`, virtual from inherited body | P2 |
| `123_CompiledParity` | F4 | 2 / 2 — output differs (middle body twice), compiler silent on broken input | P3 |
| `124_StaticMethodStatus` | F5 | 3 / 2 — 5.2: scratch leak, lost stdout on `return`, `false` → 0; 5.3: `return 3` → 0, `false` → 0 | P1 |
| `125_ReservedNames` | F6, D2 | 10 / 10 — 7 property names + method `this` + DSL field + `method_body` value executed | P1 |
| `126_ComputedPropertyOutput` | F7, D1 | 3 / 3 — bare print (function + method getter), side effect lost in subshell | P2 |

- `bench/kklass_bench.sh`: template bytes, `.new`, `.delete` at 50 and 1000 live instances, method call, `.call`, property read/write, computed read at 50 and 1000 live. Baseline numbers in the ledger (`baseline.bench`).
- Gate: 232 legacy tests green on 5.2 and 5.3 with the new files present; kcl untouched.

### P1 — Runtime point fixes (M) — DONE 2026-09-05
Gate: kklass 264 green / 8 RED-by-design (122, 123, 126) on 5.2 AND 5.3; master sweep 19/20 suites (only kklass red, by design) on both; `.delete` 1.8 s → 0.2 ms at 1000 live instances, `.new` +10% (template +888 B, P4a).
- **F1** `.delete` fork-free: the per-instance function list is baked into the template at build time (`__DELETE_FUNCS__`: fixed helpers + props + methods + `.parent` when inherited + `.delete` last); `.delete` also walks `<Class>_class_methods` at run time for `defineMethod`-added wrappers, and unsets the lazy globals (`__LAZY_VARS__`, **F8**). No `compgen`, no `$(...)`.
- **F5** static methods: the body is now always a real function `<Class>.__static_<name>`; the wrapper declares the static-prop namerefs (dynamic scoping makes them visible in the body), calls it, keeps `$?`, appends a `kk._return` result, returns the status. The two dispatcher shapes STAY (first attempt unified them and broke 026 + 114): stateless classes get the thin pass-through wrapper; stateful classes keep the capturing wrapper because `REPLY` after a bare call is the return channel of a stateful static method (`$(Class.m)` would lose the state mutation — singleton `getInstance`, test 026, examples 35/36). 5.3 captures with a funsub, 5.2 with a scratch file + `rm -f` (one fork per stateful static call, as before — P4b candidate: reuse one scratch file per shell).
- **F2** guard: `kk._check_class_owner NAME [register]` shared by `declareClass` (check only, before any `_decl_*` reset) and `kk._build_class_runtime` (register). `kk._caller_source_file` now caches the canonical path per `$PWD|BASH_SOURCE` so the extra check costs no extra fork. Skip-list gains `kklass_serializable.sh`, `kklass_autoload.sh`, `kklass_compiler.sh` (**F9**).
- **F6/D2**: `_run_frame_body` locals → `__kk_frame_id`, `__kk_method_body`; reserved list (see D2, amended) in `kk.decl._validate_ident`.
- **F11**: bodies declared in the class are kept raw during the parse and rewritten once against the complete method list.
- Not done here (by design): `implement`/`implementConstructor` do not run the owner check, so an imposter file that fails `declareClass` and goes on to `implement` still overwrites the DECL body table (runtime bodies stay intact). Cost of guarding every `implement` call was judged not worth the message spam; revisit if it bites.
- Gate: 120, 121, 124, 125 green on 5.2 and 5.3 (done); full kklass suites; master sweep; bench — see ledger.

### P2 — Dynamic methods, serialization, computed output (M) — DONE 2026-09-05
Gate: kklass 272 green / 2 RED-by-design (123) on 5.2 AND 5.3; computed read 16 ms → 1.2 ms at 50 live and 42/31 ms → 1.2/1.1 ms at 1000 live (flat). **Correction:** the P2 master sweep was NOT fully green — `tstopwatch/004_ZeroFork` failed on both versions (the D1 print broke the direct-call-is-silent contract) and was missed when reading the sweep output; caught at P3, fixed by the D1 amendment. Bench rule learned: no forks between measured steps (a `$(compgen | wc)` over 24k functions made every later op ~1.7× slower on cygwin/msys; the bench now counts fork-free).
- **F3** `_defineMethodType`: re-points `_class_method_owner[m]` and `_method_cache[m]` to the class and rewrites the instance template — the exact wrapper text the build emitted (now produced by the shared `kk._method_wrapper_text`) is replaced in place, or a new wrapper is inserted before `.delete()`. Subclasses built earlier keep their copied table: a `[kk] warning` names each such subclass (found via `_KKLASS_CLASS_SOURCE` + `_parent_class`).
- **F10** `addSerializable` string/json paths register through `defineMethod`; `_regenerateConstructor` (which re-emitted every wrapper with the class as owner) and the dead `sep_escaped` are gone.
- **F7/D1** two halves. Accessor (`kk._build_class_runtime`): `local __kk_return_silent=1; if .call _get_p; then printf '%s\n' "$RESULT"; else return $?; fi` — bare call prints like a plain property, `$(obj.p)` prints exactly once (inner `kk._return` echoes are silenced), a failing getter (write-only) prints nothing and returns its status. Getter body (`kk.decl._build_property_getter_body`): if the read target is a `function` (walk of `_decl_method_kind` up the parent chain via `kk.decl._method_kind_is_function`) → `RESULT=""; $__inst__.call G` in the current shell, no fork; echo-style targets keep the `$(...)` capture.
- Lazy properties still fork once (`$(inst.init)` at first read) — left as is; P4b candidate.
- Gate: 122 + 126 green on 5.2 and 5.3 (done); full kklass suites; master sweep; bench (computed read expected to drop from ~16 ms to the method-call cost).

### P3 — Compiler parity (M, D3) — DONE 2026-09-05
Gate: kklass 273/273 on 5.2 AND 5.3 (no RED-by-design tests left); master sweep 21/21 suites, "All test suites passed", on both versions with every `[FAIL]` line checked. Also fixed here: the P2 regression in `kcl/tstopwatch/004_ZeroFork` via the D1 amendment. Bench unchanged vs P2 within noise (5.2: call 432 µs, prop 131 µs, computed 1.2 ms @50 / 1.9 ms @1000 live; 5.3: 356 / 117 / 1.1 / 1.1). Bench rule refined: it is the *enumeration* of a 24k-function table (`compgen -A function`, forked or not) that makes every later call ~1.7× slower on cygwin/msys, not a fork per se — the bench now enumerates only while small and derives the big count.
- `compile_class_file` is a dump: after sourcing the input in-process, every `<Class>_*` variable (`compgen -A variable`) goes out via `declare -p` rewritten to `-g` forms (the file is sourced from inside `autoloadClasses`, a function), and every `<Class>.*` function via `declare -f`. That covers the instance template, owner maps, pre-filled caches, method/static bodies, static state, `.new` + `__decl_new_impl` + `.constructor`, static accessors and wrappers with their `__static_` bodies, and the decl tables a later runtime subclass needs. 294 → 155 lines; the three heredoc generators are gone, so any future runtime change (P4) is compiled automatically. Caveat: an input that also CREATES instances gets their `<name>_data`/`_class` dumped too when the name starts with a class name + `_` — compile definition files only.
- Loud failure: the input's stderr passes through and a non-zero `source` status aborts the compile.
- `.ckk` location: the `$(pwd)/.ckk` default is a contract pinned by 027–033 and 063, so it stays; `KKLASS_CKK_DIR` overrides it (that is what removes the concurrent-suite race observed at P0: run one suite with a private cache dir).
- Stale `tests/.ckk/*.ckk.sh` from the old generator were deleted (gitignored; regenerated by 027).
- Gate: 027–033, 063, 115, 123 green on 5.2 (done); full suites + master + bench on both versions.

### P4a — Template shrink (L, D4 step 1, behaviour-preserving) — implemented 2026-09-05, gate pending
- Went one level further than planned: the dispatch machinery is now FRAMEWORK-level (`kk._run_frame_body`, `kk._invoke`, `kk._exec`, `kk._find_method`, `kk._call`, `kk._parent`, `kk._constructor_exec`, `kk._delete`, `kk._property`, `kk._prop_plain`, `kk._prop_computed`, `kk._prop_lazy`) — one copy per shell, not per class. Property namerefs are built at call time from the instance class's `_class_properties` / `_class_static_properties` (+ owner map) with `local -n "$p=${inst}_data[$p]"`, so no per-class generated code is needed either.
- Instance = `declare -gA inst_data`, `inst_class`, and one-line wrappers: one per property, one per method (naming the DEFINING class), plus `property`, `call`, `parent` (if inherited), `delete`. Functions per instance = members + 4 (was members + 9 with ~8 KB of bodies).
- `.delete` derives the wrapper list from the class tables at run time (covers `defineMethod` additions) — the baked `__DELETE_FUNCS__`/`__LAZY_VARS__` placeholders from P1 are gone. `.new` lost its dynamic-methods loop (the template is the single source since F3); `_has_dynamic_methods` is no longer set.
- Every runtime local is `__kk_`-prefixed and the `__kk_*` prefix is now rejected for member names (extends D2).
- Frames, visibility, `inherited`, `kk._return`, REPLY-for-statics, D1-as-amended: unchanged. Compiled mode follows automatically (P3 dumper).
- **DONE 2026-09-05.** Gate: kklass 273/273 on 5.2 AND 5.3; master 21/21 suites on both. Bench: template 8113 → 1110 B; `.new` 1058 → 206 µs (5.2, 5.1×) and 493 → 133 µs (5.3, 3.7×); 19 functions per instance (= 15 members + 4). Method call +6–9% (nameref loop replaces baked text) → P4b. Computed read at 1000 live now flat.

### P4b — Call-path trim (M, D4 step 2) — implemented 2026-09-05, gate pending
Four changes, all semantics-preserving:
- **Visibility gate.** `endImplementation` sets `<Class>_has_nonpublic` (0 = every own and inherited method/property is public). `kk._exec`, `kk._call`, `kk._parent` and the three property accessors check that one variable and skip `kk._warn_visibility` when it is 0; unset flag (class built outside the declarative path) = full check as before. This was the single biggest cost: `kk._warn_visibility` opened with `declare -p <table> &>/dev/null`, which formats the whole table on every call.
- **Frames inlined.** `kk._invoke` pushes/pops the frame on kkore's three `__KLIB_FRAME_*` arrays directly (the exact code of `kv.framePush`/`kv.framePop`) and passes the active class to `kk._run_frame_body` instead of reading it back with `kv.frameClass`: six function calls fewer per method call; `kv.frameCurrent`/`frameClass` still see the same stack (used by `kk._parent`, `kk._warn_visibility`).
- **Static-property namerefs** are only built when the class has static properties.
- **`kk._return`** tests `[[ -v __kk_return_set ]]` instead of `declare -p … &>/dev/null`.
- Not done: fusing `kk._exec` into `kk._invoke` (would save one call; the target was already met, and the body must stay in its own function so a `return` inside it still pops the frame).
- First 5.2 bench after the edits: method call 457 → 219 µs, `inst.call` 495 → 255, property read 116 → 49, write 108 → 28, computed read 1342 → 639 (@50 live) / 1368 → 680 (@1000). Tests 007/018/019/049/061/062 green.
- **DONE 2026-09-05.** Gate: kklass 273/273 on 5.2 AND 5.3; master 21/21 on both. Bench (5.2 / 5.3): method call 206 / 180 µs, `inst.call` 232 / 202, property read 41 / 37, write 27 / 25, computed read 654 / 571 µs flat vs instance count, `.new` 188 / 152, `.delete` 0.19 / 0.2 ms. Against the P0 baseline: `.new` 4.8×, method call 1.9×, property read 2.9×, `.delete` ~9500×, computed read 25×.

### P5 — Docs & cleanup (S) — implemented 2026-09-05, gate pending
- `docs/kklass_book.md`: System Requirements corrected (what forks, what does not, which utilities); Deleting Instances now states the exact `.delete` semantics (destructor, data/class/lazy vars, wrapper list from class tables, cost independent of shell size, double-free behaviour); Static Properties and Methods gained the return-channel contract (stdout, exit status, `REPLY` for stateful classes and why `$(...)` cannot be used); Computed Properties gained the output table (direct call silent + `RESULT`, `$()` prints once) and the getter-kind cost note; three new sections before the Pascal DSL chapter: **defineMethod** (with both limitations), **Reserved Member Names** (D2 as amended, `state` explicitly allowed), **kk.call_silent**; Compilation: "Why Compile?" rewritten as the honest dump description, `KKLASS_CKK_DIR` and loud failures listed under autoload features; the Singleton example was actually broken (`$(...)` lost the static state) and now uses the `REPLY` channel — verified by running it.
- `OPTIMIZATION.md` rewritten: former architecture, what P4a/P4b did, the before/after table, the two bench rules (no forks in hot paths; never enumerate a big function table), `experimental/` marked as history (idea adopted; folder kept, deletable in a separate commit — not deleted here, owner's call).
- Dead code removed from `kklass.sh`: the `kk._var` comment block; the property-peek `keyword_str` in `kk._build_class_runtime` now includes `static_method` like the one in `defineClass`.
- Verified by running: the rewritten Singleton and defineMethod book examples, `kk.call_silent`, examples 35/36 (REPLY users), all 49 `examples/*.sh`. One pre-existing example bug found and fixed on the way: `10_method_parameters.sh` fed decimals to `$(( ))` (bash arithmetic is integer-only) and printed syntax errors; it now demonstrates negative integers and says so.
- **DONE 2026-09-05.** Gate: kklass 273/273 on 5.2; master 21/21 on both versions; bench unchanged vs P4b. The standalone 5.3 kklass run in the chain showed two transient failures (028, 029 — autoload freshness check, 1-second mtime granularity right after the 5.2 run wrote the same `tests/.ckk` files); both passed on four immediate re-runs and in the master sweep. Not a runtime regression. **Fixed 2026-09-05 (follow-up):** 028 and 029 are now hermetic — private fixture and cache dir per run via `KKLASS_CKK_DIR` under the ktests temp dir, rebuilt on every run, mtime ordering pinned with `touch -d` instead of `sleep 1` and whatever an earlier run (or the other bash) left in `tests/.ckk`. On the way: the 029 fixture had no line continuations, so it never compiled and the test passed through the "Compilation failed" path; it now asserts a real recompile ("Source file is newer" + "Compilation successful" + compiled not older than source). A runner-wide `KKLASS_CKK_DIR` was rejected: 027 and 030–033 pin the `$(pwd)/.ckk` contract.

### P6 — changes made for kcl review P0 (2026-09-06)
Not a kklass phase of this plan: these edits were requested by **kcl's** review plan
(`kcl/PLAN.md` P0, `kcl/kcl_ledger.json`, findings G1-13 / G2-03 / G1-14 / G8-01 / G8-04
and decisions D1 / D6 / D7 / R15). Recorded here so a later kklass session knows where
they came from. They also touch kkore and ktests, which kklass loads.
- **`kk._return`: `echo -n "$v"` → `printf '%s' "$v"`** (G1-13/G2-03). Values that bash's
  `echo` parses as options (`-e`, `-n`, `-E`, `-en`, `-neE`, `-nEe`) were silently lost
  under `$( )` by every `func` and every `function`-kind computed property, while the
  direct-call `RESULT` path was correct — so the whole corpus stayed green. Test
  `tests/127_ReturnValueFidelity.sh` (24 assertions; 6 red before the fix).
- **`set -u` contract** (G1-14 + G8-01, kcl decision D7 — a kcl unit must be sourceable
  from a script running `set -eu`). `${!var:-}` on every indirect metadata read (~36 sites
  in `kklass.sh`, `kklass_pascal.sh`, `kklass_decl.sh`, `kklass_serializable.sh`), plus
  `${meth_index[$2]:-}` in `defineClass`, `${6:-}` in `kk._prop_computed`/`kk._prop_plain`
  and `${2:-}` in `class()`; re-source guards read `${_X_SOURCED:-}` in `kklass_pascal.sh`,
  `kklass_decl.sh`, `kklass_kkp.sh`. Same fix in **kkore** (`klib/kerr/kvar/kcfg/kuse`,
  including `kerr.sh`'s re-source branch, which read a bare `$1` — that one bites for real:
  `kklass.sh` loads kkore, and `tlist.sh`/`tdictionary.sh`/`tstopwatch.sh` then source
  `kerr.sh` again, taking that branch) and in **ktests** (all five files, plus
  `${KTESTS_LIB_DIR:-}` and `${KK_OUTPUT_COUNTS:-}`). Test `tests/128_SetUContract.sh`
  (31 assertions: every entry point sourced once AND twice, the kklass→unit re-source
  shape, both class DSLs, full instance lifecycle, rc-booleans under `set -eu`).
- **Builder namespace** (G8-04): `local m p sm sp wm` in `kk._build_class_runtime`,
  `local wm` in `kk._processMethodBody`, `local m` in `_defineMethodType`. Every
  `defineClass` used to clobber the caller's one-letter variables, and kcl units define
  their classes at source time. Test `tests/129_BuilderNamespace.sh`.
- **Tests 030/031/063/065 made hermetic** (kcl R15): private fixture dir plus
  `KKLASS_CKK_DIR` under the ktests temp dir, so no test writes `.ckk` into `$PWD` any
  more — a sweep started from a kcl unit directory used to leave a stray `<unit>/.ckk`
  behind (four of them were in the tree). This revises the P5 note above ("a runner-wide
  `KKLASS_CKK_DIR` was rejected"): the pin is **per test**, not runner-wide, and 027/032/033
  still exercise the default `$(pwd)/.ckk` contract (they `cd` into `kklass/tests` first).
  Their weak asserts went too: 030 accepted "Force **or** Compiling" and 031 "runtime **or**
  No compiled", both of which also pass on the failure path.
- **kkore gained `kk.isInt` / `kk.isNum` / `kk._setOut`** (kcl D1) — shared numeric guards,
  fork-free, silent, never expanding their argument. Not used by kklass itself.
- **ktests pins `LC_ALL=LANG=C.UTF-8`** (kcl D6) in `ktest.sh`, so the whole corpus runs
  under UTF-8 instead of the C locale. Test `ktests/tests/030_LocaleContract.sh`.
- **DONE 2026-09-06.** Gate: kklass 335/335, kkore 334/334, ktests 308/308, master sweep
  20 suites / 3238 tests / 0 FAIL — all on bash 5.2.37 AND 5.3.9, run sequentially, every
  `[FAIL]` line grepped (0). Bench not re-run: no runtime path
  changed except `kk._return` (printf where echo was, same cost) and nothing was added to a
  hot path. The old 028/029 5.3 timing flake did not recur.

---

## 3. Gates (every phase)

1. `bash kklass/tests/tests.sh` — 232 + new, 0 failures.
2. kcl suites using kklass: tlist, tobjectlist, tstringlist, tdictionary, tqueuestack, tstopwatch, tregex, tarray, tinifile, tcustomapplication, thashset (when landed).
3. `bench/kklass_bench.sh` — no metric slower than the previous phase; P1 and P4 must hit their targets.
4. Every phase also on bash 5.3.9 (recipe above); P4a/P4b are not done until both versions are green.

## 4. Order & sizes

P0 (S) → P1 (M) → P2 (M) → P3 (M) → P4a (L) → P4b (M) → P5 (S). P1–P3 are independent of P4 and can ship as their own commit(s).

---

# Round 2 — findings from the kcl ports (2026-09-30, critic-hardened 2026-10-01)

**Status: COMPLETE 2026-10-02 — ktests P0, P7, P8 committed; P9 done, commit pending review.**
(Was: PLANNED, critic-hardened (C1–C14 folded), DR1 amendment DECIDED 2026-10-01
(remove + the point fixes).) Four findings from the kcl work, each reproduced; a critic pass
(2026-10-01) built the K1 equivalence matrix itself, exposed four wrapper-vs-`.call`
divergences, showed `fromJSON` is broken before any escaping question, and proved the
rewrite-removed tree green (kklass 344/344 both bashes; full kbool sweep 29/29,
identical per-suite totals, sum 7794). Same workflow as round 1; the ktests finding
(`ktests/PLAN.md`) goes FIRST so later green gates are trustworthy.
Order: **ktests P0 → P7 (JSON) → P8 ($this) → P9 (isAbstract + docs)**.

## R2.1 Findings (as measured — supervisor 2026-09-30 + critic 2026-10-01)

| ID | Sev | Where | Symptom |
|---|---|---|---|
| K1 | high | `kklass.sh:141-146` (methods), `:871-876` (constructors) | The `$this.NAME` → `$__inst__.call NAME` rewrite is a blind **prefix** text substitution: it rewrites occurrences inside quoted strings (measured: `local s="$this.Home"` → `q.call Home`; broke thttpserver's demo_oop), and with a method `count` it also mangles `$this.counter` / `$this.HomeDir` (C8 — `Error: Method 'counter' not found`). The unrewritten wrapper call dispatches virtually too, **but not identically**: the wrapper is `kk._exec` with the owner baked at `.new` and no cache lookup, `.call` is `kk._call` through the cache. Divergences (C2, measured both bashes): (a) `defineMethod` on an existing class — `.call` sees the new/overridden body, the wrapper of a pre-existing instance does not; (b) a method added after `.new` — `.call` works, the wrapper is rc 127; (c) an **empty body** — `.call` silent rc 0, the wrapper rc 1 + error (`kk._exec` tests emptiness instead of set-ness); (d) a user method named `call`/`delete`/`property`/`parent` — the rewrite routes to the user method, the wrapper to the built-in (`$this.delete` then destroys the instance). Equivalent (measured): visibility warnings, frame class, `inherited`, leak-free. Perf: the wrapper is 12–15 % faster than `.call` (5.2: 182–191 vs 210–216 µs; 5.3: 148–155 vs 177–180 µs). |
| K2 | low (docs) | bash 5.2.37 + kklass vars | A kklass `var` is a nameref onto an assoc element. On 5.2.37 `${#v}` = 0 (5.3.9 correct); on **both** bashes `[[ -v v ]]` is false even when set and `${#v[@]}` = 0; `unset v` inside a member deletes the instance's storage element. `${v:1:2}`, `${v%x}`, `@Q`, `^^`, `+=`, `printf -v`, `read` all work. Docs trap (C12). |
| K3 | medium | `kklass_serializable.sh` | `toJSON` embeds values unescaped (a quote, backslash or newline makes `JSON.parse` reject the output). **And `fromJSON` is broken independently** (C3): it splits on `,` (`kklass_serializable.sh:171-176`), so valid JSON with a comma in a value already loses data; whitespace-formatted input yields empty values; a `__class__` mismatch loads silently; a naive global unescape is wrong in either order (the escaped `C:\new` becomes `C:` + LF + `ew` one way, `C:\` + LF + `ew` the other). |
| K4 | low | no public abstract check | thttpserver reads `${CLASS}_class_abstract` directly — in `thttprouter.sh`, **`thttpapplication.sh:143` and `tests/001_Request.sh:501`** (C10) — and all three repos use the underscore-internal `kk._class_derives_from`. Flag semantics are subtle: unset for a raw-built class (instantiable) AND for a never-declared name; 0 for a declared-but-unfinalized class that `.new` refuses. |

## R2.2 Decisions

| # | Decision |
|---|---|
| DR1 | (2026-09-30) remove the rewrite if the matrix is clean. **The matrix found the four divergences above; owner 2026-10-01 (quiz): amendment ACCEPTED —** **remove the rewrite anyway** + the point fixes — (c) `kk._exec` tests set-ness, not emptiness; (d) the member-name validators reject `call delete property parent new`; (a)/(b) documented as the `defineMethod` limitation (instances made before a `defineMethod` see it via `.call` only) in kklass_book §Dispatch Semantics ("`$this.Method` is virtual **as of `.new`**"). The removal is measured green (suite + sweep + examples) and 12–15 % faster; it also kills the C8 prefix bug outright. Alternative: command-position-only rewrite with an end-of-name anchor (next char outside `[A-Za-z0-9_]`), keeping the double dispatch path. |
| DR2 | (2026-09-30) full JSON-spec escaping, widened by C3: P7 also **replaces the `fromJSON` parser** with a string-aware scanner (P7 below). Control chars = U+0001–U+001F (`\n \r \t \b \f` named, the rest `\u00XX`); DEL/C1 untouched; multibyte stays raw UTF-8; NUL impossible in a bash string (documented). |
| DR3 | (2026-09-30) `kk.isAbstract` in kklass.sh, semantics pinned by C10: identifier check else rc 2; `${1}_class_methods` must exist (a **built** class) else rc 2; then rc 0 iff the flag is 1. Silent, fork-free (`${!v}` on a non-identifier name is NOT silent — it aborts the caller's command — hence the regex guard first). Plus a public **`kk.derivesFrom`** alias for `kk._class_derives_from`. All three thttpserver readers switched, rc other than 0 treated as refusal by the router. |

## R2.3 Phases

| phase | content | gate |
|---|---|---|
| **P7** | K3 per DR2: a runtime fork-free escape helper (fast-path glob guard for quote/backslash/control bytes — measured locale-safe in C, C.UTF-8, en_US.UTF-8; helper added to the module's `export -f` list) called from the generated `toJSON` body; a new left-to-right `fromJSON` scanner (whitespace tolerant; JSON strings with escapes; bare tokens; one-pass unescape of the eight named escapes plus `\uXXXX`; `\u0000` rc 1; BMP `\uXXXX` decoded to UTF-8 via printf, surrogate pairs measured first — combine or rc 1; `__class__` mismatch rc 1 + debug, a documented change); `__kk_`-prefixed locals (test 049 pins no shadowing); red-first: comma value, backslash-sequence value, a nested `toJSON` string stored in a property and round-tripped, whitespace-formatted input, `\u0000`, mismatch; `saveObjects`/`loadObjects` stay one line per object; a toJSON bench row. **DONE 2026-10-02 (worker; commit pending review):** kk._jsonInit/_jsonEscape/_jsonObject/_jsonParse/_jsonString; toJSON = one glob over `${state[*]}` + printf from the store, slow path kk._jsonObject; fromJSON = member ERE fast path + scanner, atomic, `__class__` must name the instance's class or the serializer's class; test 131 (108, red 65 on both bashes); kklass 452/452 threaded 5.2 + 5.3 and single 5.2; examples 41–43 green (43: nested JSON now escaped). **Bench flagged:** toJSON clean +14–15 % (+26/+33 µs = the measured floor of one expansion + one glob per call), fromJSON −33 %; details, measurements and 3 `found_in_R2_P7` items in the ledger | kklass suite green both bashes, master sweep 0 [FAIL] both |
| **P8** | K1 per DR1-as-amended: FIRST the matrix as red-first tests — quoted-string preservation, the C8 prefix cases, (a)–(d) each pinned to its decided behaviour; the (c)/(d) point fixes; then remove both rewrite loops; kklass_book §Dispatch Semantics rewrite; bench gains a row "internal `$this.m` call" (gate: not slower; expect 12–15 % faster); sweep must keep per-suite totals identical (sum 7794); update the 8 kcl files that describe the rewrite (`tutil/tutil.sh:102`, `tutil/PLAN.md:205,484`, `tutil/docs/TUtil.md`, `tgrep/tests/006_Contract.sh:74` + the same title in tawk/tfind/thead/tsed/ttail 006, `thttpserver/PLAN.md:101,835`, `thttpserver/README.md:324`, `thttpserver/examples/demo_oop.sh:181`, `thttpserver/tests/008_Contract.sh:27,194`) — wording only where it claims the rewrite; note in kklass_book that user `.ckk` caches are invalidated by the `.kk` source mtime only, so pre-P8 caches keep `.call` bodies (they stay correct). **DONE 2026-10-02 (worker; commit pending review):** both rewrite loops removed (`$this.NAME` = the instance wrapper, virtual as of `.new`); `kk._exec` tests set-ness; `kk.decl._validate_member` refuses `call delete property parent new` for instance members on every entry path (decl verbs, `kk._build_class_runtime`, `defineMethod`/`Procedure`/`Function`, which also gained identifier validation); test 132 (58, red 29 on both bashes); kklass 510/510 threaded 5.2 + 5.3 and single 5.2; all 49 examples identical; tgrep 185 / tutil 209 / thttpserver 497 both bashes; bench internal `$this.m` −10.9 % on both (193.7→172.6 / 165.4→147.4 µs, under the 12–15 % expectation, gate met); kcl wording in 8 files (the five other 006 titles make no rewrite claim — unchanged); 3 `found_in_R2_P8` items in the ledger | kklass suite + bench both bashes, master sweep 0 [FAIL] + identical totals both |
| **P9** | K4 per DR3 (`kk.isAbstract`, `kk.derivesFrom`, the three thttpserver readers + its 003/008 tests, a kcl-wide grep for other `_class_abstract` / `_class_derives_from` readers); K2: the full C12 quirk list as one kklass_book §Best Practices trap paragraph with the measured repro. **DONE 2026-10-02 (worker; commit pending review):** `kk.isAbstract` (regex guard, then `${CLASS}_class_methods` must exist, then rc 0 iff the flag is 1; rc 1 concrete incl. raw-built; rc 2 malformed / never declared / not finalized) and `kk.derivesFrom` (guard on both arguments, then the internal) next to `kk._class_derives_from`, both in the export list; test 133 (25, red 23 on both bashes); kklass 535/535 threaded 5.2 + 5.3 and single 5.2; thttpserver: every internal read in the unit switched (router D8 + RouteRequest, application ServerClass, server BeginServe Transport), accept = rc 1 only, behaviour identical; 001/003 assert through the predicates, 008's source-integrity assertion now also forbids the internals (red 1 before the switch); 497/497 both bashes; no other kcl reader; K2 paragraph + API reference entries in kklass_book; measured facts (internal aborts on a malformed CHILD, BASH_REMATCH overwritten, +17–26 µs per kk.derivesFrom) in the ledger | kklass + thttpserver suites, master sweep 0 [FAIL] both |

## R2.4 Critic record (2026-10-01)

One Opus critic, probes on both bashes, scratchpad `critic2/`. C1/C4–C7/C14 went to
the ktests plan; C2 (wrapper vs `.call` matrix), C3 (fromJSON), C8 (prefix match), C9
(bench row), C10 (isAbstract semantics + two missed readers), C11 (8 doc sites +
stale caches), C12 (K2 quirks), C13 (escape details) are folded above. Key measured
facts: the rewrite-removed tree is green everywhere with identical per-suite totals;
the wrapper is 12–15 % faster than `.call`; visibility, frames and `inherited` are
identical between the two call forms; kklass examples byte-identical apart from temp
names.

# Round 3 — the round-2 leftovers (2026-10-02, critic-hardened the same day)

**Status: IN PROGRESS — ktests P1 and P10 committed; P11 done, commit pending review.** (Was: PLANNED, critic-hardened (C5–C15 folded), all decisions taken.)
Owner 2026-10-02: "Бери список в работу" — the `found_in_*` items left open by round 2
(ledger `round2`, phases R2_P7–R2_P9), each re-confirmed on HEAD (kklass 3368737) by
the supervisor (`scratchpad/r3/probe.sh`, `verify.sh`). The ktests leftovers (T2–T5)
are planned in `ktests/PLAN.md` "Round 3" and run FIRST, as in round 2.
Order: **ktests P1 → P10 (serialization) → P11 (declaration hygiene)**.
Ledger: `kklass_ledger.json` key `round3`.

## R3.1 Findings (re-confirmed 2026-10-02; critic additions marked C#)

| ID | Sev | Where | Symptom (measured) |
|---|---|---|---|
| S1 | medium | `defineSerializableClass` (`kklass_serializable.sh:13-72`) | `FORMAT=json` builds the class rc 0 with EMPTY `toString`/`fromString` bodies and no `toJSON`/`fromJSON`. The string format comes from an inline copy that differs from `_addSerializable_string`: it serializes only the class's own `property` arguments — **inherited properties are lost** (`TChild:X` for a child of a class with property `p`), lazy properties skipped (C7). An unknown format or fewer than 4 arguments is not refused (`shift 4` fails silently). |
| S1b (C8) | major | both string generators | SEPARATOR is spliced unquoted into generated code and patterns: `$(touch pwn)` as separator EXECUTES; `*` breaks the round trip (`a=[] b=[x*y*]`); `"` `\` `'` make `fromString` rc 2 (syntax error in the generated body). |
| S2 | medium | `saveObjects` (`:497-512`) | A class with both formats is saved with `toString`, which does not escape: `a='x:y' b=z` → `TB:x:y:z`, reloads as `a=x b=y:z`; a value with LF breaks the one-object-per-line file. |
| S3 | medium | `loadObjects` (`:515-543`) | The `fromJSON`/`fromString` rc is ignored: a refused line (`__class__` mismatch) still adds a default-valued instance; rc 0. **And (C10)** instance names restart at `${class}_loaded_0` on every call while `.new` on an existing name is rc 0 and keeps the old data — a second `loadObjects` ALIASES and merges the first call's instances (verified: `L1[0]` = `L2[0]`, a=9 b=2); an output array named `line`/`count` is silently empty, `instances_array` warns circular nameref; a JSON-only class given a string line → bash "fromString: command not found", instance kept, rc 0; a JSON line with leading whitespace goes to `fromString`; "Loaded N objects" printed on a direct call (§1.1). |
| S4 | low | `fromJSON`/`fromString` bodies | End with `echo "$this"` / `printf '%s\n' "$this"`: a direct call PRINTS the instance name and leaves `RESULT` empty (§1). (C9) On a refusal `RESULT` keeps the CALLER's old value (`kk._invoke` restores it unless `kk._return` ran) — §1.2 wants `RESULT=''` on rc 1. |
| M1 | low→major (C12) | static members | A static member named `new`/`constructor` is silently lost (rc 0). Wider (C12, measured): static `__decl_new_impl` hijacks `.new`; static `foo` + static `__static_foo` → `foo` runs the other body; `static_property x` + `static_method x` → accessor lost; `kk.register_static_methods … new` REPLACES the constructor; Pascal `constructor` + `static proc Create` → ctor body empty. Generated class-level names: `Class.new`, `Class.constructor`, `Class.__decl_new_impl`, `Class.__static_<m>`, the static-property accessor and static-method dispatcher, `<prefix>.__impl_<m>` (register_static_methods). |
| M2 | medium | declarative + Pascal DSL + .kkp | A refused member inside an open class prints the error, but `endClass`/`endImplementation`, Pascal `end`/`build` return rc 0 and the class is BUILT without it; `.kkp` compile rc 0 too (C13). Also (C13): a refused `defineClass` leaves the class OPEN (`KK_DECL_CURRENT_CLASS` set — a stray `field` attaches rc 0; test 132 resets it by hand 11×); a refused REdefinition wipes the old decl tables (`decl_methods=()`, `class_abstract=0`) while the old runtime survives; after an override error, `endImplementation` prints the misleading "must be closed with endClass first". `kk.decl._error` is stateless and also reached from non-declarative paths (the flag must not live there). Under `set -e` the refused verb itself already exits (no change for such files). |
| M3 | low→major (C14) | identifier guards | `kk.isAbstract`/`kk.derivesFrom` overwrite the caller's `BASH_REMATCH` (and so does every `.new`). (C14) The `=~` guard is also NOT exact: under `shopt -s nocasematch` in C.UTF-8/en_US.UTF-8 it accepts `ı`/`İ` → `kk.derivesFrom ı X` ABORTS the caller's command on both bashes (verified), `defineClass ı` aborts at kklass_decl.sh:842, `TN.new ı` rc 0 with errors. A plain range glob is not exact either (`ı`/`Ａ` on 5.2 en_US; é Ä ß with `globasciiranges` off). Exact in all 12 locale × globasciiranges × nocasematch combinations on both bashes: `local LC_ALL=C` + range glob (18.6–21.4 µs vs the regex's 14.8–15.7 µs). |

Aside (C15, pre-existing, NOT in this round): `kklass_compiler.sh` prints "line 82: source: filename argument required" on any `.kkp` and dumps kkore's `kv` as a class (test 063 hides it with `>/dev/null 2>&1`) → ledger `found_in_round3_critic`. Also out of scope: a class named `kk` with static `debug` replaces `kk.debug`.

## R3.2 Decisions

| # | Decision |
|---|---|
| DR4 | (owner 2026-10-02) S1: `defineSerializableClass` = `defineClass` + `addSerializable` — ONE generator per format. FORMAT, argument count and SEPARATOR validated BEFORE `defineClass` (refused → class not built, rc 1 + error, as `addSerializable`). **Format change accepted by the owner** (2026-10-02, after C7): fields are `${CLASS}_class_properties` — inherited + own, lazy included; documented in kklass_book. The toString/fromString entries in `_decl_methods`/`_method_visibility` the inline copy registered are not reproduced (no reader — the worker greps). |
| DR4b | (supervisor, C8) SEPARATOR (both `addSerializable` and `defineSerializableClass`): exactly one character, not alnum/`_`, none of `" $ \ ' \` * ? [ ]`, not LF → else rc 1 + error, nothing generated; every generated pattern use quoted. |
| DR5 | (owner) S2: `saveObjects` prefers `toJSON` when the instance has both; the string format stays unescaped, "values must not contain SEPARATOR or LF" documented. |
| DR6 | (owner, widened by C10; owner 2026-10-02: silent + RESULT=N) S3: names unique per shell (a name whose `${name}_class` exists is skipped — the counter continues); output array via `kk._outName` + `__kk_` locals (§1.7, rc 2 on a bad name); a JSON line = first non-blank char `{`; a refused line (rc ≠ 0, INCLUDING rc 127 of a missing `from*` method, bash's diagnostic suppressed) → instance deleted, `kk.warn` naming FILE:LINE, loading continues; final rc 1 if any line was refused; **direct call silent, `RESULT` = number loaded**, the "Loaded N objects" text only via `kk.debug`. Example 43 (mixed classes loaded as Person — today 2 garbage Persons) is fixed to load each class from its own file. |
| DR7 | (owner, completed by C9) S4: `fromJSON`/`fromString` end with `kk._return "$this"`; every refusal path does `kk._return ""` before `return 1`. `toString`/`toJSON` stay printers. Expected example deltas: 42 −1 line, 43 −6 name lines (plus the DR6 fix). |
| DR8 | (owner, placement by C13) M2: per-class `${class}_decl_refused=<member>`, set by the declarative verbs while that class is open, reset by `declareClass`; `endClass` → rc 1 naming class + member, clears `KK_DECL_CURRENT_CLASS`, leaves `finalized=0`; `endImplementation`/`build` check the flag FIRST (named, no misleading "close with endClass" message); a refused `defineClass` closes the class; a refused REdefinition leaves the old class's decl tables and abstract flag intact; the `.kkp` compiler fails (rc 1) when any class is poisoned. `kk.decl._error` stays stateless. |
| DR9 | (supervisor, widened by C12/C14) M1: refuse as a static member name `new`, `constructor`, `__decl_new_impl`, any `__static_*` / `__decl_*`, and a static property/method name clash — on every static path (defineClass `static_*` tokens via `kk.decl._remember_static_*` and `kk._build_class_runtime`, `kk.decl._declare_method` class_*, `classVar`, Pascal `static var/proc/func`, `kk.register_static_methods` incl. its `.__impl_` names, `.kkp` `class var/procedure/function`); Pascal: a static whose name equals the class's constructor name refused. `.ckk` load needs no check. M3: ONE shared fork-free helper (`local LC_ALL=C` + range glob, no `=~`) replaces the identifier regex in `kk.isAbstract`, `kk.derivesFrom`, `kk.decl._validate_ident` and the `.new` instance-name check (the worker greps for other `^[A-Za-z_][A-Za-z0-9_]*$` guards on public entry paths and lists them); BASH_REMATCH untouched by all of them. |

## R3.3 Phases

| phase | content | gate |
|---|---|---|
| **P10** | S1–S4 per DR4–DR7. Red-first: `defineSerializableClass … json` round trip; bad format / short call / bad separator (`$(touch x)` → no file, `"`, `*`, two chars, LF) refused with nothing built; a subclass + lazy property under the string format (pins the new field order); a both-formats class saved as JSON and reloaded intact (separator + LF in values); `loadObjects`: two calls in one shell keep the first array intact, a refused JSON line (rc 1, instance gone, warning names the line, RESULT=count), a JSON-only class given a string line (no bash diagnostic), leading-whitespace JSON line, out-array named `line`/`count`/hostile (rc 2 or correct), direct call silent; `fromJSON`/`fromString` direct call silent + RESULT=inst, `$()` once, refusal → RESULT=''. kklass_book §Serialization (format change, separator rule, loadObjects contract); examples 41/42/43 re-run, deltas as DR7 + the fixed 43. **DONE 2026-10-02 (worker; commit pending review):** defineSerializableClass = checks (≥ 4 args, format, `_addSerializable_checkSep`) then `defineClass` + `addSerializable`; string generator splices the separator only inside single quotes (`printf` toString, `IFS='S' read -r … <<< ${1#C'S'}` fromString); fromJSON/fromString `kk._return`; saveObjects prefers toJSON; loadObjects per DR6 (+ set -e safe, whitespace-only lines skipped, missing file / bad class on the contract); test 134 (43, red 40 against HEAD on both bashes); review remarks R1–R5 folded (loadObjects reads a last line without LF; fromString refuses input without the serializer class + SEP prefix, `${1-}` so no-arg under set -u is rc 1; addSerializable debug note via kk.debug; 43 header; book prefix-check paragraph); kklass 578/578 threaded 5.2 + 5.3 and single 5.2; examples 41 −1 / 42 −2 / 43 −6 name lines + rewritten section (20→19, 32→30, 63→59) (the "Loaded N objects" line is gone from all three — DR6, not counted in DR7's estimate). **Flagged:** DR4b widened to every whitespace separator (space/TAB/VT/FF are IFS whitespace for `read`, CR is lost by the body rebuild — measured); 1 `found_in_P10` item (defineMethod debug note on stdout, kklass.sh) in the ledger | kklass suite both bashes (`--mode single` on 5.2); master sweep 0 [FAIL] both, totals identical except kklass |
| **P11** | M1/M3 per DR9, M2 per DR8. Red-first: each static path × `new`/`constructor`/`__decl_new_impl`/`__static_x`, prop/method clash, `register_static_methods … new`, Pascal ctor-name clash; declarative `declareClass`+`procedure delete` → endClass and endImplementation rc 1, no `.new`, member named, `KK_DECL_CURRENT_CLASS` empty after; Pascal `class … proc delete … end` + `build` rc 1, the next class in the same file builds fine; refused `defineClass` leaves no open class; refused REdefinition keeps the old decl tables + abstract flag; `.kkp` with `procedure delete;` → compile rc 1; `shopt -s nocasematch` + `ı`/`İ` in C.UTF-8 and en_US.UTF-8 + `Ａ` (5.2) → rc 2, no abort, for both predicates, `defineClass` and `.new`; BASH_REMATCH preserved by both predicates and `.new`; bench row for `.new` (not slower beyond noise). Drop 132's 11 manual `KK_DECL_CURRENT_CLASS=""` resets only if they become dead (asserts unchanged). Book §Reserved Member Names + API reference. Plus (supervisor, from found_in_P10): the `VERBOSE_KKLASS=debug` notes of `_defineMethodType` ("Method … added to class …", kklass.sh ~:1285) and any other kklass.sh debug `echo` go through `kk.debug` (stderr), never stdout — red-first: `VERBOSE_KKLASS=debug addSerializable C : string > out` leaves `out` empty. **DONE 2026-10-02 (worker; commit pending review):** M3 — one helper `kk._is_ident` (`local LC_ALL=C` + range glob, no `=~`) behind kk.isAbstract, kk.derivesFrom, kk.decl._validate_ident, the generated `.new` and loadObjects' class check; exact in all 12 locale × globasciiranges × nocasematch combos, BASH_REMATCH untouched. M1 — `kk.decl._validate_static` (new/constructor/__decl_new_impl/__static_*/__decl_*) + property/method clash (`kk.decl._static_clash` at the verb incl. the built parent chain, merged-list check in kk._build_class_runtime) on every static path; kk.register_static_methods checks every name (+ `__impl_*`) before generating anything; Pascal `end` refuses a static named like the constructor (default Create), either order. M2 — `${C}_decl_refused` set by the verbs through kk.decl._poison, reset by declareClass; endClass (incl. the override-of-non-virtual refusal) rc 1 naming class + member and closing the class; endImplementation/build check it first; defineClass closes on any refused token; a refused REdefinition restores the 32 tables declareClass reset (snapshot taken only when a built class is re-declared, dropped by a clean endClass); the compiler fails on any poisoned class, nothing written. Debug: kklass.sh's two debug echoes (`_defineMethodType`, "class created") → kk.debug. Test 135 (38, red 32 against HEAD on both bashes); 132: 4 dead resets removed, 4 kept (`declareClass X; <refused verb>` without endClass — the class is open by design); kklass_book §Reserved static member names / §A refused member fails its class / §Identifier checks + API; bench rows; kklass 616/616 threaded 5.2 + 5.3 and single 5.2; examples identical (only the C15 noise line number 82→98); kkore + 11 kcl suites totals identical on both bashes (one thttpserver 006 launch flake on 5.2, green on re-run). **Flagged:** on 5.2 `.new` is +10 % (+17.6 µs: the guard is +8.5 µs, not ~+5, plus a function call), on 5.3 within noise (the helper beats the regex there). Gate numbers, deviations and the `found_in_P11` items in the ledger. **Review remarks R1–R3 (2026-10-02) done:** R1 `.new` carries an inline explicit-letter glob (no ranges, no `=~`; kk._is_ident only under nocasematch), kept equivalent to kk._is_ident by test 135 C5 (41 names × 12 combos); R2 `constructor NAME`, Pascal `destructor NAME` and `implementConstructor CLASS` validated before their eval (a `$( )` name ran the command), refusal poisons; R3 static names `method_body_*` refused (CLASS_static_SP vs CLASS_static_method_body_M storage, map in the ledger) + instance/class method of one name in the declarative tables refused; test 135 = 44 (red 37 vs HEAD, 15 vs the first report, both bashes) | kklass suite both bashes; master sweep 0 [FAIL] both, totals identical except kklass |

## R3.4 Critic record (2026-10-02)

One Opus critic, every probe on both bashes, scratchpad `critic3/`. C1–C6 went to
`ktests/PLAN.md` Round 3; C7 (DR4 field set — owner accepted the change), C8
(separator injection), C9 (RESULT on refusal + example deltas), C10 (loadObjects
aliasing/naming/out-array/rc 127/whitespace/stdout — owner chose silent + RESULT=N),
C11 (example 43), C12 (static name collisions + entry paths), C13 (poison flag
placement, open class after refused defineClass, wiped decl tables, .kkp), C14
(locale-exact identifier guard), C15 (compiler noise — out of scope) are folded above.
Supervisor re-verified C3, C7, C10, C14 (`scratchpad/r3/verify.sh`).

# Round 4 — the round-3 leftovers (2026-10-03, critic-hardened 2026-10-05)

**Status: P12 DONE 2026-10-05 (worker; commit pending review). Was: PLANNED, critic-hardened (C1–C14 folded), decisions taken.**
Owner 2026-10-03: "Потом приступай к открытым пунктам" — the items round 3 left open
(ledger `round3`: P11 found_in, `found_in_round3_critic`, the P11 review's open
visibility question). The ktests items (T6, T7) are planned in `ktests/PLAN.md`
"Round 4" and run FIRST. kkore has no plan of its own; its item (L1) is planned here.
Order: **ktests P2 → kklass P12**. Ledger: `kklass_ledger.json` key `round4`.

**Moved out of this round (owner 2026-10-05):** N1 (a class or instance named like an
existing function namespace — `kk`, `kv`, a kcl helper — silently replaces framework
functions) and C5 (the same for instance names). The owner's answer: duplicate names
must be refused "as in any Pascal compiler", designed together with a Pascal-like
`uses` directive that tracks which source files were already included — "это нужно
подробно обсуждать и планировать". A separate design plan (`kklass/USES_PLAN.md`,
draft for discussion) carries the critic's measurements (N1 follow-up: 8 re-declarations
in the whole tree, all in kklass tests 119/121/135; a duplicate-identifier prototype
broke 2 wording assertions; the imposter-rebuild loophole; frame-chain declaration
sites; costs). Owner 2026-10-05: an interactive (`bash -i`) re-definition stays allowed.
**Also moved out:** C3 — the dynamic-scope leak (a static method body, or another
class's method body without property `y`, called from an instance method, sees and
WRITES the caller's property namerefs: `SThin.bump` setting `y` changes `i.y`;
re-verified 2026-10-05). Owner 2026-10-05: a separate research round; in P12 it is only
documented in kklass_book as a trap and recorded in the ledger.

## R4.1 Findings (critic numbers C#)

| ID | Sev | Where | Symptom (measured) |
|---|---|---|---|
| V1 | medium | instance vs static PROPERTY of one name | (C1) Inside a body, a static property/classVar hides an instance property of the same name: every instance property kind (plain, field, lazy, computed/read-write) × static_property/classVar, own or inherited, either order, on every path (raw build, defineClass, declarative verbs, Pascal `var`+`static var`, .kkp field+`class var`) — 22 combos build rc 0, `x=fromBody` writes the STATIC. Pairs involving METHODS do not collide (method x + static_property x: `$this.x` runs the method; property x + static_method x; method x + static_method x on raw/defineClass). (C2) 135 A11 builds `TStOk` with `property x` + `static_property x` and the book (§Reserved static member names) says "a static member may share its name with an instance member" — both pin the pair DR10 refuses. No built kcl class has such a pair (39 classes scanned). |
| C15 | low | `kklass_compiler.sh` | (C6) The backquoted `` `source` `` in a comment line of the UNQUOTED `<<HEADER` heredoc (:103-104) is a command substitution: every compile (.kk and .kkp, and every autoload compile) runs `source` with no argument → "line 98: source: filename argument required" (bash reports the heredoc's first line), and every generated header reads "load with ." — since ac5979f (2026-09-05). (C7) `_collect_classes` takes every function `*.new` → kkore's `kv.new` is dumped as a class (21 lines). In the fresh compiler process no class exists before the source, so a before/after snapshot is not the issue: the criterion "`X.new` is a function AND `${X}_class_methods` exists" selects exactly the built classes (abstract, raw empty, parents loaded by the source — which MUST be dumped, else a compiled child loses its inherited methods). (C8) 12 stale `.ckk` caches (kklass/.ckk ×5, examples/.ckk ×1, tests/.ckk ×6; gitignored) carry a `Class: kv` section that redefines all 10 kkore `kv.*` functions when sourced; autoload recompiles only on a newer source mtime. |
| L1 | low | kkore `kk._outName` (`klib.sh:245`), `kc.alias` (`kcfg.sh:85`) | (C11) `kk._outName`'s range glob accepts ı İ Ａ (and é Ä ß with globasciiranges off) under en_US.UTF-8 on 5.2, İ under nocasematch elsewhere → the caller's `local -n` then prints a bash diagnostic. `kc.alias`: its `=~` is exact without nocasematch, but under nocasematch ı/İ pass → `declare -ng` prints a bash diagnostic; it clobbers BASH_REMATCH on EVERY call. (C10) Under nocasematch `kk._outName` over-refuses `result`, `Result`, `This`, `STATE`, `ifs`, `reply`; kklass `kk.decl._validate_ident` refuses `result`/`ifs`/`reply`/`__KK_x` (so `defineClass T "" property result` is rc 1). |
| L2 | **major** (regression from round 3 P11) | kklass `kk._is_ident` | (C9) `local LC_ALL=C` costs ≈4.5× under a UTF-8 caller locale: `kk._is_ident` 81–114 µs, `kk.derivesFrom` 208–225 µs under en_US.UTF-8 (vs 10–17 / 58–75 µs with the locale unset — P11 measured only that); supervisor re-verified 70 → 213 µs. thttprouter calls `kk.derivesFrom` twice per request. |

## R4.2 Decisions

| # | Decision |
|---|---|
| DR10 | (owner 2026-10-03, scoped by C1) V1: an instance PROPERTY of any kind (property, field, lazy, computed/read-write) and a STATIC PROPERTY (static_property, classVar) of the same name — own or inherited, either order — are refused and poison the class (DR8). Pairs involving methods stay allowed (they do not collide). Two check sites: the declarative verbs (own decl tables + the BUILT parent's merged `_class_properties` / `_class_static_properties`) and the merged-list check in `kk._build_class_runtime` (every path ends there). 135 A11 rewritten to keep `method y` + `static_method y` only; book: "a static member may share its name with an instance METHOD, never with an instance property/field". |
| DR12 | (supervisor, per C6–C8) C15: escape the backquotes in the heredoc (it stays unquoted for `$KKLASS_COMPILER_DIR`); `_collect_classes` = functions `X.new` with `${X}_class_methods` set (parents loaded by the source included; never a plain `X.new`); the 12 stale caches deleted once, and autoload also recompiles when `kklass_compiler.sh` or `kklass.sh` is newer than the cache (the critic's second option — the worker measures its cost on the autoload path). 063 asserts empty stderr and exactly "Classes: CounterKkp FancyCounterKkp". |
| DR13 | (supervisor, per C9–C12) L1+L2: ONE identifier helper `kk._is_ident` moves to `kkore/klib.sh` (kklass.sh already sources klib.sh first; kklass drops its copy and keeps `export -f kk._is_ident` — 135 D3); `kcfg.sh` (standalone, kkore test 003 sources it alone) sources klib.sh under a guard. Body: NO locale switch — the existing ASCII ranges plus a `*[![:ascii:]]*` guard, and under nocasematch the core runs with `shopt -u nocasematch` and restores it (C9: exact on 213–215 names × 12 locale/globasciiranges/nocasematch combos × 2 bashes; +2–4 µs over today's kk._outName in every locale). `kk._outName` and `kc.alias` use it; reserved-word comparisons in `kk._outName` and `kk.decl._validate_ident` run with nocasematch off (C10 — the reserved set is case-sensitive). The `.new` inline guard stays equivalent (135 C5 re-run). Contract otherwise unchanged; `kc.alias` keeps its own message (red-first asserts "own message, no bash diagnostic", not rc). |
| DC3 | (owner 2026-10-05) C3: kklass_book trap paragraph + ledger `found_for_round5`; no code. |

## R4.3 Phase

| phase | content | gate |
|---|---|---|
| **P12** | V1 (DR10), C15 (DR12), L1+L2 (DR13), C3 docs (DC3). Red-first: a body write for each colliding property×static-property pair on each path, inherited both ways → refused, not built; method+static_property and property+static_method still build with unchanged body semantics; compiler: empty stderr, header "load with \`source\`", Classes = the source's own built classes, a `.kk` that sources its parent dumps both and the compiled child's inherited call works when loaded alone, `Factory.new` and kv not dumped, abstract and empty raw classes dumped, a stale cache older than `kklass_compiler.sh` is recompiled; under nocasematch `kk._outName result` rc 0 and `RESULT` rc 2, `defineClass T "" property result` builds, ı İ Ａ é × 12 combos → rc 2 with no bash diagnostic, BASH_REMATCH preserved by `kc.alias` on a VALID name, nocasematch still set after each call. Bench rows `kk._outName`, `kk._is_ident`, `kk.derivesFrom`, `.new` with the locale unset AND en_US.UTF-8 (gate: no row slower than round-3 HEAD beyond noise in either locale; derivesFrom under en_US back near its unset-locale cost) **DONE 2026-10-05 (worker; commit pending review):** V1 — `kk.decl._prop_clash` at field / property / lazy / static-property verbs (own tables + the built parent's merged lists; poisons) + the merged-list check in `kk._build_class_runtime`; methods unaffected; 135 A11 = `method y` + `static_method y`; book rule. C15 — heredoc backquotes escaped; `_collect_classes` = `X.new` + `${X}_class_methods`; the 12 stale caches deleted; autoload also recompiles when `kklass_compiler.sh` / `kklass.sh` `-nt` the cache (≈0.4 ms stat, no fork, vs ≈256 ms per cached kkload); 063 clean + exact Classes. L1+L2 — `kk._is_ident` in kkore/klib.sh (ranges + `[![:ascii:]]`, nocasematch off around the core via a `[[ a == A ]]` probe, no locale switch), kklass's copy dropped (export kept); kcfg.sh sources klib.sh under a guard; kc.alias on it; kk._outName with an INLINE copy of the rule (calling the helper was +20 µs) and nocasematch off for the whole body; the three kklass validators case-sensitive under nocasematch. DC3 — book trap paragraph, ledger `found_for_round5`. Tests: 136 (14, red 10), 137 (5, red 4), 138 (5, red 4), 063 +1 (red 1), kkore 008 (9, red 7), same on both bashes. kklass 647/647 threaded 5.2 + 5.3 and single 5.2; kkore 464/464 both; examples 49 rc 0, deltas = C15 only; 11 kcl suites identical totals both bashes. Bench: kk.derivesFrom en_US 217→64 µs (5.2) / 228→64 (5.3), at its unset cost; kk._is_ident en_US 90→16. **Flagged:** kk._outName +4 µs (+15–18 %) in both locales on both bashes — the plan's C9 budget, not "within noise". Deviations + `found_in_P12` in the ledger. **Review R1/R2 (2026-10-05) done:** R1 kkore `kk._setOut` (OUTVAR of kk.isInt/kk.isNum) on the same rule — inline copy + nocasematch wrapper (inline +4.5 µs vs +17 for a call), now silent on ı İ Ａ é K…, test 008 +1 (red 2 vs the first report, 8 vs HEAD, both bashes); kkore grep: nothing else to switch (kv.*/kc.* names are assoc subscripts only); kkore 465 both, kklass 647 both, 15 isInt/isNum kcl suites identical both. R2 `inst.call` re-measured (10 alternating runs, 5.2): 226.2 vs 225.5 µs unset, 221.1 vs 219.0 en_US — noise; the call path reaches no changed function | kklass + kkore suites both bashes (`--mode single` on 5.2); kcl suites that use statics (P11's list) + thttpserver; master sweep 0 [FAIL] both, totals identical except kklass/kkore |

## R4.4 Critic record (2026-10-05)

One Opus critic, probes on both bashes, scratchpad `critic4/{v1,n1,n1b,c15,l1,t6,t7}/`.
C1/C2 (V1 pair map, A11 + book) → DR10; C3 (dynamic scope) → round 5; C4/C5 + the
follow-up N1b (namespaces kk kkp kc kv ke kl — ktests has none; kcl helper namespaces
tawk tca ths tpipe tsed tutil; shadowing needs no static member; duplicate-identifier
prototype) → `USES_PLAN.md`; C6–C8 → DR12; C9–C12 → DR13; C13/C14 → ktests Round 4.
Supervisor re-verified C3 (i.y = fromStatic), C6 (heredoc :100-104), C9 (70 → 213 µs).
