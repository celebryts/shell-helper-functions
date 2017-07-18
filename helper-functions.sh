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
