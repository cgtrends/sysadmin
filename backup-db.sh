#!/bin/bash
#
# Backup MySQL databases

BACKUP_ROOT="/backup"
BACKUP_LOG="/var/log/backup"

# Database name
MYSQL_DB_NAME="poll"
# Database backup user name
MYSQL_BACKUP_USER="backup"
# Database backup user password
MYSQL_BACKUP_PWD=$(cat /root/.p.mysql.$MYSQL_BACKUP_USER)

renice 19 -p $$ &>/dev/null
mysqldump --user=$MYSQL_BACKUP_USER --password=$MYSQL_BACKUP_PWD $MYSQL_DB_NAME | gzip > $BACKUP_ROOT/db/$MYSQL_DB_NAME.sql.gz
