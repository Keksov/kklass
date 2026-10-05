# `uses` — Pascal-like unit inclusion and duplicate identifiers (design)

**Status: DESIGN COMPLETE — decisions §5 (U1–U17), §6 (U18–U33), critic-amended §7 (owner 2026-10-06); phases §8; no code.**
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
| U22 (Q5) | which names are taken | **classes + the unit registry**: when a unit is loaded the loader records the function namespaces it defined (`kk.`, `kv.`, `tca.` …); a CLASS or an INSTANCE with such a name is refused; the `.new` check is an assoc lookup (~1 µs, locale-exact); a unit loaded AFTER a class of the same name is caught at load. Plain functions/variables named X are not counted |
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
- **Registry (C7, C8, C9):** a per-unit function-table diff costs 28 ms (5.2) / 7 ms (5.3) per update — +4.3 s / +1.07 s to load all of kcl if done per file. So `kk.unit`/`kk.uses` set a dirty flag and ONE diff runs lazily at the next `declareClass`/`.new` (capture: 5.3 `compgen -V`, 5.2 a temp file + `$(<…)`, no fork). Several units MAY share a namespace (`kk.` is defined by 5 files, `ths.` by 3); class namespaces and instances (`${X}_class` set) are excluded from the namespace set; class names come from the class registry. The `.new` lookup costs 0.5–0.7 µs (≈1 %).
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

## 8. Phases (refined)

| phase | content | gate |
|---|---|---|
| **U1a** kkore loader | `kbool.sh`; `kuse.sh` rewrite: loader guard, `kk.unit` (rc 0/1/2, `__kk_unit_rc`, name = stem, `-ef` identity, cycle by frame index, incomplete-unit error, `--forget`), `kk.uses` (`set --`, plain source, name index of headered files, caller dir → project → system, `\` as path char, forget on failure, KK_UNIT_DIR save/restore), `kk.defined`; old `kk.use`/`kk.getScriptDir` removed | new kkore tests red-first; kkore + kklass suites unchanged, both bashes |
| **U1b** config + project | the key = value reader (repeat-to-append lists, CR, `#`); lookup chain env → project → `~/.kbool` else `$USERPROFILE/.kbool` → `/etc/kbool` else `$ProgramData/kbool` → defaults (fixture dirs via env overrides; unset USERPROFILE); `kk.project PATH|NAME` (paths relative to the project file, ordering rule U37), `.ckk` dir, debug level, defines | new tests; both bashes |
| **U2** kklass | class sites (frame chain, `-ef` on file parts); Duplicate identifier + poison; header-less re-source sink (C6 state machine incl. Pascal static restore + scratch cleanup) with one WARNING; prompt-only interactive allowance; lazy namespace registry checked in `declareClass`/`.new`; DSL verb names refused (U35); `.ckk` registration + `kk.uses kklass` in compiled files; `uses` synonym in the Pascal DSL; `.kkp` `unit`/`uses` translation (U36) | 119/121/135 updated as listed; kklass suite + new tests, both bashes |
| **U3** kkore + kklass modules migrate | two-line headers; `ke.setTrap`; runtime dir variables kept where C19 says | kkore, kklass and every kcl suite (all units source kklass) |
| **U4** kcl (29 files, in groups) | headers; drop `_X_SOURCED` and hard-coded `../../kklass/...`; footprint tests updated | per-group suites; then the master sweep on both bashes |
| **U5** docs | kklass_book "Units and uses", kcl README §1, kkore docs | — |

Red-first ideas per phase: the critic5 report (copied into the ledger when the phases start).
