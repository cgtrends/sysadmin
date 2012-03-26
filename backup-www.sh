#!/bin/bash
#
# Backup web applications

BACKUP_ROOT="/backup"
BACKUP_LOG="/var/log/backup"

renice 19 -p $$ &>/dev/null
tar --absolute-names -czf $BACKUP_ROOT/www/www.tgz /var/www >> $BACKUP_LOG/www.log
