# `kk.image` — a general kbool load image (plan)

**Status: ACCEPTED rev 3 (owner answers 2026-11-23).** Rev 1 → independent critic
(`scratchpad/p4/image_critic/`) → rev 2 (the supervisor's decisions on the findings, table
§R) → the owner answered Q1–Q9 the same day: decisions **IMG-D1…D9** (§D), folded in here as
rev 3. Nothing is implemented. Ledger: [`image_ledger.json`](image_ledger.json).

Origin: fv PLAN **D35** (P4 owner answer Q4 = b, 2026-11-22): kbool gets a general load
image; `kk.image UNIT…` behaves like `kk.uses UNIT…` but sources a valid saved state of the
unit closure instead of loading it; `bin/fvdlg` is its first user. Requirements:
`kcl/docs/dev/fv/P4_DESIGN.md` §11 (P4 critic findings H1, H2, M1, M2).

Inputs read: P4_DESIGN §0.1, §1.3, §6.2, §8, §10 Q4, §11; the P4 prototype and the P4
critic's `diff/`; this folder's `USES_PLAN.md` / `uses_ledger.json`; `kkore/kuse.sh`,
`kbool.sh`, `kklass/kklass.sh` (class sites, the duplicate-class guard, `__kk_ft`,
`kk._fn_text_cr`, `kk._body_fns_for`), every kcl unit's load-time code;
`ktests/docs/GATE_FOR_AGENTS.md`; the image critic's notes and reproducers.

How numbers are marked: **measured** = on this laptop (Windows 11; Git-bash 5.3.15, MSYS2
5.3.9, Cygwin 5.2.21) with the number of runs — indicative only (battery throttling);
**est.** = estimated. **Every target is a CI bench row** (Linux rows; Windows rows as ratios,
fv D20) — the owner's rule. Probes: `scratchpad/p4/image/` (Appendix A).

---

## D. Owner decisions (2026-11-23)

| # | question | answer | what it means in this plan |
|---|---|---|---|
| **IMG-D1** | Q1 how a changed file is noticed | **c + a flag** | `KBOOL_IMAGE_CHECK=stat|dates|hash`; default `dates` on Git-bash / MSYS2 / Cygwin, `stat` on Linux / macOS / FreeBSD; an invalid value → the default + a debug line; the effective mode is part of the key; `KBOOL_VERSION` in `kbool.sh`, bumped by a release-checklist step and asserted by a test (§7.6) |
| **IMG-D2** | Q2 one image per script or chained | **b (chained) + a flag** | `KBOOL_IMAGE_CHAIN=on|off`, default `on`: units loaded before `kk.image` (the prior set P) join the key; the image holds only this call's delta; a base check and the undo work on the slots the delta touches; a chained simulation in a fresh process; `off` = rev 2's first-load-only rule (§7.7) |
| **IMG-D3** | Q3 messages | **b** | silent for "cannot write", holds and refusal rules; **one WARNING** when an existing image file fails a trust check (§3) |
| **IMG-D4** | Q4 location | **b** | per-user; on the Windows runtimes without `LOCALAPPDATA`: `$USERPROFILE/AppData/Local` when set, else the **`$HOME/.cache` fallback**; the MSYS2 / Cygwin home-inside-the-install-folder risk stays visible (§7.3, §8.2) |
| **IMG-D5** | Q5 hook form | **a** | explicit `kk.settings FN [VAR…]` |
| **IMG-D6** | Q6 internal reload guards | **a** | the 88 `__` self-defaults stay at load, image-held; exported `__` names are not settings (documented) |
| **IMG-D7** | Q7 CR functions | **a** | the writer reuses kklass's `kk._fn_text_cr`; no unit edits |
| **IMG-D8** | Q8 a damaged image | **a** | source under `if`, end mark, undo, normal load; a flipped byte that still parses is not detected |
| **IMG-D9** | Q9 class bodies on bash 5.1 | **a** | raw `declare -f`; on bash < 5.2 no image when a function text holds `&> "$…` |

---

## R. Rev 2: critic findings → where the plan handles them

| # | finding (critic) | supervisor | where now |
|---|---|---|---|
| H1 | tawk / tfind / tsed append to tutil's hook VARs `TUTIL_OUT_PREFIXES/SUFFIXES` at load; the rev-1 check (re-run hooks after the load) cannot see it (`reg.sh`: 4 / 3 entries instead of 7 / 10) | accept | §5.2 simulated image start (in a fresh process when chained, §7.7); §5.4 tawk / tfind / tsed get hooks; §5.5 lint; §12 the simulation test in I1a / I1b |
| H2 | a repeated miss costs ~5× a plain load; silent repeat-miss triggers (callers with different local units, caller spelling, `VERBOSE_KKLASS` not hashed, future mtimes, blocked renames) | accept all | §7.1 the file-name hash covers every key row + resolved request paths (+ the prior set, D2); §7.2 `-ef`; §6.2 future-mtime rule; §7.5 repeat-miss guard; §7.4 silent rename failure; §10 / §11 alternating callers |
| H3 | kkore / kbool.sh / kimage.sh not stamped | accept | §7.1 stamped with the closure |
| M1 | dependency shadowing, an edit during the write window, dates blind to zip extraction | accept | §7.2 dependency edges per start (header form); stamps / reference before the load; D1 `KBOOL_VERSION` |
| M2 | the undo unsound; flipped byte undetectable | accept | §6.1 final block before registration; §8.3 undo of units / classes / functions / variables and, chained, of touched base slots; flipped byte: not detected; tpipe bug → ledger, fixed in I1b |
| M3 | `set -e` caller killed; readonly arrays; stderr noise | accept | §9 source under `if`, stderr captured; readonly pre-check; §8.3 failure paths |
| M4 | Q7 misdescribed; OSTYPE-based CR detection wrong | accept | §6.4 `kk._fn_text_cr` (D7) |
| M5 | bash 5.1 `>&"$fd"` → `&> "$fd"` | accept | §6.3 refusal on bash < 5.2 (D9) |
| M6 | writer speed unexplained | accept | §6.2 profile; miss target to be measured |
| M7 | parse options not keyed | accept | §7.1 `extglob`, `expand_aliases`, `BASH_COMPAT` |
| M8 | Windows trust vacuous on `noacl`; `ln -s` copies | accept | §8.2; tests with `mklink /J` |
| L | root, base ancestors, pruning, laptop targets, aliases / function attributes / hash table, BSD `stat`, `set -a`, temp pruning, disk full, I1 critic | accept all | §8.1, §7.4, §6.3, §3, §7.1, §11, §12 |

---

## 0. Summary

* **API** (§3). `kk.image UNIT…` = `kk.uses UNIT…` (same rc, same units loaded), through an
  image when a valid one exists; else a normal load, then the image is written for the next
  start (unless a hold says not to). `--rebuild | --forget | --path`; `KBOOL_IMAGE=off`,
  `KBOOL_IMAGE_DIR`, **`KBOOL_IMAGE_CHECK=stat|dates|hash`** (D1), **`KBOOL_IMAGE_CHAIN=on|off`**
  (D2). Any doubt = a normal load; one WARNING only for an untrusted image file (D3).
* **Owner: kkore** (§2): hit path in `kkore/kuse.sh`, writer in a new `kkore/kimage.sh`
  sourced only on a miss; kklass one line. The plan stays next to `USES_PLAN.md`.
* **What it holds** (§4): the **delta of this `kk.image` call** — its units' functions,
  variables, kklass tables, registration, and its changes to slots that existed before (the
  prior units' tables, kkore's), each with the value it had before so a start can check and
  undo them. **Never**: kbool.sh's state, the prior units themselves, exports, hook outputs,
  pids / fds / traps / jobs / options / aliases / the hash table, the name index,
  caller-keyed entries, lazy data, runtime instances.
* **Settings hooks** (§5): `kk.settings FN [VAR…]` (D5); **79 load-time reads in 33 files**;
  the writer proves the hooks complete by a **simulated image start** (subshell without a
  prior set; a fresh process with one).
* **Key** (§7): format, `KBOOL_HOME`, `$BASH`, `BASH_VERSION`, `OSTYPE`, `MACHTYPE`, `EUID`,
  parse options, the check mode, `KBOOL_VERSION`, the request and its resolved files, **the
  prior set P in load order with its files**, the merged config, `VERBOSE_KKLASS`; stamps of
  the closure, P's files, kbool.sh, kkore, kimage.sh, kklass.sh, taken before the load; every
  dependency edge re-checked per start.
* **Measured**: sourcing the fv.dlg image **76–83 ms** (three runtimes, 5 runs each) vs a
  **~650–750 ms** load; all 46 units **186 ms vs 2615 ms**. Hit path est. **~105 ms** on the
  laptop, **65–100 ms** on CI Linux; fvdlg first frame est. **0.10–0.15 s** CI Linux (target
  ≤ 0.3 s).
* **Stages** (§12): I0 kkore (critic) → I1a fv hooks + simulation test (critic) → I1b other
  hooks + tpipe fix (critic) → **I2a** image core, unchained (critic) → **I2b** chaining +
  flags (critic) → I3 env-diff + round trip incl. chained starts (critic) → I4 perf + docs →
  I5 `bin/fvdlg`.

---

## 1. What the probes say

| # | probe (scratch `p4/image/` unless noted) | result |
|---|---|---|
| M1 | `run_locdiff.sh` — all 46 units under no locale vs `LANG=ru_RU.UTF-8`, `LC_ALL=C`, `PATH=/nonexistent`; Git-bash, 1 run each | ru: `__FV_KB_LOC`, `__FV_VS_LOC`, the `LC_CTYPE` export; C: the export; PATH: `TFILE_USE_CP`. `declare -f`, `shopt`, `set -o`, traps identical |
| M2 | `run_envdiff.sh` — 244 candidate names exported | every difference a self-default taking the preset, a locale item or a pid |
| M3 | `toplevel.sh` static scan | 125 self-defaults (37 public, 88 internal), 28 locale blocks, 1 `command -v`, preset guards |
| M4 | delta image of fv.dlg's closure (14 units), element-wise arrays, 1.71 MB | sourced in 77–78 / 77–83 / 77–79 ms (Git-bash / MSYS2 / Cygwin, 5 runs each); `kbool.sh` 6–8 ms; a normal load 731–746 ms (1 run each) |
| M5 | compound `declare -p` arrays | 94–96 ms and CR-corrupt on MSYS; critic: 40 k elements as one compound line 162–182 ms vs element lines 71–83 ms |
| M6 | image vs real load (fv.dlg on three runtimes, 46 units on Git-bash; critic `imghit.sh` under another environment) | differences only `__KK_UNIT_BOT` (+1, inert), caller-keyed entries, `__kk_ft`, `__FV_VW_OWNER`, `LC_CTYPE`, `RESULT`, CR functions; `KBOOL_HOME` spelled `C:/…` vs `/c/…` on Cygwin |
| M7 | MSYS bash and CR (+ critic `ctl.sh`) | only CR is dropped when text is parsed: compound arrays silently, function texts on `source` and `eval`; element / scalar assignments fine; kklass records Cygwin 5.2.37 dropping CR too |
| M8 | CR bytes after loading all 46 units | 12 in 11 functions (9 outside kbool.sh) |
| M9 | the 46-unit image | 4.37 MB, 186 ms vs 2615 ms (Git-bash, 1 run) |
| M10 | hit-path pieces (median of 9; FNV 5), G / M / C | request `kk._unit_find` with a fresh index 6.6 / 6.6 / 6.2 ms; `-nt` × 14 files 2.6 / 2.6 / 2.4 ms; one `stat` 25 / 30 / 47 ms; one `cksum` 29 / 35 / 48 ms; FNV-1a over 300 chars 3.2 / 2.8 / 2.9 ms; hooks (upper bound) 1.1 / 1.0 / 1.0 ms; header 0.5 ms; a fork 15 ms |
| M11 | `read -N` + length check + `eval` vs `source` | 111 vs 78 ms (3 runs each, Git-bash) |
| M12 | writer profile (fv.dlg, Git-bash, 2 runs) | before: `declare -p` read 44–45 ms, function texts 140–143 ms; load 0.67–0.70 s; after: variable loop 2.80 s, of it ~1.8 s reading `declare -p` from a pipe — through a temp file the write is **3.16 → 1.39–1.44 s**; arrays 134–143 ms; ~0.9 s per-line work left; function compare 130–136 ms; `declare -f` emit 55–57 ms |
| M13 | kklass at load | keeps two fds for `__kk_ft` |
| M14 | Windows trust | `noacl` on all three; `-L` true for a junction, `ln -s` copies; MSYS2 started from Git-bash: no `LOCALAPPDATA`, `HOME=/home/1` inside `C:/bin/msys64` |
| M15 | dependency edges (fv.dlg: 20 edges, 14 not kkore / kklass), G / M / C | full `kk._unit_find` each 14.5 / 14.5 / 15.4–16.2 ms; header form 2.2 / 1.7 / 1.5 ms |
| M16 | readonly pre-check, naive | 3.9 / 4.4 / 6.1 ms; bash's own names skipped est. < 0.5 ms |
| M17 | kklass body functions (fv.dlg) | 210 of 1395 functions; re-made from texts in 23–25 ms |
| M18 | bash-5.1 redirect hazard in today's code | none |
| critic | `reg.sh`, `shadow.sh`, `nt.sh`, `undo.sh`, `reload.sh`, `ro*.sh`, `ren.sh`, `run_opt*.sh` | registry loss; dependency shadowing; write-window edit, `cp -p`, future mtime; undo leaves "declared again; ignored" classes; tpipe forget + reload fails; readonly re-declare under `set -e` exits, a readonly array re-declare exits always; a bash reader keeps old bytes across a rename, a native holder blocks it; caller options change no load state |

---

## 2. Owner: kkore (proposal)

| piece | where | why |
|---|---|---|
| `kk.image` hit path (~180 lines) | `kkore/kuse.sh` | needs the unit tables and `kk._unit_find` |
| writer, `--rebuild` / `--forget`, simulations (~400 lines) | new `kkore/kimage.sh`, sourced on a miss only | the slow path costs nothing on a hit |
| `kk.settings`, `kk.localeDefault`, the load-order list `__KK_UNIT_ORDER` (~60 lines) | `kkore/kuse.sh` | header-level verbs; the order list keys chained images (§7.7) |
| `KBOOL_VERSION` | `kbool.sh` | D1 |
| `kk.settings : __kk_ft` | `kklass/kklass.sh`, 1 line | pid- and fd-bound state |
| CR rewrite | kklass's `kk._fn_text_cr` (D7) | proven path |
| hooks | each kcl unit (§5.4) | — |
| tests | `kkore/tests/0xx_Image*.sh`; kcl (simulation, env-diff, lint); a kbool master test for `KBOOL_VERSION` | — |

---

## 3. API

```bash
source /path/to/kbool/kbool.sh      # ALWAYS fresh: config levels, root, $BASH, kkore state
kk.uses tstringlist                 # optional: earlier units (the prior set, D2)
kk.image fv.dlg || exit             # = kk.uses fv.dlg, through an image when one is valid
```

| call / variable | does | rc |
|---|---|---|
| `kk.image UNIT…` | as `kk.uses UNIT…`. Hit: §9. Miss: `kk.uses`, then write (§6) unless a hold says not to (§7.5). Not applicable — `KBOOL_IMAGE=off`, `KBOOL_IMAGE_CHAIN=off` with units already loaded, inside a unit's load, `set -a`, no trusted folder: plain `kk.uses`, nothing read or written | kk.uses' rc; a hit is 0 |
| `kk.image --rebuild UNIT…` | a normal load, then write even when valid; clears a hold | the load's rc |
| `kk.image --forget UNIT…` | delete this request's images and holds (every key and prior set) | 0 / 2 |
| `kk.image --path [UNIT…]` | the image path this start would use; without units the folder | 0 valid, 1 none / stale / refused / held, 2 usage |
| `KBOOL_IMAGE=off` (or `0`) | every call is `kk.uses` | — |
| `KBOOL_IMAGE_DIR=DIR` | replaces the base folder (same checks; the only folder `EUID` 0 uses) | — |
| **`KBOOL_IMAGE_CHECK=stat|dates|hash`** (D1) | how changed files are noticed (§7.6); default `dates` on `OSTYPE` msys* / cygwin*, `stat` elsewhere; unset, empty or anything else → the default, and with `VERBOSE_KKLASS=debug` one line `kbool: image: KBOOL_IMAGE_CHECK=<v> is not stat|dates|hash; using <default>` | — |
| **`KBOOL_IMAGE_CHAIN=on|off`** (D2) | `on` (default): an image may sit on top of units loaded before; `off`: only when no non-system unit is loaded yet (rev 2's rule). An invalid value → `on` + a debug line | — |

* **Messages (D3)**: nothing on the normal output for "cannot write", holds, refusals, stale
  images; **one WARNING** when an existing image file fails a trust check:
  `kbool: WARNING: image ~/.cache/kbool/image/v1/fv.dlg-1a2b3c4d.img is not trusted (owned by bob); loading normally`
  (not repeated within the process). `VERBOSE_KKLASS=debug` prints a `kbool: image: …` line
  for every reason.
* `set -a` on: not applicable on both paths (every image assignment would be exported).
* `kk.project` before `kk.image` is fine (the merged config is keyed).

---

## 4. What the image holds and never holds

| state | in the image? | why |
|---|---|---|
| kbool.sh itself | **never** — sourced fresh | config, root, `$BASH` current |
| **the prior set P** (units loaded before this call: their functions, variables, classes) | **never** — they are in the shell already; P's names, load order and files are in the key (§7.7) | the image is this call's delta |
| this call's functions, incl. redefinitions of earlier functions | **yes**, `declare -f` text, CR-rewritten (§6.4); a redefined earlier function also records its earlier text's hash in the base list | — |
| variables this call created | **yes**: arrays element by element, scalars `declare -g…`; readonly flags in the final block | M4, M7 |
| **slots that existed before this call and it changed** (kkore tables, P's kklass tables, a P unit's registry, a scalar) | **yes, as element deltas** (add / change / `unset 'X[k]'`), each recorded in the **base list** with its value before (or "absent") | the start checks the base before sourcing and the undo restores it (§7.7, §8.3) |
| kkore registration entries of this call's units | **yes**, after the final block, before the end mark | later `kk.uses` / `source` are no-ops |
| caller-keyed entries, the name index, dependency resolutions | **never** | per start |
| kklass tables and class variables of this call's classes | **yes**, final block | — |
| kklass instances | runtime instances never; at-load instances as plain state (none today) | — |
| `__kk_ft`; exports; exported functions; hook VARs; shell-owned / scratch names | **never** | — |
| pids, fds (kklass's pair excepted), traps, jobs, coprocesses, options, `umask`, aliases, the hash table, function attributes | **never**; a change during the load → no image | — |
| lazily sourced data | **never** | written right after the load |
| `__KK_UNIT_BOT` of complete units | held | inert; allow-listed |

---

## 5. Settings hooks

### 5.1 The rule

A load-time statement goes into its unit's hook when its result can differ between two starts
with the same key: (1) it reads the environment or a caller's earlier value of a **public**
name (`${X:-d}`, `${X-d}`, `${X:=d}`, `X+=()`, `[[ -z ${X[*]+x} ]]` guards, appends to another
unit's public registry); (2) the locale or a locale export; (3) `PATH` probes; (4) the process
(`$$`, `$BASHPID`, fds, pids); (5) anything else not a function of the unit's files and the key.
Internal `__` self-defaults stay at load (D6). Runtime-only facts (`OSTYPE`, `/proc/version`,
`$BASH`) are keyed.

### 5.2 `kk.settings FN [VAR…]` and the simulated image start

* Called in a unit's load after FN is defined; runs FN **at once**, records `UNIT<US>FN` in
  `__KK_UNIT_SETTINGS` (load order) and each VAR in `__KK_SETTINGS_VARS` (several units may list
  one VAR: tutil owns `TUTIL_OUT_*`, tawk / tfind / tsed append in their own hooks). FN may be
  `:`. rc = FN's rc (`|| return`); 2 outside a unit's load / bad arguments. `kk.unit --forget`
  drops the entries.
* `kk.localeDefault` (kkore): `[[ -n ${LC_ALL:-}${LC_CTYPE:-}${LANG:-} ]] || export LC_CTYPE=C.UTF-8`.
* **The writer's proof — a simulated image start** (H1):
  * **no prior set**: in one subshell (the user's process untouched) every hook VAR of this
    call's hooks is put back to its value before the load, every hook runs in load order, and
    the full state (variables with attributes, functions, exports) must equal the end-of-load
    state;
  * **with a prior set** (D2): in a **fresh process** with the same environment — `source
    kbool.sh`, `kk.project` when the writer had one, `kk.uses` P in its recorded load order,
    then the candidate image sourced exactly as a start would (base check, hooks) — and its
    state dumped; every name present in that process must equal the writer's end-of-load
    state (names only the writer's script made are ignored). This also proves that the delta
    does not depend on changes the writer's script made to P between its load and `kk.image`
    (a P class modified at run time would show here).
  * Any difference → no image, a hold with the first differing name (§7.5).
* On an image start the hooks of this call's units run after the image is sourced, in load
  order; P's hooks ran when P loaded.

### 5.3 Cost per image start

All of today's candidates together: 1.0–1.1 ms (M10).

### 5.4 The inventory

79 items in 33 files (M1–M3, critic `reg.sh`).

| file | load-time reads | change |
|---|---|---|
| 28 units with the locale block (dateutils, fv.drivers, fv.histlist, fv.keyboard, fv.mouse, fv.video, fv.views, math, tawk, tcustomapplication, tdirectory, tfile, tfind, tgrep, thead, thttpapplication, thttpmessage, thttprouter, thttpserver, tinifile, tpath, tpipe, tregex, tsed, tstopwatch, tstringhelper, ttail, tutil) | `export LC_CTYPE=C.UTF-8` when no locale is set | `kk.localeDefault` in the hook, `LC_CTYPE` a VAR |
| fv.keyboard | `fv.keyboard._locale` → `__FV_KB_LOC`; `FV_KEY_FD` | hook |
| fv.video | `fv.video._load` → `__FV_VS_LOC`, `FV_VIDEO_ASCII`; `FV_SCREEN_W/H`, `FV_VIDEO_ON`, `FV_VIDEO_RESIZED`, `FV_TTY_FD`, `FV_VIDEO_ASCII`, `FV_VIDEO_COLORS`, `FV_VIDEO_OUT_FD` | hook |
| fv.views | 21 public self-defaults; `__FV_VW_OWNER` (pid) | hook |
| fv.app | `FV_APP`, `FV_DESKTOP`, `FV_STATUSLINE`, `FV_MENUBAR` | hook |
| fv.dialogs | `FV_CLIPBOARD` | hook |
| fv.dlg | `FV_DLG_CMD`, `FV_DLG_TAGS+=()` | hook |
| fv.histlist | `FV_HISTORY_SIZE` | hook |
| fv.msgbox | `FV_MSGBOX_TITLES` / `_BUTTONS` caller presets | hook |
| tutil | `TUTIL_OUT_PREFIXES` / `_SUFFIXES` presets | hook |
| tawk, tfind, tsed | registry appends to `TUTIL_OUT_*` | own hooks (idempotent loops) |
| tfile | `TFILE_USE_CP` (`command -v cp`, readonly) | hook |
| tpipe | locale block; **pre-existing bug** `tpipe.sh` 909–911 unguarded `declare -gr` (forget + reload fails) | hook; guards (I1b, with a test) |
| kklass | `__kk_ft`; `KKLASS_EXPORT_FUNCTIONS` warning | `kk.settings : __kk_ft`; warning hook |

Not needing a hook: fv.menus, fv.unicode, tarray, tdictionary, thashset, tlist, tobjectlist,
tqueuestack, tstringlist; use-time reads; the 88 internal self-defaults (D6). The 9 CR
functions need no unit change (D7).

### 5.5 Lint (kcl/tests/001_UnitFiles, I1a)

* no public self-default, locale read / export, PATH probe, `$$` / `$BASHPID` on a load-time
  line outside a function passed to `kk.settings`;
* no load-time line outside a hook writes a VAR another unit declared.

---

## 6. The image file and the writer

### 6.1 Format v1 (order matters for the undo)

```
# kbool image v1                                    line 1: magic + format
__kk_img_key=…                                      line 2: the full key (%q)
__kk_img_files=(…) __kk_img_edges=(…)               line 3: stamped files + stamps; DEPDIR|NAME|FILE edges
__kk_img_units=(…) __kk_img_classes=(…) __kk_img_vars=(…) __kk_img_fns=(…) __kk_img_ro=(…) __kk_img_wtime=…
__kk_img_base=(…)                                   line 5: touched pre-existing slots: KIND|NAME|KEY|BEFORE
<functions>
<variables>                                         declare -g (no -r); arrays X=() then X[k]=v; deltas X[k]=v / unset 'X[k]'
<final block> readonly flags, kklass tables
<kkore unit tables>                                 registration LAST
<hook list>
__kk_img_end=<nonce of line 2>
```

`BEFORE` is `%q` of the earlier value, or `-` for "absent"; a redefined function's slot holds
a hash of its earlier `declare -f` text. Written under `LC_ALL=C`. Header lines are `read`
before anything is sourced.

### 6.2 The writer (miss path)

1. Before the load: `declare -p` into a temp file and read it (never a pipe); function names
   and texts of existing functions; traps, options, aliases, `BASH_CMDS`, fds; P (names in
   `__KK_UNIT_ORDER` order, files); the stamps per the check mode (`stat` output, a `.ref`
   file created now, or `cksum` output) — taken now, so an edit during the load makes the next
   start stale.
2. `kk._uses CALLER …`.
3. The delta, with the base list for every touched pre-existing slot; the refusal rules
   (§6.3); the simulated image start (§5.2).
4. Future mtimes: the temp file is created now; any stamped file `-nt` it → no write, a hold.
5. The image is built in memory and written by **one** `printf '%s'` into
   `NAME.img.tmp.$BASHPID.$SRANDOM` (`umask 077`, `set -C`), rc checked.
6. `mv -f` the image, then the `.ref` file (`dates` mode) — image first. Pruning (§7.4).

Forks on a miss: the simulation (subshell, or a fresh `bash` with a prior set), `mkdir -p`
(first time), `mv` ×1–2, `rm` when pruning, `stat` / `cksum` per mode. Speed: M12 (the pipe
read was ~1.8 s of 3.16 s; 1.4 s with a temp file; ~0.9 s per-line work left for I2a). The
chained simulation adds a load of P in the child. **The miss target is to be measured** (§11).

### 6.3 Refusal rules (no image; the units stay loaded; a hold + a debug line)

* a new or changed export or exported function outside the hooks' VARs;
* changed traps, options, `umask`, jobs, coprocesses, aliases, the hash table, function
  attributes; fds other than kklass's pair;
* the simulated image start differs (§5.2);
* a CR function `kk._fn_text_cr` cannot rewrite (rc 1), or CR on a CR-dropping parser without
  kklass loaded (§6.4);
* bash < 5.2 and a function text with `&> "$` / `&>"$` (D9);
* a stamped file with a future mtime; a load failure; failed `--optional` units; `set -a`;
* a refused or uncreatable folder (§8).

### 6.4 CR (D7)

Every function text holding a CR byte goes through **`kk._fn_text_cr`** (kklass.sh 1089–1185,
.ckk format 4): one `eval` probe of the running parser, then each CR rewritten into the quoting
the parser restores, verified by re-printing. rc 1 → refusal. Arrays never hold raw CR (`%q`
element lines).

---

## 7. Key, staleness, location, chaining

### 7.1 The key

| part | read | fork-free |
|---|---|---|
| format `v1`; `KBOOL_HOME` as normalised; `$BASH`, `BASH_VERSION`, `OSTYPE`, `MACHTYPE`, `EUID` | variables | yes |
| parse options: `extglob`, `expand_aliases`, `BASH_COMPAT` | variables | yes |
| **the effective check mode** (`stat` / `dates` / `hash`, after defaulting, §7.6) | D1 | yes |
| **`KBOOL_VERSION`** (all modes) | kbool.sh | yes |
| the request and each resolved request file, normalised | `kk._unit_find` + `kk._unit_lexnorm` | yes |
| **the prior set P**: non-system unit names in `__KK_UNIT_ORDER` order with their normalised files (empty when none) | D2, §7.7 | yes |
| the merged config (`unitpath`, `defines`, `debug`, `ckkdir`, project file) | `__KK_CFG`, `__KK_PROJECT` | yes |
| `VERBOSE_KKLASS` | variable | yes |
| stamped files: the closure, **P's files**, `kbool.sh`, `kkore/{kuse,klib,kerr,kvar,kcfg,kimage}.sh`, `kklass/kklass.sh` | per mode (§7.6) | `dates` yes; `stat`, `hash` one fork |

**The file name**: `<request, sanitised, ≤ 64 chars>-<FNV-1a 32-bit hex over every key row
except the stamps — incl. the check mode, the resolved request paths and P>.img`. Different
callers, prior sets or modes get different files. FNV over ~300 characters 2.8–3.2 ms (M10);
I2a may take a cheaper string hash and measure it.

### 7.2 Invalidation (each start)

* a key row differs (line 2) or the format is unknown;
* the request resolves to another file — compared with `-ef`;
* a dependency edge changed (header form: one `-e DEPDIR/NAME.sh` and the fresh index's first
  candidate compared, a full `kk._unit_find` only on a difference; 1.5–2.2 ms for fv.dlg, M15);
* a stamped file changed per the mode (§7.6), or is missing;
* (chained) **the base check fails** (§7.7) — not "stale": the image does not fit this shell;
  a plain `kk.uses`, no write.

### 7.3 Location (D4)

| runtime | base, first that is set |
|---|---|
| Linux, macOS, FreeBSD | `$XDG_CACHE_HOME/kbool/image/v1/`, else `$HOME/.cache/kbool/image/v1/` |
| Git-bash, MSYS2, Cygwin | `$LOCALAPPDATA/kbool/image/v1/` → `$USERPROFILE/AppData/Local/kbool/image/v1/` (the same per-user folder, reached when only `LOCALAPPDATA` is missing) → **`$HOME/.cache/kbool/image/v1/`** (the owner's fallback); `\` → `/` |
| any | `KBOOL_IMAGE_DIR` replaces the base; for `EUID` 0 it is the only place images are read or written |

When the `$HOME/.cache` fallback is taken, one debug line names it and, if `$HOME` lies
inside the runtime's install folder (the folder holding `$BASH`), says so (§8.2).

### 7.4 Atomic write, concurrent writers, size, pruning

* Temp + rename; a bash reader keeps old bytes; a blocked rename ("Device or resource busy")
  is silent, the temp removed, the old image kept.
* Two writers: the last rename wins, both valid. No lock.
* Size: fv.dlg 1.7 MB, all 46 units 4.4 MB; a chained image holds only its call's delta
  (smaller than an unchained image of the same request).
* Pruning on each write (one `rm`): images whose header `KBOOL_HOME` no longer exists; older
  than 30 days (`__kk_img_wtime`); **more than 8 per (request, prior set) and more than 16 per
  request name** (chaining multiplies files) → the oldest; **more than 64 images or 256 MB in
  the folder** → the oldest; holds older than 1 h; temps of dead pids (`kill -0`).
  `kk.image --path` prints the folder for a full clean.

### 7.5 Holds: the repeat-miss guard and refusals

`NAME.hold` (one line: time, reason) for one (request, prior set, mode) — while younger than
1 h every start is a plain `kk.uses` with no write. Written when: an image of this name
written < 10 min ago is stale again (H2); the writer refused (§6.3: the same script would
refuse again — e.g. a script that changes a P class before `kk.image`, §5.2); a stamped file
has a future mtime. `--rebuild` and `--forget` clear it. Cost: one `-f` on the miss path.

### 7.6 The check modes (D1)

| `KBOOL_IMAGE_CHECK` | how | cost (laptop, M10) | blind to |
|---|---|---|---|
| `stat` (default on Linux / macOS / FreeBSD) | one `stat` over the stamped files before the load (GNU `-c '%s %Y %Z %i %u %a'`, BSD `-f '%z %m %c %i %u %Lp'`, flavour probed as kcl TPath does); compared per start | 1 fork: est. 1–2 ms Linux; 25–47 ms on the Windows runtimes | nothing practical (ctime cannot be set back by `cp -p` / unzip) |
| `dates` (default on Git-bash / MSYS2 / Cygwin) | `[[ FILE -ot NAME.ref ]]` for every stamped file, the `.ref` made before the load and its nonce in line 2; **`KBOOL_VERSION`** in the key catches release archives unpacked with old dates | ~0.18 ms per file, est. ~3.9 ms for ~21 | an unreleased copy with old dates copied over kbool (`cp -p`, a zip of a branch) |
| `hash` | one `cksum` over the stamped files | 1 fork, 29–48 ms on Windows, reads ~1.5 MB | nothing (content) |

A mode whose tool is missing (`stat` / `cksum` not on `PATH`, an unknown `stat` flavour) runs
as `dates` and that effective mode is keyed; a debug line says so.

**`KBOOL_VERSION`**: a plain `declare -g KBOOL_VERSION=0.1.1` near the top of `kbool.sh`
(not exported: a child shell sources kbool.sh itself). The release checklist gains the step
"bump `KBOOL_VERSION` in `kbool.sh` with the CHANGELOG heading" (a short "Releasing" section
in the kbool root `CONTRIBUTING.md`, I0), and a kbool master test asserts that `KBOOL_VERSION`
equals the newest `## X.Y.Z` heading of `CHANGELOG.md`, so a forgotten bump fails CI.

### 7.7 Chaining (D2)

* **The prior set P** = the non-system units registered complete when `kk.image` starts, in
  load order. kkore keeps that order in `__KK_UNIT_ORDER` (appended by `kk.unit` at
  registration, dropped by `--forget`; I0). P's names and normalised files are key rows and in
  the file name; P's files are stamped. `kk.uses tstringlist; kk.image fv.dlg` and plain
  `kk.image fv.dlg` are two images.
* **What the image holds**: only the delta of this call (§4); P is never in it. Slots that
  existed before and the call changed — kkore tables, P's kklass tables (`_KKLASS_TAKEN`,
  namespaces, a parent class's subclass lists), P's registries — are element deltas with
  their earlier values in the base list.
* **The base check** (hit path, before sourcing): every base-list slot must hold its recorded
  earlier value (or be absent); a redefined earlier function must still have its recorded
  text hash. Any difference → plain `kk.uses`, no write (the delta was made against another
  base). Cost est. 1–2 ms for a few hundred slots (µs per `[[ … ]]`); 0 slots beyond kkore's
  without a prior set.
* **The simulation** with a prior set runs in a fresh process (§5.2): P loaded normally, the
  image applied, compared — the image is valid for "P as its own load leaves it".
* **The undo** (§8.3) additionally puts every base-list slot back to its earlier value
  (checked equal before sourcing, so the undo restores exactly).
* **The repeat-miss guard and pruning** work per (request, prior set, mode) (§7.4, §7.5).
* **`KBOOL_IMAGE_CHAIN=off`**: any prior set → plain `kk.uses`, nothing written — rev 2's
  first-load-only rule.
* **Limit** (documented, R13): the base check sees the slots the delta *writes*, not what this
  call's load *read* from P. A script that changes P's state the call reads (e.g.
  `defineMethod` on a P class that a class of this call inherits) before `kk.image` gets the
  image made against an unchanged P. The writer side is covered (its simulation refuses when
  its own script did this); the reader side is not.

---

## 8. Security

### 8.1 Threat, model, checks

**Threat**: an image is shell code run by every start. **Model**: another local account, or
a foreign / stale file; not the user's own account, not root.

Checks before reading a byte (fork-free): the base is a directory, `-O`, not a symlink; from
`kbool/` down every folder `-d`, `-O`, `! -L`; the image `-f`, `-O`, `! -L`. Folders made
under `umask 077`. With `stat` mode also the modes (group / world writable → refused). `EUID`
0 reads and writes only under `KBOOL_IMAGE_DIR`. A user whose `~/.cache` is a symlink sets
`XDG_CACHE_HOME` / `KBOOL_IMAGE_DIR` to the real folder.

### 8.2 Windows runtimes: thin checks, and the home fallback (D4)

`noacl` makes `-O` always true and modes fake; the guard is the location's ACL. `-L` refuses
junctions and native symlinks; tests make links with `mklink /J`. `%LOCALAPPDATA%` and
`%USERPROFILE%\AppData\Local` admit only the user, SYSTEM and administrators.

**The `$HOME/.cache` fallback (owner's choice, D4) carries a visible risk**: MSYS2's home is
`C:\msys64\home\<you>` and Cygwin's `C:\cygwin64\home\<you>` — inside the install folder,
whose ACL is whatever the installer gave it (often writable by every local user when the
install was not made per-user). On a shared Windows machine another account could then plant
an image there, and on `noacl` no check would notice. Mitigations that keep the owner's
choice: the `USERPROFILE` step before it (same per-user folder as `LOCALAPPDATA`), folders made
under `umask 077`, a debug line naming the fallback and "inside the install folder" when
`$HOME` lies under the folder holding `$BASH`, and the README telling shared-machine users to
set `KBOOL_IMAGE_DIR` or `KBOOL_IMAGE=off`. When the user points `KBOOL_IMAGE_DIR` or
`LOCALAPPDATA` elsewhere on these runtimes, that folder's safety is the user's responsibility.

### 8.3 Failure paths (each ends with the units loaded)

| where | what happens |
|---|---|
| `KBOOL_IMAGE=off`, chain off with units loaded, inside a unit's load, `set -a`, no base | plain `kk.uses`, no write |
| trust check fails | plain `kk.uses`, no write, nothing deleted; **one WARNING** (D3) |
| key / format mismatch, stale, missing file, edge changed | miss path (`kk.uses`, then write or hold) |
| base check fails (chained) | plain `kk.uses`, no write |
| readonly collision (a name in `__kk_img_vars` readonly in the caller; bash's own names skipped) | plain `kk.uses`, no write |
| `source` fails or the end mark is missing | **undo**: drop the listed units' registration, `kk._unit_forget_class` for the listed classes, `unset -f` the listed functions, `unset -v` the listed non-readonly variables, **put every base-list slot back**; readonly flags that landed stay (units' reload guards keep readonly constants — tpipe fixed in I1b); then `kk.uses` under `if`, then rewrite or hold |
| a hook fails during a start | undo, then `kk.uses` (the unit's real error and rc) |
| the source itself | `if source "$img" 2>"$sink"; then` — errexit off inside the condition; `$sink` `/dev/null`, or a temp file printed under `VERBOSE_KKLASS=debug` |

**Not detected**: a flipped byte that still parses and leaves the end mark (D8).

---

## 9. The hit path (fork-free in `dates` mode; laptop Git-bash pieces, indicative)

| step | cost |
|---|---|
| `source kbool.sh` | 6–8 ms |
| flags, options, key rows, P from `__KK_UNIT_ORDER` | est. < 0.5 ms |
| the request: fresh index + `kk._unit_find` + `-ef` | 6.2–6.6 ms |
| file name hash (~300 chars) | 2.8–3.2 ms |
| trust checks; header (5 lines); `.ref` read | est. 0.2 + 0.6 + 0.5 ms |
| readonly pre-check | est. < 0.5 ms |
| dependency edges (header form) | 1.5–2.2 ms |
| base check | est. ~0.1 ms unchained, 1–2 ms chained |
| staleness: `dates` ~21 files / `stat` one fork | est. ~3.9 ms / 25–47 ms (Windows; Linux est. 1–2 ms) |
| `source` the image under `if` | 77–83 ms (fv.dlg) |
| hooks | ~1 ms |
| **total after bash's start** | **est. ~105 ms** (`dates`, unchained) vs `kk.uses fv.dlg` 731–746 ms |

Forks: **0** in `dates` mode (the Windows default); **1** (`stat` / `cksum`) in the other modes
(the POSIX default `stat`: est. 1–2 ms on Linux). CI Linux est. 65–100 ms; checked by §11.

---

## 10. Correctness tests

| test | stage | what |
|---|---|---|
| kkore `0xx_Settings` | I0 | `kk.settings` contract; `__KK_UNIT_ORDER` (order, `--forget`) |
| `KBOOL_VERSION` vs CHANGELOG | I0 | kbool master test |
| simulated image start, every unit | I1a / I1b | §5.2's subshell form as a harness; the H1 registry case; a fixture writing another unit's VAR must fail |
| kcl lint (001) | I1a | §5.5 |
| normal-load env-diff | I1a / I1b | moving reads changes no behaviour |
| tpipe forget + reload | I1b | under `set -e`, no readonly error |
| kkore `0xx_Image` contract | I2a | §3 incl. `KBOOL_IMAGE_CHECK` (each value, an invalid one → the default + the debug line, the mode in the key: switching modes uses another file), the missing-tool fallback to `dates`, `KBOOL_IMAGE_DIR`, `set -a`, inside a unit's load, `--optional`, interactive caller, a relative caller after `cd` |
| staleness per mode | I2a | content edit (same size), size change, `touch`, an edit during the write window, `cp -p` / old-dated copies (`stat` / `hash` catch; `dates` catches only a `KBOOL_VERSION` change — asserted as documented), a future mtime (no write, hold), removed file, kkore / kbool.sh / kimage.sh / kklass.sh edits, a shadowed dependency, the request shadowed in the caller's folder, `KBOOL_HOME` spellings, extglob, `BASH_COMPAT`, `VERBOSE_KKLASS`, a config change with no merged effect |
| alternating callers | I2a | two scripts, one with a local `app.sh`, alternating: 2 writes, then only hits |
| holds | I2a | repeat-miss; refusal; `--rebuild` / `--forget` clear |
| trust | I2a | symlink (POSIX) / junction (`mklink /J`, Windows), foreign or group-writable (POSIX), `EUID` 0 without `KBOOL_IMAGE_DIR`, unwritable folder; **the WARNING exactly once** (D3); the location chain on Windows: `LOCALAPPDATA` → `USERPROFILE` → `$HOME/.cache` with its debug lines |
| damage | I2a | truncation in each section, syntax error, another key's image, empty / binary file, format `v2` — under `set -e` / `set -u`: the script survives, the state equals a normal load, no "ignored" class; a flipped byte in a value: not detected (documented) |
| refusal | I2a | export, exported function, trap, option, alias, `hash` entry, `declare -ft`, fd, job, a hook VAR written after its hook, a CR function `kk._fn_text_cr` cannot rewrite, `&> "$f"` on bash 5.1 |
| rename / concurrency / readonly collision | I2a | as rev 2 |
| **chained starts** (D2) | I2b | `kk.uses tstringlist; kk.image fv.dlg`: miss writes a chained image, the next start is a hit, its state equals `kk.uses tstringlist fv.dlg` loaded normally (round-trip compare); the same request without P / with another P / P in another order → other files; a P file edited → stale; `KBOOL_IMAGE_CHAIN=off` (and an invalid value → on) |
| chained base check | I2b | the script pre-sets a slot the delta writes (a registry entry, a `_KKLASS_TAKEN` name) before `kk.image` → plain `kk.uses`, no write, correct state |
| chained writer simulation | I2b | the writer's script changes a P class (`defineMethod`) before `kk.image` → refusal + hold; the documented reader-side limit asserted as known |
| chained undo | I2b | truncated chained image under `set -e`: base slots restored, state equals a normal load |
| pruning caps | I2b | per (request, P), per request name, per folder |
| env-diff (every unit, unchained and chained) | I3 | image under A, start under B == a real load under B, except the allow-list |
| round trip, lazy data, behaviour | I3 | per bash version; layouts load lazily; fv.dlg headless widgets and demos equal from an image start |
| rows | I2a–I3 | Git-bash, MSYS2, Cygwin (gate.sh); CI 16 rows; the 5.1 VM gate |

---

## 11. Perf targets (CI bench rows only)

| row | what | target (CI Linux unless said) |
|---|---|---|
| `image.hit.fvdlg` | fresh process: `source kbool.sh; kk.image fv.dlg`, launch → return | **≤ 0.12 s**; Windows rows as ratios |
| `image.load.fvdlg` | the same with `KBOOL_IMAGE=off`, interleaved | logged; `hit / load` **≤ 0.2** |
| `image.hit.chain` | `source kbool.sh; kk.uses tstringlist; kk.image fv.dlg` (image hit) vs the same with `KBOOL_IMAGE=off` | `hit.chain − load(tstringlist)` **≤ 0.12 s**; ratio to the unchained hit logged |
| `image.check` | in-process: §9 without the source and the hooks | **≤ 10 ms** |
| `image.miss.fvdlg` | first start, folder emptied | **to be measured** (set in I4 from CI) |
| `image.alt` | alternating callers, 10 starts | after the first two: **0 writes**, each within `image.hit` |
| `image.forks` | forks on the hit path | **0** in `dates` mode; **1, named**, in `stat` / `hash` |
| `dlg1.proc.<widget>.image` | spawned `bin/fvdlg` through the image | **first frame ≤ 0.3 s**; exit logged |

The Linux rows run the POSIX default (`stat`); a second Linux row with
`KBOOL_IMAGE_CHECK=dates` shows the fork's share. Process rows use P4 §6.2's method. Perf runs
go through the `perf` branches.

---

## 12. Stages (re-checked for rev 3)

Each: Opus worker → supervisor review against the tree → critic where marked → fixes →
`ktests/tools/gate.sh` on the Windows bashes (+ the 5.1 VM gate for kkore / kklass changes) →
commit; CI on the perf branches; the hygiene block in every brief.

| stage | content | size (est.) | review / gate |
|---|---|---|---|
| **I0** kkore | `kk.settings`, `__KK_UNIT_SETTINGS` / `__KK_SETTINGS_VARS`, `kk.localeDefault`, **`__KK_UNIT_ORDER`**, **`KBOOL_VERSION`** in kbool.sh + the "Releasing" step in `CONTRIBUTING.md` + the CHANGELOG test; kkore tests; kkore README | ~90 + tests | **critic**; gate all + VM 5.1 |
| **I1a** fv hooks | 10 fv units; the lint; the simulation harness (subshell form) + normal-load env-diff for them | ~150 moved + ~250 tests | **critic**; gate kcl + 12 fv suites; CI |
| **I1b** other hooks | the remaining 23 files (tawk / tfind / tsed, tutil, tfile, tpipe incl. the readonly fix + test, locale-only units), kklass's line + warning hook; the simulation over every unit | ~130 moved + tests | **critic**; gate all; CI |
| **I2a** image core, unchained | hit path + `kkore/kimage.sh`: format v1 (incl. the base list — kkore's own slots), key + file name, **`KBOOL_IMAGE_CHECK`** (three modes, defaults, invalid values, missing tools), `KBOOL_VERSION` keyed, dependency edges, `-ef`, location chain (D4), trust + the WARNING (D3), refusals, the subshell simulation, CR via `kk._fn_text_cr`, the 5.1 rule, one-printf write, rename, holds, end mark + undo, readonly pre-check, source under `if`, `--rebuild` / `--forget` / `--path`; `KBOOL_IMAGE_CHAIN` present but only `off` behaviour (a prior set → plain load); writer profile first; tests of §10 for I2a | ~520 + ~650 tests | **critic** (security, staleness, fallback); gate all + VM 5.1; CI |
| **I2b** chaining | P in the key and stamps, deltas on P's slots, the base check, the fresh-process simulation, the undo of base slots, holds and pruning per (request, P), `KBOOL_IMAGE_CHAIN=on` default; tests of §10 for I2b | ~150 + ~250 tests | **critic** (base check soundness, the documented reader-side limit); gate all + VM 5.1; CI |
| **I3** env-diff + round trip | every unit, unchained **and chained** (P = tstringlist, tutil), on every CI row | ~350 tests | **critic** (allow-list); gate all; CI 16 rows |
| **I4** perf + docs | the `image.*` rows incl. `image.hit.chain`, `image.alt`, the `dates` Linux row; writer speed per I2a's profile; miss target from CI; docs (kkore README "Images" with the flags, kcl README unit rule, kklass book "Units and uses", the shared-machine note of §8.2) | ~150 + docs | supervisor; CI bench |
| **I5** fvdlg | `bin/fvdlg`: `kk.uses fv.dlg` → `kk.image fv.dlg`; `dlg1.proc.<widget>.image` rows (into P4 4e's suite or a skeleton 4e extends); fv.dlg README "Cost" | ~20 + bench | supervisor; fv.dlg suites; CI bench |

Rev 3 changes to the stage list: I0 gains `__KK_UNIT_ORDER`, `KBOOL_VERSION` and the release
step; rev 2's I2 is split into **I2a** (unchained core, both flags parsed) and **I2b**
(chaining), each with a critic; I3 adds chained env-diffs; I4 adds `image.hit.chain` and the
`dates` Linux row. I1a / I1b are unchanged.

---

## 13. Risks

| # | risk | mitigation |
|---|---|---|
| R1 | stale image runs old code | key + stamps (closure, P, kkore), edges, load-start reference; `stat` default on POSIX; `KBOOL_VERSION` for release archives on Windows; `--rebuild`, `--forget` |
| R2 | planted image | §8; thin on Windows `noacl` |
| R3 | a frozen environment | simulated image start, lint, env-diff per unit |
| R4 | CR corruption | element-wise arrays; `kk._fn_text_cr`, refusal on rc 1 |
| R5 | `declare -f` differences per bash | `BASH_VERSION` keyed; the 5.1 refusal; round trip on 5.1 rows |
| R6 | stack traces name the image file | documented; `KBOOL_IMAGE=off` for debugging |
| R7 | a damaged image half-applied | final block, registration last, end mark, undo incl. base slots; under `if`; flipped bytes not detected |
| R8 | repeat misses slower than no image | file names per caller / P / mode, `-ef`, future-mtime rule, holds, silent rename failure |
| R9 | a slow first start; slower still when chained (the fresh-process simulation loads P again) | writer profile; miss target from CI; holds stop repeated slow misses; README |
| R10 | cache growth, more with chaining | caps per (request, P), per request, per folder (64 files / 256 MB), age, missing root |
| R11 | new load-time reads later | lint, simulation, env-diff in kcl's suite; the writer refuses |
| R12 | load-time messages hidden | environment-dependent messages in hooks |
| **R13** | **chained reader-side limit**: a script that changes P's state the call reads (e.g. `defineMethod` on a P class a class of this call inherits) before `kk.image` gets an image made against an unchanged P | the base check covers written slots; the writer's simulation refuses its own such script; documented; `KBOOL_IMAGE_CHAIN=off` for such programs |
| **R14** | **the `$HOME/.cache` fallback on MSYS2 / Cygwin** lies inside the install folder, possibly writable by other local users, and `noacl` hides it | the `USERPROFILE` step first, `umask 077`, a debug line naming it, the README's shared-machine advice (`KBOOL_IMAGE_DIR` / `KBOOL_IMAGE=off`) |
| **R15** | `dates` (Windows default) misses an unreleased copy with old dates | `KBOOL_VERSION` for releases; `KBOOL_IMAGE_CHECK=stat` or `hash` per user; documented |
| R16 | a forgotten `KBOOL_VERSION` bump | the CHANGELOG test fails CI |

---

## 14. Owner questions — answered

All nine answered on 2026-11-23 (§D): Q1 c + `KBOOL_IMAGE_CHECK`, Q2 b + `KBOOL_IMAGE_CHAIN`,
Q3 b, Q4 b, Q5 a, Q6 a, Q7 a, Q8 a, Q9 a. The options the owner chose from are kept in short
form in the ledger's `questions_for_owner` (rev 2's full quiz texts were replaced by this
record; rev 2 was never committed).

---

## Appendix A. Probes (`scratchpad/p4/image/`; the critic's in `../image_critic/`)

| file | what |
|---|---|
| `NOTES.md` | raw notes and numbers (rev 1, rev 2, rev 3 sections) |
| `toplevel.sh`, `selfdef.txt`, `envreads.txt`, `upper_names.txt`, `hook_units.txt` | static scan (M3) |
| `envdump.sh`, `run_envdiff.sh`, `run_locdiff.sh` | env-diff (M1, M2) |
| `img_probe.sh`, `load_dump.sh`, `dumpfn.sh`, `rt_hit.sh`, `g/` | delta-image prototype and comparisons (M4–M6, M9) |
| `img_prof.sh`, `img_prof2.sh` | writer profile (M12) |
| `dp_test.sh`, `dp2-4.sh`, `cr1.sh` | `declare -p` forms, MSYS CR (M7) |
| `costs.sh` | hit-path pieces (M10) |
| `edges.sh` | dependency edges, readonly pre-check (M15, M16) |
| `bodyfns.sh` | kklass body functions from texts (M17) |
| `rdeval.sh` | read + eval vs source (M11) |
| `own.sh` | Windows ownership (M14) |
