#!/usr/bin/env bash

set -e

typeset -A config
typeset -A param

export CONFIG_ENV_LIST=""

#
# ex: setParam "config.file.name" "config.properties"
#
function setParam() {
    echo "= set param ${1} to ${2}"
    [[ ${1} = [\#!]* ]] || [[ ${1} = "" ]] || param[$1]=${2}
}

#
# ex: setConfig "test.name" "value"
#
# $ echo ${CONFIG_TEST_NAME}
# value
#
function setConfig() {
    if [[ "$2" =~ \[(.*)\] ]]; then
        value=${BASH_REMATCH[1]}
        storeConfigVariable "$1" "${value//,/ }"
    else
        storeConfigVariable "$1" "$2"
    fi
}

function storeConfigVariable() {
    echo "= set config ${1} to ${2}"
    [[ ${1} = [\#!]* ]] || [[ ${1} = "" ]] || config[$1]=${2}
    VAR=${1^^}
    CONFIG_ENV_LIST+="\$CONFIG_${VAR//./_} "
    export "CONFIG_${VAR//./_}=${2}"
}

function printDebug() {
    if [[ ${param['debug']} == "true" ]]; then
        echo
        echo ">> debug: $1"
        eval "${@:2}"
        echo
    fi
}

function printJsonDebug() {
    if [[ ${param['debug']} == "true" ]]; then
        echo
        echo ">> debug: $1"
        echo "$2" | jq
        echo
    fi
}

function help() {
    echo
    echo "Usage: $0 {build <all|${config['boards']// /|}> | other} [options...]" >&2
    echo
    echo " options:"
    echo "    --working-directory=<...>       change current working directory"
    echo "    --config-path=<...>             change configuration file location path"
    echo "    --config-name=<...>             change configuration file name (current 'config.properties')"
    echo
    echo "    --enable-debug                  enable debug mode for $0"
    echo "    --enable-packer-log             enable packer extra logs"
    echo
    echo " cmd:"
    echo "    build                           build packer image <all|${config['boards']// /|}>"
    echo
    exit 1
}

# Default params config set
setParam "working.directory" "."
setParam "config.file.path" "."
setParam "config.file.name" "config.properties"
setParam "debug" "false"

if [[ " $@ " =~ --working-directory=([^' ']+) ]]; then
    setParam "working.directory" ${BASH_REMATCH[1]}
fi

if [[ " $@ " =~ --config-path=([^' ']+) ]]; then
    setParam "config.file.path" ${BASH_REMATCH[1]}
fi

if [[ " $@ " =~ --config-name=([^' ']+) ]]; then
    setParam "config.file.name" ${BASH_REMATCH[1]}
fi

if [[ " $@ " =~ --enable-debug ]]; then
    setParam "debug" "true"
fi

if [[ " $@ " =~ --enable-packer-log ]]; then
    export PACKER_LOG=1
fi

if [[ ! -f ${param['config.file.path']}/${param['config.file.name']} ]]; then
    echo "error: ${param['config.file.path']}/${param['config.file.name']} not found!"
    exit -1
fi

config_file=$(cat "${param['config.file.path']}/${param['config.file.name']}")

for line in ${config_file// /}; do
    if [[ "$line" =~ (.*)\=(.*) ]]; then
        setConfig ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}
    fi
done

printDebug "Config file to env variables" "env | grep 'CONFIG_*'"

function packer() {
    echo ${config["${1}.config.file"]}
    generated_json=$(envsubst "${CONFIG_ENV_LIST}" <boards/${config["${1}.config.file"]})
    printJsonDebug "Config JSON file" "$generated_json"
    echo $generated_json | sudo packer build -
}

if [[ " $1 $2 " =~ ' build all ' ]]; then
    echo
    echo "build all"
    for board in ${config['boards']}; do
        echo "build $board"
        packer $board
    done
    exit 0
fi

if [[ " $1 $2 " =~ (build (${config['boards']// /|})) ]]; then
    echo
    echo ${BASH_REMATCH[0]}
    packer "${BASH_REMATCH[2]}"
    exit 0
fi

help