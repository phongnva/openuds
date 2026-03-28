#!/bin/bash
set -e

echo "=== Step 1: Fix replication on Server 02 ==="
ssh -i /root/private_key -o StrictHostKeyChecking=no root@103.131.85.202 bash <<'REMOTE'
mysql -u root -e "STOP REPLICA;"
mysql -u root -e "RESET REPLICA ALL;"
mysql -u root -e "CHANGE REPLICATION SOURCE TO SOURCE_HOST='103.131.85.198', SOURCE_USER='repl_user', SOURCE_PASSWORD='Repl@2024!Secure', SOURCE_AUTO_POSITION=1;"
mysql -u root -e "START REPLICA;"
sleep 2
echo "--- Replica Status ---"
mysql -u root -e "SHOW REPLICA STATUS\G" | grep -E 'Replica_IO_Running|Replica_SQL_Running|Last_Error|Source_Host'
REMOTE

echo ""
echo "=== Step 2: Re-run Ansible playbook ==="
cd /root
tar -xzf ansible_only.tar.gz -C /root/
export ANSIBLE_HOST_KEY_CHECKING=False
cd /root/ansible
ansible-playbook -i hosts.ini site.yml \
    --private-key=/root/private_key \
    --ssh-common-args="-o StrictHostKeyChecking=no" \
    --start-at-task="Clone/update OpenUDS source code" \
    2>&1 | tee /tmp/ansible_output_final.log

echo "=== Done ==="
