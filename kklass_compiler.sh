#!/bin/bash
# kklass_compiler.sh - Compile class definitions to optimized bash code
# Usage: bash kklass_compiler.sh input.kk output.sh

KKLASS_COMPILER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$KKLASS_COMPILER_DIR/kklass.sh"

# The classes to dump: every X with a function X.new AND an array
# ${X}_class_methods — i.e. exactly the classes the runtime BUILT in this
# process (round 4 / P12, C15, DR12). This includes abstract classes, empty
# raw builds and the parents the source loaded itself (a compiled child needs
# them: its inherited methods resolve through them). A plain function that is
# merely named X.new — kkore's kv.new (it used to be dumped as a class "kv"
# with all ten kv.* functions), a user factory — is not a class. The
# compiler is a fresh process, so nothing is built before the source runs.
kk.compiler._collect_classes() {
    local output_array_name="$1"
    local -n output_ref="$output_array_name"
    local function_name=""

    output_ref=()
    while IFS= read -r function_name; do
        if [[ "$function_name" == *.new ]] \
            && declare -p "${function_name%.new}_class_methods" &>/dev/null; then
            output_ref+=("${function_name%.new}")
        fi
    done < <(compgen -A function)
}

# Emit `declare -p NAME` for every variable NAME, rewritten to declare into the
# GLOBAL scope: a compiled file is commonly sourced from inside a function
# (autoloadClasses), where a plain `declare -a` would create a local.
kk.compiler._dump_vars() {
    local output_file="$1"
    shift
    local var_name declaration
    for var_name in "$@"; do
        declaration="$(declare -p "$var_name" 2>/dev/null)" || continue
        declaration="${declaration/declare -a /declare -ga }"
        declaration="${declaration/declare -A /declare -gA }"
        declaration="${declaration/declare -- /declare -g }"
        declaration="${declaration/declare -i /declare -gi }"
        printf '%s\n' "$declaration" >> "$output_file"
    done
}

# kk.compiler._fold PATH -> REPLY: backslashes -> `/`, `.`, `..` and `//` folded
# lexically (an absolute PATH; a drive prefix C: is kept).
kk.compiler._fold() {
    local p="$1" pre="" seg
    local -a in=() out=()
    p="${p//\\//}"
    if [[ "$p" == [A-Za-z]:/* ]]; then pre="${p:0:2}"; p="${p:2}"; fi
    IFS=/ read -r -a in <<< "$p"
    for seg in "${in[@]}"; do
        case "$seg" in
            ''|.) ;;
            ..) (( ${#out[@]} )) && unset 'out[${#out[@]}-1]' ;;
            *) out+=("$seg") ;;
        esac
    done
    local IFS=/
    REPLY="$pre/${out[*]}"
}

# kk.compiler._relpath DIR FILE -> REPLY: FILE relative to DIR (both folded,
# absolute); FILE itself when they share nothing but the root.
kk.compiler._relpath() {
    local -a d=() f=()
    local i=0 j up="" IFS=/
    read -r -a d <<< "${1#/}"
    read -r -a f <<< "${2#/}"
    while (( i < ${#d[@]} && i < ${#f[@]} - 1 )) && [[ "${d[i]}" == "${f[i]}" ]]; do i=$((i + 1)); done
    if (( i == 0 )); then REPLY="$2"; return 0; fi
    for (( j = i; j < ${#d[@]}; j++ )); do up+="../"; done
    REPLY="$up${f[*]:i}"
}

# kk.compiler._site_part POSITIONS -> REPLY: the FILE:LINE positions (joined by
# $'\x1f') with every position in the sourced file ($site_raw / $site_abs of the
# caller) turned into the placeholder $'\x1e':LINE, which the cache resolves at
# load time (kk._ckk_begin / kk._ckk_class, uses U2b).
kk.compiler._site_part() {
    local -a __kk_sp=()
    local __kk_p __kk_o=""
    IFS=$'\x1f' read -r -a __kk_sp <<< "$1"
    for __kk_p in "${__kk_sp[@]}"; do
        if [[ "${__kk_p%:*}" == "$site_raw" || "${__kk_p%:*}" == "$site_abs" ]]; then
            __kk_p=$'\x1e'":${__kk_p##*:}"
        fi
        __kk_o+="${__kk_o:+$'\x1f'}$__kk_p"
    done
    REPLY=$__kk_o
}

# Compile = DUMP. The classes are built in this process by the normal runtime
# (source the input), then every `<Class>_*` variable and every `<Class>.*`
# function is written out verbatim with `declare -p` / `declare -f`. There is
# no second code generator to keep in sync with kklass.sh (F4 was exactly that
# drift: owner-less cache, missing tables, an old static-method shape): whatever
# the runtime builds — templates, owner maps, caches, static wrappers, the
# .new/.constructor pair, decl tables for later subclassing — is what loads.
#
# Since uses U2b (C13, P9) a cache REGISTERS its classes like a build does: per
# class `if kk._ckk_class CLASS SITE; then <dump>; kk._ckk_built CLASS; fi` —
# SITE is the declaration site the class was built from here, with the source
# file as a placeholder that the cache resolves when it is loaded (the file
# autoloadClasses loads; else the unit of that NAME; else the path recorded
# here, a .kkp's relative to the cache). A class already built from another
# place is a Duplicate identifier, from the same place a WARNING (U20/U21):
# its dump is skipped either way. kklass itself is loaded through the unit
# loader when kbool is loaded (header below).
compile_class_file() {
    local input_file="$1"
    local output_file="$2"
    local source_file="$input_file"
    local translated_dir=""
    local source_label="$input_file"
    local source_stem="${input_file##*/}"
    source_stem="${source_stem%.*}"

    [[ ! -f "$input_file" ]] && { echo "Error: Input file not found: $input_file" >&2; return 1; }

    if [[ "$input_file" == *.kkp ]]; then
        # translated into a temporary <stem>.sh: a `unit X;` header (U36) loads
        # only from a file named X.sh (kk.unit checks the stem, U33)
        translated_dir="$(mktemp -d)" || return 1
        # a `unit X;` translation bootstraps kbool from ${KBOOL_HOME-} (§7.4 user
        # form): with neither kbool nor KBOOL_HOME, this compiler's own kbool
        if [[ ${__KK_UNITS[@]@a} != A* && -z ${KBOOL_HOME-} ]]; then
            KBOOL_HOME="${KKLASS_COMPILER_DIR%/*}"
        fi
        source_file="$translated_dir/$source_stem.sh"
        bash "$KKLASS_COMPILER_DIR/kklass_kkp.sh" "$input_file" "$source_file" || {
            rm -rf "$translated_dir"
            return 1
        }
    fi

    # Build the classes in THIS shell. Loud: the input's stderr goes through and
    # a failing input aborts the compile instead of producing a half-empty file.
    local source_rc
    source "$source_file"; source_rc=$?
    if (( source_rc != 0 )); then
        [[ -z "$translated_dir" ]] || rm -rf "$translated_dir"
        echo "Error: sourcing $input_file failed with status $source_rc; nothing compiled" >&2
        return 1
    fi

    # P11/M2 (DR8): a class whose declaration refused a member is not built,
    # and the source's status is only its LAST command's (a .kkp unit ends
    # with one endImplementation per class) — so the poison flags are read
    # here: any poisoned class fails the compile, nothing is written.
    local __kk_var __kk_poisoned=""
    while IFS= read -r __kk_var; do
        [[ "$__kk_var" == *_decl_refused ]] || continue
        [[ -n "${!__kk_var:-}" ]] || continue
        __kk_poisoned+=" '${__kk_var%_decl_refused}' (member '${!__kk_var}')"
    done < <(compgen -A variable)
    if [[ -n "$__kk_poisoned" ]]; then
        [[ -z "$translated_dir" ]] || rm -rf "$translated_dir"
        echo "Error: $input_file: class(es)${__kk_poisoned} refused a member; nothing compiled" >&2
        return 1
    fi

    local class_list=()
    kk.compiler._collect_classes class_list

    [[ ${#class_list[@]} -eq 0 ]] && {
        [[ -z "$translated_dir" ]] || rm -rf "$translated_dir"
        echo "Error: No classes found in $input_file" >&2
        return 1
    }

    # The source as a unit (P9): a .kkp with `unit X;` or a file with a unit
    # header is named by its unit NAME in the cache.
    local source_unit=""
    if declare -F kk._unit_has_header >/dev/null && kk._unit_has_header "$source_file" "$source_stem"; then
        source_unit="$source_stem"
    fi
    # The file the declaration sites name, as the cache refers to it: for a
    # .kkp its runtime translation <cache folder>/<stem>.sh (relative to the
    # cache — where autoloadClasses' runtime mode writes it), else the source
    # made absolute.
    # P9 (review R2): the reference is RELATIVE to the cache's folder, so a project
    # moved together with its cache keeps working; the absolute path is the last
    # fallback (kk._ckk_begin).
    local site_ref site_abs_ref="" site_raw="$source_file" site_abs="$source_file" out_abs="$output_file"
    [[ "$site_abs" == /* || "$site_abs" == [A-Za-z]:* ]] || site_abs="$PWD/$site_abs"
    [[ "$out_abs" == /* || "$out_abs" == [A-Za-z]:* ]] || out_abs="$PWD/$out_abs"
    if [[ -n "$translated_dir" ]]; then
        site_ref="$source_stem.sh"
    else
        kk.compiler._fold "$site_abs"; site_abs_ref="$REPLY"
        kk.compiler._fold "${out_abs%/*}"
        kk.compiler._relpath "$REPLY" "$site_abs_ref"; site_ref="$REPLY"
    fi
    local source_comment="# Source: $source_label"
    [[ -z "$source_unit" ]] || source_comment="# Source unit: $source_unit"

    # The heredoc is UNQUOTED (it expands $KKLASS_COMPILER_DIR), so a backquote
    # in it is a command substitution: the backquotes below MUST stay escaped
    # (round 4 / P12, C15 — unescaped, every compile ran `source` with no
    # argument and the header read "load with ."). So must every `$` meant for
    # the cache's own run.
    cat > "$output_file" <<HEADER
#!/bin/bash
# Auto-generated by kklass_compiler.sh
# DO NOT EDIT MANUALLY - Changes will be overwritten
# A verbatim dump (declare -p / declare -f) of the classes the runtime built
# from the source file; load with \`source\`.
$source_comment

# kklass (uses U2b, C13): already loaded -> nothing to do; kbool loaded -> through
# the unit loader (kk.uses, by path until kklass carries a unit header — U3);
# else the kklass of KBOOL_HOME; else the kklass that compiled this file.
if ! declare -F kk._ckk_class >/dev/null; then
    if [[ \${__KK_UNITS[@]@a} == A* ]]; then
        kk.uses "\$KBOOL_HOME/kklass/kklass.sh" || return
    elif [[ -n \${KBOOL_HOME-} && -f \$KBOOL_HOME/kklass/kklass.sh ]]; then
        source "\$KBOOL_HOME/kklass/kklass.sh" || return
    else
        source $(printf '%q' "$KKLASS_COMPILER_DIR/kklass.sh") || return
    fi
fi
kk._ckk_begin $(printf '%q' "$source_unit") $(printf '%q' "$site_ref") $(printf '%q' "$site_abs_ref")
HEADER

    local class_name var_name fn_name site
    local -a var_names fn_names
    for class_name in "${class_list[@]}"; do
        # this class's declaration site, the sourced file as the placeholder
        site="${_KKLASS_CLASS_SITE[$class_name]-}"
        if [[ -z "$site" ]]; then
            site=$'\x1e:0\x1d\x1e:0'
        else
            kk.compiler._site_part "${site%%$'\x1d'*}"
            site="$REPLY"$'\x1d'
            kk.compiler._site_part "${_KKLASS_CLASS_SITE[$class_name]#*$'\x1d'}"
            site+="$REPLY"
        fi
        {
            echo ""
            echo "# ===== Class: $class_name ====="
            printf 'if kk._ckk_class %s %q; then\n' "$class_name" "$site"
        } >> "$output_file"

        # Every <Class>_* variable: metadata tables, method bodies, static
        # state, the instance template, the decl tables.
        var_names=()
        while IFS= read -r var_name; do
            [[ -n "$var_name" ]] && var_names+=("$var_name")
        done < <(compgen -A variable "${class_name}_")
        kk.compiler._dump_vars "$output_file" "${var_names[@]}"

        # Every <Class>.* function: .new (and the abstract-guard wrapper's
        # __decl_new_impl), .constructor, static accessors, static methods and
        # their __static_ bodies.
        fn_names=()
        while IFS= read -r fn_name; do
            [[ -n "$fn_name" ]] && fn_names+=("$fn_name")
        done < <(compgen -A function "${class_name}.")
        for fn_name in "${fn_names[@]}"; do
            declare -f "$fn_name" >> "$output_file"
        done
        printf 'kk._ckk_built %s\nfi\n' "$class_name" >> "$output_file"
    done

    cat >> "$output_file" <<EOF
kk._ckk_end

# Compiled classes: ${class_list[*]}
# Generated: $(date)
${source_comment}
EOF

    chmod +x "$output_file"
    [[ -z "$translated_dir" ]] || rm -rf "$translated_dir"

    echo "✓ Compiled ${#class_list[@]} classes to: $output_file"
    echo "  Classes: ${class_list[*]}"
    echo "  Usage: source $output_file && ClassName.new instance_name"
}

# Main
if [[ $# -lt 2 ]]; then
    cat <<'USAGE'
Usage: bash kklass_compiler.sh <input.kk> <output.sh>

Compiles class definitions from input file into optimized bash code.

Example:
    # Compile classes
    bash kklass_compiler.sh my_classes.kk my_classes_compiled.sh
    
    # Use compiled classes
    source my_classes_compiled.sh
    MyClass.new myobj
    myobj.method_name
USAGE
    exit 1
fi

compile_class_file "$1" "$2"
