#!/bin/bash

. "$(dirname $0)/ansible.sh"

hookname="$(basename $0)"

case "$hookname" in
    install)
        install
        ;;
    start)
        charmstart 
        ;;
    config-changed)
        config_changed
        ;;
    juju-info-relation-joined)
        relation_changed
        ;;
    juju-info-relation-changed)
        relation_changed
        ;;
    update-status)
        update
        ;;
    *)
        juju-log -l 'WARN' unknown hook "$hookname"
        ;;
esac

