#!/bin/bash

if [[ -n "${_KKLASS_KKP_SOURCED:-}" ]]; then
    return
fi
declare -g _KKLASS_KKP_SOURCED=1

# Units and uses (USES_PLAN.md U36, U33, U32, §7.4):
#   unit X;          the first statement of the file -> the two unit header lines
#                    of a unit OUTSIDE the kbool tree (§7.4's user form, owner
#                    2026-10-08: a generated file cannot reach kbool.sh relative
#                    to itself, and no translator path is baked in):
#                        [[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
#                        kk.unit X || return $__kk_unit_rc
#                    right after the shebang (the header must end within the
#                    first 512 characters of the translated file). X must be the
#                    .kkp file's stem (U33) — otherwise a translation error. A
#                    translated unit is loadable only from a file named X.sh
#                    (kk.unit checks the stem): autoloadClasses' runtime file
#                    is <cache>/X.sh, kklass_compiler.sh translates into a
#                    temporary X.sh; both set KBOOL_HOME to their own kbool when
#                    neither kbool nor KBOOL_HOME is there, so a translated unit
#                    loads through them in a bare shell. Sourcing a translation
#                    by hand needs kbool loaded or KBOOL_HOME set.
#   uses A, B;       (anywhere outside a class body, may span lines) ->
#                        kk.uses A B || return
#                    preceded by the kbool.sh line when the file has no unit
#                    header. Unit names only (identifiers); `in 'path'` is not
#                    supported.
# A comment after a `unit` or `uses` statement on the same line is an error
# naming FILE:LINE (put comments on their own line). A unit or uses error
# removes the output file.

# kkp._boot_line -> the kbool.sh line of a translated unit header (§7.4 user form).
kkp._boot_line() {
    printf '%s' '[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2'
}

# kkp._prescan_unit FILE -> __kkp_unit: the X of `unit X;` when it is the first
# statement (blank lines and // comments skipped), else ''. rc 1 = a `unit`
# statement that is not `unit NAME;` (printed with FILE:LINE).
kkp._prescan_unit() {
    local raw line n=0
    __kkp_unit=""
    while IFS= read -r raw || [[ -n "$raw" ]]; do
        n=$((n + 1))
        line="$(kkp._trim "${raw%$'\r'}")"
        [[ -n "$line" && "$line" != //* ]] || continue
        case "${line,,}" in
            unit|unit[[:space:]]*|unit\;*)
                if [[ "$line" =~ ^[Uu][Nn][Ii][Tt][[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\;$ ]]; then
                    __kkp_unit="${BASH_REMATCH[1]}"
                    return 0
                fi
                if [[ "${line%%;*}" != "$line" && "${line#*;}" == *[![:space:]]* ]]; then
                    echo "Error: $1:$n: '$line': text after the unit statement's ';' — comments after a statement are not supported; put them on their own line" >&2
                else
                    echo "Error: $1:$n: malformed unit statement '$line' (expected: unit NAME;)" >&2
                fi
                return 1
                ;;
        esac
        return 0
    done < "$1"
    return 0
}

kkp._trim() {
    local value="$1"
    value="${value%$'\r'}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

kkp._lower_trim() {
    local value
    value="$(kkp._trim "$1")"
    printf '%s' "${value,,}"
}

kkp._quote() {
    printf '%q' "$1"
}

kkp._emit_line() {
    local output_file="$1"
    local line="$2"
    printf '%s\n' "$line" >> "$output_file"
}

kkp._append_unique_class() {
    local class_name="$1"
    local array_name="$2"
    local -n array_ref="$array_name"
    local current_name

    for current_name in "${array_ref[@]}"; do
        if [[ "$current_name" == "$class_name" ]]; then
            return 0
        fi
    done

    array_ref+=("$class_name")
}

kkp._extract_decl_name() {
    local signature="$1"
    signature="$(kkp._normalize_decl "$signature")"
    signature="${signature%%(*}"
    signature="${signature%%:*}"
    signature="$(kkp._trim "$signature")"
    printf '%s' "$signature"
}

kkp._normalize_decl() {
    local value="$1"
    local parts=()

    value="${value//$'\r'/ }"
    value="${value//$'\n'/ }"
    read -r -a parts <<< "$value"
    printf '%s' "${parts[*]}"
}

kkp._emit_class_var_decl() {
    local output_file="$1"
    local line="$2"
    local decl="$(kkp._normalize_decl "${line%;}")"
    local lhs=""
    local field_name=""

    decl="${decl#class var }"
    decl="${decl#Class var }"
    decl="${decl#CLASS VAR }"
    lhs="${decl%%:*}"

    IFS=',' read -ra __kkp_fields <<< "$lhs"
    for field_name in "${__kkp_fields[@]}"; do
        field_name="$(kkp._trim "$field_name")"
        [[ -n "$field_name" ]] || continue
        kkp._emit_line "$output_file" "classVar $(kkp._quote "$field_name")"
    done
}

kkp._emit_property_decl() {
    local output_file="$1"
    local line="$2"
    local decl="$(kkp._normalize_decl "${line%;}")"
    local tokens=()
    local cmd=""
    local property_name=""
    local rest=""
    local index=0

    decl="${decl#property }"
    decl="${decl#Property }"

    if [[ "$decl" == *:* ]]; then
        property_name="$(kkp._trim "${decl%%:*}")"
        rest="${decl#*:}"
    else
        read -r property_name rest <<< "$decl"
    fi

    read -r -a tokens <<< "$rest"
    [[ -n "$property_name" ]] || return 0

    cmd="property $(kkp._quote "$property_name")"
    while (( index < ${#tokens[@]} )); do
        case "${tokens[$index],,}" in
            read|write)
                if (( index + 1 < ${#tokens[@]} )); then
                    cmd+=" ${tokens[$index],,} $(kkp._quote "${tokens[$((index + 1))]}")"
                fi
                ((index += 2))
                ;;
            *)
                ((index++))
                ;;
        esac
    done

    kkp._emit_line "$output_file" "$cmd"
}

kkp._emit_field_decl() {
    local output_file="$1"
    local line="$2"
    local decl="$(kkp._normalize_decl "${line%;}")"
    local lhs="${decl%%:*}"
    local field_name=""

    IFS=',' read -ra __kkp_fields <<< "$lhs"
    for field_name in "${__kkp_fields[@]}"; do
        field_name="$(kkp._trim "$field_name")"
        [[ -n "$field_name" ]] || continue
        kkp._emit_line "$output_file" "field $(kkp._quote "$field_name")"
    done
}

kkp._emit_method_decl() {
    local output_file="$1"
    local line="$2"
    local decl="$(kkp._normalize_decl "${line%;}")"
    local signature=""
    local method_name=""
    local part=""
    local emitter=""

    IFS=';' read -ra __kkp_parts <<< "$decl"
    signature="$(kkp._trim "${__kkp_parts[0]}")"

    for part in "${__kkp_parts[@]:1}"; do
        case "$(kkp._lower_trim "$part")" in
            virtual|override|abstract)
                kkp._emit_line "$output_file" "$(kkp._lower_trim "$part")"
                ;;
        esac
    done

    if [[ "$signature" =~ ^[Cc][Ll][Aa][Ss][Ss][[:space:]]+[Pp][Rr][Oo][Cc][Ee][Dd][Uu][Rr][Ee][[:space:]]+(.+)$ ]]; then
        emitter="classProcedure"
        method_name="$(kkp._extract_decl_name "${BASH_REMATCH[1]}")"
    elif [[ "$signature" =~ ^[Cc][Ll][Aa][Ss][Ss][[:space:]]+[Ff][Uu][Nn][Cc][Tt][Ii][Oo][Nn][[:space:]]+(.+)$ ]]; then
        emitter="classFunction"
        method_name="$(kkp._extract_decl_name "${BASH_REMATCH[1]}")"
    elif [[ "$signature" =~ ^[Pp][Rr][Oo][Cc][Ee][Dd][Uu][Rr][Ee][[:space:]]+(.+)$ ]]; then
        emitter="procedure"
        method_name="$(kkp._extract_decl_name "${BASH_REMATCH[1]}")"
    elif [[ "$signature" =~ ^[Ff][Uu][Nn][Cc][Tt][Ii][Oo][Nn][[:space:]]+(.+)$ ]]; then
        emitter="func"
        method_name="$(kkp._extract_decl_name "${BASH_REMATCH[1]}")"
    elif [[ "$signature" =~ ^[Cc][Oo][Nn][Ss][Tt][Rr][Uu][Cc][Tt][Oo][Rr][[:space:]]+(.+)$ ]]; then
        emitter="constructor"
        method_name="$(kkp._extract_decl_name "${BASH_REMATCH[1]}")"
    else
        return 0
    fi

    kkp._emit_line "$output_file" "$emitter $(kkp._quote "$method_name")"
}

kkp._begin_method_impl() {
    local line="$1"

    local decl="$(kkp._normalize_decl "${line%;}")"
    local signature=""
    local qualified_name=""

    IFS=';' read -ra __kkp_parts <<< "$decl"
    signature="$(kkp._trim "${__kkp_parts[0]}")"

    if [[ "$signature" =~ ^[Cc][Ll][Aa][Ss][Ss][[:space:]]+[Pp][Rr][Oo][Cc][Ee][Dd][Uu][Rr][Ee][[:space:]]+(.+)$ ]]; then
        qualified_name="$(kkp._extract_decl_name "${BASH_REMATCH[1]}")"
        RESULT="class_procedure:$qualified_name"
        return 0
    fi
    if [[ "$signature" =~ ^[Cc][Ll][Aa][Ss][Ss][[:space:]]+[Ff][Uu][Nn][Cc][Tt][Ii][Oo][Nn][[:space:]]+(.+)$ ]]; then
        qualified_name="$(kkp._extract_decl_name "${BASH_REMATCH[1]}")"
        RESULT="class_function:$qualified_name"
        return 0
    fi
    if [[ "$signature" =~ ^[Pp][Rr][Oo][Cc][Ee][Dd][Uu][Rr][Ee][[:space:]]+(.+)$ ]]; then
        qualified_name="$(kkp._extract_decl_name "${BASH_REMATCH[1]}")"
        RESULT="procedure:$qualified_name"
        return 0
    fi
    if [[ "$signature" =~ ^[Ff][Uu][Nn][Cc][Tt][Ii][Oo][Nn][[:space:]]+(.+)$ ]]; then
        qualified_name="$(kkp._extract_decl_name "${BASH_REMATCH[1]}")"
        RESULT="function:$qualified_name"
        return 0
    fi
    if [[ "$signature" =~ ^[Cc][Oo][Nn][Ss][Tt][Rr][Uu][Cc][Tt][Oo][Rr][[:space:]]+(.+)$ ]]; then
        qualified_name="$(kkp._extract_decl_name "${BASH_REMATCH[1]}")"
        RESULT="constructor:$qualified_name"
        return 0
    fi

    return 1
}

kkp.compile() {
    local input_file="$1"
    local output_file="$2"
    local raw_line=""
    local line=""
    local lowered_line=""
    local current_class=""
    local current_visibility="public"
    local in_interface=0
    local in_implementation=0
    local in_class=0
    local in_method=0
    local current_method_kind=""
    local current_method_class=""
    local current_method_name=""
    local current_method_body=""
    local begin_seen=0
    local pending_class_header=""
    local pending_interface_decl=""
    local pending_impl_signature=""
    local normalized_decl=""
    local signature_decl=""
    local -a class_order=()

    [[ -f "$input_file" ]] || {
        echo "Error: Input file not found: $input_file" >&2
        return 1
    }

    [[ -n "$output_file" ]] || {
        echo "Usage: bash kklass_kkp.sh <input.kkp> <output.sh>" >&2
        return 1
    }

    # U36/U33: `unit X;` must name the file (its stem) — checked before anything is written
    local __kkp_unit="" stem="${input_file##*/}" unit_seen=0 boot_done=0 pending_uses=""
    stem="${stem%.*}"
    kkp._prescan_unit "$input_file" || return 1
    if [[ -n "$__kkp_unit" && "$__kkp_unit" != "$stem" ]]; then
        echo "Error: unit name '$__kkp_unit' does not match the file name '${input_file##*/}' (a unit's name is its file stem: unit $stem;)" >&2
        return 1
    fi

    : > "$output_file"
    if [[ -n "$__kkp_unit" ]]; then
        {
            printf '#!/bin/bash\n'
            kkp._boot_line; printf '\n'
            printf 'kk.unit %s || return $__kk_unit_rc\n' "$__kkp_unit"
            printf '# Generated from %s by kklass_kkp.sh\n\n' "$input_file"
        } > "$output_file"
        boot_done=1
    else
        printf '#!/bin/bash\n# Generated from %s by kklass_kkp.sh\n\n' "$input_file" > "$output_file"
    fi

    local line_no=0
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        line_no=$((line_no + 1))
        line="${raw_line%$'\r'}"
        line="$(kkp._trim "$line")"
        lowered_line="${line,,}"

        [[ "$lowered_line" == //* ]] && continue

        [[ -n "$line" ]] || continue

        # the unit statement (the prescan emitted its header); a second or a late one is an error
        if (( ! in_method && ! in_class )) && [[ -z "$pending_uses$pending_interface_decl$pending_class_header$pending_impl_signature" ]]; then
            case "$lowered_line" in
                unit|unit[[:space:]]*|unit\;*)
                    if (( unit_seen == 0 )) && [[ -n "$__kkp_unit" ]]; then
                        unit_seen=1
                        continue
                    fi
                    echo "Error: $input_file:$line_no: '$line': the unit statement must be the first statement, once" >&2
                    rm -f "$output_file"
                    return 1
                    ;;
            esac
        fi
        unit_seen=1

        # uses A, B;  ->  kk.uses A B || return   (may span lines)
        if (( ! in_method && ! in_class )) && [[ -n "$pending_uses" || "$lowered_line" == uses || "$lowered_line" == uses[[:space:]]* || "$lowered_line" == uses\;* ]]; then
            if [[ "${line%%;*}" != "$line" && "${line#*;}" == *[![:space:]]* ]]; then
                echo "Error: $input_file:$line_no: '$line': text after the uses statement's ';' — comments after a statement are not supported; put them on their own line" >&2
                rm -f "$output_file"
                return 1
            fi
            pending_uses="${pending_uses:+$pending_uses }$line"
            [[ "$pending_uses" == *";" ]] || continue
            local uses_list="${pending_uses:4}" uses_name uses_out=""
            uses_list="${uses_list%;}"
            IFS=',' read -ra __kkp_uses <<< "$uses_list"
            for uses_name in "${__kkp_uses[@]}"; do
                uses_name="$(kkp._trim "$uses_name")"
                if [[ ! "$uses_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                    echo "Error: $input_file:$line_no: '$pending_uses': not a unit name: '$uses_name' (uses NAME, NAME ...;)" >&2
                    rm -f "$output_file"
                    return 1
                fi
                uses_out+=" $uses_name"
            done
            if [[ -z "$uses_out" ]]; then
                echo "Error: $input_file:$line_no: '$pending_uses': no unit named" >&2
                rm -f "$output_file"
                return 1
            fi
            if (( ! boot_done )); then
                kkp._emit_line "$output_file" "$(kkp._boot_line)"
                boot_done=1
            fi
            kkp._emit_line "$output_file" "kk.uses${uses_out} || return"
            pending_uses=""
            continue
        fi

        if (( in_method )); then
            if (( begin_seen == 0 )) && [[ "$lowered_line" == "begin" ]]; then
                begin_seen=1
                continue
            fi

            if [[ "$lowered_line" == "end;" ]]; then
                current_method_body="${current_method_body%$'\n'}"
                if [[ "$current_method_kind" == "constructor" ]]; then
                    kkp._emit_line "$output_file" "implementConstructor $(kkp._quote "$current_method_class") $(kkp._quote "$current_method_body")"
                else
                    kkp._emit_line "$output_file" "implement $(kkp._quote "${current_method_class}.${current_method_name}") $(kkp._quote "$current_method_body")"
                fi

                in_method=0
                begin_seen=0
                current_method_kind=""
                current_method_class=""
                current_method_name=""
                current_method_body=""
                continue
            fi

            begin_seen=1
            current_method_body+="$line"$'\n'
            continue
        fi

        case "$lowered_line" in
            interface)
                in_interface=1
                in_implementation=0
                continue
                ;;
            implementation)
                in_interface=0
                in_implementation=1
                continue
                ;;
            type)
                continue
                ;;
            private|protected|public)
                if (( in_class )); then
                    current_visibility="$lowered_line"
                    case "$lowered_line" in
                        private) kkp._emit_line "$output_file" "privateSection" ;;
                        protected) kkp._emit_line "$output_file" "protectedSection" ;;
                        public) kkp._emit_line "$output_file" "publicSection" ;;
                    esac
                fi
                continue
                ;;
            end.)
                break
                ;;
        esac

        if (( in_interface )); then
            if (( in_class == 0 )); then
                if [[ -n "$pending_class_header" || "$lowered_line" == *"= class"* || "$lowered_line" == *"= class("* ]]; then
                    pending_class_header="${pending_class_header:+$pending_class_header }$line"
                    normalized_decl="$(kkp._normalize_decl "$pending_class_header")"
                    if [[ "$normalized_decl" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*class([[:space:]]*\([[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\))?[[:space:]]*$ ]]; then
                        current_class="${BASH_REMATCH[1]}"
                        current_visibility="public"
                        in_class=1
                        pending_class_header=""
                        kkp._append_unique_class "$current_class" class_order
                        kkp._emit_line "$output_file" "declareClass $(kkp._quote "$current_class") $(kkp._quote "${BASH_REMATCH[3]}")"
                    fi
                    continue
                fi
            else
                if [[ -z "$pending_interface_decl" ]]; then
                    case "$lowered_line" in
                        private|protected|public)
                            current_visibility="$lowered_line"
                            case "$lowered_line" in
                                private) kkp._emit_line "$output_file" "privateSection" ;;
                                protected) kkp._emit_line "$output_file" "protectedSection" ;;
                                public) kkp._emit_line "$output_file" "publicSection" ;;
                            esac
                            continue
                            ;;
                    esac

                    if [[ "$lowered_line" == "end;" ]]; then
                        kkp._emit_line "$output_file" "endClass"
                        current_class=""
                        current_visibility="public"
                        in_class=0
                        continue
                    fi
                fi

                pending_interface_decl="${pending_interface_decl:+$pending_interface_decl }$line"
                normalized_decl="$(kkp._normalize_decl "$pending_interface_decl")"
                if [[ "$normalized_decl" != *";" ]]; then
                    continue
                fi

                case "${normalized_decl,,}" in
                    class\ var*)
                        kkp._emit_class_var_decl "$output_file" "$normalized_decl"
                        ;;
                    property*)
                        kkp._emit_property_decl "$output_file" "$normalized_decl"
                        ;;
                    class\ procedure*|class\ function*|procedure*|function*|constructor*)
                        kkp._emit_method_decl "$output_file" "$normalized_decl"
                        ;;
                    *:*)
                        kkp._emit_field_decl "$output_file" "$normalized_decl"
                        ;;
                esac

                pending_interface_decl=""
                continue
            fi
        fi

        if (( in_implementation )); then
            if [[ -n "$pending_impl_signature" || "$lowered_line" == class\ procedure* || "$lowered_line" == class\ function* || "$lowered_line" == procedure* || "$lowered_line" == function* || "$lowered_line" == constructor* ]]; then
                pending_impl_signature="${pending_impl_signature:+$pending_impl_signature }$line"
                normalized_decl="$(kkp._normalize_decl "$pending_impl_signature")"

                if [[ "$normalized_decl" =~ ^(.*)[[:space:]]begin[[:space:]]*$ ]]; then
                    signature_decl="$(kkp._trim "${BASH_REMATCH[1]}")"
                    if ! kkp._begin_method_impl "$signature_decl"; then
                        echo "Error: Could not parse implementation signature: $signature_decl" >&2
                        return 1
                    fi

                    current_method_kind="${RESULT%%:*}"
                    local qualified_name="${RESULT#*:}"
                    current_method_class="${qualified_name%%.*}"
                    current_method_name="${qualified_name#*.}"
                    in_method=1
                    begin_seen=1
                    current_method_body=""
                    pending_impl_signature=""
                fi
                continue
            fi
        fi
    done < "$input_file"

    if (( in_method )); then
        echo "Error: Unterminated implementation block in $input_file" >&2
        return 1
    fi

    if [[ -n "$pending_impl_signature" ]]; then
        echo "Error: Unterminated implementation signature in $input_file" >&2
        return 1
    fi

    if [[ -n "$pending_uses" ]]; then
        echo "Error: Unterminated uses clause in $input_file: '$pending_uses'" >&2
        rm -f "$output_file"
        return 1
    fi

    if [[ -n "$pending_interface_decl" || -n "$pending_class_header" ]]; then
        echo "Error: Unterminated interface declaration in $input_file" >&2
        return 1
    fi

    local class_name
    for class_name in "${class_order[@]}"; do
        kkp._emit_line "$output_file" "endImplementation $(kkp._quote "$class_name")"
    done

    chmod +x "$output_file"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ $# -lt 2 ]]; then
        cat <<'USAGE'
Usage: bash kklass_kkp.sh <input.kkp> <output.sh>

Translates a Pascal-like .kkp unit into the Bash declarative kklass DSL.
USAGE
        exit 1
    fi

    kkp.compile "$1" "$2"
fi