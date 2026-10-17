#!/bin/bash
# DocExamples — the runnable examples of the kklass book (docs/kklass_book.md:
# chiefly the chapter "Units and uses" and the getting-started / Pascal DSL
# examples that show the canonical `source kbool.sh` + `kk.uses` loading) run
# as written (kklass/USES_PLAN.md phase U5). The marker (`<!-- doctest -->`
# before a ```bash fence), the expected-output comments (`# => LINE`,
# `# 2> TEXT`) and the hermetic run (env -i, an empty folder and HOME, no
# config) are described in kkore/tests/doc_examples.sh, shared with kkore 015.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "DocExamples" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KDOC_ROOT="$(cd "$KKLASS_DIR/.." && pwd)"
source "$KDOC_ROOT/kkore/tests/doc_examples.sh"

kdoc_check_file "$KKLASS_DIR/docs/kklass_book.md" "kklass_book.md" 11
