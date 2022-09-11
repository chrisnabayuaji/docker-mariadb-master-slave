#!/bin/bash
echo
echo Starting deploying...
echo

export DB_NAME_1=${MYSQL_DB_NAME_1:-'db-1'}
export DB_NAME_2=${MYSQL_DB_NAME_2:-'db-2'}

export REPL_USER_1=${MYSQL_REPL_USER_1:-'repl'}
export REPL_PASS_1=${MYSQL_REPL_PASS_1:-'replsecure'}

export ROOT_PASS_1=${MYSQL_ROOT_PASS_1:-'root'}
export ROOT_PASS_2=${MYSQL_ROOT_PASS_2:-'root'}

export HOST_1=${MYSQL_HOST_1:-'db-1'}
export HOST_2=${MYSQL_HOST_2:-'db-2'}

docker-compose -f docker-compose.yml up -d

echo
echo Waiting 60s for containers to be up and running...
echo Implementing mysql master slave replication...
sleep 60
echo

echo Create repl user on master database...
docker exec $HOST_1 \
  mysql -u root --password=$ROOT_PASS_1 \
  --execute="CREATE USER '$REPL_USER_1'@'%' IDENTIFIED BY '$REPL_PASS_1';\
  GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER_1'@'%';\
  FLUSH PRIVILEGES;"

echo Get the log position and name...
result=$(docker exec $HOST_1 mysql -u root --password=$ROOT_PASS_1 --execute="SHOW MASTER STATUS;")
log=$(echo $result|awk '{print $5}')
position=$(echo $result|awk '{print $6}')

echo Connect slave 1 to master...
docker exec $HOST_2 \
  mysql -u root --password=$ROOT_PASS_2 \
  --execute="STOP SLAVE;\
  RESET SLAVE;\
  CHANGE MASTER TO MASTER_HOST='$HOST_1', MASTER_USER='$REPL_USER_1', \
  MASTER_PASSWORD='$REPL_PASS_1', MASTER_LOG_FILE='$log', MASTER_LOG_POS=$position;\
  START SLAVE;\
  SHOW SLAVE STATUS\G;"