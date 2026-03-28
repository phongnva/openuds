#!/bin/bash
# Setup MySQL replication on Server 02
set -e

echo "=== Setting up MySQL GTID replication ==="

# Check repl_user exists on primary
echo "--- Checking repl_user on primary ---"
mysql -u root -e "SELECT user,host FROM mysql.user WHERE user='repl_user';"

echo "--- Setting up replication on Server 02 ---"
ssh -i /root/private_key -o StrictHostKeyChecking=no root@103.131.85.202 bash -c "'
mysql -u root -e \"STOP REPLICA;\"
mysql -u root -e \"CHANGE REPLICATION SOURCE TO SOURCE_HOST='103.131.85.198', SOURCE_USER='repl_user', SOURCE_PASSWORD='ReplP@ss2024!', SOURCE_AUTO_POSITION=1;\"
mysql -u root -e \"START REPLICA;\"
sleep 2
mysql -u root -e \"SHOW REPLICA STATUS\G\"
'"

echo "=== Done ==="
