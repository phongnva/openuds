#!/bin/bash
# Script to run ansible deployment on the remote server
set -e

cd /root
if [ -f ansible_only.tar.gz ]; then
    tar -xzf ansible_only.tar.gz -C /root/
fi

export ANSIBLE_HOST_KEY_CHECKING=False
cd /root/ansible

ansible-playbook -i hosts.ini site.yml \
    --private-key=/root/private_key \
    --ssh-common-args="-o StrictHostKeyChecking=no" \
    > /tmp/ansible_output_v6.log 2>&1
