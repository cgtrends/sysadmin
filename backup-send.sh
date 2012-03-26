#!/bin/bash
#
# Send backup files by FTP

E_OPTERROR=85

if [ $# -ne "2" ] # Script invoked with wrong command-line args?
then
  echo "Usage: `basename $0` user password"
  exit $E_OPTERROR # Exit and explain usage.
fi  
FTP_USER=$1
FTP_PASS=$2
BACKUP_ROOT="/backup"
DAY_OF_WEEK=$(date +%u)
FTP_HOST='ftpback-rbx4-52.ovh.net'

if [ -e "/root/scripts/backup-init.sh" ]
then
	/root/scripts/backup-init.sh $FTP_USER $FTP_PASS
    if [ $? -ne 0 ]
    then
    	echo "Unable to initialize backup directories"
    	echo "Backup aborted"
        exit 3
    fi
    rm -f /root/scripts/backup-init.sh
fi

ts=$(date "+%Y-%m-%dT%H-%M-%S")
ftp -ivn $FTP_HOST <<EOT | mail -s "[$ts] Pollonius backup transfer report" webmaster@pollonius.com 
user $FTP_USER $FTP_PASS
cd $DAY_OF_WEEK/dirs
lcd $BACKUP_ROOT/dirs
mput *
cd ../www
lcd $BACKUP_ROOT/www
mput *
cd ../db
lcd $BACKUP_ROOT/db
mput *
bye
EOT

exit 0