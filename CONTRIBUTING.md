# Contributing to kklass

kklass is a submodule of [kbool](https://github.com/Keksov/kbool), and its
tests need the whole tree. The full guide — the one test command, what CI
checks, what the verdicts mean, the house rules — is
[kbool's CONTRIBUTING.md](https://github.com/Keksov/kbool/blob/main/CONTRIBUTING.md).

Work in the `kklass/` folder of a kbool checkout
(`git clone --recurse-submodules https://github.com/Keksov/kbool.git`) and send
the pull request here, against `main`.

* The suite is `tests/` — gate suite id `kklass`. Every kcl unit is built on
  kklass, so a kklass change is checked with every suite: from the kbool root,
  `bash ktests/tools/gate.sh all`.
* The documentation is [the kklass book](docs/kklass_book.md); its runnable
  examples are run by `tests/142_DocExamples.sh`. Plans and ledgers: `docs/dev/`.
* Object creation, dispatch, property access, `.delete`, computed properties
  and class building fork nothing ([System Requirements](docs/kklass_book.md#system-requirements)) — keep it so.
* `tests/148_Bash51Hazards.sh` checks the bash 5.1 floor over the non-test code.
* CI: `.github/workflows/ci.yml` runs kbool's 13 rows with your PR in place of
  kklass; the checks are named `kbool / linux (debian 13)` and so on.
