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

# Contact Information

Consortium GARR

cloud-support@garr.it
