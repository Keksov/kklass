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
- **DONE 2026-09-05.** Gate: kklass 273/273 on 5.2; master 21/21 on both versions; bench unchanged vs P4b. The standalone 5.3 kklass run in the chain showed two transient failures (028, 029 — autoload freshness check, 1-second mtime granularity right after the 5.2 run wrote the same `tests/.ckk` files); both passed on four immediate re-runs and in the master sweep. Not a runtime regression; a per-run `KKLASS_CKK_DIR` in the runner would remove the flake.

---

## 3. Gates (every phase)

1. `bash kklass/tests/tests.sh` — 232 + new, 0 failures.
2. kcl suites using kklass: tlist, tobjectlist, tstringlist, tdictionary, tqueuestack, tstopwatch, tregex, tarray, tinifile, tcustomapplication, thashset (when landed).
3. `bench/kklass_bench.sh` — no metric slower than the previous phase; P1 and P4 must hit their targets.
4. Every phase also on bash 5.3.9 (recipe above); P4a/P4b are not done until both versions are green.

## 4. Order & sizes

P0 (S) → P1 (M) → P2 (M) → P3 (M) → P4a (L) → P4b (M) → P5 (S). P1–P3 are independent of P4 and can ship as their own commit(s).
