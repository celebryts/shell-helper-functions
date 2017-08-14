#!/bin/bash

#######################################################
# Messages functions
#######################################################
function _info {
    echo -e "\e[34m[INFO]: $@\e[0m"
}
function _warn {
    echo -e "\e[93m[WARN]: $@\e[0m"
}
function _err {
    echo -e "\e[91m[ERR]: $@\e[0m"
}
function _success {
    echo -e "\e[92m[SUCCESS]: $@\e[0m"
}


#######################################################
# Jobs asynchronous functions
#######################################################
function _waitAll()
{
    for job in `jobs -p`
    do
        _info "Waitting $job..."
        wait $job
        _info "Job done: $job"
    done
}


#######################################################
# Exit control functions
#######################################################
_EXITING=0
function _sigint {
    _EXITING=1
}
function _exit {
    _EXITING=1
    _info "Exiting..."
    for job in `jobs -p`
    do
        echo "   Killing job $job..."
        kill $job 2> /dev/null
    done
}

#######################################################
# Others helpers functions
#######################################################
function _waitFile {
    trap _sigint SIGINT SIGTERM SIGQUIT
    trap _exit EXIT

    FILE=$1
    MSG="Waiting for the file \"$FILE\""
    if [ ! -z "$2" ]; then
        MSG=$2
    fi

    while [[ ! -e "$FILE" && "$_EXITING" -eq "0" ]]; do
        _warn $MSG
        sleep 2
    done
}
function _waitForever {
    trap _sigint SIGINT SIGTERM SIGQUIT
    trap _exit EXIT

    while [ "$_EXITING" -eq "0" ]; do
        sleep 2
    done
}

function _getOverriteConfigFileContent {
    local FORMAT=php
    if [ ! -z "$1" ]; then
        FORMAT=$1
    fi

    local PHP_ARRAY_VAR_NAME=\$_DOCKER_CONTAINER_OVERRIDE_CONFIG
    local ENV_PREFIX=CELY_OVERRIDE_
    local OVERRIDES=$(env | grep -E "$ENV_PREFIX.+")

    local outputContent=""
    for OVERRIDE in $OVERRIDES; do
        local SHELL_ENV_NAME=$(echo $OVERRIDE | sed -r "s/=.+//")
        local SHELL_ENV_VALUE=$(echo $OVERRIDE | sed -r "s/^.+?=//")

        if [ "$FORMAT" == "php" ]; then
            local line=$(echo $SHELL_ENV_NAME | sed -r "s/^$ENV_PREFIX//" | sed -r "s/,/']['/g")
            line="$PHP_ARRAY_VAR_NAME['$line']=$SHELL_ENV_VALUE;"
        elif [ "$FORMAT" == ".env" ]; then
            local line=$(echo $SHELL_ENV_NAME | sed -r "s/^$ENV_PREFIX//")
            line="$line=$SHELL_ENV_VALUE"
        elif [ "$FORMAT" == "bash_env" ]; then
            local line=$(echo $SHELL_ENV_NAME | sed -r "s/^$ENV_PREFIX//")
            line=$(echo $line | sed -r "s/[-,]/_/g")
            line="$line=$SHELL_ENV_VALUE"
        fi

        outputContent="$outputContent\n$line"
    done

    if [ "$FORMAT" == "php" ]; then
        local outputTempFile=$(tempfile)
        printf "$outputContent" > "$outputTempFile"
        outputContent=$(sort "$outputTempFile")
        echo "$outputContent" > "$outputTempFile"

        printf "<?php \n /* FILE AUTO GENERATED */ \n $PHP_ARRAY_VAR_NAME = [];\n" > "$outputTempFile"
        echo "$outputContent" >> "$outputTempFile"
        printf "\n return $PHP_ARRAY_VAR_NAME;\n" >> "$outputTempFile"

        cat "$outputTempFile"

        rm -f "$outputTempFile"
    elif [ "$FORMAT" == ".env" ]; then
        printf "$outputContent\n"
    elif [ "$FORMAT" == "bash_env" ]; then
        printf "$outputContent\n"
    fi
}
