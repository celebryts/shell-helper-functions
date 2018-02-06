#!/bin/bash

#######################################################
# Messages functions
#######################################################
function _info {
    echo -e "\e[96m[INFO]: $@\e[0m"
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
    local ANY_FAIL=0
    for job in `jobs -p`
    do
        _info "Waitting $job..."
        wait $job || ANY_FAIL=1
        _info "Job done: $job"
    done

    return $ANY_FAIL
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
function _sendInfraMail {
    local SUBJECT=$1
    local TEXT=$2
    local SILENT=0
    if [ ${3+x} ]; then
        SILENT=1
    fi

    local MAILGUN_KEY=$(_celyGetSecret clap,mail,mailgun,apiKey)
    local MAILGUN_DOMAIN=$(_celyGetSecret clap,mail,mailgun,domain)

    if [[ "$MAILGUN_KEY" == "" || "$MAILGUN_DOMAIN" == "" ]]; then
        _err I cant send an infra-email since nither "clap,mail,mailgun,apiKey" nor "clap,mail,mailgun,domain" is set.
        return
    fi

    curl -s --user "api:$MAILGUN_KEY" \
        "https://api.mailgun.net/v3/$MAILGUN_DOMAIN/messages" \
        -F from="infra@celebryts.com" \
        -F to=faelsta@gmail.com \
        -F subject="$SUBJECT" \
        -F text="$TEXT" > /dev/null

    if [ $SILENT == 0 ]; then
        if [ $? == 0 ]; then
            _success "Email sent successfully: \"$SUBJECT\""
        else
            _err "Failed to send email: \"$SUBJECT\""
        fi
    fi
}

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

function _celyGetSecret {
    key=$1
    default=
    if [ ${2+x} ]; then
        default=$2
    fi

    if [ $(_getOverriteConfigFileContent CHECK_IF_SET $key) ]; then
        printf "$(_getOverriteConfigFileContent env_value $key)"
    elif [ $(_celyDoesSecretExists "$key") ]; then
        printf "${CELY_SECRETS["$key"]}"
    else
        printf "$default"
    fi
}
function _celyDoesSecretExists {
    local key=$1
    local ignoreOverrites=

    if [ ! -z "$2" ]; then
        ignoreOverrites=1
    fi

    if [[ ! $ignoreOverrites && $(_getOverriteConfigFileContent CHECK_IF_SET $key) ]]; then
        echo 1
    elif [[ ${CELY_SECRETS+x} && ${CELY_SECRETS[$key]+x} ]]; then
        echo 1
    else 
        echo
    fi
}

function _getOverriteConfigFileContent {
    local FORMAT=php
    if [ ! -z "$1" ]; then
        FORMAT=$1
    fi

    local LOKING_FOR_KEY=
    if [[ "$FORMAT" == "env_value" || "$FORMAT" == "CHECK_IF_SET" ]]; then
        if [ -z "$2" ]; then
            echo "When format is \"$FORMAT\" you must provide a second argument with the key you are looking for."
            return
        fi
        LOKING_FOR_KEY=$2
    fi

    local PHP_ARRAY_VAR_NAME=\$_DOCKER_CONTAINER_OVERRIDE_CONFIG
    local ENV_PREFIX=CELY_OVERRIDE_
    local OVERRIDES=$(env | grep -E "$ENV_PREFIX.+")

    local outputContent=""
    for OVERRIDE in $OVERRIDES; do
        #printf "\n$OVERRIDE"
        local SHELL_ENV_NAME=$(echo $OVERRIDE | sed -r "s/=.+//")
        local SHELL_ENV_NAME_WIHTOUT_PREFIX=$(echo $SHELL_ENV_NAME | sed -r "s/^$ENV_PREFIX//")
        local SHELL_ENV_VALUE=$(echo $OVERRIDE | sed -r "s/^.+?=//")
        #printf "\n$SHELL_ENV_NAME_WIHTOUT_PREFIX"

        if [ "$FORMAT" == "php" ]; then
            local line=$(echo $SHELL_ENV_NAME_WIHTOUT_PREFIX | sed -r "s/,/']['/g")
            line="$PHP_ARRAY_VAR_NAME['$line']=$SHELL_ENV_VALUE;"
        elif [ "$FORMAT" == ".env" ]; then
            local line=$SHELL_ENV_NAME_WIHTOUT_PREFIX
            line="$line=$SHELL_ENV_VALUE"
        elif [ "$FORMAT" == "bash_env" ]; then
            local line=$SHELL_ENV_NAME_WIHTOUT_PREFIX
            line=$(echo $line | sed -r "s/[-,]/_/g")
            line="$line=$SHELL_ENV_VALUE"
        elif [ "$SHELL_ENV_NAME_WIHTOUT_PREFIX" == "$LOKING_FOR_KEY" ]; then
            if [ "$FORMAT" == "env_value" ]; then
                printf "$SHELL_ENV_VALUE"
                return
            elif [ "$FORMAT" == "CHECK_IF_SET" ]; then
                echo 1
                return
            fi
        fi

        outputContent="$outputContent\n$line"
    done

    if [ "$FORMAT" == "env_value" ]; then
        return
    elif [ "$FORMAT" == "CHECK_IF_SET" ]; then
        echo
        return
    fi

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
