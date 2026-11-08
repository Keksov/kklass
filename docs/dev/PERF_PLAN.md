# kklass — call-path speedup round (K)

**Created:** 2026-11-08, for the kcl TUI library (Free Vision model): a keypress
costs ~10 kklass calls, and at 0.2–0.6 ms a call they are 60% of the key.
**Ledger:** `perf_ledger.json` (this folder) — single source of truth for status.
**Branches:** work happens on `perf` in kklass and kbool (owner 2026-11-08: free
pushes to `perf`; `main` only after the owner's "go" at the end of the round).
**Harness:** kbool `tools/bench/` (cases.sh, bench.sh, prepare.sh) and
`.github/workflows/bench.yml` — runs on every push to kbool `perf`, on 11 rows
(Linux host + bash 5.1/5.2/5.3 Alpine + Debian 13 + Ubuntu 22.04 + Fedora 44,
macOS brew bash, Windows Git-bash/MSYS2/Cygwin), sides measured interleaved in
fresh processes; read the ratio between sides of ONE row.

## Owner decisions (2026-11-08)

| # | Question | Decision |
|---|---|---|
| D1 | Scope | K0–K5 approved; K6 (bind only the fields a body names) **rejected**: it silently breaks helpers that reach fields through dynamic scope and `eval`/`${!x}`. |
| D2 | Bodies as functions add a frame to `FUNCNAME`/`caller` | Accepted. |
| D3 | Order vs the TUI | In parallel: TUI L0/L1 do not depend on kklass speed; L2 (views) waits for this round. |
| D4 | Where the gates run | GitHub: kklass `ci.yml` dispatched on `perf` (calls kbool's reusable gate, 15 rows) + bench.yml A/B; locally only the quick suite runs. |

## K0 — harness, baseline, drift (DONE 2026-11-08)

kbool c0b9ac0 on `perf`; first bench run 42481258498 (A/A: two copies of the
same kklass, 7691162). Microseconds per call, median of 5:

| row | plain | call1 | call14 | long | inherited | nested | prop | newdel |
|---|---|---|---|---|---|---|---|---|
| ubuntu host, bash 5.3.9 | 4.0 | 186 | — | — | 551 | 403 | — | — |
| ubuntu 22.04, bash 5.1.16 | 4.5 | 142 | — | — | 444 | 303 | — | — |
| debian 13, bash 5.2.37 | 4.6 | 133 | 207 | 221 | 385 | 277 | 20.8 | 161 |
| alpine bash 5.3.20 | 3.6 | 120 | 184 | 175 | 354 | 253 | 18.5 | 149 |
| macOS brew 5.3.20 | 3.1 | 136 | 194 | 238 | 425 | 289 | 18.0 | 166 |
| windows git-bash 5.3.15 | 5.1 | 197 | 267 | 262 | 596 | 418 | 26.2 | 190 |
| windows cygwin 5.2.21 | 5.0 | 194 | 264 | 237 | 578 | 411 | 26.9 | 203 |
| windows msys2 5.3.20 | 7.4 | 352 | 487 | 495 | 1096 | 742 | 45.7 | 371 |

* A method call is 30–47 plain calls everywhere; `inherited` is ~3 calls, a
  nested call ~2.1. Linux is NOT much faster than Windows here: the call path
  has no fork, its cost is bash interpretation.
* **Drift: none.** After 12 000 stressor calls (nested, inherited, helper,
  new/delete) s.Short is 0.93–1.08× its time before (Linux/Windows 0.96–1.03).
  The local 1.6× slowdown of 2026-11-08 was outside load on the machine.
  **K5 dropped.**
* Noise floor (A/A ratio): Linux and Windows ±1–4%, macOS ±5–8%.

Local split (Git-bash, a method with one field, ≈185 us): wrapper 4,
kk._exec ~48, kk._invoke ~78, kk._run_frame_body ~52, `eval` of a one-line
body 8 (a 17-line body: eval 41 vs 15 as a function); 14 fields add ~80
(nameref loop 63 vs one `local -n` from a template 32); `inherited` = kk._parent
~215 of its own, of which `kv.frameCurrent >/dev/null 2>&1` is ~54 (a direct
read of the frame arrays: 8). bash copies a function's command tree on every
call: the length of the hot functions is time.

## Phases (order: small and safe first)

Every phase: Opus worker → kklass suite + affected kcl suites locally → push
kklass `perf` + kbool `perf` (pointer bump) → kklass `ci.yml` on `perf`
(15 rows) and bench.yml A/B (`SIDES="main=main cur=pointer"`) → independent
Opus critic → fixes → ledger. Nothing reaches `main` before the round's "go".

### K4 — cheap `inherited`
`kk._parent` reads the frame class straight from `__KLIB_FRAME_STACK` /
`__KLIB_FRAME_CLASS` (as kk._invoke writes them) instead of
`kv.frameCurrent >/dev/null 2>&1` + `kv.frameClass`; look for the same pattern
on other hot paths (`.parent`, visibility checks). Target: inherited ≤ 0.85× main.

### K2 — fields in one `local -n`
At build, per class, a template array `NAME=@_data[NAME] ...` (and one for
static properties with their owners resolved); kk._run_frame_body binds with one
`local -n +x "${tmpl[@]//@/$inst}"`. Kept in step with every place that changes
a class's property table (build, inheritance, compiled cache, serializer, any
runtime defineProperty). Target: call14 ≤ 0.85× main, call1 not slower.

### K1 — method bodies as functions
At build every body becomes a real function defined once (e.g.
`__kkm_<Owner>__<Method>`), run by the trampoline instead of `eval "$body"`.
`return` in a body then returns from that function, which lets
kk._run_frame_body merge into kk._invoke (K3). Inventory first: every reader of
`<Class>_method_body_<M>` (exec, call, parent, constructors, statics, dynamic
`defineMethod`, serializer, compiler, `.call`, docs/tests that read it). The
compiled `.ckk` cache dumps the functions too: format number bump, old caches
refused as stale (existing mechanism). Target: long ≤ 0.85× main.

### K3 — short hot path
Fold kk._exec / kk._invoke / kk._run_frame_body into as few and as short
functions as the guarantees allow; move rare branches (set -a, visibility
warning, errors, the outermost localvar_unset toggle) into helpers called only
when needed; precompute per-class flags at build. Target: call1 ≤ 0.6× main.

### K5 — drift fix: dropped (K0: no drift on any platform).

### K6 — rejected (D1).

## Guarantees kept (existing tests pin them; none may change)
Scope isolation (round 5: callee sees only its own fields, unset isolation via
localvar_unset), `set -a` callers, frame stack for `inherited` and visibility
warnings, RESULT protocol (caller RESULT restored unless the body returns),
`return N` in bodies, `$this.m` virtual dispatch, constructors/destructors,
statics, compiled caches, bash 5.1 floor, `set -eu` callers.

## Round targets (bench.yml, cur/main, every Linux and Windows row)
call1 ≤ 0.6, call14 ≤ 0.55, long ≤ 0.6, inherited ≤ 0.45, nested ≤ 0.6; no
case > 1.03 (plain, prop untouched).
