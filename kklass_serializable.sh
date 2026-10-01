#!/bin/bash
# kklass_serializable.sh - Serialization mixin for kklass
# Adds automatic serialization/deserialization methods to classes

# Requires kklass.sh to be loaded first
if ! declare -f defineClass &>/dev/null; then
    echo "Error: kklass.sh must be loaded before kklass_serializable.sh" >&2
    return 1
fi

# Helper: Define a serializable class (wrapper around defineClass)
# Usage: defineSerializableClass CLASS_NAME PARENT_CLASS SEPARATOR FORMAT property prop1 property prop2 method meth1 "body1" ...
defineSerializableClass() {
    local class_name="$1"
    local parent_class="$2"
    local separator="${3:-:}"
    local format="${4:-string}"
    shift 4
    
    # Collect properties first to generate serialization methods
    local -a props_arr=()
    local -a args_copy=("$@")
    local i=0
    while [[ $i -lt ${#args_copy[@]} ]]; do
        if [[ "${args_copy[$i]}" == "property" ]]; then
            props_arr+=("${args_copy[$((i+1))]}")
            ((i+=2))
        else
            # Skip other definitions
            case "${args_copy[$i]}" in
                method|static_method)
                    ((i+=3))
                    ;;
                lazy_property)
                    ((i+=3))
                    ;;
                constructor|static_property)
                    ((i+=2))
                    ;;
                *)
                    ((i++))
                    ;;
            esac
        fi
    done
    
    # Generate serialization methods based on format
    local toString_method=""
    local fromString_method=""
    
    if [[ "$format" == "string" ]]; then
        # Build property values string
        local prop_values=""
        local prop_read=""
        
        for prop in "${props_arr[@]}"; do
            prop_values+="\${$prop}${separator}"
            prop_read+="$prop "
        done
        prop_values="${prop_values%$separator}"
        
        toString_method="echo \"${class_name}${separator}${prop_values}\""
        fromString_method="local __kk_input=\"\$1\"; __kk_input=\"\${__kk_input#${class_name}${separator}}\"; __kk_input=\"\${__kk_input%$'\\n'}\"; IFS=\"${separator}\" read -r ${prop_read} <<< \"\$__kk_input\"; echo \"\$this\""
    fi
    
    # Call defineClass with original args plus serialization methods
    defineClass "$class_name" "$parent_class" "$@" \
        "method" "toString" "$toString_method" \
        "method" "fromString" "$fromString_method"
}


# Add serialization methods to an existing class
# Usage: addSerializable CLASS_NAME [SEPARATOR] [FORMAT]
#   CLASS_NAME - name of the class to extend
#   SEPARATOR  - field separator (default: ":")
#   FORMAT     - "string" (default) or "json"
# NOTE: Must be called IMMEDIATELY AFTER defineClass, BEFORE creating instances
addSerializable() {
    local class_name="$1"
    local separator="${2:-:}"
    local format="${3:-string}"
    
    # Validate class exists
    local props_var="${class_name}_class_properties"
    if ! declare -p "$props_var" &>/dev/null; then
        echo "Error: Class '$class_name' not found" >&2
        return 1
    fi
    
    # Get class properties
    local -n props_ref="$props_var"
    local props_list="${props_ref[*]}"
    
    case "$format" in
        string)
            _addSerializable_string "$class_name" "$separator" "$props_list"
            ;;
        json)
            _addSerializable_json "$class_name" "$props_list"
            ;;
        *)
            echo "Error: Unknown format '$format'. Use 'string' or 'json'" >&2
            return 1
            ;;
    esac
    
    if [[ "${VERBOSE_KKLASS:-1}" == "debug" ]]; then echo "Serialization methods added to $class_name (format: $format)"; fi
}

# Internal: Add string-based serialization
_addSerializable_string() {
    local class_name="$1"
    local separator="$2"
    local props_list="$3"

    # Build property list for serialization
    local prop_values=""
    local prop_read=""
    
    for prop in $props_list; do
        prop_values+="\${$prop}${separator}"
        prop_read+="$prop "
    done
    prop_values="${prop_values%$separator}"
    
    # Create toString method
    local toString_body="echo \"${class_name}${separator}${prop_values}\""
    
    # Create fromString method
    local fromString_body="
        local __kk_input=\"\$1\"
        __kk_input=\"\${__kk_input#${class_name}${separator}}\"
        IFS=\"${separator}\" read -r ${prop_read} <<< \"\$__kk_input\"
        echo \"\$this\"
    "
    
    # Register through the one dynamic-method path (F10): owner, cache and the
    # instance template are all updated there.
    defineMethod "$class_name" toString "$toString_body" || return 1
    defineMethod "$class_name" fromString "$fromString_body" || return 1
}

# ---------------------------------------------------------------------------
# JSON format (round 2 / P7: finding K3, decision DR2)
# ---------------------------------------------------------------------------
# toJSON writes one flat object per instance:
#     {"__class__":"<Class>","<prop>":"<value>",...}
# Every value is a JSON string. Escaping (RFC 8259): `\` and `"` are escaped,
# LF CR TAB BS FF are written as \n \r \t \b \f, every other U+0001..U+001F
# as \u00XX (lower-case hex). DEL, C1 controls and multi-byte UTF-8 are
# written raw (valid JSON). NUL cannot occur: a bash string cannot hold it.
# Because LF is always escaped, one object is always ONE line — saveObjects /
# loadObjects rely on that.
#
# fromJSON is a left-to-right, string-aware scanner over ONE flat object:
# whitespace between tokens, string values with the eight named escapes and
# \uXXXX (surrogate pairs combined), bare tokens (numbers, true, false, null —
# stored verbatim as text). Rejected with rc 1 and the instance untouched:
# malformed input, a nested object/array value, \u0000, a lone surrogate, and a
# "__class__" naming neither the receiving instance's class nor the class the
# serializer was added to. Unknown keys are ignored (as before).
#
# No function body below contains a $'..' word: declare -f / export -f
# re-print such a word with its bytes raw, and a raw CR does not survive that
# round trip (measured on 5.2.37 and 5.3.9). The control characters, the guard
# pattern and the member regex are built ONCE per shell by kk._jsonInit, with
# printf only; every helper re-runs it when they are missing (a child shell
# that inherited only the exported functions).

# kk._jsonInit — builds the shared tables (idempotent, fork-free):
#   __KK_JSON_CC[i]     the character with code i, i = 1..31
#   __KK_JSON_ESC[i]    its JSON escape (\n \r \t \b \f named, else \u00xx)
#   __KK_JSON_SPECIAL   glob: a value holding " or \ or U+0001..U+001F —
#                       measured locale-safe in C, C.UTF-8 and en_US.UTF-8 on
#                       both bashes (DEL and U+0085 miss, as they must)
#   __KK_JSON_CTRL      glob: a value holding U+0001..U+001F
#   __KK_JSON_WS        the four JSON whitespace characters
#   __KK_JSON_RE_MEMBER anchored ERE for one member WITHOUT any backslash:
#                       ws "key" ws : ws ( "string" | bare-token ) ws [,}]
kk._jsonInit() {
    local __kk_i __kk_x
    declare -ga __KK_JSON_CC=() __KK_JSON_ESC=()
    for (( __kk_i = 1; __kk_i < 32; __kk_i++ )); do
        printf -v __kk_x '\\x%02x' "$__kk_i"
        printf -v "__KK_JSON_CC[__kk_i]" "$__kk_x"
        printf -v "__KK_JSON_ESC[__kk_i]" '\\u%04x' "$__kk_i"
    done
    __KK_JSON_ESC[8]='\b'
    __KK_JSON_ESC[9]='\t'
    __KK_JSON_ESC[10]='\n'
    __KK_JSON_ESC[12]='\f'
    __KK_JSON_ESC[13]='\r'
    declare -g __KK_JSON_SPECIAL="*[\"\\\\${__KK_JSON_CC[1]}-${__KK_JSON_CC[31]}]*"
    declare -g __KK_JSON_CTRL="*[${__KK_JSON_CC[1]}-${__KK_JSON_CC[31]}]*"
    declare -g __KK_JSON_WS=" ${__KK_JSON_CC[9]}${__KK_JSON_CC[10]}${__KK_JSON_CC[13]}"
    __kk_x="[$__KK_JSON_WS]*"
    declare -g __KK_JSON_RE_MEMBER="^${__kk_x}\"([^\"\\\\]*)\"${__kk_x}:${__kk_x}(\"([^\"\\\\]*)\"|([^],\"{}:[\\\\${__KK_JSON_WS}]+))${__kk_x}([,}])"
}
kk._jsonInit

# kk._jsonEscape VALUE  ->  RESULT = VALUE escaped as a JSON string body
# (without the surrounding quotes). Fork-free; rc 0.
kk._jsonEscape() {
    local __kk_s="${1-}"
    if [[ -n ${__KK_JSON_SPECIAL-} && $__kk_s != $__KK_JSON_SPECIAL ]]; then
        RESULT="$__kk_s"
        return 0
    fi
    (( ${#__KK_JSON_ESC[@]} == 31 )) || kk._jsonInit
    local __kk_b='\' __kk_q='"' __kk_i
    # Backslash FIRST, then the quote: the escapes added later are never
    # escaped again.
    if [[ $__kk_s == *"$__kk_b"* ]]; then
        __kk_s="${__kk_s//"$__kk_b"/"$__kk_b$__kk_b"}"
    fi
    if [[ $__kk_s == *"$__kk_q"* ]]; then
        __kk_s="${__kk_s//"$__kk_q"/"$__kk_b$__kk_q"}"
    fi
    # One global replace per control code actually present: the five named
    # ones first (the common case: LF, TAB, CR), then — only if a control
    # character is still left — the rest, stopping as soon as none remains.
    # No index arithmetic on the (possibly multi-byte) string.
    if [[ $__kk_s == $__KK_JSON_CTRL ]]; then
        for __kk_i in 10 9 13 8 12; do
            if [[ $__kk_s == *"${__KK_JSON_CC[__kk_i]}"* ]]; then
                __kk_s="${__kk_s//"${__KK_JSON_CC[__kk_i]}"/"${__KK_JSON_ESC[__kk_i]}"}"
            fi
        done
        for (( __kk_i = 1; __kk_i < 32; __kk_i++ )); do
            [[ $__kk_s == $__KK_JSON_CTRL ]] || break
            if [[ $__kk_s == *"${__KK_JSON_CC[__kk_i]}"* ]]; then
                __kk_s="${__kk_s//"${__KK_JSON_CC[__kk_i]}"/"${__KK_JSON_ESC[__kk_i]}"}"
            fi
        done
    fi
    RESULT="$__kk_s"
    return 0
}

# kk._jsonObject CLASS [NAME VALUE]...  — prints one JSON object line
# {"__class__":"CLASS","NAME":"VALUE",...} with every VALUE escaped; also
# leaves the line (without the newline) in RESULT. The slow path of the
# generated toJSON (which tests the clean case inline), and usable directly:
# CLASS and NAMEs are identifiers, so ONE glob test over all the arguments
# joined decides — clean -> one printf that reuses its format for every
# NAME/VALUE pair; otherwise every VALUE goes through kk._jsonEscape.
kk._jsonObject() {
    local __kk_o=""
    if [[ -n ${__KK_JSON_SPECIAL-} && "$*" != $__KK_JSON_SPECIAL ]]; then
        if (( $# > 1 )); then
            printf -v __kk_o ',"%s":"%s"' "${@:2}"
        fi
        RESULT="{\"__class__\":\"${1-}\"$__kk_o}"
    else
        __kk_o="{\"__class__\":\"${1-}\""
        shift
        while (( $# >= 2 )); do
            kk._jsonEscape "$2"
            __kk_o+=",\"$1\":\"$RESULT\""
            shift 2
        done
        RESULT="$__kk_o}"
    fi
    printf '%s\n' "$RESULT"
}

# kk._jsonString — consumes ONE JSON string from the front of the caller's
# __kk_r (which starts with the opening quote) and leaves the decoded text in
# the caller's __kk_s. rc 1 on an unterminated string, an unknown escape, a
# malformed or NUL \u escape, or a lone surrogate. Called by kk._jsonParse
# only (bash scopes locals dynamically: __kk_r / __kk_s are kk._jsonParse's).
kk._jsonString() {
    local __kk_p __kk_e __kk_h __kk_n __kk_l __kk_f __kk_b='\'
    __kk_r="${__kk_r:1}"
    __kk_s=""
    while :; do
        __kk_p="${__kk_r%%[\"\\]*}"
        __kk_n=${#__kk_p}
        __kk_r="${__kk_r:__kk_n}"
        [[ -n $__kk_r ]] || return 1                  # no closing quote
        __kk_s+="$__kk_p"
        if [[ ${__kk_r:0:1} == '"' ]]; then
            __kk_r="${__kk_r:1}"
            return 0
        fi
        __kk_e="${__kk_r:1:1}"                        # the char after '\'
        case $__kk_e in
            '"'|'/') __kk_s+="$__kk_e" ;;
            "$__kk_b") __kk_s+="$__kk_b" ;;
            b) __kk_s+="${__KK_JSON_CC[8]}" ;;
            t) __kk_s+="${__KK_JSON_CC[9]}" ;;
            n) __kk_s+="${__KK_JSON_CC[10]}" ;;
            f) __kk_s+="${__KK_JSON_CC[12]}" ;;
            r) __kk_s+="${__KK_JSON_CC[13]}" ;;
            u)
                __kk_h="${__kk_r:2:4}"
                [[ $__kk_h == [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f] ]] || return 1
                __kk_n=$(( 16#$__kk_h ))
                if (( __kk_n == 0 )); then
                    return 1                          # NUL: impossible in bash
                elif (( __kk_n >= 0xD800 && __kk_n <= 0xDBFF )); then
                    # High surrogate: a \u low surrogate must follow.
                    [[ ${__kk_r:6:2} == "${__kk_b}u" ]] || return 1
                    __kk_h="${__kk_r:8:4}"
                    [[ $__kk_h == [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f] ]] || return 1
                    __kk_l=$(( 16#$__kk_h ))
                    if (( __kk_l < 0xDC00 || __kk_l > 0xDFFF )); then
                        return 1
                    fi
                    __kk_n=$(( 0x10000 + ((__kk_n - 0xD800) << 10) + (__kk_l - 0xDC00) ))
                    __kk_r="${__kk_r:12}"
                elif (( __kk_n >= 0xDC00 && __kk_n <= 0xDFFF )); then
                    return 1                          # lone low surrogate
                else
                    __kk_r="${__kk_r:6}"
                fi
                # UTF-8 bytes via printf \xHH: locale-independent (bash's own
                # printf \u / \U prints the escape literally for a supplementary
                # code point in the C locale, and emits lone surrogates as
                # invalid UTF-8 — measured on 5.2.37 and 5.3.9).
                if (( __kk_n < 0x80 )); then
                    printf -v __kk_f '\\x%02x' "$__kk_n"
                elif (( __kk_n < 0x800 )); then
                    printf -v __kk_f '\\x%02x\\x%02x' \
                        $(( 0xC0 | (__kk_n >> 6) )) $(( 0x80 | (__kk_n & 0x3F) ))
                elif (( __kk_n < 0x10000 )); then
                    printf -v __kk_f '\\x%02x\\x%02x\\x%02x' \
                        $(( 0xE0 | (__kk_n >> 12) )) $(( 0x80 | ((__kk_n >> 6) & 0x3F) )) \
                        $(( 0x80 | (__kk_n & 0x3F) ))
                else
                    printf -v __kk_f '\\x%02x\\x%02x\\x%02x\\x%02x' \
                        $(( 0xF0 | (__kk_n >> 18) )) $(( 0x80 | ((__kk_n >> 12) & 0x3F) )) \
                        $(( 0x80 | ((__kk_n >> 6) & 0x3F) )) $(( 0x80 | (__kk_n & 0x3F) ))
                fi
                printf -v __kk_e "$__kk_f"
                __kk_s+="$__kk_e"
                continue
                ;;
            *) return 1 ;;
        esac
        __kk_r="${__kk_r:2}"
    done
}

# kk._jsonParse TEXT — parses ONE flat JSON object into the CALLER's arrays
# __kk_jk (keys) / __kk_jv (values), in document order (duplicates kept: the
# caller's last assignment wins, as with JSON.parse). A "__class__" member is
# not stored there: its value goes to the caller's __kk_jc and __kk_jhc=1.
# The generated fromJSON body declares all four local and reads them back —
# no nameref, no fork. rc 0 parsed / rc 1 malformed or unsupported (the
# arrays may then be partial; the caller discards them).
#
# A member without any backslash is consumed by ONE anchored regex
# (__KK_JSON_RE_MEMBER); anything else — an escape, malformed input, invalid
# UTF-8 the regex engine will not match — falls through to the scanner, which
# alone decides acceptance. The regex accepts nothing the scanner rejects and
# decodes nothing differently (no backslash = no decoding).
kk._jsonParse() {
    local __kk_r="${1-}" __kk_s __kk_k __kk_d __kk_w
    (( ${#__KK_JSON_CC[@]} == 31 )) || kk._jsonInit
    __kk_w="$__KK_JSON_WS"
    __kk_r="${__kk_r#"${__kk_r%%[!$__kk_w]*}"}"
    [[ ${__kk_r:0:1} == '{' ]] || return 1
    __kk_r="${__kk_r:1}"
    if [[ $__kk_r =~ ^[$__kk_w]*\} ]]; then
        __kk_r="${__kk_r:${#BASH_REMATCH[0]}}"
    else
        while :; do
            if [[ $__kk_r =~ $__KK_JSON_RE_MEMBER ]]; then
                __kk_k="${BASH_REMATCH[1]}"
                if [[ ${BASH_REMATCH[2]:0:1} == '"' ]]; then
                    __kk_s="${BASH_REMATCH[3]}"
                else
                    __kk_s="${BASH_REMATCH[4]}"
                fi
                __kk_d="${BASH_REMATCH[5]}"
                __kk_r="${__kk_r:${#BASH_REMATCH[0]}}"
            else
                __kk_r="${__kk_r#"${__kk_r%%[!$__kk_w]*}"}"
                [[ ${__kk_r:0:1} == '"' ]] || return 1
                kk._jsonString || return 1
                __kk_k="$__kk_s"
                __kk_r="${__kk_r#"${__kk_r%%[!$__kk_w]*}"}"
                [[ ${__kk_r:0:1} == ':' ]] || return 1
                __kk_r="${__kk_r:1}"
                __kk_r="${__kk_r#"${__kk_r%%[!$__kk_w]*}"}"
                case ${__kk_r:0:1} in
                    '"')
                        kk._jsonString || return 1
                        ;;
                    ''|','|'}'|'{'|'['|']'|':')
                        return 1                      # missing / nested value
                        ;;
                    *)
                        __kk_s="${__kk_r%%[,\}$__kk_w]*}"   # a bare token
                        [[ $__kk_s == *[\"\{\[\]:\\]* ]] && return 1
                        __kk_r="${__kk_r:${#__kk_s}}"
                        ;;
                esac
                __kk_r="${__kk_r#"${__kk_r%%[!$__kk_w]*}"}"
                __kk_d="${__kk_r:0:1}"
                [[ $__kk_d == [,\}] ]] || return 1
                __kk_r="${__kk_r:1}"
            fi
            if [[ $__kk_k == "__class__" ]]; then
                __kk_jc="$__kk_s"
                __kk_jhc=1
            else
                __kk_jk+=("$__kk_k")
                __kk_jv+=("$__kk_s")
            fi
            [[ $__kk_d == ',' ]] || break
        done
    fi
    __kk_r="${__kk_r#"${__kk_r%%[!$__kk_w]*}"}"
    [[ -z $__kk_r ]] || return 1                      # trailing garbage
    return 0
}

# Internal: Add JSON-based serialization (toJSON / fromJSON) to CLASS.
# Property names are identifiers (validated at class definition), so they are
# spliced into the generated bodies as-is; VALUES are only ever read at call
# time through the frame's property namerefs and never become code.
#
# Both bodies read and write the instance store <inst>_data directly, through
# the `state` nameref every member frame binds onto it (or, when the class has
# a property called `state` — which shadows that nameref — through a local
# __kk_d bound the same way). toJSON body for two props a b:
#   if [[ "${state[*]}" != ${__KK_JSON_SPECIAL:-*} ]]; then
#       printf '%s\n' "{\"__class__\":\"C\",\"a\":\"${state[a]-}\",\"b\":\"${state[b]-}\"}"
#   else
#       kk._jsonObject C a "${state[a]-}" b "${state[b]-}"
#   fi
# ONE glob test over the whole store in ONE expansion. The values printed are
# exactly the values tested, so a clean verdict can never be wrong (a special
# character in an element that is not serialized only costs the slow path).
# Measured on the bench class (5 props): +10..15 us/call over the old
# unescaped body; testing the five properties one expansion each cost +30..40,
# a one-line body calling kk._jsonObject unconditionally +55.
_addSerializable_json() {
    local class_name="$1"
    local props_list="$2"
    local prop
    local nl=$'\n'

    local store="state" bind=""
    for prop in $props_list; do
        if [[ $prop == state ]]; then
            store="__kk_d"
            bind="local -n __kk_d=\"\${this}_data\"${nl}"
        fi
    done

    local fields="" args="" from_cases=""
    for prop in $props_list; do
        fields+=",\\\"${prop}\\\":\\\"\${${store}[${prop}]-}\\\""
        args+=" ${prop} \"\${${store}[${prop}]-}\""
        from_cases+="        ${prop}) ${store}[${prop}]=\"\${__kk_jv[__kk_i]}\" ;;${nl}"
    done
    local to_body="${bind}if [[ \"\${${store}[*]}\" != \${__KK_JSON_SPECIAL:-*} ]]; then
    printf '%s\\n' \"{\\\"__class__\\\":\\\"${class_name}\\\"${fields}}\"
else
    kk._jsonObject ${class_name}${args}
fi"

    # Parse everything first, check __class__, and only then assign: a
    # rejected input leaves the instance exactly as it was.
    local from_body="${bind}local -a __kk_jk=() __kk_jv=()
local __kk_jc='' __kk_jhc=0 __kk_i
if ! kk._jsonParse \"\${1-}\"; then
    kk.debug \"Error: ${class_name}.fromJSON: malformed or unsupported JSON input\"
    return 1
fi
if (( __kk_jhc )) && [[ \$__kk_jc != '${class_name}' ]]; then
    __kk_i=\"\${this}_class\"
    if [[ \$__kk_jc != \"\${!__kk_i-}\" ]]; then
        kk._jsonEscape \"\$__kk_jc\"
        kk.debug \"Error: ${class_name}.fromJSON: __class__ \\\"\$RESULT\\\" matches neither \${!__kk_i-} nor ${class_name}\"
        return 1
    fi
fi
for (( __kk_i = 0; __kk_i < \${#__kk_jk[@]}; __kk_i++ )); do
    case \"\${__kk_jk[__kk_i]}\" in
${from_cases}    esac
done
printf '%s\\n' \"\$this\""

    # Register through the one dynamic-method path (F10). The former
    # _regenerateConstructor re-emitted EVERY wrapper with this class as owner,
    # which broke `inherited` inside inherited methods.
    defineMethod "$class_name" toJSON "$to_body" || return 1
    defineMethod "$class_name" fromJSON "$from_body" || return 1
}

# Utility: Serialize multiple objects to a file
saveObjects() {
    local file="$1"
    shift
    
    : > "$file"
    
    for obj in "$@"; do
        if declare -F "${obj}.toString" &>/dev/null; then
            echo "$(${obj}.toString)" >> "$file"
        elif declare -F "${obj}.toJSON" &>/dev/null; then
            echo "$(${obj}.toJSON)" >> "$file"
        else
            echo "Warning: Object '$obj' has no serialization method" >&2
        fi
    done
}

# Utility: Load serialized objects from file
loadObjects() {
    local file="$1"
    local class_name="$2"
    local -n instances_array="$3"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File '$file' not found" >&2
        return 1
    fi
    
    local line
    local count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local inst_name="${class_name}_loaded_${count}"
        ${class_name}.new "$inst_name"
        
        if [[ "$line" =~ ^\{ ]]; then
            ${inst_name}.fromJSON "$line" >/dev/null
        else
            ${inst_name}.fromString "$line" >/dev/null
        fi
        
        instances_array+=("$inst_name")
        ((count++))
    done < "$file"
    
    echo "Loaded $count objects from $file"
}

export -f defineSerializableClass
export -f addSerializable
export -f _addSerializable_string
export -f _addSerializable_json
export -f kk._jsonInit
export -f kk._jsonEscape
export -f kk._jsonObject
export -f kk._jsonString
export -f kk._jsonParse
export -f saveObjects
export -f loadObjects
