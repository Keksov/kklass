# kklass — experimental / legacy prototypes

**Not for production use. Not sourced by `kklass.sh` and not part of the test suite.**

These files are early prototypes of an alternative object model (shared class methods +
thin per-object proxies) explored in [`../OPTIMIZATION.md`](../OPTIMIZATION.md). They were
moved here (task P1.5 of the optimization effort) because:

- They do **not** validate class/method names before `eval`, unlike the hardened
  `defineClass` in the declarative layer.
- They `export -f defineClass`, which — if sourced — would silently **override** the
  hardened `defineClass` from `kklass.sh`.

Contents:

| File | Notes |
|------|-------|
| `kklass_new.sh` | Proxy-based object model prototype. Defines a demo `Person` class on load. |
| `kklass_cnfh.sh` | `command_not_found_handle`-based dispatch prototype. Does not work in non-interactive scripts. |
| `kklass_new_fields.sh` | Standalone field-accessor demo with inline security tests. |
| `test_kklass_new.sh`, `test_kklass_cnfh.sh`, `test_kklass.sh` | Manual test scripts for the above. Run directly, e.g. `bash experimental/test_kklass_new.sh`. |

The production object model lives in `../kklass.sh` and `../kklass_decl.sh`. If the shared-method
model is adopted for production (see optimization task P3.2), it will be implemented there with the
same identifier validation and API compatibility, and these prototypes can be deleted.
