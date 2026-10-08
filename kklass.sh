#!/bin/bash
# kklass.sh - Working class system for bash with dot notation

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${KKLASS_DIR}/../kkore/klib.sh"
source "${KKLASS_DIR}/../kkore/kerr.sh"
source "${KKLASS_DIR}/../kkore/kvar.sh"

# ---------------------------------------------------------------------------
# Class declaration sites — "Duplicate identifier" (uses phase U2a; design:
# kklass/USES_PLAN.md U18', U20, U21, U23, C6, C14, P4).
#
# The SITE of a class declaration (declareClass, and so every builder: the
# Pascal `class`, defineClass, defineSerializableClass, a raw
# kk._build_class_runtime) is the chain of FILE:LINE call positions from the
# innermost one outside the kklass framework files outward, up to and including
# the position inside the first sourced file (its `source` frame) — or inside
# the script itself at the bottom. A re-source of a file and a loop give the
# same chain; two calls through a wrapper (`mk A x; mk A y`) do not. Positions
# with no file behind them — a prompt, `bash -c`, a script read from stdin
# (`bash < f`, `bash -s`, a pipe), and functions defined there (bash 5.2 names
# their file `environment` / `main`, 5.3 names it `$0`) — are the one pseudo
# file "(no file)": judged by their line like any file. Leading positions inside
# such functions are skipped like kklass's own frames, so both bashes give the
# same site.
#
# A class that is BUILT has a site (_KKLASS_CLASS_SITE). Declaring it again:
#   * from another site          -> "kklass: Duplicate identifier: ..." naming
#     both sites, rc 1; the class is poisoned (${X}_decl_refused), the unit
#     being loaded is marked incomplete (kk._unit_taint, U34) and the rest of
#     that declaration block is swallowed silently (the sink, kklass_decl.sh):
#     an imposter unit can neither rebuild the original nor leave its Pascal
#     bodies behind;
#   * from the same site (a file without a unit header sourced again, a loop,
#     two declarations on one line) -> one `kklass: WARNING:` (kk.warn) and the
#     class is NOT rebuilt: instances, defineMethod changes and static values
#     survive; the block is swallowed, a Pascal `build` restores the static
#     methods the re-run redefined and drops its body functions; defineClass is
#     ignored as a whole. (File-scope defineMethod / addSerializable calls of
#     such a file still run: U20 covers declarations only.)
#   * at an interactive prompt (`$-` has i) from a chain with no file position
#     -> allowed: the class is rebuilt (C14). A file sourced at a prompt is
#     still checked.
# The FILE parts of two chains: the same spelling is the same file unless both
# absolute forms exist and are not `-ef` (a relative script started before a
# `cd` keeps its spelling); different spellings are compared with `[[ -ef ]]`,
# so C:/x, C:\x, /c/x, /C/X and a `..` spelling of one file are one site
# (U18'). A relative BASH_SOURCE is made absolute with $PWD when captured;
# paths are normalised lexically for the messages only.
#
# Tables (keys: class names, validated identifiers):
#   _KKLASS_CLASS_SITE[X]    the site X was built from: RAW positions, $'\x1d',
#                            the same positions with absolute files
#   _KKLASS_CLASS_SOURCE[X]  the innermost file of that site — also the set of
#                            built classes (defineMethod walks it)
#   _KKLASS_DECL_SITE[X]     the site of X's declaration still being built
#                            (declareClass -> endImplementation)
#   _KKLASS_SINK_AT[X]       "BOT|FILE": the `source` frame that opened X's sink
#   _KKLASS_TAKEN[N]         verb | class | ns: names no class / instance may take
#   _KKLASS_NS_OWNER[X]      "UNIT<US>FILE" that declared the namespace X
#   _KKLASS_SINK_NS[X]       `declare -f` text of the namespace X's functions a
#                            swallowed verb named (sink mode n), restored at its close
#   __KKLASS_TABLES          ([on]=1) OWNERSHIP: the tables are this shell's.
# A child bash never inherits assoc arrays (functions exported with set -a /
# KKLASS_EXPORT_FUNCTIONS=1 do arrive): every entry point checks
# `${__KKLASS_TABLES[@]@a} == A` before it subscripts a table and starts an empty
# registry otherwise (U28) — a non-assoc table would evaluate the key as
# arithmetic (uses R14). The sink state (__KK_SINK, __KK_SINK_OPEN,
# __KK_SINK_FNS) and kklass_decl.sh's snapshot table are reset with them.
#
# Units (P4): when kbool.sh is loaded (`${__KK_LOADED[@]@a} == A`), a class
# built while a unit loads is filed with kk._unit_add_class under
# kk._unit_current; `kk.unit --forget NAME` calls kk._unit_forget_class for each,
# so the next source of the unit rebuilds them. Without kbool the site rules
# hold and the unit hooks are skipped. `kk.class --forget X` does the same for
# one class (a header-less file).
kk._class_tables() {
    unset _KKLASS_CLASS_SITE _KKLASS_CLASS_SOURCE _KKLASS_DECL_SITE _KKLASS_SINK_AT \
          __KKLASS_TABLES __kk_decl_snap_taken _KKLASS_TAKEN _KKLASS_NS_OWNER _KKLASS_SINK_NS
    declare -gA _KKLASS_CLASS_SITE=() _KKLASS_CLASS_SOURCE=() _KKLASS_DECL_SITE=() _KKLASS_SINK_AT=()
    declare -gA __kk_decl_snap_taken=()   # kklass_decl.sh: redefinition snapshots, keyed by class
    # the taken names (uses U2b, "Taken names" below): verbs, classes, declared
    # namespaces and their owners; snapshots of a refused namespace declaration
    declare -gA _KKLASS_TAKEN=() _KKLASS_NS_OWNER=() _KKLASS_SINK_NS=()
    declare -gA __KKLASS_TABLES=([on]=1)
    declare -g __KK_SINK="" __KK_SINK_OPEN="" __KK_SINK_FNS="" __KK_SINK_LAST=""
    kk._taken_init
}

# ---------------------------------------------------------------------------
# Taken names (uses phase U2b; USES_PLAN.md U22 as amended by U40, U35).
#
# A class X creates the functions X.* and the variables X_*, and so does an
# instance X. A name that is already a kklass DSL VERB, a CLASS or a declared
# function NAMESPACE (the X of functions X.* a library defines: kkore's kk kl ke
# kv kc, kklass's kkp, a unit's own name, a `kk.namespace X`) must not be taken
# again: `defineClass kv` replaced kv.new, `T.new kc` replaced kc.delete, a
# Pascal `class ke; proc enableErrorReport` deleted kkore's function (n1b).
#
# _KKLASS_TAKEN[NAME] = verb | class | ns — ONE assoc lookup on every path, no
# listing of bash's function table anywhere (U40: a listing costs O(functions)
# after any definition, measured ~quadratic: 16k functions ~0.9 s):
#   verb   every public dotless function of kklass.sh, kklass_decl.sh,
#          kklass_pascal.sh, kklass_serializable.sh, plus `uses` (U35, U32);
#   class  added when a class is registered (built, also from a .ckk cache);
#   ns     the namespaces DECLARED to kkore (kuse.sh "Declared namespaces":
#          every unit's name, kk.namespace X, the kkore namespaces of
#          kbool.sh — imported when the tables are created, then pushed by
#          kkore's hook call kk._namespace_add), plus the namespaces kklass
#          loads itself (kk kl ke kv from kkore, kkp) so they are taken also
#          when kbool is not loaded. _KKLASS_NS_OWNER[X] = "UNIT<US>FILE".
#  * A CLASS declaration (declareClass — so every builder —, a raw
#    kk._build_class_runtime, a .ckk load) of a class not built yet: a verb is
#    refused; a namespace is refused unless the declaration comes from its
#    owner (a position of the declaration's site is the owner's file: kcl's
#    dateutils unit declares `class dateutils`). (An UNdeclared prefix is not
#    taken: `kk.register_static_methods X X ...` turns it into a class.) "kklass: Duplicate identifier: 'X' is ...", rc 1; the
#    class is poisoned and the rest of its block swallowed (kklass_decl.sh, the
#    sink; mode n for a namespace: every namespace function a swallowed verb
#    names is snapshotted and restored when the sink closes).
#  * An INSTANCE name (CLASS.new NAME) that is a verb, a class or a namespace:
#    "Invalid instance name: NAME (...)", rc 1, nothing created.
#  * The other direction (U22: a unit loaded AFTER a class of that name): kkore
#    asks kk._name_in_use before it declares a namespace — kk.unit NAME and
#    kk.namespace X refuse (rc 2) a built class or a live instance.
# GAP (U40, documented): a plain library that has no unit header and never calls
# `kk.namespace` declares nothing, so its functions are not protected.

# kk._taken_init — _KKLASS_TAKEN / _KKLASS_NS_OWNER = the verbs, kklass's own
# namespaces and every namespace kkore declared so far (the caller owns the
# tables). The lists are literal (a child that inherited the functions gets no
# arrays); test 140 recomputes the verbs from the live function table.
kk._taken_init() {
    local __kk_v __kk_d=${KKLASS_DIR-}
    _KKLASS_TAKEN=()
    _KKLASS_NS_OWNER=()
    for __kk_v in \
        declareClass privateSection protectedSection publicSection classVar field property \
        constructor virtual override abstract procedure declareProcedure func declareFunction \
        classProcedure classFunction endClass finalizeClass implement implementConstructor \
        endImplementation finalizeImplementation \
        class end public private protected static var proc destructor build uses \
        defineClass defineMethod defineProcedure defineFunction \
        defineSerializableClass addSerializable saveObjects loadObjects; do
        _KKLASS_TAKEN[$__kk_v]=verb
    done
    kk._namespace_add kk kklass "$__kk_d/kklass.sh"
    kk._namespace_add kkp kklass "$__kk_d/kklass_kkp.sh"
    kk._namespace_add kl klib "${__kk_d%/*}/kkore/klib.sh"
    kk._namespace_add ke kerr "${__kk_d%/*}/kkore/kerr.sh"
    kk._namespace_add kv kvar "${__kk_d%/*}/kkore/kvar.sh"
    if [[ ${__KK_LOADED[@]@a} == A && ${__KK_NAMESPACES[@]@a} == A* ]]; then
        for __kk_v in "${!__KK_NAMESPACES[@]}"; do
            kk._namespace_add "$__kk_v" "${__KK_NAMESPACES[$__kk_v]%%$'\x1f'*}" "${__KK_NAMESPACES[$__kk_v]#*$'\x1f'}"
        done
    fi
    return 0
}

# kk._namespace_add X UNIT FILE — X is a declared namespace (kkore's hook call,
# kuse.sh kk._ns_declare). A class or a verb of that name stays what it is; a
# namespace keeps its first owner. rc 2 for an X that is not an identifier.
kk._namespace_add() {
    kk._is_ident "${1-}" || return 2
    [[ ${__KKLASS_TABLES[@]@a} == A ]] || kk._class_tables
    [[ -z ${_KKLASS_TAKEN[$1]+x} ]] || return 0
    _KKLASS_TAKEN[$1]=ns
    _KKLASS_NS_OWNER[$1]="${2-}"$'\x1f'"${3-}"
    return 0
}

# kk._name_in_use X FILE — kkore's hook before it declares the namespace X from
# FILE (kk.unit, kk.namespace): rc 0 when X is a live instance or a built class
# not declared from FILE (RESULT = "an instance of CLASS" / "a class declared at
# SITE"); rc 1 otherwise.
kk._name_in_use() {
    RESULT=""
    kk._is_ident "${1-}" || return 1
    [[ ${__KKLASS_TABLES[@]@a} == A ]] || kk._class_tables
    local __kk_v=${1}_class __kk_p __kk_site_txt
    local -a __kk_a
    if [[ -n ${!__kk_v+x} ]]; then
        RESULT="an instance of ${!__kk_v}"
        return 0
    fi
    [[ -n ${_KKLASS_CLASS_SITE[$1]+x} ]] || return 1
    IFS=$'\x1f' read -r -a __kk_a <<<"${_KKLASS_CLASS_SITE[$1]#*$'\x1d'}"
    for __kk_p in "${__kk_a[@]}"; do
        __kk_p=${__kk_p%:*}
        if [[ -n $__kk_p && -n ${2-} ]] && [[ $__kk_p == "$2" || $__kk_p -ef $2 ]]; then return 1; fi
    done
    kk._class_site_text "${_KKLASS_CLASS_SITE[$1]}"
    RESULT="a class declared at $__kk_site_txt"
    return 0
}

# kk._ns_txt X -> __kk_ns_txt: "X.* of unit U (FILE)" / "X.* (FILE)" for messages.
kk._ns_txt() {
    [[ ${__KKLASS_TABLES[@]@a} == A ]] || kk._class_tables     # ownership first (R14)
    __kk_ns_txt="${1-}.*"
    kk._is_ident "${1-}" || return 0
    local __kk_o=${_KKLASS_NS_OWNER[$1]-} __kk_u __kk_f __kk_site_txt
    __kk_u=${__kk_o%%$'\x1f'*}
    __kk_f=${__kk_o#*$'\x1f'}
    __kk_ns_txt="$1.*"
    [[ -z $__kk_u ]] || __kk_ns_txt+=" of unit $__kk_u"
    if [[ -n $__kk_f ]]; then
        kk._class_site_text $'\x1d'"$__kk_f:0"
        __kk_ns_txt+=" (${__kk_site_txt%:0})"
    fi
}

# kk._taken_check CLASS — may a class CLASS that is not built yet be declared?
# rc 0 yes; rc 1 CLASS is a DSL verb or a declared namespace it does not own:
# printed (the caller's __kk_site names the refused declaration), the loading
# unit marked incomplete (U34); __kk_taken_kind = verb | ns for the caller.
kk._taken_check() {
    [[ ${__KKLASS_TABLES[@]@a} == A ]] || kk._class_tables     # ownership first (R14)
    kk._is_ident "${1-}" || return 0
    local __kk_site_txt __kk_ns_txt __kk_what __kk_f __kk_p
    local -a __kk_ra __kk_aa
    __kk_taken_kind=""
    case ${_KKLASS_TAKEN[$1]-} in
        verb)
            __kk_taken_kind=verb
            __kk_what="a kklass DSL verb"
            ;;
        ns)
            # its owner may declare it as a class (a unit `dateutils` -> class dateutils)
            __kk_f=${_KKLASS_NS_OWNER[$1]-}
            __kk_f=${__kk_f#*$'\x1f'}
            if [[ -n $__kk_f ]]; then
                IFS=$'\x1f' read -r -a __kk_ra <<<"${__kk_site%%$'\x1d'*}"
                IFS=$'\x1f' read -r -a __kk_aa <<<"${__kk_site#*$'\x1d'}"
                for __kk_p in "${__kk_ra[@]}" "${__kk_aa[@]}"; do
                    __kk_p=${__kk_p%:*}
                    [[ -n $__kk_p ]] || continue
                    if [[ $__kk_p == "$__kk_f" || $__kk_p -ef $__kk_f ]]; then return 0; fi
                done
            fi
            __kk_taken_kind=ns
            kk._ns_txt "$1"
            __kk_what="a function namespace ($__kk_ns_txt)"
            ;;
        *) return 0 ;;
    esac
    kk._class_site_text "$__kk_site"
    echo "kklass: Duplicate identifier: '$1' is $__kk_what; refusing to declare a class '$1' at ${__kk_site_txt}" >&2
    if [[ ${__KK_LOADED[@]@a} == A ]]; then kk._unit_taint 1; fi
    return 1
}

# kk._new_refused NAME — the message of a .new refused by _KKLASS_TAKEN.
kk._new_refused() {
    [[ ${__KKLASS_TABLES[@]@a} == A ]] || kk._class_tables     # ownership first (R14)
    local __kk_ns_txt __kk_w
    case ${_KKLASS_TAKEN[${1:-.}]-} in
        verb)  __kk_w="a kklass DSL verb" ;;
        class) __kk_w="the name of a class" ;;
        ns)    kk._ns_txt "$1"; __kk_w="a function namespace: $__kk_ns_txt" ;;
        *)     __kk_w="a taken name" ;;
    esac
    echo "Invalid instance name: ${1-} ($__kk_w)" >&2
    return 1
}

[[ ${__KKLASS_TABLES[@]@a} == A ]] || kk._class_tables

# kk._class_site — the site of the class verb being run (see above), into the
# CALLER's __kk_site (RAW positions FILE:LINE joined by $'\x1f', innermost
# first, then $'\x1d' and the same positions with absolute FILEs; a pseudo file
# is ''), __kk_site_tty (1 = an interactive shell and no position in a file)
# and __kk_site_open ("BOT|FILE" of the first `source` frame — BOT counted from
# the bottom of the stack — or "-1|"). Fork-free.
kk._class_site() {
    local __i __n=${#BASH_SOURCE[@]} __f __a __started=0 __nofile=1 __script=0 __raw="" __abs="" __l __z=""
    [[ ${FUNCNAME[__n-1]-} == main ]] && __script=1
    # Outside a script (no bottom `main` frame) 5.3 names the file of a function
    # defined at a prompt / in bash -c / on stdin after $0 — a pseudo file,
    # unless $0 is a real file other than bash itself (`bash -c 'source "$0"'
    # f.sh`, the ktests runner). Decided once per value of $0.
    if (( ! __script )) && [[ -n $0 ]]; then
        if [[ ${__KK_SITE_Z0-} != "$0" ]]; then
            __KK_SITE_Z0=$0 __KK_SITE_Z0P=1
            if [[ -f $0 ]] && ! [[ -n ${BASH-} && $0 -ef $BASH ]]; then __KK_SITE_Z0P=0; fi
        fi
        [[ $__KK_SITE_Z0P == 1 ]] && __z=$0
    fi
    __kk_site_open="-1|"
    for (( __i = 0; __i < __n; __i++ )); do
        # the bottom `main` frame of a script has no call position of its own
        (( __script && __i == __n - 1 )) && break
        __f=${BASH_SOURCE[__i+1]-}
        # a pseudo file: a function defined at a prompt, in bash -c or in a
        # script read from stdin (5.2: environment / main; 5.3: $0), or one
        # inherited from the environment
        if [[ $__f == environment || $__f == main || ( -n $__z && $__f == "$__z" ) ]]; then
            (( __started )) || continue
            __f=""
        elif (( ! __started )); then
            case ${__f##*/} in
                kklass.sh|kklass_decl.sh|kklass_pascal.sh|kklass_kkp.sh|kklass_serializable.sh|kklass_autoload.sh|kklass_compiler.sh) continue ;;
            esac
        fi
        __started=1
        case $__f in
            '') __a="" ;;
            /*|[A-Za-z]:[/\\]*) __a=$__f; __nofile=0 ;;
            *) __a=$PWD/$__f; __nofile=0 ;;
        esac
        __l=${BASH_LINENO[__i]-0}
        __raw+="${__raw:+$'\x1f'}$__f:$__l"
        __abs+="${__abs:+$'\x1f'}$__a:$__l"
        if [[ ${FUNCNAME[__i+1]-} == source ]]; then
            __kk_site_open="$(( __n - 2 - __i ))|${BASH_SOURCE[__i+1]}"
            break
        fi
    done
    __kk_site=$__raw$'\x1d'$__abs
    __kk_site_tty=0
    if (( __nofile )) && [[ $- == *i* ]]; then __kk_site_tty=1; fi
    return 0
}

# kk._class_site_same SITE_A SITE_B — rc 0 when both are the same site: the
# same lines and, per position, the same file (see "The FILE parts" above).
kk._class_site_same() {
    [[ $1 == "$2" ]] && return 0
    local -a __ra __rb __aa __ab
    local __k __fa __fb
    IFS=$'\x1f' read -r -a __ra <<<"${1%%$'\x1d'*}"
    IFS=$'\x1f' read -r -a __rb <<<"${2%%$'\x1d'*}"
    IFS=$'\x1f' read -r -a __aa <<<"${1#*$'\x1d'}"
    IFS=$'\x1f' read -r -a __ab <<<"${2#*$'\x1d'}"
    (( ${#__ra[@]} == ${#__rb[@]} && ${#__aa[@]} == ${#__ra[@]} && ${#__ab[@]} == ${#__rb[@]} )) || return 1
    for (( __k = 0; __k < ${#__ra[@]}; __k++ )); do
        [[ ${__ra[__k]##*:} == "${__rb[__k]##*:}" ]] || return 1
        __fa=${__aa[__k]%:*} __fb=${__ab[__k]%:*}
        [[ $__fa == "$__fb" ]] && continue
        if [[ ${__ra[__k]%:*} == "${__rb[__k]%:*}" ]]; then
            # one spelling: the same file unless both absolute forms are files and differ
            if [[ -e $__fa && -e $__fb ]] && ! [[ $__fa -ef $__fb ]]; then return 1; fi
            continue
        fi
        [[ -n $__fa && -n $__fb && $__fa -ef $__fb ]] || return 1
    done
    return 0
}

# kk._class_site_text SITE -> __kk_site_txt: "FILE:LINE <- FILE:LINE ..." from
# the absolute positions, each FILE normalised lexically (`\` -> `/`, `.`, `..`
# and `//` folded), a pseudo file as "(no file)" — for messages only.
kk._class_site_text() {
    local -a __a __s __o
    local __p __f __pre __g __t="" IFS=/
    IFS=$'\x1f' read -r -a __a <<<"${1#*$'\x1d'}"
    for __p in "${__a[@]}"; do
        __f=${__p%:*} __f=${__f//\\//} __pre=""
        case $__f in
            '') __f="(no file)" ;;
            *)
                [[ $__f == [A-Za-z]:/* ]] && { __pre=${__f:0:2}; __f=${__f:2}; }
                __o=()
                IFS=/ read -r -a __s <<<"$__f"
                for __g in "${__s[@]}"; do
                    case $__g in
                        ''|.) ;;
                        ..) (( ${#__o[@]} )) && unset '__o[${#__o[@]}-1]' ;;
                        *) __o+=("$__g") ;;
                    esac
                done
                __f="$__pre/${__o[*]}"
                ;;
        esac
        __t+="${__t:+ <- }$__f:${__p##*:}"
    done
    __kk_site_txt=$__t
}

# kk._class_verdict CLASS [SITE] — may CLASS be built from the current site
# (or from SITE: a compiled cache names the site its class was built from)?
#   rc 0 yes (not built yet, or a prompt redefinition), __kk_site = the site;
#   rc 1 "Duplicate identifier" (printed; the loading unit tainted, U34);
#   rc 2 the same site again (WARNING printed);
#   rc 3 not built yet, but CLASS is a DSL verb or a function namespace
#        (printed, "Taken names" above; __kk_taken_kind = verb | ns).
# Needs the caller's locals __kk_site __kk_site_tty __kk_site_open
# __kk_taken_kind.
kk._class_verdict() {
    local __kk_c=$1 __kk_site_txt __kk_old
    [[ ${__KKLASS_TABLES[@]@a} == A ]] || kk._class_tables
    if (( $# > 1 )); then
        __kk_site=$2 __kk_site_tty=0 __kk_site_open="-1|"
    else
        kk._class_site
    fi
    if [[ -z ${_KKLASS_CLASS_SITE[$__kk_c]+x} ]]; then
        kk._taken_check "$__kk_c" || return 3
        return 0
    fi
    (( __kk_site_tty )) && return 0
    kk._class_site_text "${_KKLASS_CLASS_SITE[$__kk_c]}"; __kk_old=$__kk_site_txt
    if kk._class_site_same "${_KKLASS_CLASS_SITE[$__kk_c]}" "$__kk_site"; then
        kk.warn "kklass: WARNING: class '${__kk_c}' declared again from the same place (${__kk_old}); ignored, the class is not rebuilt"
        return 2
    fi
    kk._class_site_text "$__kk_site"
    echo "kklass: Duplicate identifier: class '${__kk_c}' is already declared at ${__kk_old}; refusing to redeclare it at ${__kk_site_txt}" >&2
    # a structural error inside a unit's load: that unit is not complete (U34)
    if [[ ${__KK_LOADED[@]@a} == A ]]; then kk._unit_taint 1; fi
    return 1
}

# kk._class_register CLASS SITE — CLASS is built: remember its site, file it
# under the unit being loaded (P4). rc 2 for a CLASS that is not an identifier.
kk._class_register() {
    [[ -n ${1-} ]] && kk._is_ident "$1" || return 2
    [[ ${__KKLASS_TABLES[@]@a} == A ]] || kk._class_tables
    local __kk_f=${2#*$'\x1d'} __kk_r
    __kk_f=${__kk_f%%$'\x1f'*}
    __kk_f=${__kk_f%:*}
    _KKLASS_CLASS_SITE[$1]=$2
    _KKLASS_CLASS_SOURCE[$1]=${__kk_f:-(no file)}
    _KKLASS_TAKEN[$1]=class
    unset '_KKLASS_DECL_SITE[$1]'
    if [[ ${__KK_LOADED[@]@a} == A ]]; then
        __kk_r=${RESULT-}
        if kk._unit_current; then kk._unit_add_class "$RESULT" "$1"; fi
        RESULT=$__kk_r
    fi
    return 0
}

# kk._unit_forget_class CLASS — the `kk.unit --forget` hook (kkore/kuse.sh,
# P4): drop CLASS's site records so the next source of its unit rebuilds it
# (and close a sink of it). rc 0; rc 2 for a name that is not an identifier.
kk._unit_forget_class() {
    [[ -n ${1-} ]] && kk._is_ident "$1" || return 2
    [[ ${__KKLASS_TABLES[@]@a} == A ]] || return 0
    kk.decl._sink_close "$1"
    unset '_KKLASS_CLASS_SITE[$1]' '_KKLASS_CLASS_SOURCE[$1]' '_KKLASS_DECL_SITE[$1]'
    return 0
}

# kk.class --forget CLASS — forget where CLASS was declared, so the next source
# of its file (a file without a unit header) rebuilds it instead of ignoring the
# declaration with a WARNING (U20). The class itself and its instances are NOT
# deleted: until the rebuild they keep working, and after it existing instances
# dispatch to the new method bodies. A unit's classes are forgotten with
# `kk.unit --forget UNIT`. rc 0 forgotten, 1 CLASS is not a registered (built)
# class, 2 a malformed call (silent, kk.debug — kcl §1).
kk.class() {
    if [[ ${1-} != --forget || $# -ne 2 ]]; then
        kk.debug "kk.class: usage: kk.class --forget CLASS"
        return 2
    fi
    if ! kk._is_ident "$2"; then
        kk.debug "kk.class --forget: not a class name: '$2'"
        return 2
    fi
    [[ ${__KKLASS_TABLES[@]@a} == A ]] || kk._class_tables
    [[ -n ${_KKLASS_CLASS_SITE[$2]+x} ]] || return 1
    kk._unit_forget_class "$2"
}

# ---------------------------------------------------------------------------
# Compiled caches (.ckk, uses U2b: C13, P9, U11). kklass_compiler.sh writes, per
# class, `if kk._ckk_class CLASS SITE; then <the dump>; kk._ckk_built CLASS; fi`
# after one `kk._ckk_begin UNIT REL ABS`, and `kk._ckk_end` at the end. A class
# loaded from a cache is so registered like a built one: declared again from
# another file it is a Duplicate identifier (before U2b it was replaced
# silently), from the same place a WARNING (U20) — and a cache whose class is
# already built from another place, or named like a verb or a namespace, skips
# that class's dump instead of overwriting it.
# SITE is the declaration site the compiler saw, the compiled source file as
# the placeholder $'\x1e'; kk._ckk_begin UNIT REL ABS resolves it to (first
# that applies):
#   1. the file autoloadClasses is loading (its local __kk_ckk_from: the source
#      made absolute; for a .kkp its runtime translation <cache>/<stem>.sh) —
#      so a cached and a runtime load of one source are the same site;
#   2. REL, the source relative to the cache's folder (P9, review R2: a project
#      moved together with its cache), when ABS is empty (a .kkp's runtime
#      translation, which need not exist) or that file exists;
#   3. the source UNIT by name, when the source is a unit and kbool is loaded:
#      the file `kk.uses UNIT` finds from the folder above the cache;
#   4. ABS, the absolute path at compile time.

# kk._ckk_begin UNIT REL [ABS] — a compiled cache starts (see above).
kk._ckk_begin() {
    local __kk_d=${BASH_SOURCE[1]-} __kk_found __kk_f="" __kk_r=${2-}
    [[ ${__KKLASS_TABLES[@]@a} == A ]] || kk._class_tables
    case $__kk_d in
        */*|*\\*) __kk_d=${__kk_d%[/\\]*} ;;
        *) __kk_d=. ;;
    esac
    [[ $__kk_d == /* || $__kk_d == [A-Za-z]:* ]] || __kk_d=$PWD/$__kk_d
    [[ -z $__kk_r || $__kk_r == /* || $__kk_r == [A-Za-z]:* ]] || __kk_r=$__kk_d/$__kk_r
    if [[ -n ${__kk_ckk_from-} ]]; then
        __kk_f=$__kk_ckk_from
    elif [[ -n $__kk_r ]] && [[ -z ${3-} || -f $__kk_r ]]; then
        __kk_f=$__kk_r
    elif [[ -n ${1-} && ${__KK_LOADED[@]@a} == A ]] && declare -F kk._unit_find >/dev/null \
         && kk._unit_find "$1" "${__kk_d%[/\\]*}" 2>/dev/null; then
        __kk_f=$__kk_found
    else
        __kk_f=${3:-$__kk_r}
    fi
    [[ -z $__kk_f || $__kk_f == /* || $__kk_f == [A-Za-z]:* ]] || __kk_f=$PWD/$__kk_f
    __KK_CKK_FILE=$__kk_f
    __KK_CKK_SITE=""
    return 0
}

# kk._ckk_class CLASS SITE — rc 0: load CLASS's dump (its resolved site is kept
# for kk._ckk_built); rc 1: skip it — already built from another place
# (Duplicate identifier), from the same place (WARNING), or a verb / namespace
# (printed by kk._class_verdict).
kk._ckk_class() {
    local __kk_site __kk_site_tty __kk_site_open __kk_taken_kind __kk_s=${2-}
    kk._is_ident "${1-}" || { echo "kklass: a compiled cache names an invalid class: '${1-}'" >&2; return 1; }
    __kk_s=${__kk_s//$'\x1e'/${__KK_CKK_FILE-}}
    kk._class_verdict "$1" "$__kk_s" || return 1
    __KK_CKK_SITE=$__kk_site
    return 0
}

# kk._ckk_built CLASS — the dump of CLASS is loaded: register it (site, unit).
kk._ckk_built() {
    kk._class_register "$1" "${__KK_CKK_SITE-}"
}

# kk._ckk_end — the cache is loaded.
kk._ckk_end() {
    unset __KK_CKK_FILE __KK_CKK_SITE
    return 0
}

# Scratch global used by kk._find_method to return the resolving class
# without forking a subshell.
declare -g __kk_find_class=""

kk._return() {
    local return_value="$1"

    # -v, not `declare -p ... &>/dev/null`: declare -p formats the variable
    # (and every enclosing scope lookup) on every function return (P4b).
    if [[ -v __kk_return_set ]]; then
        __kk_return_set=1
        __kk_return_value="$return_value"
    fi

    RESULT="$return_value"

    # Automatically emit the value if we're in a subshell context.
    # printf, not `echo -n`: a returned value is DATA and must round-trip
    # verbatim. `echo` parses leading `-e`/`-n`/`-E`/`-neE` as its own options
    # and prints nothing, so `$(L.Get 0)` lost every such element while the
    # direct-call RESULT path stayed correct (kcl review 2026-09-06, G1-13/G2-03).
    if [[ $BASH_SUBSHELL -gt 0 && "${__kk_return_silent:-0}" != "1" ]]; then
        printf '%s' "$return_value"
        return
    fi
}

kk.call_silent() {
    local instance_name="$1"
    local method_name="$2"
    shift 2

    local had_silent=0
    local previous_silent=""
    if [[ ${__kk_return_silent+x} ]]; then
        had_silent=1
        previous_silent="$__kk_return_silent"
    fi

    __kk_return_silent=1
    "${instance_name}.call" "$method_name" "$@"
    local call_status=$?
    local call_result="$RESULT"

    if (( had_silent )); then
        __kk_return_silent="$previous_silent"
    else
        unset __kk_return_silent
    fi

    RESULT="$call_result"
    return "$call_status"
}

# Final form of a member body: the text as written, plus the kk._return trailer
# for a `function`. Result in METHOD_BODY.
#
# Up to round 2 / R2_P8 this also rewrote the TEXT `$this.NAME` / `${this}.NAME`
# into `$__inst__.call NAME` for every method NAME of the class. That was a blind
# prefix substitution: it rewrote quoted data (`local s="$this.Home"` became
# `q.call Home`) and longer names (with a method `count`, `$this.counter` became
# `.call counter`; with a method `pa`, the `$this.parent go` that `inherited go`
# turns into became `.call parent go`) — finding K1. It is gone (DR1 as amended
# 2026-10-01): `$this.NAME` is now a plain call of the instance's own wrapper
# function (kk._exec, the defining class baked in at `.new`), which dispatches
# virtually as of `.new`. A 5th argument (the old methods-array name) is still
# accepted and ignored.
kk._processMethodBody() {
    local class_name="$1"
    local method_name="$2"
    local method_body="$3"
    local meth_type="${4:-method}"

    # For function type, append kk._return call
    if [[ "$meth_type" == "function" ]]; then
        #method_body+=$'\n'"kk._return \"${class_name}_${method_name}\" \"\$RESULT\""
        method_body+=$'\n'"kk._return \"\$RESULT\""
    fi
    
    METHOD_BODY="$method_body"
}

kk._class_derives_from() {
    local candidate_class="$1"
    local ancestor_class="$2"
    local parent_var=""

    if [[ -z "$candidate_class" || -z "$ancestor_class" ]]; then
        return 1
    fi

    if [[ "$candidate_class" == "$ancestor_class" ]]; then
        return 0
    fi

    parent_var="${candidate_class}_parent_class"
    while [[ -n "${!parent_var:-}" ]]; do
        if [[ "${!parent_var:-}" == "$ancestor_class" ]]; then
            return 0
        fi
        candidate_class="${!parent_var:-}"
        parent_var="${candidate_class}_parent_class"
    done

    return 1
}

# kk._is_ident NAME — the ONE identifier guard of the kklass entry paths
# (round 3 / P11, finding M3, decision DR9): kk.isAbstract, kk.derivesFrom,
# kk.decl._validate_ident (every class / member name of every builder), the
# generated CLASS.new under nocasematch (instance name) and loadObjects (class
# name). It replaced `[[ $x =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]`, which overwrote
# the caller's BASH_REMATCH on every call and, under nocasematch in a UTF-8
# locale, accepted ı / İ (an indirect expansion of those ABORTED the caller's
# command). Since round 4 / P12 (findings L1 + L2, decision DR13) it is
# DEFINED in kkore/klib.sh — sourced above, before anything here — and shared
# with kk._outName and kc.alias: ASCII ranges + a `*[![:ascii:]]*` guard,
# nocasematch switched off around the core, NO locale switch (P11's
# `local LC_ALL=C` cost ≈4.5× under a UTF-8 caller locale: kk.derivesFrom
# 70 -> 213 us). kklass keeps exporting it (KKLASS_EXPORT_FUNCTIONS, test 135 D3).

# kk.isAbstract CLASS — the public "would CLASS.new refuse?" predicate (round 2
# / R2_P9, finding K4, decision DR3; replaces reading ${CLASS}_class_abstract).
#   rc 0  CLASS is a built class that is still abstract (an abstract member is
#         unresolved) — CLASS.new refuses it;
#   rc 1  CLASS is a built, instantiable class — including one built directly
#         by kk._build_class_runtime, which never sets the flag;
#   rc 2  CLASS is not an identifier, was never declared, or is declared but
#         not finalized (endImplementation / build not run: no CLASS.new yet).
# "Built" = ${CLASS}_class_methods exists. Silent on every path and fork-free.
# The identifier check runs FIRST: an indirect expansion of a non-identifier
# is a fatal error that aborts the caller's whole top-level command. The check
# is kk._is_ident (P11/M3): locale-exact, BASH_REMATCH left alone.
kk.isAbstract() {
    kk._is_ident "${1:-}" || return 2
    declare -p "${1}_class_methods" &>/dev/null || return 2
    local __kk_ia="${1}_class_abstract"
    if [[ "${!__kk_ia:-}" == 1 ]]; then
        return 0
    fi
    return 1
}

# kk.derivesFrom CHILD ANCESTOR — the public form of kk._class_derives_from
# (R2_P9, DR3). rc 0 when CHILD is ANCESTOR or descends from it (the parent
# chain, ${CLASS}_parent_class), rc 1 when not — including a CHILD that was
# never declared — and rc 2 when either argument is not an identifier. The
# internal validates nothing: a non-identifier CHILD aborts the caller's
# command (`${!v}` on "a b_parent_class"), and two EQUAL non-identifiers
# answer 0. Reflexive, no existence check. Silent, fork-free; the identifier
# check is kk._is_ident (P11/M3), BASH_REMATCH is left alone.
kk.derivesFrom() {
    kk._is_ident "${1:-}" && kk._is_ident "${2:-}" || return 2
    kk._class_derives_from "$1" "$2"
}

kk._warn_visibility() {
    local class_name="$1"
    local member_type="$2"
    local member_name="$3"
    local visibility_var="${class_name}_${member_type}_visibility"
    local owner_var="${class_name}_${member_type}_owner"
    local visibility="public"
    local owner_class="$class_name"
    local current_frame=""
    local current_class=""
    local warn_key=""

    if ! declare -p "$visibility_var" &>/dev/null; then
        return 0
    fi

    local -n visibility_ref="$visibility_var"
    visibility="${visibility_ref[$member_name]:-public}"
    if [[ "$visibility" == "public" || -z "$visibility" ]]; then
        return 0
    fi

    if declare -p "$owner_var" &>/dev/null; then
        local -n owner_ref="$owner_var"
        owner_class="${owner_ref[$member_name]:-$class_name}"
    fi

    kv.frameCurrent >/dev/null 2>&1 || true
    current_frame="$RESULT"
    if [[ -n "$current_frame" ]]; then
        kv.frameClass "$current_frame" >/dev/null 2>&1 || true
        current_class="$RESULT"
    fi

    case "$visibility" in
        private)
            if [[ "$current_class" == "$owner_class" ]]; then
                return 0
            fi
            ;;
        protected)
            if [[ "$current_class" == "$owner_class" ]] || kk._class_derives_from "$current_class" "$owner_class"; then
                return 0
            fi
            ;;
        *)
            return 0
            ;;
    esac

    declare -gA __KK_VIS_WARNED
    warn_key="${current_class:-external}:${owner_class}:${member_type}:${member_name}:${visibility}"
    if [[ -n "${__KK_VIS_WARNED[$warn_key]:-}" ]]; then
        return 0
    fi

    __KK_VIS_WARNED["$warn_key"]=1
    echo "[kk] warning: ${visibility} ${member_type%_*} '${owner_class}.${member_name}' accessed from '${current_class:-external}'" >&2
}

# Text of one per-instance method wrapper (template form, __INST__ placeholder).
# Shared by the class build and by defineMethod (F3) so the latter can find and
# replace the exact wrapper the build emitted. Result in METHOD_WRAPPER.
kk._method_wrapper_text() {
    METHOD_WRAPPER=$'\n'"__INST__.$1() { kk._exec __INST__ $1 $2 \"\$@\"; }"
}

# Run a class's constructor body in the CURRENT frame (used by parent-constructor
# chaining). The body is looked up indirectly and eval'd — never embedded into a
# generated function, so a body containing quotes/semicolons is safe. Extra args
# become the constructor's positional parameters ($1, $2, ...).
kk._invoke_constructor() {
    local __kk_ctor_cls="$1"
    shift
    local __kk_ctor_var="${__kk_ctor_cls}_constructor_body"
    if [[ -n "${!__kk_ctor_var:-}" ]]; then
        eval "${!__kk_ctor_var:-}"
    fi
}

# ---------------------------------------------------------------------------
# Shared instance runtime (P4a). ONE copy per shell, not per instance: an
# instance is a data array, a class variable and one-line wrappers that call
# these with the instance name as the first argument. Before P4a every .new
# eval'd its own ~8 KB copy of all of this (dispatch, frames, accessors, find,
# call, parent, delete). Behaviour is unchanged; only the copies are gone.
# Every local here is __kk_-prefixed: a method body is eval'd inside
# kk._run_frame_body and sees the whole dynamic scope chain.

kk._property() {   # INST NAME [= VALUE]
    local -n __kk_d="${1}_data"
    if [[ "${3:-}" == "=" ]]; then
        __kk_d["$2"]="$4"
    else
        # printf, not echo -e: values are data and must round-trip verbatim.
        printf '%s\n' "${__kk_d["$2"]}"
    fi
}

# Visibility gate shared by the accessors: a class whose every member is public
# (<Class>_has_nonpublic=0, set at endImplementation) skips the check entirely.
# Unset flag (a class built outside the declarative path) = do the full check.
kk._prop_plain() {   # INST CLASS PROP [= VALUE]
    local __kk_np="${2}_has_nonpublic"
    [[ "${!__kk_np:-1}" == "0" ]] || kk._warn_visibility "$2" property "$3"
    local -n __kk_d="${1}_data"
    if [[ "${4:-}" == "=" ]]; then
        __kk_d["$3"]="$5"
    else
        printf '%s\n' "${__kk_d["$3"]}"
    fi
}

kk._prop_computed() {   # INST CLASS PROP GETTER SETTER [= VALUE]
    local __kk_np="${2}_has_nonpublic"
    [[ "${!__kk_np:-1}" == "0" ]] || kk._warn_visibility "$2" property "$3"
    local __kk_inst="$1" __kk_prop="$3" __kk_getter="$4" __kk_setter="$5"
    if [[ "${6:-}" == "=" ]]; then
        if [[ -n "$__kk_setter" ]]; then
            kk._call "$__kk_inst" "$__kk_setter" "$7"
        else
            kk._property "$__kk_inst" "$__kk_prop" = "$7"
        fi
        return
    fi
    if [[ -z "$__kk_getter" ]]; then
        kk._property "$__kk_inst" "$__kk_prop"
        return
    fi
    # D1 (amended): a computed property follows the kk._return contract every
    # kcl unit relies on: a DIRECT read is silent and sets RESULT, a
    # $(obj.prop) capture prints the value exactly once. The getter chain runs
    # silent so no inner kk._return echoes; the single echo happens here, only
    # in a subshell and only if the caller was not already silent.
    local __kk_outer_silent="${__kk_return_silent:-0}"
    local __kk_return_silent=1
    # The getter's status is the answer of an rc-predicate property; keep it,
    # but still print the value under $( ) on a non-zero status (P6-F1).
    local __kk_grc=0
    kk._call "$__kk_inst" "$__kk_getter" || __kk_grc=$?
    if (( BASH_SUBSHELL > 0 )) && [[ "$__kk_outer_silent" != "1" ]]; then
        printf '%s' "$RESULT"
    fi
    return "$__kk_grc"
}

kk._prop_lazy() {   # INST CLASS PROP INIT SETTER [= VALUE]
    local __kk_np="${2}_has_nonpublic"
    [[ "${!__kk_np:-1}" == "0" ]] || kk._warn_visibility "$2" property "$3"
    local __kk_inst="$1" __kk_prop="$3" __kk_init="$4" __kk_setter="$5"
    if [[ "${6:-}" == "=" ]]; then
        if [[ -n "$__kk_setter" ]]; then
            kk._call "$__kk_inst" "$__kk_setter" "$7"
        else
            kk._property "$__kk_inst" "$__kk_prop" = "$7"
        fi
        return
    fi
    local __kk_lv="${__kk_inst}_lazy_${__kk_prop}"
    if [[ ! -v "$__kk_lv" ]]; then
        local __kk_val
        __kk_val="$("${__kk_inst}.${__kk_init}")"
        declare -g "${__kk_lv}=${__kk_val}"
    fi
    printf '%s\n' "${!__kk_lv:-}"
}

# Run BODY with the instance context in scope: this/__inst__/__class__, the
# `state` nameref to the data array, one nameref per property (including
# inherited ones; the list is the one of the instance class) and one per
# static property (bound to the DEFINING class storage).
kk._run_frame_body() {   # INST ACTIVE_CLASS BODY ARGS...
    local __kk_inst="$1" __class__="$2" __kk_method_body="$3"
    shift 3
    local this="$__kk_inst"
    local __inst__="$__kk_inst"
    local -n state="${__kk_inst}_data"
    local __kk_cv="${__kk_inst}_class"
    local __kk_cls="${!__kk_cv:-}"
    local -n __kk_props="${__kk_cls}_class_properties"
    local __kk_p
    for __kk_p in "${__kk_props[@]}"; do
        local -n "${__kk_p}=${__kk_inst}_data[${__kk_p}]"
    done
    local -n __kk_sprops="${__kk_cls}_class_static_properties"
    if (( ${#__kk_sprops[@]} )); then
        local -n __kk_sowner="${__kk_cls}_class_static_property_owner"
        for __kk_p in "${__kk_sprops[@]}"; do
            local -n "${__kk_p}=${__kk_sowner[$__kk_p]:-$__kk_cls}_static_${__kk_p}"
        done
    fi

    eval "$__kk_method_body"
}

# Frame push/pop + RESULT protocol around one body execution. The frame
# push/pop is kv.framePush/kv.framePop inlined (P4b): same three kkore arrays,
# so kv.frameCurrent / kv.frameClass in kk._parent and kk._warn_visibility see
# exactly the same stack — minus three function calls per method call. The
# body must stay in its own function (kk._run_frame_body): a `return` inside
# it must come back HERE so the frame is always popped.
kk._invoke() {   # INST ACTIVE_CLASS BODY ARGS...
    local __kk_inst="$1" __kk_active_class="$2" __kk_body="$3"
    shift 3
    local this="$__kk_inst"
    local __kk_caller_result="$RESULT"
    local __kk_return_set=0
    local __kk_return_value=""
    local __kk_frame_id=${#__KLIB_FRAME_STACK[@]}
    __KLIB_FRAME_STACK[__kk_frame_id]=$__kk_frame_id
    __KLIB_FRAME_INSTANCE[__kk_frame_id]="$__kk_inst"
    __KLIB_FRAME_CLASS[__kk_frame_id]="$__kk_active_class"

    kk._run_frame_body "$__kk_inst" "$__kk_active_class" "$__kk_body" "$@"
    local __kk_status=$?

    unset '__KLIB_FRAME_STACK[$__kk_frame_id]' '__KLIB_FRAME_INSTANCE[$__kk_frame_id]' '__KLIB_FRAME_CLASS[$__kk_frame_id]'
    if (( __kk_return_set )); then
        RESULT="$__kk_return_value"
    else
        RESULT="$__kk_caller_result"
    fi
    return $__kk_status
}

# Static dispatch used by the per-instance method wrappers: the wrapper names
# the DEFINING class (owner) of the method, so `inherited`/.parent inside the
# body walks up from where the body was defined (Pascal semantics). This is
# also what `$this.NAME` inside a body runs (R2_P8: the body text is no longer
# rewritten into `.call NAME`), so a call is virtual as of `.new`.
kk._exec() {   # INST METHOD OWNER ARGS...
    local __kk_inst="$1" __kk_m="$2" __kk_owner="$3"
    shift 3
    local __kk_bv="${__kk_owner}_method_body_${__kk_m}"
    local __kk_body="${!__kk_bv:-}"
    # SET-ness, not emptiness (R2_P8, divergence c): an empty body is a valid
    # no-op and runs silently with rc 0, exactly as `.call` runs it. The second
    # test only runs for an empty body, so the hot path keeps one expansion.
    if [[ -z "$__kk_body" && -z "${!__kk_bv+x}" ]]; then
        echo "Error: Method '$__kk_m' not found in class '$__kk_owner'" >&2
        return 1
    fi
    local __kk_np="${__kk_owner}_has_nonpublic"
    [[ "${!__kk_np:-1}" == "0" ]] || kk._warn_visibility "$__kk_owner" method "$__kk_m"
    kk._invoke "$__kk_inst" "$__kk_owner" "$__kk_body" "$@"
}

# Find the first class in the chain starting at SEARCH_CLASS that holds a body
# for METHOD. Result in __kk_find_class (empty = not found), no fork.
kk._find_method() {   # METHOD SEARCH_CLASS
    local __kk_m="$1" __kk_cls="$2"
    local __kk_bv="${__kk_cls}_method_body_${__kk_m}"
    __kk_find_class=""
    if [[ -n "${!__kk_bv:-}" ]]; then
        __kk_find_class="$__kk_cls"
        return 0
    fi
    local __kk_pv="${__kk_cls}_parent_class"
    local __kk_parent="${!__kk_pv:-}"
    while [[ -n "$__kk_parent" ]]; do
        __kk_bv="${__kk_parent}_method_body_${__kk_m}"
        if [[ -n "${!__kk_bv:-}" ]]; then
            __kk_find_class="$__kk_parent"
            return 0
        fi
        __kk_pv="${__kk_parent}_parent_class"
        __kk_parent="${!__kk_pv:-}"
    done
    return 1
}

# VIRTUAL dispatch (Pascal semantics): resolve from the own class of the
# instance so subclass overrides win even from inside an inherited body; the
# resolved class is mapped to the DEFINING class so nested `inherited`
# continues from the right level.
kk._call() {   # INST METHOD ARGS...
    local __kk_inst="$1" __kk_m="$2"
    shift 2
    local __kk_cv="${__kk_inst}_class"
    local __kk_search="${!__kk_cv:-}"

    local __kk_cache_cell="${__kk_search}_method_cache[${__kk_m}]"
    local __kk_found="${!__kk_cache_cell:-}"
    if [[ -z "$__kk_found" ]]; then
        kk._find_method "$__kk_m" "$__kk_search"
        __kk_found="$__kk_find_class"
        if [[ -z "$__kk_found" ]]; then
            echo "Error: Method '$__kk_m' not found in class hierarchy" >&2
            return 1
        fi
        local __kk_ov="${__kk_found}_class_method_owner[${__kk_m}]"
        [[ -n "${!__kk_ov:-}" ]] && __kk_found="${!__kk_ov:-}"
        local -n __kk_cache="${__kk_search}_method_cache"
        __kk_cache["$__kk_m"]="$__kk_found"
    fi

    local __kk_bv="${__kk_found}_method_body_${__kk_m}"
    local __kk_np="${__kk_found}_has_nonpublic"
    [[ "${!__kk_np:-1}" == "0" ]] || kk._warn_visibility "$__kk_found" method "$__kk_m"
    kk._invoke "$__kk_inst" "$__kk_found" "${!__kk_bv:-}" "$@"
}

# `inherited` / $this.parent: STATIC resolution from the parent of the class
# that owns the CURRENTLY RUNNING body (frame class), not of the instance.
kk._parent() {   # INST METHOD ARGS...
    local __kk_inst="$1" __kk_m="$2"
    shift 2
    # Internal dispatch (see kk._call): result via RESULT, no echo.
    local __kk_return_silent=1
    local __kk_cv="${__kk_inst}_class"
    local __kk_active="${!__kk_cv:-}"
    local __kk_frame=""
    kv.frameCurrent >/dev/null 2>&1 || true
    __kk_frame="$RESULT"
    if [[ -n "$__kk_frame" ]]; then
        kv.frameClass "$__kk_frame"
        __kk_active="$RESULT"
    fi

    local __kk_pv="${__kk_active}_parent_class"
    local __kk_parent_of="${!__kk_pv:-}"
    if [[ -z "$__kk_parent_of" ]]; then
        echo "Error: No parent class for '${__kk_active}'" >&2
        return 1
    fi

    local __kk_key="${__kk_active}_parent_${__kk_m}"
    local __kk_cache_cell="${__kk_active}_method_cache[${__kk_key}]"
    local __kk_found="${!__kk_cache_cell:-}"
    if [[ -z "$__kk_found" ]]; then
        kk._find_method "$__kk_m" "$__kk_parent_of"
        __kk_found="$__kk_find_class"
        if [[ -z "$__kk_found" ]]; then
            echo "Error: Parent method '$__kk_m' not found" >&2
            return 1
        fi
        local __kk_ov="${__kk_found}_class_method_owner[${__kk_m}]"
        [[ -n "${!__kk_ov:-}" ]] && __kk_found="${!__kk_ov:-}"
        local -n __kk_cache="${__kk_active}_method_cache"
        __kk_cache["$__kk_key"]="$__kk_found"
    fi

    local __kk_bv="${__kk_found}_method_body_${__kk_m}"
    local __kk_np="${__kk_found}_has_nonpublic"
    [[ "${!__kk_np:-1}" == "0" ]] || kk._warn_visibility "$__kk_found" method "$__kk_m"
    kk._invoke "$__kk_inst" "$__kk_found" "${!__kk_bv:-}" "$@"
}

# Run the class constructor body (if any) in a frame of CLASS.
kk._constructor_exec() {   # INST CLASS ARGS...
    local __kk_inst="$1" __kk_cls="$2"
    shift 2
    local __kk_bv="${__kk_cls}_constructor_body"
    [[ -n "${!__kk_bv:-}" ]] || return 0
    kk._invoke "$__kk_inst" "$__kk_cls" "${!__kk_bv:-}" "$@"
}

# Destroy an instance: destructor (if the class declares one), lazy globals,
# data + class vars, every per-instance wrapper. The wrapper list comes from
# the class tables (props + methods + the four fixed ones), so it also covers
# methods added later with defineMethod. No fork, no compgen (F1).
kk._delete() {   # INST
    local __kk_inst="$1"
    local __kk_cv="${__kk_inst}_class"
    local __kk_cls="${!__kk_cv:-}"
    local __kk_dv="${__kk_cls}_destructor_name"
    local __kk_dtor="${!__kk_dv:-}"
    [[ -n "$__kk_dtor" ]] && kk._call "$__kk_inst" "$__kk_dtor"

    local -n __kk_ms="${__kk_cls}_class_methods"
    local -n __kk_ps="${__kk_cls}_class_properties"
    local -n __kk_lz="${__kk_cls}_lazy_inits"
    local __kk_x
    for __kk_x in "${!__kk_lz[@]}"; do unset "${__kk_inst}_lazy_${__kk_x}"; done
    unset "${__kk_inst}_data" "${__kk_inst}_class"
    local -a __kk_fns=("${__kk_inst}.property" "${__kk_inst}.call" "${__kk_inst}.parent" "${__kk_inst}.delete")
    for __kk_x in "${__kk_ms[@]}" "${__kk_ps[@]}"; do
        __kk_fns+=("${__kk_inst}.${__kk_x}")
    done
    unset -f "${__kk_fns[@]}"
}

# kk._class_static_api CLASS — (re)generate CLASS's class-level functions from
# its stored tables (${CLASS}_class_static_properties, _static_property_owner,
# _class_static_methods): the static property accessors CLASS.PROP and the
# static method dispatchers CLASS.METHOD. The bodies (CLASS.__static_METHOD) and
# the static values are not touched. Called by kk._build_class_runtime, and by
# the swallowed Pascal `build` of a unit sourced again (uses U20, C6): the
# re-run redefined CLASS.METHOD as a plain body function, which would otherwise
# replace the dispatcher (`TU20.GetCount` printed `count=` instead of `count=2`).
kk._class_static_api() {
    local class_name="$1" sp sm static_owner static_namerefs=""
    local -n __kk_sa_props="${class_name}_class_static_properties"
    local -n __kk_sa_owner="${class_name}_class_static_property_owner"
    local -n __kk_sa_meths="${class_name}_class_static_methods"

    # Static property accessors: Class.property = value / Class.property
    for sp in "${__kk_sa_props[@]}"; do
        static_owner="${__kk_sa_owner[$sp]:-$class_name}"
        eval "${class_name}.${sp}() {
                if [[ \"\$1\" == \"=\" ]]; then
                    ${static_owner}_static_${sp}=\"\$2\"
                else
                    echo \"\${${static_owner}_static_${sp}}\"
                fi
            }"
        static_namerefs+="local -n $sp=${static_owner}_static_${sp}; "
    done

    # Static methods: Class.method args
    #
    # The body ALWAYS lives in its own function Class.__static_NAME (F5): a
    # `return N` inside it then comes back to the wrapper, which finishes
    # its bookkeeping and returns N. Before, the body was inlined into the
    # wrapper, so `return` aborted the wrapper mid-way: the 5.2 path leaked
    # its scratch file and lost stdout, the 5.3 funsub path swallowed the
    # status, and a failing last command reported printf's 0 on both.
    # Static-property namerefs are declared in the wrapper and reach the
    # body through bash's dynamic scoping.
    #
    # Two dispatcher shapes (pinned by test 114):
    #   * no static properties -> THIN: stdout flows straight through, no
    #     capture, no fork on any bash version (the string.* utility path).
    #   * static properties    -> CAPTURING: stdout is captured into REPLY
    #     and re-printed. REPLY is the return channel for a STATEFUL static
    #     method (a singleton's getInstance, test 026): `$(Class.m)` would
    #     run it in a subshell and lose the state mutation, so callers do
    #     `Class.m >/dev/null; use "$REPLY"`. bash 5.3+ captures with a
    #     funsub (no fork); 5.2 uses a scratch file (as before).
    local __kk_has_funsub=0
    if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 3) )); then
        __kk_has_funsub=1
    fi

    for sm in "${__kk_sa_meths[@]}"; do
        if (( ${#__kk_sa_props[@]} == 0 )); then
            eval "${class_name}.${sm}() {
                    local __kk_return_set=0
                    local __kk_return_value=\"\"
                    local __kk_return_silent=1
                    ${class_name}.__static_${sm} \"\$@\"
                    local __kk_status=\$?
                    if (( __kk_return_set )); then
                        printf \"%s\" \"\$__kk_return_value\"
                    fi
                    return \$__kk_status
                }"
        elif (( __kk_has_funsub )); then
            # The assignment's status is the funsub's status = the body's.
            eval "${class_name}.${sm}() {
                    ${static_namerefs}
                    local __kk_return_set=0
                    local __kk_return_value=\"\"
                    local __kk_return_silent=1
                    REPLY=\${ ${class_name}.__static_${sm} \"\$@\"; }
                    local __kk_status=\$?
                    if (( __kk_return_set )); then
                        REPLY+=\"\$__kk_return_value\"
                    fi
                    printf \"%s\" \"\$REPLY\"
                    return \$__kk_status
                }"
        else
            eval "${class_name}.${sm}() {
                    ${static_namerefs}
                    local __kk_return_set=0
                    local __kk_return_value=\"\"
                    local __kk_return_silent=1
                    local __kk_static_out=\"\${TMPDIR:-/tmp}/.kk_static_\${BASHPID}_\${RANDOM}\${RANDOM}\"
                    ${class_name}.__static_${sm} \"\$@\" >\"\$__kk_static_out\"
                    local __kk_status=\$?
                    REPLY=\"\$(<\"\$__kk_static_out\")\"
                    rm -f \"\$__kk_static_out\"
                    if (( __kk_return_set )); then
                        REPLY+=\"\$__kk_return_value\"
                    fi
                    printf \"%s\" \"\$REPLY\"
                    return \$__kk_status
                }"
        fi
    done
}

kk._build_class_runtime() {
    local class_name="$1"
    local parent_class="$2"
    shift 2

    # SECURITY: class_name, parent_class and every member name below are
    # interpolated into eval'd metadata assignments and generated function
    # names. The declarative defineClass path validates these before calling
    # us, but this function is also reachable directly and via other builders,
    # so validate here too (defense in depth). Reject anything that is not a
    # plain bash identifier.
    if [[ -z "$class_name" ]]; then
        echo "kk._build_class_runtime: class name is required" >&2
        return 1
    fi
    kk.decl._validate_ident "$class_name" "class name" || return 1
    kk.decl._validate_ident "$parent_class" "parent class name" || return 1

    # Declaration sites ("Duplicate identifier", uses U2a — see the top of this
    # file), checked BEFORE any runtime state is created/replaced below, so an
    # already-built original is left fully intact. endImplementation builds a
    # class declareClass already judged: its site is the declaration's. A raw
    # call is judged here: another site -> rc 1, the same site again -> one
    # WARNING and rc 0 without rebuilding. The site is registered at the end,
    # once the class is built.
    local __kk_site __kk_site_tty __kk_site_open __kk_taken_kind
    if [[ ${FUNCNAME[1]-} == endImplementation && ${__KKLASS_TABLES[@]@a} == A \
          && -n ${_KKLASS_DECL_SITE[$class_name]+x} ]]; then
        __kk_site=${_KKLASS_DECL_SITE[$class_name]}
    else
        kk._class_verdict "$class_name"
        case $? in
            1) return 1 ;;
            2) return 0 ;;
            3) return 1 ;;     # a DSL verb or a function namespace (printed)
        esac
    fi

    # Collect properties and methods (including inherited)
    local -a props_arr=()
    local -a meths_arr=()
    local -A meth_bodies
    local -A meth_index  # For fast lookup
    local -A meth_owner=()  # method -> DEFINING class (Pascal 'inherited' semantics)
    local -A own_raw_bodies=()  # methods declared HERE: raw body, processed after the parse (F11)
    local -A own_meth_type=()
    local constructor_body=""
    # Loop variables of the member walks below. Without `local` every class
    # definition clobbered the caller's p/m/sm/sp/wm — and kcl units define
    # their classes at source time, so `source tlist.sh` silently overwrote a
    # script's own $p and $m (G8-04).
    local m p sm sp wm

    # Static members support (lazy initialization)
    local has_static_members=false
    local -a static_props_arr=()
    local -a static_meths_arr=()
    local -A static_meth_bodies
    local -A static_prop_owner=()
    local -A static_prop_index=()
    local -A static_meth_owner=()
    local -A static_meth_index=()
    
    # Computed and lazy properties support
    local -A computed_getters=()
    local -A computed_setters=()
    local -A lazy_inits=()

    # Inherit from parent class if specified
    if [[ -n "$parent_class" ]]; then
        # Copy parent properties using name reference (bash 4.3+)
        local parent_props_var="${parent_class}_class_properties"
        if declare -p "$parent_props_var" &>/dev/null; then
            local -n parent_props_ref="$parent_props_var"
            props_arr+=("${parent_props_ref[@]}")
        fi

        # Copy parent methods using name reference
        local parent_meths_var="${parent_class}_class_methods"
        if declare -p "$parent_meths_var" &>/dev/null; then
            local -n parent_meths_ref="$parent_meths_var"
            meths_arr+=("${parent_meths_ref[@]}")

            # Copy parent method bodies and index. The OWNER (defining class)
            # travels along: for a method the parent itself inherited, keep the
            # original defining class, not the parent.
            for m in "${parent_meths_ref[@]}"; do
                local parent_body_var="${parent_class}_method_body_${m}"
                meth_bodies["$m"]="${!parent_body_var:-}"
                meth_index["$m"]=1
                local parent_owner_var="${parent_class}_class_method_owner[$m]"
                meth_owner["$m"]="${!parent_owner_var:-$parent_class}"
            done
        fi

        local parent_getters_var="${parent_class}_computed_getters"
        if declare -p "$parent_getters_var" &>/dev/null; then
            local -n parent_getters_ref="$parent_getters_var"
            for p in "${!parent_getters_ref[@]}"; do
                computed_getters["$p"]="${parent_getters_ref[$p]}"
            done
        fi

        local parent_setters_var="${parent_class}_computed_setters"
        if declare -p "$parent_setters_var" &>/dev/null; then
            local -n parent_setters_ref="$parent_setters_var"
            for p in "${!parent_setters_ref[@]}"; do
                computed_setters["$p"]="${parent_setters_ref[$p]}"
            done
        fi

        local parent_lazy_var="${parent_class}_lazy_inits"
        if declare -p "$parent_lazy_var" &>/dev/null; then
            local -n parent_lazy_ref="$parent_lazy_var"
            for p in "${!parent_lazy_ref[@]}"; do
                lazy_inits["$p"]="${parent_lazy_ref[$p]}"
            done
        fi

        local parent_static_props_var="${parent_class}_class_static_properties"
        local parent_static_prop_owner_var="${parent_class}_class_static_property_owner"
        if declare -p "$parent_static_props_var" &>/dev/null; then
            local -n parent_static_props_ref="$parent_static_props_var"
            local -n parent_static_prop_owner_ref="$parent_static_prop_owner_var"
            local inherited_static_prop
            for inherited_static_prop in "${parent_static_props_ref[@]}"; do
                if [[ -z "${static_prop_index[$inherited_static_prop]+x}" ]]; then
                    static_props_arr+=("$inherited_static_prop")
                    static_prop_index["$inherited_static_prop"]=1
                fi
                static_prop_owner["$inherited_static_prop"]="${parent_static_prop_owner_ref[$inherited_static_prop]:-$parent_class}"
            done
            if (( ${#parent_static_props_ref[@]} > 0 )); then
                has_static_members=true
            fi
        fi

        local parent_static_meths_var="${parent_class}_class_static_methods"
        local parent_static_meth_owner_var="${parent_class}_class_static_method_owner"
        if declare -p "$parent_static_meths_var" &>/dev/null; then
            local -n parent_static_meths_ref="$parent_static_meths_var"
            local -n parent_static_meth_owner_ref="$parent_static_meth_owner_var"
            local inherited_static_method
            for inherited_static_method in "${parent_static_meths_ref[@]}"; do
                if [[ -z "${static_meth_index[$inherited_static_method]+x}" ]]; then
                    static_meths_arr+=("$inherited_static_method")
                    static_meth_index["$inherited_static_method"]=1
                fi
                static_meth_owner["$inherited_static_method"]="${parent_static_meth_owner_ref[$inherited_static_method]:-$parent_class}"
                local static_body_owner="${static_meth_owner[$inherited_static_method]}"
                local parent_static_body_var="${static_body_owner}_static_method_body_${inherited_static_method}"
                static_meth_bodies["$inherited_static_method"]="${!parent_static_body_var:-}"
            done
            if (( ${#parent_static_meths_ref[@]} > 0 )); then
                has_static_members=true
            fi
        fi
    fi

    # Parse class definition (can override parent methods)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            static_property)
                kk.decl._validate_static "$2" "static property name" || return 1
                has_static_members=true
                if [[ -z "${static_prop_index[$2]+x}" ]]; then
                    static_props_arr+=("$2")
                    static_prop_index["$2"]=1
                fi
                static_prop_owner["$2"]="$class_name"
                shift 2
                ;;
            static_method)
                kk.decl._validate_static "$2" "static method name" || return 1
                has_static_members=true
                if [[ -z "${static_meth_index[$2]+x}" ]]; then
                    static_meths_arr+=("$2")
                    static_meth_index["$2"]=1
                fi
                static_meth_owner["$2"]="$class_name"
                static_meth_bodies["$2"]="$3"
                shift 3
                ;;
            property)
                kk.decl._validate_member "$2" "property name" || return 1
                local prop_name="$2"
                props_arr+=("$prop_name")
                shift 2
                
                # Check if next arguments are getter/setter methods
                # Method names starting with "get" or "set" are treated as computed accessors
                # Consume following getter/setter methods until we hit a keyword or non-accessor
                local keyword_str=" property static_property static_method method procedure function lazy_property constructor "
                while [[ $# -gt 0 ]]; do
                    # Peek at next argument
                    local peek_arg="$1"
                    
                    # Check if it's a keyword
                    if [[ "$keyword_str" == *" $peek_arg "* ]]; then
                        break
                    fi
                    
                    # Check if it's a getter/setter by prefix
                    # Allows both "get"/"set" and "_get"/"_set"
                    case "$peek_arg" in
                        get* | _get*)
                            kk.decl._validate_member "$peek_arg" "getter name" || return 1
                            computed_getters["$prop_name"]="$peek_arg"
                            shift
                            ;;
                        set* | _set*)
                            kk.decl._validate_member "$peek_arg" "setter name" || return 1
                            computed_setters["$prop_name"]="$peek_arg"
                            shift
                            ;;
                        *)
                            # Not a getter/setter, stop processing
                            break
                            ;;
                    esac
                done
                ;;
            lazy_property)
                # usage: lazy_property PROP INIT_METHOD
                kk.decl._validate_member "$2" "lazy property name" || return 1
                kk.decl._validate_member "$3" "lazy init method name" || return 1
                props_arr+=("$2")
                lazy_inits["$2"]="$3"
                shift 3
                ;;
            method|procedure|function)
                kk.decl._validate_member "$2" "method name" || return 1
                local meth_type="$1"
                # Check if method already exists (override) using fast lookup
                if [[ -z "${meth_index[$2]:-}" ]]; then
                    meths_arr+=("$2")
                    meth_index["$2"]=1
                fi
                # Declared (or overridden) here: this class is the defining one.
                meth_owner["$2"]="$class_name"

                # Keep the raw body; it is finalized (kk._processMethodBody)
                # after the whole definition is parsed (F11).
                own_raw_bodies["$2"]="$3"
                own_meth_type["$2"]="$meth_type"
                shift 3
                ;;
            constructor)
                # Store constructor body for processing later (after all methods are collected)
                constructor_body="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # A static property and a static method of the same name would both be
    # CLASS.NAME — the method dispatcher silently replaced the property
    # accessor (P11/M1, DR9). Checked over the MERGED lists, so an inherited
    # static of the other kind is caught too; nothing is stored yet.
    for sp in "${static_props_arr[@]}"; do
        if [[ -n "${static_meth_index[$sp]+x}" ]]; then
            kk.decl._error "Static member clash in class '${class_name}': '${sp}' is both a static property and a static method (both would be the function ${class_name}.${sp})"
            return 1
        fi
    done

    # An instance property (plain, lazy, computed — inherited or own) and a
    # static property of the same name are both the variable NAME inside a
    # member body, and the static one hid the instance property (round 4 /
    # P12, V1, DR10). Merged lists again: every build path ends here (the
    # declarative verbs checked their own tables + the built parent already).
    if (( ${#static_props_arr[@]} > 0 && ${#props_arr[@]} > 0 )); then
        local -A __kk_prop_index=()
        for p in "${props_arr[@]}"; do __kk_prop_index["$p"]=1; done
        for sp in "${static_props_arr[@]}"; do
            if [[ -n "${__kk_prop_index[$sp]+x}" ]]; then
                kk.decl._prop_clash_error "$class_name" "$sp"
                return 1
            fi
        done
    fi

    # Finalize the bodies declared here (function trailer; no text rewrite
    # since R2_P8).
    local __kk_om
    for __kk_om in "${!own_raw_bodies[@]}"; do
        kk._processMethodBody "$class_name" "$__kk_om" "${own_raw_bodies[$__kk_om]}" "${own_meth_type[$__kk_om]}"
        meth_bodies["$__kk_om"]="$METHOD_BODY"
    done

    # Store class metadata for inheritance
    eval "${class_name}_class_properties=(\"\${props_arr[@]}\")"
    eval "${class_name}_class_methods=(\"\${meths_arr[@]}\")"
    eval "${class_name}_class_static_properties=(\"\${static_props_arr[@]}\")"
    eval "${class_name}_class_static_methods=(\"\${static_meths_arr[@]}\")"
    eval "declare -gA ${class_name}_class_static_property_owner=()"
    eval "declare -gA ${class_name}_class_static_method_owner=()"
    eval "${class_name}_parent_class=\"$parent_class\""
    for p in "${!static_prop_owner[@]}"; do
        eval "${class_name}_class_static_property_owner[\"$p\"]=\"${static_prop_owner[$p]}\""
    done
    for m in "${!static_meth_owner[@]}"; do
        eval "${class_name}_class_static_method_owner[\"$m\"]=\"${static_meth_owner[$m]}\""
    done
    # Instance-method owners (defining class of each body) — the anchor for
    # Pascal-correct `inherited`/.parent resolution.
    eval "declare -gA ${class_name}_class_method_owner=()"
    for m in "${!meth_owner[@]}"; do
        eval "${class_name}_class_method_owner[\"$m\"]=\"${meth_owner[$m]}\""
    done
    
    # Store computed property getters/setters
    eval "declare -gA ${class_name}_computed_getters"
    eval "declare -gA ${class_name}_computed_setters"
    for p in "${!computed_getters[@]}"; do
        eval "${class_name}_computed_getters[\"$p\"]=\"${computed_getters[$p]}\""
    done
    for p in "${!computed_setters[@]}"; do
        eval "${class_name}_computed_setters[\"$p\"]=\"${computed_setters[$p]}\""
    done
    eval "declare -gA ${class_name}_lazy_inits"
    for p in "${!lazy_inits[@]}"; do
        eval "${class_name}_lazy_inits[\"$p\"]=\"${lazy_inits[$p]}\""
    done
    
    # Create method resolution cache for performance
    eval "declare -gA ${class_name}_method_cache"
    
    for m in "${meths_arr[@]}"; do
        eval "${class_name}_method_body_${m}=\${meth_bodies[\$m]}"

        # Pre-populate cache: method resolves to its DEFINING class (owner), so
        # dispatch pushes the owner as the frame class and `inherited`/.parent
        # inside the body walks up from where the body was defined (Pascal
        # semantics), not from the instance's class.
        eval "${class_name}_method_cache[\"${m}\"]=\"${meth_owner[$m]:-$class_name}\""
    done

    for m in "${static_meths_arr[@]}"; do
        eval "${class_name}_static_method_body_${m}=\${static_meth_bodies[\$m]}"
    done
    
    # The constructor body is stored as written: `$this.NAME` in it is a plain
    # call of the instance wrapper (no text rewrite since R2_P8).

    # ---- instance template (P4a) -------------------------------------------
    # An instance is: its data array, its class variable and ONE-LINE wrappers
    # that forward to the shared kk._* runtime with the instance name as the
    # first argument. `__INST__` is replaced by the (validated) instance name at
    # .new time. Nothing else is generated per instance any more.
    local prop_funcs=""
    for p in "${props_arr[@]}"; do
        if [[ -n "${computed_getters[$p]:-}${computed_setters[$p]:-}" ]]; then
            prop_funcs+=$'\n'"__INST__.$p() { kk._prop_computed __INST__ $class_name $p '${computed_getters[$p]:-}' '${computed_setters[$p]:-}' \"\$@\"; }"
        elif [[ -n "${lazy_inits[$p]:-}" ]]; then
            prop_funcs+=$'\n'"__INST__.$p() { kk._prop_lazy __INST__ $class_name $p ${lazy_inits[$p]} '' \"\$@\"; }"
        else
            prop_funcs+=$'\n'"__INST__.$p() { kk._prop_plain __INST__ $class_name $p \"\$@\"; }"
        fi
    done

    local meth_funcs=""
    for m in "${meths_arr[@]}"; do
        # The wrapper names the DEFINING class (owner) of the method, see kk._exec.
        kk._method_wrapper_text "$m" "${meth_owner[$m]:-$class_name}"
        meth_funcs+="$METHOD_WRAPPER"
    done

    local parent_func=""
    if [[ -n "$parent_class" ]]; then
        parent_func=$'\n'"__INST__.parent() { kk._parent __INST__ \"\$@\"; }"
    fi

    local instance_template
    instance_template="declare -gA __INST___data
__INST___class=\"${class_name}\"
__INST__.property() { kk._property __INST__ \"\$@\"; }${prop_funcs}${meth_funcs}
__INST__.call() { kk._call __INST__ \"\$@\"; }${parent_func}
__INST__.delete() { kk._delete __INST__ \"\$@\"; }"

    # Store template for this class (.new evals it; the compiler dumps it)
    eval "${class_name}_instance_template=\$instance_template"

    # Process constructor body to support parent.constructor syntax
    if [[ -n "$parent_class" && "$constructor_body" == *"parent.constructor"* ]]; then
        # Replace parent.constructor with actual parent class constructor call
        constructor_body="${constructor_body//parent.constructor/${parent_class}.constructor}"
    fi
    
    # Store constructor body
    eval "${class_name}_constructor_body=\$constructor_body"
    
    # Create static members if needed (lazy approach)
    if [[ "$has_static_members" == "true" ]]; then
        # Initialize static properties as global variables
        for sp in "${static_props_arr[@]}"; do
            local static_owner="${static_prop_owner[$sp]:-$class_name}"
            if [[ "$static_owner" == "$class_name" ]]; then
                eval "${class_name}_static_${sp}=\"\""
            fi
        done
        
        # The static method bodies, each in its own function
        # Class.__static_NAME (see kk._class_static_api for why).
        for sm in "${static_meths_arr[@]}"; do
            local sm_body="${static_meth_bodies[$sm]}"
            eval "${class_name}.__static_${sm}() {
                ${sm_body}
            }"
        done

        # The class-level API — static property accessors and static method
        # dispatchers — generated from the tables stored above (the same
        # helper restores it when a Pascal unit is sourced again, uses U20).
        kk._class_static_api "$class_name"
    fi

    # Constructor function: materialize the instance by substituting the
    # (validated) instance name into the class template with a pure-bash
    # replacement and eval'ing it (no fork). Methods added later with
    # defineMethod are already in the template (F3), so nothing else to do.
    #
    # Instance-name check (round 3 / P11, M3 + review remark R1): .new is the
    # hottest builder path, and on bash 5.2 a call of kk._is_ident (function
    # call + two locale switches, as it was then) cost +17.6 us per .new. So
    # the check is INLINED here as an explicit-letter glob (round 4 / P12 kept
    # it: the helper no longer switches the locale, but the call itself is
    # still the cost on this path) — every allowed character
    # listed, NO ranges: a bracket of explicit characters is matched by
    # character equality, never by collation, so it is exact in every locale
    # and with globasciiranges on or off (critic probe m3d, list_g). Its one
    # weakness is `shopt -s nocasematch`, whose case folding lets the dotted
    # İ / dotless ı match i/I — so under nocasematch it falls back to
    # kk._is_ident. No =~, so BASH_REMATCH is untouched.
    # THIS INLINE COPY MUST STAY EQUIVALENT TO kk._is_ident (the single
    # definition of the rule); test 135 C5 runs one name table through both
    # in every locale × globasciiranges × nocasematch combination.
    # Then the taken names (uses U2b, "Taken names" at the top): a verb, a
    # class or a declared namespace is refused — one ownership test (R14) and
    # one assoc lookup; nothing lists the function table.
    local __kk_new_guard='if [[ ":$BASHOPTS:" != *:nocasematch:* ]]; then
            [[ -n "$instname" && "$instname" != [!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_]* && "$instname" != *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]* ]]
        else
            kk._is_ident "$instname"
        fi || { echo "Invalid instance name: $instname" >&2; return 1; }
        [[ ${__KKLASS_TABLES[@]@a} == A ]] || kk._class_tables
        [[ -z ${_KKLASS_TAKEN[$instname]+x} ]] || { kk._new_refused "$instname"; return 1; }'
    eval "${class_name}.new() {
        local instname=\"\$1\"
        shift
        ${__kk_new_guard}
        eval \"\${${class_name}_instance_template//__INST__/\$instname}\"

        if [[ -n \"\$${class_name}_constructor_body\" ]]; then
            local __inst__=\"\$instname\"
            kk._constructor_exec \"\$instname\" \"${class_name}\" \"\$@\"
        fi
    }"

    # Constructor caller for explicit parent-constructor chaining. A thin wrapper
    # to the generic helper — the body is never embedded here (a body with quotes
    # or semicolons would otherwise corrupt this generated function).
    eval "${class_name}.constructor() { kk._invoke_constructor ${class_name} \"\$@\"; }"

    # Built: register the declaration site (and the unit, P4).
    kk._class_register "$class_name" "$__kk_site"

    # Debug note on the debug channel (stderr), never on stdout (P11).
    kk.debug "$class_name class created"
}

defineClass() {
    local class_name="$1"
    local parent_class="$2"
    local -a declared_methods=()
    local -A declared_method_seen=()
    local -A declared_method_body=()
    local constructor_body=""
    local keyword_str=" property static_property static_method method procedure function lazy_property constructor "

    [[ -n "$class_name" ]] || {
        echo "defineClass: Usage: defineClass CLASS_NAME PARENT_CLASS [definition tokens...]" >&2
        return 1
    }

    shift 2

    # defineClass is ONE call: a refused declaration (Duplicate identifier) or
    # the same site again (WARNING, uses U20) ends the sink declareClass opened
    # and ignores the call as a whole.
    declareClass "$class_name" "$parent_class" || { kk.decl._sink_end "$class_name"; return 1; }
    if [[ ${__KK_SINK_OPEN-} == "$class_name" ]]; then
        kk.decl._sink_end "$class_name"
        return 0
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            static_property)
                kk.decl._remember_static_property "$class_name" "$2" || { kk.decl._abandon_class "$class_name" "$2"; return 1; }
                shift 2
                ;;
            static_method)
                kk.decl._remember_static_method "$class_name" "$2" "$3" || { kk.decl._abandon_class "$class_name" "$2"; return 1; }
                shift 3
                ;;
            property)
                local prop_name="$2"
                local -a prop_decl=("$prop_name")
                local has_read_accessor=0
                local has_write_accessor=0
                shift 2

                while [[ $# -gt 0 ]]; do
                    local peek_arg="$1"
                    if [[ "$keyword_str" == *" $peek_arg "* ]]; then
                        break
                    fi

                    case "$peek_arg" in
                        get*|_get*)
                            prop_decl+=("read" "$peek_arg")
                            has_read_accessor=1
                            shift
                            ;;
                        set*|_set*)
                            prop_decl+=("write" "$peek_arg")
                            has_write_accessor=1
                            shift
                            ;;
                        *)
                            break
                            ;;
                    esac
                done

                if (( has_read_accessor )) && (( ! has_write_accessor )); then
                    prop_decl+=("write" "$prop_name")
                elif (( has_write_accessor )) && (( ! has_read_accessor )); then
                    prop_decl+=("read" "$prop_name")
                fi

                property "${prop_decl[@]}" || { kk.decl._abandon_class "$class_name" "$prop_name"; return 1; }
                ;;
            lazy_property)
                kk.decl._remember_lazy_property "$class_name" "$2" "$3" || { kk.decl._abandon_class "$class_name" "$2"; return 1; }
                shift 3
                ;;
            method|procedure|function)
                local legacy_kind="$1"
                local method_name="$2"
                local method_body="$3"

                if [[ "$legacy_kind" == "function" ]]; then
                    func "$method_name" || { kk.decl._abandon_class "$class_name" "$method_name"; return 1; }
                else
                    procedure "$method_name" || { kk.decl._abandon_class "$class_name" "$method_name"; return 1; }
                fi

                if [[ -z "${declared_method_seen[$method_name]:-}" ]]; then
                    declared_methods+=("$method_name")
                    declared_method_seen["$method_name"]=1
                fi
                declared_method_body["$method_name"]="$method_body"
                shift 3
                ;;
            constructor)
                constructor || { kk.decl._abandon_class "$class_name" constructor; return 1; }
                constructor_body="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    endClass || return 1

    local method_name
    for method_name in "${declared_methods[@]}"; do
        implement "$class_name.$method_name" "${declared_method_body[$method_name]}" || return 1
    done

    if [[ -n "$constructor_body" ]]; then
        implementConstructor "$class_name" "$constructor_body" || return 1
    fi

    endImplementation "$class_name"
}

_defineMethodType() {
    local class_name="$1"
    local method_name="$2"
    local method_body="$3"
    local meth_type="${4:-method}"
    local func_name="${5:-Method}"
    
    # Validate inputs
    [[ -z "$class_name" || -z "$method_name" || -z "$method_body" ]] && {
        echo "define${func_name}: Usage: define${func_name} CLASS_NAME METHOD_NAME BODY" >&2
        return 1
    }
    # Both names are interpolated into eval'd assignments below; the method
    # name is an instance member like any other (reserved built-in names
    # refused, R2_P8).
    kk.decl._validate_ident "$class_name" "class name" || return 1
    kk.decl._validate_member "$method_name" "method name" || return 1

    # Check if class exists
    local class_meths_var="${class_name}_class_methods"
    if ! declare -p "$class_meths_var" &>/dev/null; then
        echo "define${func_name}: Class '$class_name' does not exist" >&2
        return 1
    fi
    
    # Get existing methods array
    local -n meths_ref="${class_name}_class_methods"
    local -A meth_index
    local m                    # loop var — never leak it (G8-04)

    # Build index of existing methods
    for m in "${meths_ref[@]}"; do
        meth_index["$m"]=1
    done
    
    # Check if method already exists (will override it)
    if [[ -z "${meth_index[$method_name]}" ]]; then
        meths_ref+=("$method_name")
    fi
    
    # Process method body using shared logic from defineClass
    kk._processMethodBody "$class_name" "$method_name" "$method_body" "$meth_type"
    eval "${class_name}_method_body_${method_name}=\$METHOD_BODY"

    # Update class methods array in global scope
    eval "${class_name}_class_methods=(\"\${meths_ref[@]}\")"

    # F3: this class now DEFINES the method. For an INHERITED method the
    # template wrapper and the .call cache still named the parent as owner, so
    # the new body was silently ignored. Re-point owner + cache, and rewrite
    # (or add) the wrapper in the instance template so new instances get it.
    declare -p "${class_name}_class_method_owner" &>/dev/null || eval "declare -gA ${class_name}_class_method_owner=()"
    declare -p "${class_name}_method_cache" &>/dev/null || eval "declare -gA ${class_name}_method_cache=()"
    local -n __kk_dm_owner_ref="${class_name}_class_method_owner"
    local -n __kk_dm_cache_ref="${class_name}_method_cache"
    local -n __kk_dm_tpl_ref="${class_name}_instance_template"
    local __kk_dm_old_owner="${__kk_dm_owner_ref[$method_name]:-$class_name}"
    __kk_dm_owner_ref["$method_name"]="$class_name"
    __kk_dm_cache_ref["$method_name"]="$class_name"
    kk._method_wrapper_text "$method_name" "$__kk_dm_old_owner"
    local __kk_dm_old_wrapper="$METHOD_WRAPPER"
    kk._method_wrapper_text "$method_name" "$class_name"
    local __kk_dm_new_wrapper="$METHOD_WRAPPER"
    if [[ "$__kk_dm_tpl_ref" == *"$__kk_dm_old_wrapper"* ]]; then
        __kk_dm_tpl_ref="${__kk_dm_tpl_ref/"$__kk_dm_old_wrapper"/$__kk_dm_new_wrapper}"
    else
        __kk_dm_tpl_ref="${__kk_dm_tpl_ref/__INST__.delete() \{/${__kk_dm_new_wrapper}
__INST__.delete() \{}"
    fi

    # Known limitation: subclasses built BEFORE this call carry their own copy
    # of the method table (bodies are copied down at build time) and keep
    # resolving to what they copied. Say so once per affected subclass.
    local __kk_dm_sub __kk_dm_pv
    for __kk_dm_sub in "${!_KKLASS_CLASS_SOURCE[@]}"; do
        __kk_dm_pv="${__kk_dm_sub}_parent_class"
        if [[ "${!__kk_dm_pv:-}" == "$class_name" ]]; then
            echo "[kk] warning: define${func_name} ${class_name}.${method_name}: subclass '${__kk_dm_sub}' was built earlier and does not pick up this change" >&2
        fi
    done
    
    # Debug note on the debug channel (stderr), never on stdout (P11; was an
    # echo to stdout that leaked into addSerializable's callers).
    kk.debug "${func_name} '$method_name' added to class '$class_name'"
}

defineMethod() {
    _defineMethodType "$1" "$2" "$3" "method" "Method"
}

defineProcedure() {
    _defineMethodType "$1" "$2" "$3" "procedure" "Procedure"
}

defineFunction() {
    _defineMethodType "$1" "$2" "$3" "function" "Function"
}

kk.register_static_methods() {
    local class_name="$1"
    local public_prefix="$2"
    local display_name="${3:-$1}"
    shift 3

    local -a method_names=("$@")
    local -a class_args=()
    local method_name public_name impl_name method_decl

    # Every name is checked BEFORE anything is generated (P11/M1, DR9): a
    # static named `new` used to REPLACE the class constructor, and the
    # PREFIX.__impl_NAME helper below was already eval'd by the time
    # defineClass refused a name. __impl_* is this helper's own namespace.
    for method_name in "${method_names[@]}"; do
        [[ -n "$method_name" ]] || {
            kk.decl._error "Error: ${display_name}: empty static method name"
            return 1
        }
        kk.decl._validate_static "$method_name" "static method name" || return 1
        case "$method_name" in
            __impl_*)
                kk.decl._error "Reserved static method name: '${method_name}' (kk.register_static_methods keeps each registered body in PREFIX.__impl_NAME)"
                return 1
                ;;
        esac
    done

    for method_name in "${method_names[@]}"; do
        public_name="${public_prefix}.${method_name}"
        impl_name="${public_prefix}.__impl_${method_name}"

        if ! declare -F "$public_name" >/dev/null; then
            echo "Error: ${display_name} method '$public_name' is not defined" >&2
            return 1
        fi

        method_decl="$(declare -f "$public_name")"
        method_decl="${method_decl#*$'\n'}"
        eval "${impl_name}() ${method_decl}"
        class_args+=("static_method" "$method_name" "${impl_name} \"\$@\"")
    done

    defineClass "$class_name" "" "${class_args[@]}" || return 1

    for method_name in "${method_names[@]}"; do
        public_name="${public_prefix}.${method_name}"
        impl_name="${public_prefix}.__impl_${method_name}"
        eval "${public_name}() { ${impl_name} \"\$@\"; }"
    done
}

source "${KKLASS_DIR}/kklass_decl.sh"

if [[ "${KKLASS_EXPORT_FUNCTIONS:-0}" == "1" ]]; then
    export -f kk._processMethodBody kk.call_silent kk._class_derives_from kk._is_ident kk.isAbstract kk.derivesFrom kk._warn_visibility kk._build_class_runtime _defineMethodType defineClass defineMethod defineProcedure defineFunction kk.register_static_methods
    export -f kk._class_tables kk._class_site kk._class_site_same kk._class_site_text kk._class_verdict kk._class_register kk._unit_forget_class kk.class kk._class_static_api
    export -f kk._taken_init kk._namespace_add kk._name_in_use kk._ns_txt kk._taken_check kk._new_refused kk._ckk_begin kk._ckk_class kk._ckk_built kk._ckk_end
fi