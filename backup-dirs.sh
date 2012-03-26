#!/bin/bash
#
# Backup directories

BACKUP_ROOT="/backup"
BACKUP_LOG="/var/log/backup"

renice 19 -p $$ &>/dev/null
tar --absolute-names -czf $BACKUP_ROOT/dirs/etc.tgz /etc >> $BACKUP_LOG/dirs.log
