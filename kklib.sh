#!/bin/bash

kk.write() {
    echo -en "$@"
}

kk.writeln() {
    echo -e "$@"
}

kk.result() {
    kk.var "$1"
    declare -g "${KK_VAR}=$2"
}

kk.var() {
    local str="${1^^}" # To upper case
    str="${str// /_}"
    KK_VAR="${str//./_}"
}