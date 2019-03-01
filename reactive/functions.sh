#!/bin/bash

MAINDIR="$CHARM_DIR"
HOSTFILE="${MAINDIR}/ansiblecharmhosts"
GITDIR="${MAINDIR}/mycharmplaybook"
KEYDIR="${MAINDIR}/.ssh"
KEYFILE="${KEYDIR}/git_id_rsa"

@when 'install_key'
function installkey() {
    # install the SSH key
    juju-log -l 'INFO' installkey called
    mkdir -p "$KEYDIR"
    config-get git_deploy_key > "$KEYFILE"
    chmod 600 "$KEYFILE"
    chmod 700 "$KEYDIR"
    juju-log -l 'INFO' key installed 
}

@when 'create_ansible_hosts'
function createansiblehosts() {
    hostgroup="$(config-get hostgroup)"
    if [ -z "$hostgroup" ]; then
        hostgroup="local"
    fi
    echo "[${hostgroup}]" > $HOSTFILE
    echo "localhost ansible_connection=local" >> $HOSTFILE
    juju-log -l 'INFO' ansible hosts created
    cat $HOSTFILE

    inventorydir="$(config-get inventory_dir)"
    if [ -n "$inventorydir" ]; then
        linkedinventory="${GITDIR}/${inventorydir}/ansiblecharmhosts" 
        rm -f "$linkedinventory"
        ln -s -v "$HOSTFILE" "$linkedinventory" 
        juju-log -l 'INFO' "ansible hosts linked in inventory directory $linkedinventory"
    fi
}

function clone() {
    repo="$(config-get git_repo)"
    git_path="$(which git)"
    # rm -rf myplaybook
    # git clone $repo myplaybook
    juju-log -l 'INFO' clone called $git_path $repo in $(pwd)
    status-set maintenance "cloning git repository at $repo"
    rm -rf "$GITDIR"
    branch="$(config-get git_branch)"
    if [ -n "$(config-get git_deploy_key)" ]; then
        export GIT_SSH_COMMAND="ssh -i $KEYFILE"
    fi
    git clone -b "$branch" "$repo" "$GITDIR" || return 1
    juju-log -l 'INFO' cloned
    git -C "$GITDIR" submodule init && git -C "$GITDIR" submodule update && juju-log -l 'INFO' submodules updated
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
    status-set maintenance "running playbook"
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

# leaving these functions here to be ready to migrate to the reactive framework
@when 'config.changed.git_repo'
function configrepo() {
    juju-log -l 'INFO' config.changed.git_repo called: $(config-get git_repo)
}

@when 'config.changed.git_deploy_key'
function configkey() {
    juju-log -l 'INFO' config.changed.git_deploy_key called: $(config-get git_deploy_key)
    set-flag 'install_key'
}

@when 'config.changed.git_branch'
function configbranch() {
    juju-log -l 'INFO' config.changed.git_branch called: $(config-get git_branch)
    set-flag 'install_key'
}

@when 'config.changed.playbook_yaml'
function configplaybookyaml() {
    juju-log -l 'INFO' config.changed.playbook_yaml called: $(config-get playbook_yaml) 
}

@when 'config.changed.hostgroup'
function confighostgroup() {
    juju-log -l 'INFO' config.changed.hostgroup called: $(config-get hostgroup)  
    set-flag 'create_ansible_hosts'
}

@when 'config.changed.become'
function configbecome() {
    juju-log -l 'INFO' config.changed.become called: $(config-get become)  
}

@when 'config.changed.tags'
function configtags() {
    juju-log -l 'INFO' config.changed.tags called: $(config-get tags)  
}

@when 'config.changed.update_eval'
function configeval() {
    juju-log -l 'INFO' config.changed.update_eval called: $(config-get update_eval)
}

@when 'config.changed.inventory_dir'
function configinventorydir() {
    juju-log -l 'INFO' config.changed.inventory_dir called: $(config-get inventory_dir)
    set-flag 'create_ansible_hosts'
}

@when 'run-playbook'
run_playbook_wrap() {
    juju-log  -l 'INFO' env $(env)
    juju-log  -l 'INFO' whoami $(whoami)
    if run_playbook; then
        status-set active
    else
        status-set blocked "error running playbook"
    fi
}

#
# Hooks
#

@hook 'install'
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

@hook 'start'
function charmstart() {
    git_repo=$(config-get git_repo)
    if [ -z "$git_repo"]; then
        status-set blocked "please configure git_repo and/or git_deploy_key"
        return
    fi
    status-set active
    run_playbook_wrap
}

@hook 'update-status'
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
        createansiblehosts
        run_playbook_wrap
    fi
}

@hook 'juju-info-relation-changed'
function relation_changed() {
    ansible_path="$(which ansible-playbook)"
    git_path="$(which git)"
    juju-log  -l 'INFO' juju-info-relation-changed called $ansible_path $git_path
    status-set active
    set-flag 'run-playbook'
}

@hook 'config-changed'
function config_changed() {
    if clone; then
        status-set active
    else
        status-set blocked "could not clone repository"
        return
    fi

    set-flag 'run-playbook'
}


