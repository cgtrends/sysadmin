#!/bin/bash

if [ $# -ne "1" ] # Script invoked with wrong command-line args?
then
  echo "Usage: `basename $0` user"
  exit $E_OPTERROR # Exit and explain usage.
fi  
FTP_USER=$1
FTP_PASSWD=$(cat /root/.p.ftp.$FTP_USER)

# Check the script is run by root user
if [ $EUID -ne 0 ]; then
    echo "This script must be run by root user"
    echo "Backup aborted"
    exit 3
fi

renice 19 -p $$ &>/dev/null
/root/scripts/backup-dirs.sh
/root/scripts/backup-www.sh
/root/scripts/backup-db.sh

/root/scripts/backup-send.sh $FTP_USER $FTP_PASSWD

exit 0
