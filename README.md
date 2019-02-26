# Overview

This subordinate charm runs an Ansible playbook, in a git repository, against localhost.

The charm clones the git repository and runs the playbook.
  
The rationale behind this Charm is that:
* the idempotency provided by Ansible seem to fit the idempotency required by Juju Charm hook implementations
* there are several ready to go Ansible playbooks available online
* DevOps which prefer Ansible over scripting are facilitated.


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
