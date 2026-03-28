#!/bin/bash
echo "--- Checking MySQL status on Server 01 (Local) ---"
mysql -e "SHOW VARIABLES LIKE 'gtid_mode';"
mysql -e "SHOW VARIABLES LIKE 'enforce_gtid_consistency';"

echo -e "\n--- Checking MySQL status on Server 02 (Remote) ---"
ssh -i /root/private_key -o StrictHostKeyChecking=no root@103.131.85.202 "mysql -e \"SHOW VARIABLES LIKE 'gtid_mode';\"; mysql -e \"SHOW VARIABLES LIKE 'enforce_gtid_consistency';\""
