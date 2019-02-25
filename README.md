# Overview

This subordinate charm runs an Ansible playbook, in a git repository, against localhost.

The charm clones the git repository and runs the playbook.

For the git clone operation, a deployment key can be provided in the charm's configuration.


# Usage

Usage example:

    juju deploy cs:ubuntu
    juju deploy cs:ansible simpleansible
    juju config simpleansible git_repo="https://git.garr.it/clauz/simpleansible.git"
    juju config simpleansible playbook_yaml="main.yaml" 
    juju add-relation ubuntu ansible

## Known Limitations and Issues

# Configuration

    git_repo: git repository (HTTPS or SSH)
    git_deploy_key: git deployment key (copy-paste of the SSH private key)
    playbook_yaml: main ansible playbook yaml to execute

# Contact Information

Consortium GARR

cloud-support@garr.it
