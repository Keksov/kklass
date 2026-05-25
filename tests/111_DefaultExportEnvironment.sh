#!/bin/bash
# DefaultExportEnvironment

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "DefaultExportEnvironment" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"

kt_test_start "kklass does not export framework functions by default"
exported_kklass_functions=()
while IFS= read -r exported_decl; do
    function_name="${exported_decl#declare -fx }"
    function_name="${function_name%%=*}"
    case "$function_name" in
        kk.*|defineClass|defineMethod|defineProcedure|defineFunction|declareClass|privateSection|protectedSection|publicSection|virtual|override|abstract|field|property|classVar|procedure|declareProcedure|func|declareFunction|classProcedure|classFunction|constructor|endClass|finalizeClass|implement|implementConstructor|endImplementation|finalizeImplementation)
            exported_kklass_functions+=("$function_name")
            ;;
    esac
done < <(export -pf)

if (( ${#exported_kklass_functions[@]} == 0 )); then
    kt_test_pass "kklass does not export framework functions by default"
else
    kt_test_fail "kklass exported framework functions by default: ${exported_kklass_functions[*]}"
fi