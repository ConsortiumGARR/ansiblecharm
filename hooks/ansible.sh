#!/bin/bash

#
# Utility functions
#

MAINDIR="$CHARM_DIR"
HOSTFILE="${MAINDIR}/hosts"
GITDIR="${MAINDIR}/mycharmplaybook"
KEYDIR="${MAINDIR}/.ssh"
KEYFILE="${KEYDIR}/git_id_rsa"

function installkey() {
    # install the SSH key
    juju-log -l 'INFO' installkey called
    mkdir -p "$KEYDIR"
    config-get git_deploy_key > "$KEYFILE"
    chmod 600 "$KEYFILE"
    chmod 700 "$KEYDIR"
    juju-log -l 'INFO' key installed 
}

function createansiblehosts() {
    hostgroup="$(config-get hostgroup)"
    if [ -z "$hostgroup" ]; then
        hostgroup="local"
    fi
    echo "[${hostgroup}]" > $HOSTFILE
    echo "localhost ansible_connection=local" >> $HOSTFILE
    juju-log -l 'INFO' ansible hosts created
}

function clone() {
    repo="$(config-get git_repo)"
    git_path="$(which git)"
    # rm -rf myplaybook
    # git clone $repo myplaybook
    juju-log -l 'INFO' clone called $git_path $repo in $(pwd)
    status-set maintenance "cloning git repository at $repo"
    rm -rf "$GITDIR"
    if [ -n "$(config-get git_deploy_key)" ]; then
            export GIT_SSH_COMMAND="ssh -i $KEYFILE"
    fi
    git clone "$repo" "$GITDIR" || return 1
    juju-log -l 'INFO' cloned
    status-set active
}

function run_playbook() {
    # run the playbook
    ansible_path="$(which ansible-playbook)"
    playbook_yaml="$(config-get playbook_yaml)"
    juju-log -l 'INFO' run_playbook called $ansible_path
    if [ "$(status-get)" == "blocked" ]; then
        juju-log -l 'WARN' run_playbook called but blocked 
        return 1
    fi
    # TODO: if not condition return
    status-set maintenance "running playbook"
    juju-log -l 'INFO' "ansible-playbook -b -i $HOSTFILE ${GITDIR}/$playbook_yaml"
    # XXX: leave this as the last line of this function
    export HOME="$CHARM_DIR"
    ansible-playbook -b -i "$HOSTFILE" "${GITDIR}/$playbook_yaml"
}

# leaving these functions here to be ready to migrate to the reactive framework
function configrepo() {
    juju-log -l 'INFO' config.changed.git_repo called 
}

function configkey() {
    juju-log -l 'INFO' config.changed.git_deploy_key called 
    installkey
}

function configplaybookyaml() {
    juju-log -l 'INFO' config.changed.playbook_yaml called 
}

function confighostgroup() {
    juju-log -l 'INFO' config.changed.hostgroup called 
    createansiblehosts
}

function donothing() {
    juju-log -l 'INFO' donothing called 
}


#
# Hooks
#

run_playbook_wrap() {
    juju-log  -l 'INFO' env $(env)
    juju-log  -l 'INFO' whoami $(whoami)
    if run_playbook; then
        status-set active
    else
        status-set blocked "error running playbook"
    fi
}

function install() {
    status-set maintenance "installing git and ansible"
    # install packages
    apt update
    apt-get install -y git ansible
    createansiblehosts
    ansible_path="$(which ansible-playbook)"
    git_path="$(which git)"
    status-set active
    juju-log  -l 'INFO' install called $ansible_path $git_path
}

function charmstart() {
    git_repo=$(config-get git_repo)
    if [ -z "$git_repo"]; then
        status-set blocked "please configure git_repo and/or git_deploy_key"
        return
    fi
    status-set active
    run_playbook_wrap
}

function update() {
    juju-log -l 'INFO' update-status called 
    if [ "$(status-get)" == "blocked" ]; then
        juju-log -l 'WARN' update called but blocked 
        return
    fi

    juju-log -l 'INFO' evaluating update_eval
    eval "$(config-get update_eval)"
    updateeval=$?
    juju-log -l 'INFO' update_eval returned $updateeval
    if [ "$updateeval" == 0 ]; then
        juju-log -l 'INFO' playbook not executed
    else
        run_playbook_wrap
    fi
}

function relation_changed() {
    ansible_path="$(which ansible-playbook)"
    git_path="$(which git)"
    juju-log  -l 'INFO' juju-info-relation-changed called $ansible_path $git_path
    status-set active
    run_playbook_wrap
}

function config_changed() {
    configkey
    configrepo
    configplaybookyaml
    confighostgroup
    if clone; then
        status-set active
    else
        status-set blocked "could not clone repository"
        return
    fi
    run_playbook_wrap
}


