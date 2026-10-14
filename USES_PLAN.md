# `uses` — Pascal-like unit inclusion and duplicate identifiers (design)

**Status: IMPLEMENTED (U1–U5)** — design: decisions §5 (U1–U17), §6 (U18–U33), critic-amended §7.1–7.2 (U34–U44), supervisor review §7.3 (owner P1/P4/P8 2026-10-06), header shapes §7.4; phases §8; implementation summary §9.
Origin: round 4 (kklass/PLAN.md "Round 4", items N1 and C5 moved out). Owner, 2026-10-05:

> Нужно разработать план реализации "директивы" uses, аналогично Pascal. uses должен
> сам следить за повторным включением исходных файлов и не включать повторно файлы.
> Но, если пользователь сам включит файл другим способом и попытается сделать
> declareClass X, который был объявлен в ДРУГОМ файле, то это нужно отловить и выдать
> ошибку, но если пользователь включил тот же самый файл и делает declareClass X, то
> это нужно просто проигнорировать, хотя, возможно, лучше выдать WARNING. Одним
> словом, это нужно подробно обсуждать и планировать.

Also decided 2026-10-05: an interactive (`bash -i`) re-definition of a class stays
allowed. Instance names in `.new` (C5) are decided after this discussion.

## 1. What exists today (measured / read 2026-10-05)

| piece | where | what it does | gaps |
|---|---|---|---|
| `kk.use FILE` | `kkore/kuse.sh` | resolves FILE relative to the CALLER's dir, remembers it in `_KK_use_cache[path]`, prints the path when it must be loaded (rc 0) or nothing (rc 1); `--force`, `--check-mtime` (stat fork) | used by NOTHING except its own test (kkore 004); `source "$(kk.use f)"` costs a fork; the cache key is `dir/filename` as spelled (no canonicalization: `a/../b.sh` ≠ `b.sh`); does not source itself |
| hand-written include guards | all 29 kcl unit files (`_TLIST_SOURCED`, `_MATH_SOURCED`, …), kkore modules (`__KLIB_USE_SOURCED`…) | `if [[ -n ${_X_SOURCED:-} ]]; then return; fi` at the top | one variable per file, by convention only; a copy of the same file at another path loads twice |
| duplicate-class guard | `kklass.sh:16-77` (`_KKLASS_CLASS_SOURCE`, `kk._caller_source_file`, `kk._check_class_owner`), test 119/121 | a class remembers the canonical file that built it; a declaration from a DIFFERENT file is refused, the same file (re-source, `..` spelling) is allowed | keyed on the innermost non-kklass FILE, not the declaration site: two different definitions in one file (or through one wrapper function) build silently (`mk TW x; mk TW y` → props=y, rc 0); a refused Pascal "imposter" unit could rebuild the original from its old tables (critic N1b, closed by the build-time re-check) |
| framework / helper namespaces | kkore (kk kc kv ke kl), kklass (kk kkp), kcl helpers (tawk tca ths tpipe tsed tutil) | plain functions `ns.name` | a class or an INSTANCE named `kv`, `kc`, … silently replaces them (`defineClass kv` replaces `kv.new`; `T.new kc` replaces `kc.delete`, whose call then unsets kkore's) |

Critic N1b measurements (2026-10-05, instrumented run of kklass + kkore + all 26 kcl
suites + 48 examples, 2513 class declarations): a class name is declared a second time
in the same shell only 8 times, all in kklass tests 119/121/135 (2 same-file re-sources,
4 same-file other-line in 135, 2 cross-file imposters). A strict "duplicate identifier"
prototype broke 2 assertions (message wording). Costs: registry lookup ~6–7 µs;
`compgen -A function -- "X."` 24–36 µs with kcl loaded (1458 functions); bash cannot
observe a function being defined, so a namespace defined AFTER a class of that name is
undetectable without a registry fed by the loader.

## 2. Pascal reference semantics (what "аналогично Pascal" brings)

- `uses A, B;` names units, not files; the compiler finds them on a unit search path.
  A unit is compiled/initialized ONCE per program however many units use it.
- Identifiers declared twice in the SAME scope (unit) → "Duplicate identifier".
- Two DIFFERENT units may export the same identifier: no error; the one from the
  later-listed unit shadows, `UnitName.Ident` qualifies. In bash there is one global
  function namespace, so "shadowing" = silently replacing the other unit's code — the
  bash analogue has to be an error (or a warning), not shadowing.
- Circular references are illegal between interface sections, allowed via implementation.

## 3. Questions to settle in the discussion

**Q1 — syntax and name resolution.** `uses tlist tstringlist` (unit NAMES, Pascal-style)
or `uses ../tlist/tlist.sh` (paths, like `kk.use`)? If names: where is the search path
(a `KK_UNIT_PATH` list; the kcl root by default; the caller's dir first?), and is the
unit name the file stem (`tlist` → `tlist/tlist.sh`, `tlist.sh`)?

**Q2 — identity of a unit.** Canonical path (`cd -P … && pwd -P`: resolves `..` and
symlinks; on Windows also `C:\…` vs `/c/…` vs case differences) or the unit name? The
existing class guard uses `cd+pwd` canonicalization (no `-P`).

**Q3 — repeated inclusion.**
- through `uses`: always a silent no-op (Pascal);
- the same file through a plain `source` after it was loaded (by `uses` or `source`):
  re-run it (today) / skip it (only possible if the file itself checks — i.e. a guard
  line every unit keeps) / let it run and have every `declareClass X` of an already
  built X from the SAME file be ignored — with or without a WARNING (owner: "просто
  проигнорировать, хотя, возможно, лучше выдать WARNING");
- "ignored" means: the second declaration does not rebuild X at all (the class, its
  instances and any `defineMethod` changes stay), and the rest of that class block is
  swallowed silently until `end`/`build`? (A Pascal-like "sink" state; today a refused
  block prints 3–4 follow-up errors.)

**Q4 — "declared in a DIFFERENT file" — what is the declaration site?** The unit file
being sourced, measured as the chain of `BASH_SOURCE:BASH_LINENO` frames up to the
first `source` frame (critic N1b: a re-source and a loop give the same chain, two calls
through a wrapper `mk` do not), or just the file? With "file": two definitions of X in
one file are allowed (the second wins or is ignored per Q3). With "site": the second
one is a duplicate identifier.

**Q5 — which identifiers count.** Classes only, or also:
(a) function namespaces of other units (`kv.*`, `tca.*`): `uses` can REGISTER every
unit's namespaces when it loads it (one function-table diff per unit load, at load time
only), which turns the check into an O(1) registry lookup instead of `compgen`, and also
covers the order problem (a unit loaded AFTER a class of that name is detected at load);
(b) instance names (C5) — with the registry, `.new` can refuse a name that is a class or
a registered namespace in ~1 µs (an assoc lookup), exactly, in any locale;
(c) plain functions/variables named X — the critic found no real collision (a class
creates `X.*` functions and `X_*` variables, never `X` itself); propose: not counted.

**Q6 — error or warning, and the rc.** Different-file duplicate: error, rc 1, class
poisoned (DR8) so the rest of the unit cannot rebuild the original. Same-file duplicate
(Q3): ignore / WARNING (kk.warn, rc 0)? Interactive shell: allowed (decided).

**Q7 — reload for development.** Keep `kk.use --force` / `--check-mtime` semantics as
`uses --reload`? If a unit is reloaded on purpose, are its classes rebuilt (what
happens to live instances), or is reload limited to plain function units?

**Q8 — cycles.** A uses B uses A: mark a unit "loading" before sourcing it; a re-entry
while loading = cycle → error naming the chain, or allowed (the second `uses A` is a
no-op and A's declarations below that point are not yet visible to B)?

**Q9 — bootstrap and migration.** `uses` itself lives in kkore (`kuse.sh`, loaded by
plain `source`). Do the 29 kcl units and the kkore/kklass modules switch from their
hand-written guards to `uses` (one phase per layer), or keep the guards and use `uses`
only between units? Do tests keep plain `source` (they must keep working either way)?

**Q10 — compiled caches and subshells.** A class loaded from a `.ckk` cache
(autoload) must register like a unit load. A child `bash` that inherited exported
functions (KKLASS_EXPORT_FUNCTIONS=1) does not inherit the assoc registry — treat its
classes as unregistered (any declaration allowed) or rebuild the registry from markers?

## 4. Tentative phasing (after the discussion)

U0 decisions (this document) → critic → U1 kkore: `uses` core (name resolution,
canonical identity, once-only load, registry of loaded units and the namespaces they
define, cycle state, reload) → U2 kklass: declaration site = the unit being loaded;
duplicate-identifier rule (Q3–Q6) on classes; `.new` instance-name check through the
registry (C5) → U3 migrate kcl units (and kkore/kklass modules) per Q9 → U4 docs
(kklass_book, kcl README §1, a "Units and uses" chapter).

## 5. Decisions — topic 1: where units are searched for (owner, 2026-10-05)

The owner's flow (2026-10-05): (1) a user script first sources the core by a full or
relative path reachable from the call site — possibly a new `kproject` unit like a
project in FPC/Delphi; (2) a default config somewhere (`~/.kbool`, `/etc/kbool`, …)
says where kbool lives; (3) `kk.project <project file>` — a full path or the name of a
subfolder of `~/.kbool` — sets search paths and other settings; (4) `kk.uses` takes a
full path or a bare unit name looked up on the project's unit search path, as in
Delphi/FPC. Each point evaluated and decided by quiz:

| # | Question | Decision |
|---|---|---|
| U1 | implicitly loaded units (FPC `System`) | **kkore only** (klib, kerr, kvar, kcfg, kuse); kklass is an ordinary unit: `kk.uses kklass` |
| U2 | startup file | a separate **`kbool.sh`** in the kbool root loads the system units; **kuse** = the `uses` mechanism (the compiler's unit loader), **kproject** = the project description (`.lpi` analogue) |
| U3 | how the user loads it | by a full/relative path, or `source kbool.sh` through `$PATH` (bash's built-in `sourcepath`, on by default on both bashes) — nothing to implement, documented |
| U4 | no default config found | **silently use built-in defaults**: the kbool root is found from `kbool.sh`'s own location (`BASH_SOURCE[0]`), default paths `kkore`, `kklass`, `kcl/*` — no config is needed to locate kbool |
| U5 | config lookup order (stronger first) | env var (`KBOOL_HOME` / `KBOOL_CONFIG`) → project file → `~/.kbool/config` → `/etc/kbool/config` → built-in defaults |
| U6 | `~` differs between the bashes (Git-bash `/c/Users/1`, msys64 `/home/1`) | **also search `$USERPROFILE/.kbool`** on Windows (owner's choice over "document only"); order between `~/.kbool` and `$USERPROFILE/.kbool` — open (U-open-1) |
| U7 | config / project file format | **`key = value`**, read by a small reader in kkore, no code executed (`tinifile` is in kcl, above kkore — unusable by the loader) |
| U8 | `kk.project NAME` without a path | `~/.kbool/<name>/project.conf` |
| U9 | relative paths inside a project file | relative to the **project file's directory** (Lazarus) — the project is relocatable |
| U10 | auto-discovery of a project file | **no**, only an explicit `kk.project` (may be added later) |
| U11 | project contents besides unit paths | the **`.ckk` cache directory**, the **debug level**, and **defines** (owner added defines; their use — conditional loading? a `kk.defined NAME` predicate? — is open, U-open-2) |
| U12 | path vs unit name in `kk.uses` | contains `/` or ends in `.sh` → a path (relative = relative to the calling file); otherwise a unit name |
| U13 | units in their own subfolder (`kcl/tlist/tlist.sh`) | a search-path entry ending in **`/*`** means "every subfolder" (FPC `-Fu/path/*`); each folder is probed for `<name>.sh` |
| U14 | lookup order for a unit name | the calling file's folder → project paths in order → system paths |
| U15 | the same unit name in two folders | **first match, silently** (FPC; owner's choice over "first + WARNING") |
| U16 | lookup cache name → full path | yes, for the shell session |
| U17 | the loading unit's own folder | the loader exports **`KK_UNIT_DIR`** while a unit is being sourced; units migrate to it (drops one `$(cd … && pwd)` fork per unit) |

Open from topic 1: **U-open-1** order of `~/.kbool` vs `$USERPROFILE/.kbool` when both
exist (and whether that holds for `/etc/kbool` under msys64 — `/etc` is also
per-installation); **U-open-2** what defines are for and how a unit reads them.
Next topics: Q2–Q10 of §3 (unit identity, repeated inclusion, declaration site,
which identifiers count, error vs warning, reload, cycles, migration, caches/subshells).

## 6. Decisions — topics 2–10 and the open points of topic 1 (owner, 2026-10-05)

| # | Question | Decision |
|---|---|---|
| U18 (Q2) | unit identity in the loaded-units registry | the **canonical physical path** (`..` and symlinks resolved with `cd -P` in the current shell — no fork); the critic checks letter case and `C:\` vs `/c/` on Windows |
| U19 (Q3a) | unit header | every unit starts with **`kk.unit NAME \|\| return 0`** (Pascal `unit X;`): registers the unit, exports `KK_UNIT_DIR`, and makes a repeated PLAIN `source` of the same file a no-op — replaces the 29 hand-written `_X_SOURCED` guards; files without the header keep working |
| U20 (Q3b) | a file WITHOUT the header re-sourced, the same `declareClass X` again | **ignore + one WARNING** (kk.warn): X is not rebuilt (instances and `defineMethod` changes survive), the rest of that class block up to `end`/`build` is skipped silently |
| U21 (Q4) | "the same declaration site" | **file + line**: the chain of `BASH_SOURCE:BASH_LINENO` frames up to the `source` frame. A re-source gives the same site (→ U20); a second definition on another line or through a wrapper function is a **Duplicate identifier** (error, rc 1, the class poisoned so the rest of the unit cannot rebuild the original). An interactive (`bash -i`) re-definition stays allowed (2026-10-05) |
| U22 (Q5) | which names are taken (amended by U40: declared namespaces) | **classes + the unit registry**: when a unit is loaded the loader records the function namespaces it defined (`kk.`, `kv.`, `tca.` …); a CLASS or an INSTANCE with such a name is refused; the `.new` check is an assoc lookup (~1 µs, locale-exact); a unit loaded AFTER a class of the same name is caught at load. Plain functions/variables named X are not counted |
| U23 (Q6) | error vs warning | different site → error (U21); same site, no header → warning (U20); interactive → allowed |
| U24 (Q7) | reload | **not in the first version**: `kk.use --force` / `--check-mtime` are dropped |
| U25 (Q8) | cyclic uses (A → B → A while A loads) | **error naming the chain** (rc 1), as Pascal does for interface sections |
| U26 (Q9a) | migration | **everything, layer by layer**: kkore → kklass → the 29 kcl units, one phase per layer; `_X_SOURCED` guards and hard-coded `../../kklass/...` paths go away; tests may keep plain `source` |
| U27 (Q9b) | a unit sourced directly while `kbool.sh` is not loaded | `kk.unit`'s line **bootstraps `kbool.sh`** relative to the unit itself — direct `source unit.sh` keeps working (all tests and examples unchanged) |
| U28 (Q10) | a child bash with exported functions (assoc registry not inherited) | the child **starts with an empty registry**; re-loading the same files there is harmless (same site, U21) — the critic verifies |
| U29 (U-open-1) | both `~/.kbool` and `$USERPROFILE/.kbool` exist | **first found**: `~/.kbool`, else `$USERPROFILE/.kbool` |
| U30 (U-open-1b) | system config differs per bash install (`/etc`) | also read **`%PROGRAMDATA%\kbool`**; order **first found**: `/etc/kbool` → `$PROGRAMDATA/kbool` |
| U31 (U-open-2) | defines | `defines = A B …` in the project; a unit tests them with the predicate **`kk.defined NAME`** (rc 0/1) in ordinary `if`; no conditional-loading syntax |
| U32 | the command's name | **`kk.uses`** in kkore; **`uses`** as a synonym in the Pascal DSL (`kklass_pascal.sh`) |
| U33 | `kk.unit NAME` differs from the file stem | **error** (FPC: the unit name must match the file name, else `kk.uses NAME` could never find it) |

Config lookup, updated by U29/U30 (stronger first): `KBOOL_HOME`/`KBOOL_CONFIG` →
project file → user (`~/.kbool/config`, else `$USERPROFILE/.kbool/config`) → system
(`/etc/kbool/config`, else `$PROGRAMDATA/kbool/config`) → built-in defaults.

**All topics decided 2026-10-05.** Next: the critic on the whole design, then the
phases of §4 refined by U26 (U1 kkore: kbool.sh, kk.unit, kk.uses, kk.project, config
reader, registry, kk.defined; U2 kklass: declaration sites, Duplicate identifier,
registry checks in declareClass/.new, `uses` in the Pascal DSL; U3 kkore + kklass
modules migrate; U4 the 29 kcl units migrate; U5 docs).

## 7. Critic record and amendments (critic 2026-10-05, owner decisions 2026-10-06)

One Opus critic, probes on both bashes in scratchpad `critic5/`. Supervisor re-verified
C1 (a bare-shell `kk.unit u || return 0` → "command not found", rc 0, unit NOT loaded),
C5 (`cd -P` keeps letter case: `real/sub` and `Real/Sub` give two paths; `-ef` SAME),
C16 (`$PROGRAMDATA` empty, `$ProgramData` = `C:\ProgramData`).

### 7.1 Owner amendments (2026-10-06, quiz)

| # | Finding | Amended decision |
|---|---|---|
| U19′ (C1, C2 — blocker) | the literal header cannot bootstrap kbool.sh, and `\|\| return 0` turns header errors into rc 0 (the ktests runner then sees a green file) | **two header lines** — line 1 bootstraps the loader relative to the unit, line 2 registers (see below). `kk.unit` returns 0 = load, 1 = already loaded (skip), 2 = error; `__kk_unit_rc` is 0 on skip and 2 on error, so an error makes the source rc 2 (ktests verdict "source returned rc=2"). Each unit keeps exactly ONE relative path — to kbool.sh (`../` in kkore/kklass, `../../` in kcl); this amends U26 |
| U18′ (C5) | `cd -P` does not give one spelling on MSYS (case kept; `C:/` and junctions resolve to `/tmp/…` in Git-bash only; 0.7 ms) | unit identity = the **unit NAME** (unique by U33) + **`[[ -ef ]]`** against the registered file (the same name from a different file → error). Paths are normalised lexically (no `cd`) for messages only. kklass's class-site check compares the file parts with `-ef` before declaring a duplicate (today's guard already gives a false "already registered" for 3–4 of 5 spellings) |
| U34 (C12) | a plain-sourced unit that failed mid-load stays registered; a later `kk.uses` skipped it silently | registered + not done + not on the source stack → **error "unit X not completely loaded"** |
| U13′ (C18) | `kcl/*` holds non-units (16 `bench.sh`, `docs`, `fpjson`): `kk.uses bench` silently found `dateutils/bench.sh` | the name index counts a file as a unit only if its header carries `kk.unit <stem>` (read without a fork); other files stay reachable by path |
| U35 (C8) | the registry protects namespaces, not plain words: a class/instance named `class`, `end`, `var`, `func`, `proc`, `build`, `property`, `field`, `uses`, … breaks the DSL | the **DSL verb names** (kklass_decl + kklass_pascal + `uses`) are refused as class and instance names; a test checks the list against the real function table |
| U36 (C15) | the `.kkp` translator ignores `unit X;`; `uses A, B;` unsupported | `unit X;` → the two header lines (`kk.unit X`), `uses A, B;` → `kk.uses A B`; the unit name must match the file stem (U33) — example 45 (`unit CounterPascal;` in `counter_pascal.kkp`) renamed |
| U7′ (C17) | list values: `:` breaks `C:`, a space breaks "Program Files" | **list keys repeat**, one value per line (`unitpath = kcl/*` twice appends); other keys override; `defines` = space-separated names; `#` comment lines; CRLF stripped |
| U24′ (C20) | with headers an edited unit cannot be reloaded at a prompt | an escape hatch **`kk.unit --forget NAME`** (drops the registration; the next source loads it again; its classes follow the interactive re-definition rule) — not a full reload |
| U37 | defines and project paths only exist after `kk.project` | **`kk.project` must come before the first non-system `kk.uses`**, else error; a second `kk.project` → error |
| U2′ | where kproject lives | `kk.project` and the config reader live **in kuse.sh** — no separate kproject file |
| U38 (owner 2026-10-06, critic_u1a C13) | KBOOL_HOME had two meanings: the strongest config source (U5) and the folder kbool.sh was loaded from (U1a overwrites a preset) | **split**: `KBOOL_HOME` = only "where the loaded kbool lives", always written by kbool.sh (a preset pointing elsewhere → one WARNING); the config chain head is **`KBOOL_CONFIG`** only (a path to a config file). U5 reads: `KBOOL_CONFIG` → project file → user → system → defaults |
| U41 (owner 2026-10-09, found_in_U1b) | after U3 every kklass/kcl test loads kbool.sh and would read the developer's config (~/.kbool, KBOOL_CONFIG, /etc/kbool, ProgramData/kbool) | **the ktests runner isolates** every test file: KBOOL_CONFIG, USERPROFILE, ProgramData unset, HOME and the /etc hook pointed at an empty fixture folder; a test may install its own config explicitly; a standalone `bash tests/X.sh` reads the config as is |
| U44 (owner 2026-10-14, critic_u4 C5) | any file could kk.namespace an ALREADY declared name (ths, tca, TSet, kk, even class-named dateutils/math) with rc 0 — a foreign user unit could plant ths.hijack | **sharing an already declared namespace is allowed only to a unit in the SAME FOLDER as the owner** (a package, e.g. the 3 thttpserver files); a foreign folder → rc 2 + the loading unit tainted; a namespace that equals a class name is never shared with a foreign file |
| U42 (owner 2026-10-09, U3 review R2; amends U1a R1 and U34) | a failed `kk.uses X` inside a unit's load (not found, a bad name, X's own rc) left the unit "complete": a retry returned rc 0 with nothing loaded (kklass.sh failing under kklass_pascal; kklass_decl failing under kklass) | **every failed `kk.uses` taints the loading unit** (U34), and a tainted unit's next load — a plain source or `kk.uses` — **runs it again** (the "not completely loaded … until kk.unit --forget" error is gone; a unit loaded by kk.uses with rc 0 but tainted is rc 2 and forgotten). **`kk.uses --optional X…`** (also the Pascal `uses`): a failure neither taints nor prints the loader's message; the rc still reports it |
| U43 (owner 2026-10-09, U3 review R3; amends U14) | with headered system units a NAME lookup could be hijacked by the cwd: `kk.uses klib` in a folder holding a klib.sh, `bash -c` / `bash -s` / a pipe in such a folder, a script that cd's after loading kbool | (1) a loaded **kkore / kklass unit is never resolved again** by name — a same-named file in the caller's folder or the cwd is ignored (a silent no-op returning the loaded unit); (2) **without a calling file** the caller-folder step is taken only at an **interactive prompt** (`$-` has i: `$PWD`), never from `bash -c`, `bash -s` or a pipe; (3) a **relative calling file** is resolved against the PWD recorded when it was loaded (kk.unit for units, kbool.sh for the files on the stack at its boot), not the current PWD |
| U39 (owner 2026-10-07, U1b review R9) | an empty list value (`unitpath =`, `defines =`) in KBOOL_CONFIG cut the PROJECT's lists too (the merge cut every weaker level); a second `kk.project` with the same file was rc 2 | an empty list value drops the entries above it in its own file and every weaker **environment** level's (user, system) — **never the project's**: the project's lists always apply, and the project resets the inherited user/system lists with its own empty value. A second `kk.project` naming the **same file** (`-ef`) is an rc-0 no-op (like `kk.uses`); another file → rc 2 |
| U40 (owner 2026-10-08, U2b review R1; critic_u2b C1-C4, C10) | the registry of U22 / §7.2 "Registry" LISTED bash's function table: a listing costs O(functions) after any definition and grows ~quadratically (2k functions 9 ms, 8k 150 ms, 16k ~0.9 s, 24k ~2.8 s); with live instances a plugin load became 10-50x slower (1.2-2 s per plugin at 2000 instances), every `( T.new x )` subshell rescanned | **declared namespaces, no listing at all**: `kk.unit NAME` declares the namespace NAME (owner: that unit); **`kk.namespace X [Y…]`** (kkore/kuse.sh, any file, with or without a unit; ownership guard, identifier check) declares more (thttpserver → ths, tcustomapplication → tca); kbool.sh declares kk kl ke kv kc; kklass declares the ones it loads itself (kk kkp kl ke kv) so they are taken also without kbool. declareClass and `.new` refuse a declared namespace, a DSL verb or a class by ONE assoc lookup — nothing on these paths lists functions (a namespace's own unit/file may declare a class of that name: kcl's `class dateutils` in dateutils.sh). The other direction (U22, "a unit loaded AFTER a class of the same name is caught at load"): `kk.unit NAME` and `kk.namespace X` refuse (rc 2; the unit load fails with `__kk_unit_rc` 2) a NAME/X that is already a built class or a live instance. **GAP (documented):** a plain third-party library with neither a unit header nor `kk.namespace` is not protected (`source libns.sh; TB.new libns` replaces libns.get); kcl's helper namespaces (tawk tpipe tsed tutil ths tca …) are declared in U4 with the unit headers |

The two header lines (kcl unit `tlist`; kkore/kklass use `../` instead of `../../`):

```bash
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${BASH_SOURCE%tlist.sh}../../kbool.sh" || return
kk.unit tlist || return $__kk_unit_rc
```

A no-op re-source costs 212–239 µs (today's hand-written guard: 116 µs).

### 7.2 Supervisor amendments (critic findings folded as stated)

- **Loader guard (C3):** "is kbool loaded" = `[[ ${__KK_UNITS[@]@a} == A* ]]` with a sentinel element — set -u safe, no fork, not fooled by an exported scalar or exported functions (a child bash with KKLASS_EXPORT_FUNCTIONS=1 re-bootstraps with an empty registry — U28 holds). kbool.sh starts with the same guard.
- **Unit dir (C4):** `${BASH_SOURCE%NAME.sh}` (not `%/*`): works for a no-slash `source tlist.sh` from the unit's dir; a file found through PATH already has an absolute BASH_SOURCE.
- **Sink state machine (C6, U20):** for a header-less re-source the sink is keyed by class: it swallows the member verbs while X is open, `implement X.*`, `implementConstructor X`, `endImplementation X`; it ends at `endImplementation X`, `build X` or the next declareClass of X. Pascal bodies `X.m(){…}` are plain function definitions that the re-source REDEFINES before any verb runs, so `build X` on the sink path regenerates X's static wrappers from the tables and unsets the non-runtime `X.*` scratch functions (measured: otherwise `TU20.GetCount` returns `count=` instead of `count=2`). `defineClass` (one call) is ignored as a whole.
- **(SUPERSEDED by U40, 2026-10-08: declared namespaces, no listing — the measurements below assumed an unchanged function table.)** - **Registry (C7, C8, C9):** a per-unit function-table diff costs 28 ms (5.2) / 7 ms (5.3) per update — +4.3 s / +1.07 s to load all of kcl if done per file. So `kk.unit`/`kk.uses` set a dirty flag and ONE diff runs lazily at the next `declareClass`/`.new` (capture: 5.3 `compgen -V`, 5.2 a temp file + `$(<…)`, no fork). Several units MAY share a namespace (`kk.` is defined by 5 files, `ths.` by 3); class namespaces and instances (`${X}_class` set) are excluded from the namespace set; class names come from the class registry. The `.new` lookup costs 0.5–0.7 µs (≈1 %).
- **Positional args (C10):** `kk.uses` does `set --` before sourcing (units inherited the caller's `"$@"`: kklass.sh saw the compiler's args); kerr.sh's argument-driven `source kerr.sh set_trap` becomes an explicit `ke.setTrap` call (kkore 001, kklass 128 updated).
- **Sourcing (C11):** `kk.uses` uses plain `source`, never `builtin source` (under set -e from `g || …` it exits the shell; 5.2 prints `pop_var_context`); all its locals carry the `__kk_` prefix (dynamic scope reaches unit file-scope code).
- **Cycles (C12):** no RETURN trap (it would replace the ktests verdict trap); `kk.unit` records the unit's bottom-relative BASH_SOURCE index — a re-entry while that frame still holds the same path = cycle (O(1), nothing to clean up). `kk.uses` forgets a unit whose source returned non-zero, so a retry reloads it.
- **Compiled caches (C13):** a `.ckk` load registers its classes — the compiler emits a register(NAME, site) line per class and loads kklass through `kk.uses kklass` instead of the hard-coded absolute `source …/kklass.sh`.
- **Interactive allowance (C14):** a re-definition is "interactive" only when the declaration chain has no file frame (no `source` frame; the bottom BASH_SOURCE is `main`) — a file sourced at an interactive prompt is still checked.
- **Environment (C16):** the Windows variable is **`ProgramData`** (bash is case-sensitive; `$PROGRAMDATA` is empty in both bashes); `USERPROFILE`/`ProgramData` may be unset (msys64 with a stripped env) — guard with `[[ -n ]]`, never probe `/.kbool`. No cygpath: `C:\…` and `C:/…` work for `-f` and `source`; `\` → `/` only for messages. HOME is `/home/1` only when msys64 bash is started from Git-bash.
- **Lookup (C18):** a name index is built once per path entry (one glob of `kcl/*/*.sh` ≈ 2 ms; a lookup ≈ 10 µs); the U16 cache covers project/system paths only (caller-dir-first makes lookup caller-dependent); `\` counts as a path character (`C:\x\tlist` is a path).
- **KK_UNIT_DIR (C19):** `kk.uses` saves/restores it around a nested load; a plain-sourced nested dependency can leave it stale, so code that needs its dir at RUN time keeps its own copy (math.sh `MATH_DIR`, kklass_autoload `KKLASS_LIB_DIR`, kklass_compiler `KKLASS_COMPILER_DIR`).
- **Contradictions resolved:** U1 vs U19 — kuse.sh cannot carry a bootstrap header; kbool.sh sources it plainly and it registers itself afterwards. U19 vs U22 — header-less files never register namespaces (documented). U15 "first match silently" applies among HEADERED files of one name only.
- **Migration census (C21):** 1471 `source` lines (kcl tests 911, kklass tests 219, kkore tests 38, ktests 72, examples 55, tools/bench 48, frozen kcl/docs repro 59); unit → unit lines that change: kkore 2, kklass 14 (+3 in experimental/), kcl 43 in 29 files. No test re-sources a unit to RESET state (instrumented: kklass 647/647 and kkore 465/465 with re-sources made no-ops). Expected test edits: 119 #2 (silent re-source vs the U20 WARNING), 119/121 wording, kkore 004/005 (kk.use / kk.getScriptDir dropped by U24), kkore 001 + kklass 128 (kerr set_trap), tawk/tsed/tfind footprint comments, tcustomapplication 031 (compgen -v — check). ktests does not use kkore — out of scope.

### 7.3 Supervisor review of the design (2026-10-06) — owner decisions P1/P4/P8, supervisor items P2–P10

| # | Gap | Decision / amendment |
|---|---|---|
| P1 (owner) | a user unit OUTSIDE the kbool tree (`myproj/lib/x.sh`) cannot use the fixed-depth `../../kbool.sh` first line | **`KBOOL_HOME`**: kbool.sh exports it on load; a user unit's first line is `[[ ${__KK_UNITS[@]@a} == A* ]] \|\| source "${KBOOL_HOME:?kbool not loaded}/kbool.sh" \|\| return` — a clear error when neither kbool nor KBOOL_HOME is present. Units INSIDE the kbool tree keep the relative first line (U19′). Documented as the two header shapes |
| P4 (owner) | `kk.unit --forget NAME` dropped the unit registration only; its classes stayed built, so the next source hit the "same site" rule and did NOT rebuild them (U20) — the hatch could not reload a class even in a REPL | **`--forget` also forgets the unit's classes**: `kk.unit`/`declareClass` keep a registry unit → classes; `--forget NAME` drops the class sites (`_KKLASS_CLASS_SITE`, `_KKLASS_CLASS_SOURCE`) of every class that unit declared, so the next source rebuilds them. Live instances of the old class are the user's responsibility (documented) |
| P8 (owner) | through `kk.uses` a unit gets no arguments (`set --`); through a direct `source unit.sh arg` it does | one rule: **units never take arguments**; `kk.unit` with `$# > 0` prints a WARNING ("unit X called with arguments; units take none") and continues — catches stale `source kerr.sh set_trap` calls in third-party code |
| P2 | U1a said `kk.getScriptDir` is "removed" — it is still used by `kk.use` and kkore test 004 | both are removed TOGETHER as replaced by `kk.uses` + `KK_UNIT_DIR`; kkore 004/005 rewritten for the new API (C21 already lists them) |
| P3 | the two header lines are not atomic: if line 1 sources kbool.sh and kbool.sh itself fails (no kkore), `\|\| return` propagates kbool.sh's rc — which must be non-zero on every failure path | U1a gate: kbool.sh returns rc ≠ 0 on every failure path (missing kkore module, unreadable config) on both bashes; red-first with a broken fixture tree |
| P5 | the name index reads the header of every candidate file (U13′) — 29+ file reads at kbool.sh load; only the glob (≈2 ms) was measured | the index is built **lazily** at the first `kk.uses NAME` (not in kbool.sh) and the worker measures the header read (`read -r` of 2 lines per file, no fork) on both bashes; gate: first lookup ≤ 10 ms with kcl's 29 units |
| P6 | the index was built in kbool.sh but project paths only exist after `kk.project` | same lazy index (P5); `kk.project` invalidates it (rebuilt at the next name lookup) |
| P7 | a test may `source kklass.sh` by the old path BEFORE anything bootstraps kbool.sh; later a migrated unit's `kk.uses kklass` meets an already-loaded-but-unregistered kklass | kklass.sh gets the header in U3, so even a direct early source bootstraps kbool.sh and registers; red-first in U3: "kklass sourced directly first, then a unit that `kk.uses kklass`" loads kklass once, both bashes |
| P9 | a `.ckk` cache names the unit it was compiled from by ABSOLUTE path; a moved project keeps pointing at the old place | the cache refers to its source unit by **unit name** (resolved through the index at load) and to kklass through `kk.uses kklass` (C13); U2 |
| P10 | U4 migrates 29 kcl files "in groups" with one master sweep at the end — a breakage in group 2 would surface only after group 5 | the mixed state (some units with headers, some with `_X_SOURCED`) is explicitly supported, and a full master sweep on both bashes runs after **each** group |

### 7.4 Header shapes (final)

Unit inside the kbool tree (kcl unit `tlist`; kkore/kklass modules use `../`):

```bash
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${BASH_SOURCE%tlist.sh}../../kbool.sh" || return
kk.unit tlist || return $__kk_unit_rc
```

User unit outside the tree (owner 2026-10-06, R5 of the U1a review: `${KBOOL_HOME:?…}`
EXITS a non-interactive shell; this form fails the source with rc 2 — an empty
KBOOL_HOME gives bash's "/kbool.sh: No such file or directory" — and the caller
survives):

```bash
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit myunit || return $__kk_unit_rc
```

A `.kkp` unit's translation (`unit X;`, U36) uses exactly this user form (owner
2026-10-08, U2b review R5) — there is no third form and no baked kbool path; the
autoloader and the compiler supply KBOOL_HOME (their own kbool) when neither kbool
nor KBOOL_HOME is there.

**Placement (U1a review R4):** the two header lines must be the first lines of the
file that are neither blank nor `#` lines (a shebang and a comment block may come
first), and they must end within the file's first **512 characters** — the name
index reads one 512-character block per candidate file. So: shebang, then the two
header lines, then the unit's comment block. A CR at a line end is ignored.

## 8. Phases (refined)

| phase | content | gate |
|---|---|---|
| **U1a** kkore loader | `kbool.sh`; `kuse.sh` rewrite: loader guard, `kk.unit` (rc 0/1/2, `__kk_unit_rc`, name = stem, `-ef` identity, cycle by frame index, incomplete-unit error, `--forget`), `kk.uses` (`set --`, plain source, name index of headered files, caller dir → project → system, `\` as path char, forget on failure, KK_UNIT_DIR save/restore), `kk.defined`; `kk.use`/`kk.getScriptDir` removed together (P2); KBOOL_HOME export (P1); `--forget` incl. classes registry hook (P4); argument WARNING (P8); lazy name index (P5/P6) | new kkore tests red-first; kbool.sh rc ≠ 0 on every failure path (P3); first name lookup ≤ 10 ms with 29 units (P5); kkore + kklass suites unchanged, both bashes |
| **U1b** config + project | the key = value reader (repeat-to-append lists, CR, `#`); lookup chain env → project → `~/.kbool` else `$USERPROFILE/.kbool` → `/etc/kbool` else `$ProgramData/kbool` → defaults (fixture dirs via env overrides; unset USERPROFILE); `kk.project PATH|NAME` (paths relative to the project file, ordering rule U37), `.ckk` dir, debug level, defines | new tests; both bashes |
| **U2** kklass | class sites (frame chain, `-ef` on file parts); Duplicate identifier + poison; header-less re-source sink (C6 state machine incl. Pascal static restore + scratch cleanup) with one WARNING; prompt-only interactive allowance; lazy namespace registry checked in `declareClass`/`.new`; DSL verb names refused (U35); `.ckk` registration, source unit by NAME + `kk.uses kklass` in compiled files (P9); `--forget` drops class sites (P4); `uses` synonym in the Pascal DSL; `.kkp` `unit`/`uses` translation (U36) | 119/121/135 updated as listed; kklass suite + new tests, both bashes |
| **U3** kkore + kklass modules migrate | two-line headers; `ke.setTrap`; runtime dir variables kept where C19 says | kkore, kklass and every kcl suite (all units source kklass); red-first P7 (kklass sourced directly first, then `kk.uses kklass`) |
| **U4** kcl (29 units in 26 folders, in groups) | headers; drop `_X_SOURCED` and hard-coded `../../kklass/...`; footprint tests updated | mixed state supported; per-group suites AND a full master sweep on both bashes after EACH group (P10) |
| **U5** docs | kklass_book "Units and uses", kcl README §1, kkore docs | — |

- **U1a DONE 2026-10-06 (worker; awaiting critic + supervisor review, not committed).** `kbool.sh` (new, kbool root) + `kkore/kuse.sh` rewritten (kk.unit incl. `--forget`, kk.uses, kk.defined, unit → classes registry + `kk._unit_current` for U2; kk.use / kk.getScriptDir / kk.clearUseCache removed); kkore tests 009 (44) + 010 (24) new, 004/005 rewritten for the new API. Red vs HEAD: 004 3, 005 1, 009 44/44, 010 23/24 FAIL. Gate: kkore 533/533 threaded on 5.2.37 and 5.3.9 + `--mode single` on 5.2.37; kklass 647/647 on both; tcustomapplication (sources kuse.sh) 377/377 on both. P5: the first `kk.uses NAME` over kcl/* (48 files, 29 headered) 4–7 ms on both bashes — the index is lazy at two levels (candidate map by one glob, a header read per looked-up stem): reading every candidate's header up front measured 15–25 ms and could not meet the 10 ms gate. No-op re-source with the §7.4 header 206–213 µs (guard 121–137 µs). Deviations and measured facts (P8 via BASH_ARGC/BASH_ARGV, `declare -A` unassigned reads as loaded, U34 for plain sources, `${KBOOL_HOME:?}` exits the shell): `uses_ledger.json` → `phases.U1a`.
- **U1a review round 1 DONE 2026-10-06 (worker; not committed).** R1 U34 taint only on structural errors (an optional dependency the unit handles leaves it complete); R2 kuse.sh without a guard variable, tables repaired on every source, `kk._unit_reset` = unset + redeclare, kbool.sh checks one function per system unit, `__KK_LOADED` (ownership, R14); R3 (owner) `kk.uses NAME` always resolves and compares — another file is rc 2 "already loaded from X; here it resolves to Y", resolutions cached per (caller dir, name); R4 header after a shebang/blank/`#` lines within 512 chars (rule in §7.4); R5 (owner) user line 1 `source "${KBOOL_HOME-}/kbool.sh" || return 2` (§7.4); R6 hermetic 009/010; R7 `--forget` refuses all system units; R8 a child with an inherited `kk.uses` loads `$KBOOL_HOME/kbool.sh`; R9 `kk.uses NAME` of a loaded unit 110–115 → 25–30 µs (wrapper + `kk._uses`: bash copies a function body per call); R10 exact executed-detection; R11 GLOBIGNORE; R12 one WARNING for another kbool.sh copy. kkore 550/550 on both bashes + single; kklass 647/647 both; tcustomapplication 377/377 both. Details: ledger `phases.U1a.review_round_1` and `deviations`.
- **U1a R14 DONE 2026-10-06 (worker; not committed).** Registry ownership is the one-element assoc `__KK_LOADED` (`${__KK_LOADED[@]@a} == A`), checked first by every entry point (kk.uses, kk._uses, kk.unit, kk.defined, kk._unit_current/_add_class/_classes) before a table is subscripted by a non-literal key — a `set -a` child (functions exported, `bash -c` exec'd in the parent's PID) no longer evaluates a caller-path key as arithmetic. Subscript audit: ledger `phases.U1a.review_round_2`. kkore 554/554 on both bashes + single; kklass 647/647 both; tcustomapplication 377/377 both.
- **U1b DONE 2026-10-07 (worker; awaiting review, not committed).** kuse.sh "Configuration": a fork-free `key = value` reader (one `read -N`, one newline split; `#` lines, blanks, CRs, trim, value after the first `=`; keys `unitpath`/`defines` (lists, repeat to append, an empty value resets) and `debug`/`ckkdir` (scalars); relative folders joined to the file's folder and folded lexically, `C:\`/`/` values as written; malformed / unknown-key / bad-level / bad-define lines → one WARNING with file:line); levels `KBOOL_CONFIG` → project → user (`~/.kbool/config` else `$USERPROFILE/…`) → system (`/etc/kbool/config` else `$ProgramData/…`) → built-in. **Merge rule:** a scalar takes the strongest level that sets it; a list takes every level's entries strongest-first, duplicates dropped (project folders before user before system-config, then the built-in system paths); an empty list value cuts the weaker environment levels, never the project (U39). kbool.sh reads env/user/system at load (rc 2 for a KBOOL_CONFIG naming no file, P3) and warns once for a preset KBOOL_HOME elsewhere (U38); `kk.project PATH|NAME` (relative PATH = the calling file's folder; once; refused after the first non-system unit is used or sourced, U37) re-merges, resets the name index and caches, applies defines and the debug level (only over a VERBOSE_KKLASS nobody else set); `kk.config KEY [OUTVAR]` (kcl §1.1/1.7). Every new entry point checks `__KK_LOADED` first (incl. the internal `kk._cfg_*`: literal `level/key` subscripts on a non-assoc table evaluate a variable named `user`/`env` — measured). kkore 011 (49, red 42/49 vs HEAD on both bashes); kkore 603/603 both bashes + single; kklass 647/647 both; tcustomapplication 377/377 both. Reader 0.64–0.74 ms per 10-line file. Details: ledger `phases.U1b`.
- **U1b review round 1 DONE 2026-10-07 (worker; not committed).** R1 `\` → `/` in absolute FOLDER values too (`C:\x\units\*` is the every-subfolder form); R2 ownership check first in the U1a internals kk._unit_register/_check/_taint/_drop/_find/_forget/_index_build (critic sec1/taint probes: 0 PWN); R3 the read stops at a NUL (`read -d '' -n`) — UTF-16, NUL or CR-only files → one WARNING and the file ignored, a UTF-8 BOM skipped; R4 caps: 4096 characters per line (WARNING file:line), 64 KiB per file (WARNING), worst case ≤ 260 ms per file on both bashes (was 0.5–1.2 s at 64 KiB, 142–223 s uncapped); R5 a relative KBOOL_CONFIG made absolute after the read; R6 kkore 004 hermetic; R7 a config-written VERBOSE_KKLASS never exported (set -a), the same-value limitation documented; R8 kk.config refuses assoc / readonly OUTVARs and is nocasematch-exact, kk.defined A B → rc 2; R9 a system unit by PATH = its name, U39 (owner): an empty list value never cuts the project, a second kk.project of the same file → rc 0; R10 hostile / spaced / trailing-backslash tests. Reader 0.9–1.0 ms per 10-line file (the NUL-safe read is byte-wise on MSYS). Details: ledger `phases.U1b.review_round_1`.
- **U2a DONE 2026-10-07 (worker; awaiting review, not committed).** kklass.sh "Class declaration sites": the site of a declaration = the FILE:LINE call positions from the innermost one outside the kklass files outward up to the position inside the first `source` frame (or the script's own), relative files made absolute; tables `_KKLASS_CLASS_SITE` / `_KKLASS_CLASS_SOURCE` / `_KKLASS_DECL_SITE` behind the ownership assoc `__KKLASS_TABLES` (a set -a child starts empty, U28/R14); the fork-based canonical-path guard is gone. A built class declared again: another site → `kklass: Duplicate identifier: class 'X' is already declared at A; refusing to redeclare it at B`, rc 1, poisoned, the rest of the block swallowed silently (rc 1); the same site (file parts `-ef`, U18′) → one `kklass: WARNING:` and not rebuilt, the block swallowed (rc 0); a chain with no file position (prompt, `bash -c`) → rebuilt (C14). The sink (kklass_decl.sh, C6): member/section/modifier verbs of both DSLs while X is open, `implement X.*`, `implementConstructor X`; ended by `endImplementation X`, `build X`, the next `declareClass X`; defineClass / defineSerializableClass ignored as a whole; the swallowed Pascal `build` unsets the re-run's `X.*` body functions and regenerates the static API (`kk._class_static_api`, split out of kk._build_class_runtime, byte-identical). Classes register at the END of a successful build and are filed under `kk._unit_current` when kbool is loaded; `kk._unit_forget_class` drops their sites (P4). Tests: 139 new (13; red 13/13 on both bashes), 119 (3 red), 121 (1), 135 B9/B10/B14 (3). Gate: kklass 660/660 on 5.2.37 + 5.3.9 threaded and 5.2.37 single; kkore 629/629 both; all 26 kcl suites 6676/6676 both (unchanged); 48 examples no delta vs HEAD (5.2 ex 28 timing only). Bench: defineClass / declarative / .new within noise (declarations are fork-dominated); the site check itself +12–15 µs. Details: ledger `phases.U2.U2a`.
- **U2a review round 1 DONE 2026-10-07 (worker; not committed).** R1 the C14 allowance needs `$-` with `i`: `bash -c`, `bash < f`, `bash -s` and a pipe are judged — their positions are the pseudo file "(no file)", by line; R2 functions defined there (5.2: `environment` / `main`, 5.3: `$0`) are that pseudo file and skipped when leading, so both bashes give one verdict (`$0` stays a file when it is a real file other than bash — the ktests runner's `bash -c 'source "$0"' FILE`); R3 a sink belongs to the `source` frame that opened it: verbs from other files/frames run normally, a sink whose frame has returned is closed like a swallowed `build` (bodies dropped, static API restored), declareClass sweeps stale sinks; R4 the snapshot helpers check ownership; R5 every `unset "T[$k]"` in kklass and kuse.sh single-quoted, kk._class_register validates; R6 a site keeps raw and absolute positions (one raw spelling = one file unless both absolute forms exist and differ); R7 a Duplicate identifier taints the loading unit (U34); R8 (owner) `kk.class --forget X` (rc 0 / 1 not registered / 2 malformed); R9 WARNING text "declared again from the same place (SITE); ignored". Documented: two declarations on ONE line and two `source <(…)` are the same site; U20 covers declarations only (file-scope defineMethod / addSerializable of a re-sourced file still run). 139 +11 (S14–S24; red 10/11 on both bashes). Gate: kklass 671/671 both bashes + single, kkore 629/629 both, kcl 6676/6676 both, examples no delta. Details: ledger `phases.U2.U2a.review_round_1`.
- **U2b DONE 2026-10-08 (worker; awaiting review, not committed).** kklass.sh "Taken names": `_KKLASS_TAKEN[NAME] = verb | class | ns`, refused as a class name (rc 1, `kklass: Duplicate identifier: 'X' is a function namespace (X.* of unit U (FILE)) / a kklass DSL verb; refusing ...`, poisoned `(reserved name)`, the block swallowed, the loading unit tainted) and as an instance name (`Invalid instance name: X (...)`, rc 1). Verbs (U35) = every public dotless function of kklass.sh / _decl / _pascal / _serializable + `uses`. A refused namespace uses sink mode n: each swallowed member verb snapshots the namespace's function of that name, restored at the sink's close (`class ke; proc enableErrorReport` no longer deletes kkore's function). `.ckk`: per class `if kk._ckk_class C SITE; then <dump>; kk._ckk_built C; fi` — a cached class is registered (another file's declaration = Duplicate identifier, the same source = WARNING); kklass loaded only when absent (kbool: `kk.uses "$KBOOL_HOME/kklass/kklass.sh"` until U3); autoload's cache dir = KKLASS_CKK_DIR, else `kk.config ckkdir`, else `./.ckk`. Pascal DSL `uses` = kk.uses from the caller's file (U32). `.kkp`: `unit X;` → the two header lines (X = the file stem), `uses A, B;` → `kk.uses A B || return`; translated units live in `<stem>.sh`; example 45 → `CounterPascal.kkp`. Round 0's registry listed the function table (lazy scans, a stale-time probe, a generation counter) — replaced in review round 1 by U40.
- **U2b review round 1 DONE 2026-10-08 (worker; not committed).** R1 (U40, owner): declared namespaces — `kk.unit NAME` declares NAME, new public `kk.namespace X [Y…]` (kkore), kbool.sh declares kk kl ke kv kc, kklass records kk kkp kl ke kv itself; one assoc lookup in declareClass and `.new`, nothing lists functions (test 140 N4 greps the paths and times them with 5000 extra functions); a namespace's owner may declare a class of its name; `kk.unit`/`kk.namespace` refuse a built class or a live instance (rc 2); generation counter, scans, probe and pending state removed; GAP documented (a plain library without header or `kk.namespace`; kcl's helper prefixes are declared in U4). R2 the cache's source is recorded relative to the cache folder (a moved project works), unit lookup from the folder above it. R3 ownership first in every helper; tested in a fresh set -a child. R4 a comment after a `unit`/`uses` statement → error with FILE:LINE. R5 (owner) translated units use the §7.4 user header; autoload/compiler supply KBOOL_HOME. R6/R7 tests (KKLASS_CKK_DIR over ckkdir, the kklass_kkp.sh mtime rule, the moved project, `defineClass kkp` without kklass_kkp). Tests: kkore 012 new (5; red 5/5), kklass 140 (18; red 18/18), 139 S24, 063/065/135/136. Gate: kklass 689/689 on 5.2.37 + 5.3.9 threaded and 5.2.37 single; kkore 634/634 both; 26 kcl suites 6676/6676 both (unchanged); examples no delta but timing. Details: ledger `phases.U2.U2b` incl. `review_round_1`.
- **U3 DONE 2026-10-09 (worker; awaiting review, not committed).** kkore: klib, kerr, kvar, kcfg carry the §7.4 relative header (guards gone; kerr/kcfg no longer source klib — kbool.sh loads every system unit, klib first); kbool.sh registers them through their headers, declares every system unit's name (kuse klib kerr kvar kcfg) and restores the caller's KK_UNIT_DIR; kk.unit declares a unit's namespace once klib is loaded; kerr's `set_trap` argument is gone (C10/P8: `ke.setTrap`; kkore 001, kklass 128). kklass: units kklass, kklass_decl, kklass_pascal, kklass_serializable, kklass_autoload (header, `kk.uses kklass` / kklass's last line `kk.uses kklass_decl`, no ../kkore path, no `$(cd …)` fork; KKLASS_DIR / KKLASS_LIB_DIR = KK_UNIT_DIR normalised, C19); tools kklass_compiler.sh / kklass_kkp.sh (executed; no header). `.ckk`: the prologue uses `kk.uses kklass`; (REPLACED in review round 1, R1: a cache no longer registers its source unit — see below). U41: the ktests runner gives each test file an empty HOME + /etc hook and unsets KBOOL_CONFIG, KBOOL_HOME (added — deviation), USERPROFILE, ProgramData, PROGRAMDATA. Reusable lint `kkore/tests/unit_lint.sh` (kkore 013, kklass 141 K3). Red vs HEAD: kkore 013 15/20, kklass 141 12/14 (P7 K5/K5b), ktests 040 4/5, both bashes. Gate: kkore 654/654 and kklass 704/704 on 5.2.37 + 5.3.9 threaded and 5.2.37 single; ktests 440/440 both; 26 kcl suites 6676/6676 both (unchanged); examples no delta but mktemp names. Startup (best of 5): `source kklass.sh` 124–129 → 53–56 ms (5.2), 123–127 → 49 ms (5.3); `source kbool.sh; kk.uses kklass` 55–59 ms (by path at HEAD 129–136). The optional kk.unit split measured (−24…−38 µs per no-op re-source), not done. Details: ledger `phases.U3`.
- **U4-G1 DONE 2026-10-12 (worker; awaiting review, not committed).** tstopwatch, tpath, tarray, tregex, tqueuestack, thashset, tdictionary: §7.4 relative header on lines 2-3; `_X_SOURCED` guards, `X_DIR` and the `$(cd …)` fork gone; `kk.uses kklass_pascal || return` in place of the path source; `kk.namespace TQueueStack` / `TSet` / `TDict` (census: no other foreign prefix). The pattern later groups copy is written down in the ledger (`phases.U4.pattern`). New kcl-level suite `kcl/tests` (table `kcl_units.sh`, one row per migrated unit; 001 file shape + namespace census + lint, 002 loads once by absolute/relative source and kk.uses incl. set -eu in a counting private tree, 003 by name from a neutral and a decoy cwd + old globals gone + namespaces taken): red 44/50 vs HEAD on both bashes, now 50/50 on both + single. Gate: 7 G1 suites 1043 unchanged on 5.2.37 and 5.3.9 from a neutral cwd and from their tests folders; kkore 669 and kklass 709 both bashes; the other 19 kcl suites 5633 unchanged on 5.2.37. Startup within noise (class builds dominate: tregex ~0.7 s, tdictionary ~2.7 s). Details: ledger `phases.U4.groups.G1`.
- **U4-G1 review round 1 DONE 2026-10-12 (worker; not committed).** R1 kk.namespace taints the loading unit on every error (a plain-sourced unit with a refused namespace is not "complete": its next source / kk.uses fail again; kkore 012 +1). R2 pattern rule 10: readonly constants assigned once per process (`if [[ -z ${X+x} || ${X@a} != *r* ]]`), tpath; row flag `readonly`. R3–R5 kcl/tests restructured: 001 static for every row (form and place of `kk.namespace … || return`, `function X.y`, rows ↔ stubs, U43 decoy through `bash -s` for one row) + one runtime stub per unit (`NNN_<unit>.sh` → kclt_unit_tests: one set -eu load-once process in a counting tree, one by-name process with a runtime function-prefix census, owners, old variables, taken names, nsbad); 41 tests, 78 s sequential / 43–46 s threaded. R6 amendments a–i written into `phases.U4.pattern`. Red: critic mutations M1–M5 caught (were 1 of 5), R1/R2 rows red on the old code. Gate: kcl/tests, the 7 G1 suites, kkore 670, kklass 709, tlist/tstringlist/tfile/tdirectory — 0 FAIL on both bashes.
- **U4-G2 DONE 2026-10-13 (worker; awaiting review, not committed).** First the fold (supervisor decision): kcl/tests' kclt_unit_tests loads each unit ONCE — once + name + taken in one real-tree process: under set -eu a bare source bootstraps kbool and registers the unit, its `build X` classes must be filed under it, a sentinel over the first surviving file-scope function must stay through `./U.sh`, `../kcl/D/U.sh`, `kk.uses U` by name and a re-source (readonly rows: `kk.unit --forget` + reload restores it); the runtime census needs no pre-snapshot (every prefix in the shell is a registered class or a declared namespace). Critic mutations M1–M5 still caught, plus M6 (kk.unit never skips) and M7 (early return before `build`); G1 cost 38.5–44.8 → 26.7 s sequential, 22.5–27.5 → 12.4–13.9 s threaded. Then dateutils, math, tinifile, tstringhelper: §7.4 header, guards / `X_DIR` (tstringhelper lowercase) / forks / kklass paths gone, `kk.uses kklass_pascal || return`; census: no foreign prefix, no kk.namespace. Rule 10: dateutils `__KDT_*`, math `__MATH_PI…`, `__MATH_INT64_*`, `__MATH_AWK_PROG` (program text not re-indented); math keeps `MATH_DIR=$KK_UNIT_DIR` (rundir). Probe: `--forget math` + re-source with the awk engine running reset its pid/fds → "coproc … still exists", a second awk, the first orphaned — fixed (the engine state is set once per process), pinned by 202_math.sh through new stub hooks KCLT_FORGET_PRE/POST (no extra load). Red: 17/62 vs the unmigrated units on both bashes. Gate: kcl/tests 41 → 62 on 5.2.37 + 5.3.9 threaded and 5.2.37 single; G2 suites dateutils 444, math 177, tinifile 191, tstringhelper 922 unchanged on both bashes from both cwds; 7 G1 suites 1043 on 5.2.37; kkore 670 and kklass 709 both bashes; no other suite depends on a G2 unit. Found: `math.feStop` under set -e exits the caller (rc 143, pre-existing). Details: ledger `phases.U4.groups.G2`, pattern `amendments_G2`.
- **U4-G3 DONE 2026-10-13 (worker; awaiting review, not committed).** tfile, tdirectory, tlist, tobjectlist, tstringlist: §7.4 header on lines 2-3; guards / `X_DIR` / forks / kklass paths gone; `kk.uses kklass_pascal || return` and the kcl dependency BY NAME in place of its path source (tfile/tdirectory `kk.uses tpath`, tlist `kk.uses tarray`, tstringlist `kk.uses tlist`; tobjectlist only `kk.uses tlist`, amendment i); census: no foreign prefix, no kk.namespace; rule 10: tfile `TFILE_USE_CP`; stale comments (tlist, tobjectlist) updated. kcl/tests: rows + stubs 301-305; new check `mixed` for rows that kk.uses another unit of the table (the dependencies plain-sourced FIRST by the old path kcl/D/../E/N.sh, then the unit bare under set -eu: registered, complete, no dependency re-run — sentinel — and `kk.uses N` a no-op; one more load per such row); once's sentinel falls back to the first function's NAME when every file-scope function is a Pascal body consumed by `build` (tlist — none survives). Red: 20/50 vs the unmigrated units on both bashes; rule 10 (tfile unguarded) and mutations M9 (a dependency forgotten + reloaded: only `mixed` sees it) / M6 (kk.unit never skips: a SILENT re-run, only the sentinel sees it) caught. Gate: kcl/tests 62 → 92 on 5.2.37 + 5.3.9 threaded and 5.2.37 single; G3 suites tlist 134, tobjectlist 52, tstringlist 192, tfile 250, tdirectory 320 unchanged on both bashes from both cwds; tpath 243, tarray 98 and the dependents tqueuestack 98, tdictionary 148, tpipe 190 on both bashes; kkore 670, kklass 709 on 5.2.37. Startup within noise. Details: ledger `phases.U4.groups.G3`.
- **U4-G4 DONE 2026-10-14 (worker; awaiting review, not committed).** tpipe, tutil, tgrep, thead, ttail, tfind, tsed, tawk: §7.4 header on lines 2-3; guards / `X_DIR` / forks / path sources gone; `kk.uses kklass_pascal || return` (tpipe, tutil), tutil `kk.uses tpipe`, the six wrappers only `kk.uses tutil` (amendment i). Census: the lowercase helper prefixes (tpipe.* tutil.* tsed.* tawk.*) are their unit names — kk.unit declares them, so no kk.namespace line (rule 4; taken covers them through the unit name: `.new tawk` / `defineClass tawk` refused, tawk._isId intact); tgrep/thead/ttail/tfind define none. No readonly (rule 10 n/a), no runtime dir (C19: tools come through PATH). Amendment l: tutil's TUTIL_OUT_PREFIXES / _SUFFIXES (the registries the descendants extend at their load) declared once per process — a `kk.unit --forget tutil` + re-source no longer drops their entries (row flag `state`, new; 402_tutil.sh pins it through the G2 hooks). Stale comments updated (amendment f: tawk/tsed/tfind "leaves exactly …", tfind "guard above", the wrappers' "re-source guards" / "ONLY source line"); the footprint test "the unit sources ONLY ../tutil/tutil.sh" of thead/ttail/tfind/tsed/tawk 006_Contract now asserts `kk.uses tutil` and no source line (rule 7c). Red: kcl/tests 33/76 (001 8/51, 401-408 25/25), the five 006 rewrites 1 each; amendment-l and M9 mutations caught. Gate: kcl/tests 92 → 140 on 5.2.37 + 5.3.9 threaded and 5.2.37 single; the 8 G4 suites 2077 unchanged on both bashes from both cwds; tstringlist 192 both bashes; kkore 670, kklass 709 on 5.2.37; no suite outside G4 loads a G4 unit. Startup `source tawk.sh` 5.0 → 4.6 s. Details: ledger `phases.U4.groups.G4`.
- **U4-G5 DONE 2026-10-14 (worker; awaiting review, not committed).** tcustomapplication and the thttpserver package (thttpmessage, thttprouter, thttpserver, thttpapplication — 4 units, amendment b): §7.4 header on lines 2-3; guards (`_TCUSTOMAPPLICATION_SOURCED`, `_THS_<U>_SOURCED`) / `X_DIR` / forks / path sources gone; `kk.uses kklass_pascal || return`, thttprouter `kk.uses thttpmessage`, thttpserver `kk.uses thttpmessage thttprouter tstopwatch`, thttpapplication `kk.uses thttpserver tcustomapplication`; tcustomapplication's kuse.sh source deleted (amendment e); `kk.namespace tca` and `kk.namespace ths` in each of the three files that define ths.* (amendment a; thttpmessage, loaded first, owns it). No readonly, no reload-surviving state, no runtime dir (FIFOs under TMPDIR). thttpserver 008's three scope tests assert the kk.uses lines (rule 7c); demo.sh / demo_oop.sh / bench.sh keep the package entry by path and load tdictionary / tstopwatch by name. kcl/tests: G5 rows + stubs 501-505; the owners check expects a shared namespace's owner to be the first unit of the load order that declares it (kclt_owner), nsbad does not preload a dependency that declares the namespace itself. Red: kcl/tests 28/80, 008 3/107; shared-owner mutation caught. Gate: kcl/tests 140 → 172 on 5.2.37 + 5.3.9 threaded and 5.2.37 single; tcustomapplication 377 and thttpserver 497 unchanged on both bashes from both cwds (ENV fork failures re-run green); tstopwatch 61 both; kkore 670, kklass 709 on 5.2.37; demos + bench smoke, no nc left. Details: ledger `phases.U4.groups.G5`.

- **U5 DONE 2026-10-14 (worker; awaiting review, not committed).** Docs: kbool `README.md` (entry document: layout, quick start, `KBOOL_HOME`, header shapes, `kk.uses` rules, namespaces + defines, the config chain and format, `kk.project`, `--forget`, messages, running the tests + U41), `kkore/README.md` (new: the loader API with rc contracts, rules, registry/ownership, config reference, security notes, limitations), kklass book chapter 9 *Units and uses* + every example on `source kbool.sh` + `kk.uses`, kcl `README.md` §1.10 (the unit rules in reader form), `kcl/tests` and *Adding a unit*; stale unit docs updated (thttpserver README, tutil README, 10 TEST_COVERAGE_NOTES, TPipe.md / TUtil.md sources, fpjson PLAN), history annotated (*superseded by uses U3/U4*: kcl PLAN / REVIEW, kklass PLAN, unit PLANs, 8 JSON ledgers). Doc-check test red-first: kkore 015 + kklass 142 run every `<!-- doctest -->` block hermetically (§9). Details: ledger `phases.U5`.

Red-first ideas per phase: the critic5 report (copied into the ledger when the phases start).

## 9. Implementation summary

Implemented 2026-10-06 … 2026-10-14 in the phases of §8, each one worker →
critic → supervisor review → full master sweep on bash 5.2.37 and 5.3.9 →
commit (details, red-first counts and measurements: `uses_ledger.json`).

| phase | what landed | commits |
|---|---|---|
| U1a | `kbool.sh`; `kkore/kuse.sh` rewritten: `kk.unit` (+ `--forget`), `kk.uses`, `kk.defined`, the lazy name index, `KBOOL_HOME`, the `__KK_LOADED` ownership marker (R14); `kk.use` / `kk.getScriptDir` removed | kkore 9d7ec9c, kbool 4a37eda |
| U1b | the `key = value` reader, the config chain (U5/U29/U30/U38/U39), `kk.project`, `kk.config` | kkore 3a09ab5, kbool 4bf83d2 |
| U2a | class declaration sites, *Duplicate identifier* + poison, the same-site sink + WARNING, the prompt-only allowance, unit → classes, `kk.class --forget` | kklass ba9c51d, kkore 774746b |
| U2b | taken names: DSL verbs, classes, declared namespaces (U40, `kk.namespace`); `.ckk` registration; the Pascal `uses`; `.kkp` `unit` / `uses` | kklass 8011ca5, kkore 8c1de55, kbool 63e5990 |
| U3 | kkore and kklass modules carry the header; `ke.setTrap`; U41 runner isolation; U42 taint + `--optional`; U43 no cwd hijack | kklass 1ba0ea5, kkore 7aea57d, ktests c9787f2, kbool 453f948 |
| U4 | the 29 kcl units in 26 folders in five groups (G1–G5), `kcl/tests`; final round: U44 namespace sharing, math engine state from the environment refused | kcl dbb7538, 239448c, 8dcb308, c35cb6d, 6ecb74e, 251094a; kkore e26f975, f1e72b0; ktests 90b3001 |
| U5 | documentation: kbool `README.md`, `kkore/README.md`, the kklass book chapter *Units and uses*, kcl `README.md` §1.10 + `kcl/tests` + adding a unit; stale unit docs updated, history annotated; the runnable-example checker (kkore 015, kklass 142) | (U5 commit) |

Final master sweep (U4, 2026-10-14): 30 suites, 0 [FAIL] 0 [WARN] on both
bashes, 8678 tests (kkore 672, kklass 709, ktests 442, kcl/tests 179, the 26
kcl unit suites 6676). U5 adds kkore 015 (16 tests) and kklass 142 (10 tests).

Documented limitations (kkore/README.md §6): no reload (`--forget` is a hatch;
live instances are the user's); a plain library without a header or
`kk.namespace` is not protected (U40 gap); a plain-sourced unit failing by its
own `return N` counts as complete; `KK_UNIT_DIR` after a plain nested source;
a copied in-tree unit outside its folder; `source FILE FILE` escapes the
argument WARNING; a `.ckk` cache replays a unit's classes, not its body.
