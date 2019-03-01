#!/bin/bash

MAINDIR="$CHARM_DIR"
HOSTFILE="${MAINDIR}/ansiblecharmhosts"
GITDIR="${MAINDIR}/mycharmplaybook"
KEYDIR="${MAINDIR}/.ssh"
KEYFILE="${KEYDIR}/git_id_rsa"

@when 'config.changed.git_deploy_key'
function installkey() {
    # install the SSH key
    juju-log -l 'INFO' "installkey called"
    mkdir -p "$KEYDIR"
    config-get git_deploy_key > "$KEYFILE"
    chmod 600 "$KEYFILE"
    chmod 700 "$KEYDIR"
    juju-log -l 'INFO' "key installed"
    set_flag 'reclone'
}

@when_any 'ansiblehosts' 'config.changed.hostgroup' 'config.changed.inventory_dir'
function createansiblehosts() {
    hostgroup="$(config-get hostgroup)"
    if [ -z "$hostgroup" ]; then
        hostgroup="local"
    fi
    echo "[${hostgroup}]" > $HOSTFILE
    echo "localhost ansible_connection=local" >> $HOSTFILE
    juju-log -l 'INFO' "ansible hosts file created"
    cat $HOSTFILE

    inventorydir="$(config-get inventory_dir)"
    if [ -n "$inventorydir" ]; then
        linkedinventory="${GITDIR}/${inventorydir}/ansiblecharmhosts" 
        rm -f "$linkedinventory"
        ln -s -v "$HOSTFILE" "$linkedinventory" 
        juju-log -l 'INFO' "ansible hosts linked in inventory directory $linkedinventory"
    fi
    set_flag 'run-playbook'
}

@when_any 'reclone' 'config.changed.git_repo' 'config.changed.git_branch'
function clone() {
    repo="$(config-get git_repo)"
    git_path="$(which git)"
    # rm -rf myplaybook
    # git clone $repo myplaybook
    juju-log -l 'INFO' "clone called $git_path $repo in $(pwd)"
    status-set maintenance "Cloning git repository at $repo"
    rm -rf "$GITDIR"
    branch="$(config-get git_branch)"
    if [ -n "$(config-get git_deploy_key)" ]; then
        export GIT_SSH_COMMAND="ssh -i $KEYFILE"
    fi
    git clone -b "$branch" "$repo" "$GITDIR" || return 1
    juju-log -l 'INFO' "repository cloned"
    git -C "$GITDIR" submodule init && git -C "$GITDIR" submodule update && juju-log -l 'INFO' "submodules updated"
    set_flag 'ansiblehosts'
}

function run_playbook() {
    # run the playbook
    ansible_path="$(which ansible-playbook)"
    playbook_yaml="$(config-get playbook_yaml)"
    juju-log -l 'INFO' run_playbook called $ansible_path
    if [ "$(status-get)" == "blocked" ]; then
        juju-log -l 'WARN' "run_playbook called but status is blocked"
        return 1
    fi
    status-set maintenance "Running playbook"
    flags=""
    if [ "$(config-get become)" == "True" ]; then
        flags="${flags} -b "
    fi
    if [ -n "$(config-get tags)" ]; then
        flags="${flags} -t $(config-get tags) "
    fi
    inventorydir="$(config-get inventory_dir)"
    if [ -n "$inventorydir" ]; then
        flags="${flags} -i ${GITDIR}/${inventorydir}/ansiblecharmhosts "
    else
        flags="${flags} -i $HOSTFILE "
    fi
    juju-log -l 'INFO' "ansible-playbook $flags ${GITDIR}/$playbook_yaml"
    export HOME="$CHARM_DIR"
    ansible-playbook $flags "${GITDIR}/$playbook_yaml" && return 0
}

@when_any 'run-playbook' 'config.changed.playbook_yaml' 'config.changed.become' 'config.changed.tags'
run_playbook_wrap() {
    juju-log  -l 'DEBUG' "env $(env)"
    juju-log  -l 'DEBUG' "whoami $(whoami)"
    if run_playbook; then
        status-set active
    else
        status-set blocked "Error running playbook"
    fi
}

#
# Hooks
#

@hook 'start'
function charmstart() {
    git_repo=$(config-get git_repo)
    if [ -z "$git_repo"]; then
        status-set blocked "git_repo not configured"
        return
    fi
    set_flag 'reclone'
}

@hook 'update-status'
function update() {
    juju-log -l 'INFO' update-status called 
    if [ "$(status-get)" == "blocked" ]; then
        juju-log -l 'WARN' "update called but status is blocked"
        return
    fi

    juju-log -l 'INFO' "evaluating update_eval"
    eval "$(config-get update_eval)"
    updateeval=$?
    juju-log -l 'WARNING' "update_eval returned $updateeval"
    if [ "$updateeval" == 0 ]; then
        juju-log -l 'INFO' "playbook not executed"
    else
        set_flag 'reclone'
    fi
}

@hook 'juju-info-relation-changed'
function relation_changed() {
    juju-log  -l 'INFO' "juju-info-relation-changed called"
    set_flag 'reclone'
}



