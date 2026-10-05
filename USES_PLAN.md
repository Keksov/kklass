# `uses` — Pascal-like unit inclusion and duplicate identifiers (DISCUSSION DRAFT)

**Status: ALL TOPICS DECIDED by the owner 2026-10-05 (§5 U1–U17, §6 U18–U33); critic next; no code.**
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
