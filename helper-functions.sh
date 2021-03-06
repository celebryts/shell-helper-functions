#!/bin/bash

#######################################################
# Messages functions
#######################################################
function _info {
    echo -e "\e[96m[INFO]: $@\e[0m"
    #echo -e "\e[96m[INFO]: ${@//$'\n'/\\n[INFO]: }\e[0m"
}
function _warn {
    echo -e "\e[93m[WARN]: $@\e[0m"
    #echo -e "\e[93m[WARN]: ${@//$'\n'/\\n[WARN]: }\e[0m"
}
function _err {
    echo -e "\e[91m[ERR]: $@\e[0m" 1>&2;
    #echo -e "\e[91m[ERR]: ${@//$'\n'/\\n[ERR]: }\e[0m"
}
function _success {
    echo -e "\e[92m[SUCCESS]: $@\e[0m"
    #echo -e "\e[92m[SUCCESS]: ${@//$'\n'/\\n[SUCCESS]: }\e[0m"
}


#######################################################
# Jobs asynchronous functions
#######################################################
MAIN_PROCESS=0
function _waitAll()
{
    if [ ${1+x} ]; then
        MAIN_PROCESS=$1
    fi

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
_LAST_CMD=
_LAST_LINENO=
_LAST_SOURCE=
function ___debug() {
    #echo "BASH_ARGC=$BASH_ARGC"
    #echo "BASH_ARGV=$BASH_ARGV"
    #echo "BASH_COMMAND=$BASH_COMMAND"
    #echo "BASH_EXECUTION_STRING=$BASH_EXECUTION_STRING"
    #echo "BASH_LINENO=$BASH_LINENO"
    #echo "BASH_REMATCH=$BASH_REMATCH"
    #echo "BASH_SOURCE=$BASH_SOURCE"
    #echo "BASH_SUBSHELL=$BASH_SUBSHELL"

    _LAST_CMD=$BASH_COMMAND
    _LAST_LINENO=$BASH_LINENO
    _LAST_SOURCE=$BASH_SOURCE

    if [ "$_EXITING" != "0" ]; then
        exit
    fi
}
if [ "$0" == "bash" ]; then
    trap ___debug DEBUG
fi

function __exiting {
    _info "Exiting..."

    if [ $MAIN_PROCESS -gt 0 ]; then
        _info "Asking main process to gracefully stop..."
        kill -SIGTERM $MAIN_PROCESS
        MAIN_PROCESS=0
    fi

    if hash apachectl &>/dev/null; then
        _info "Asking Apache to gracefully stop..."
        apachectl -k graceful-stop
    fi
}

function _sigint {
    __exiting
    _EXITING=1
}
function _exit {
    if [ "$?" != "0" ]; then
        _err "Last command in '$_LAST_SOURCE' on line '$_LAST_LINENO'\n$_LAST_CMD"
        _showErrorMessageAndExit
    fi

    __exiting
    _EXITING=1
    
    for job in `jobs -p`
    do
        echo "   Sending SIGTERM to job $job..."
        kill -SIGTERM $job 2> /dev/null
    done
}

#######################################################
# Others helpers functions
#######################################################
function _showErrorMessageAndExit {
    local MSG=
    local SECONDS=7

    if [ "$#" == 1 ]; then
        if [[ "$1" =~ ^[0-9]+$ ]] ; then
            local SECONDS=$1
        else
            local MSG=$1
        fi
    elif [ "$#" == 2 ]; then
        local SECONDS=$1
        local MSG=$2
    fi

    if [ "$MSG" != "" ]; then
        _err "$MSG"
    fi

    _err "Exiting in $SECONDS seconds..."

    _dotSleep $SECONDS

    exit
}

function _dotSleep {
    trap _sigint SIGINT SIGTERM SIGQUIT
    trap _exit EXIT

    local SECONDS=$1

    for i in `seq 1 $SECONDS`; do
        echo -n "$i "
        sleep 1s
        if [ ! "$_EXITING" -eq "0" ]; then
            return
        fi
    done
    echo "Done"
}

function _sendInfraMessage {
    local SUBJECT=$1
    local TEXT=$2
    local SILENT=0
    local MAILGUN_KEY=
    local MAILGUN_DOMAIN=
    local INSTAGRAM_USERNAME=
    local INSTAGRAM_PASSWORD=

    if [ ${3+x} ]; then
        SILENT=$3
    fi
    if [ ${4+x} ]; then
        MAILGUN_KEY=$4
    fi
    if [ ${5+x} ]; then
        MAILGUN_DOMAIN=$5
    fi
    if [ ${6+x} ]; then
        INSTAGRAM_USERNAME=$6
    fi
    if [ ${7+x} ]; then
        INSTAGRAM_PASSWORD=$7
    fi

    _sendPushNotification "$SUBJECT: $TEXT" $SILENT "$INSTAGRAM_USERNAME" "$INSTAGRAM_PASSWORD"
    _sendInfraMail "$SUBJECT" "$TEXT" $SILENT "$MAILGUN_KEY" "$MAILGUN_KEY"
}

function _sendPushNotification {
    local TEXT=$1
    local SILENT=0
#    local INSTAGRAM_USERNAME=
#    local INSTAGRAM_PASSWORD=

    if [ ${2+x} ]; then
        SILENT=$2
    fi
#    if [ ${3+x} ]; then
#        INSTAGRAM_USERNAME=$3
#    fi
#
#    if [ ${4+x} ]; then
#        INSTAGRAM_PASSWORD=$4
#    fi
#
#    if [ "$INSTAGRAM_USERNAME" == "" ]; then
#        INSTAGRAM_USERNAME=$(_celyGetSecret "Cely\\\\InstagramClient\\\\ConfigProvider,Cely\\\\InstagramClient\\\\Middleware\\\\InstagramRequestErrorHandler,accounts-credentials,0,username")
#    fi
#
#    if [ "$INSTAGRAM_PASSWORD" == "" ]; then
#        INSTAGRAM_PASSWORD=$(_celyGetSecret "Cely\\\\InstagramClient\\\\ConfigProvider,Cely\\\\InstagramClient\\\\Middleware\\\\InstagramRequestErrorHandler,accounts-credentials,0,password")
#    fi
#
#    if [[ "$INSTAGRAM_USERNAME" == "" || "$INSTAGRAM_PASSWORD" == "" ]]; then
#        _err I cant send a push notification since "Cely\\\\InstagramClient\\\\ConfigProvider,Cely\\\\InstagramClient\\\\Middleware\\\\InstagramRequestErrorHandler,accounts-credentials,0,username" or "Cely\\\\InstagramClient\\\\ConfigProvider,Cely\\\\InstagramClient\\\\Middleware\\\\InstagramRequestErrorHandler,accounts-credentials,0,password" is not set.
#        return 1
#    fi
#
#    curl -s 'https://instagram-chat.celebryts.com/send-message' \
#         -H 'content-type: application/json' \
#         --data-binary "{\"userName\":\"$INSTAGRAM_USERNAME\",\"password\":\"$INSTAGRAM_PASSWORD\",\"toUserId\":\"stavarengo86\",\"message\":\"$TEXT\"}" > /dev/null

    #curl -s https://onesignal.com/api/v1/notification \
    #     -X POST \
    #     --include \
    #     --header "Content-Type: application/json; charset=utf-8" \
    #     --header "Authorization: Basic ZmVlYTVlNDUtYmI4MC00ZDc0LWFhZjAtMGMzMjg1ODk2Njg5" \
    #     --data-binary "{            \"app_id\": \"9042566a-2e83-41cc-89d0-9e5f403c6cf3\",             \"contents\": {                \"en\": \"$TEXT\"},                 \"included_segments\": [\"All\"]            }"

    local CURR_ENV=$CELY_ENV
    if [ "$CELY_ENV" == "production" ]; then
        CURR_ENV=prod
    fi
    TEXT="[$CURR_ENV] $TEXT"

    curl --include \
         --request POST \
         --header "Content-Type: application/json; charset=utf-8" \
         --header "Authorization: Basic ZmVlYTVlNDUtYmI4MC00ZDc0LWFhZjAtMGMzMjg1ODk2Njg5" \
         --data-binary "{\"app_id\": \"9042566a-2e83-41cc-89d0-9e5f403c6cf3\", \"contents\": {\"en\": \"$TEXT\"}, \"included_segments\": [\"All\"]}" \
         https://onesignal.com/api/v1/notifications


    local CURL_EXIT_CODE=$?

    if [ $SILENT == 0 ]; then
        if [ $CURL_EXIT_CODE == 0 ]; then
            _success "Push notification sent successfully."
        else
            _err "Failed to send push notification."
        fi
    fi

    return $CURL_EXIT_CODE
}
function _sendInfraMail {
    local SUBJECT=$1
    local TEXT=$2
    local SILENT=0
    local MAILGUN_KEY=
    local MAILGUN_DOMAIN=

    if [ ${3+x} ]; then
        SILENT=$3
    fi
    if [ ${4+x} ]; then
        MAILGUN_KEY=$4
    fi
    if [ ${5+x} ]; then
        MAILGUN_DOMAIN=$5
    fi

    if [ "$MAILGUN_KEY" == "" ]; then
        MAILGUN_KEY=$(_celyGetSecret clap,mail,mailgun,apiKey)
    fi
    if [ "$MAILGUN_DOMAIN" == "" ]; then
        MAILGUN_DOMAIN=$(_celyGetSecret clap,mail,mailgun,domain)
    fi

    if [[ "$MAILGUN_KEY" == "" || "$MAILGUN_DOMAIN" == "" ]]; then
        _err I cant send an infra-email since nither "clap,mail,mailgun,apiKey" nor "clap,mail,mailgun,domain" is set.
        return 1
    fi

    TEXT=$(printf "$TEXT")

    curl -s --user "api:$MAILGUN_KEY" \
        "https://api.mailgun.net/v3/$MAILGUN_DOMAIN/messages" \
        -F from="infra@celebryts.com" \
        -F to=tech@celebryts.com \
        -F subject="$SUBJECT" \
        -F text="$TEXT" > /dev/null
    local CURL_EXIT_CODE=$?

    if [ $SILENT == 0 ]; then
        if [ $CURL_EXIT_CODE == 0 ]; then
            _success "Email sent successfully: \"$SUBJECT\""
        else
            _err "Failed to send email: \"$SUBJECT\""
        fi
    fi

    return $CURL_EXIT_CODE
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
    elif [ ${CELY_SECRETS[$key]+x} ]; then
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
