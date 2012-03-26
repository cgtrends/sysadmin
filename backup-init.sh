#!/bin/bash
#
# Initializes remote directories to prepare file transfer

E_OPTERROR=85

if [ $# -ne "2" ] # Script invoked with wrong command-line args?
then
  echo "Usage: `basename $0` user password"
  exit $E_OPTERROR # Exit and explain usage.
fi  
FTP_USER=$1
FTP_PASS=$2
FTP_HOST='ftpback-rbx4-52.ovh.net'

ftp -n $FTP_HOST <<EOT 
user $FTP_USER $FTP_PASS
mkdir 1
mkdir 1/dirs
mkdir 1/www
mkdir 1/db
mkdir 2
mkdir 2/dirs
mkdir 2/www
mkdir 2/db
mkdir 3
mkdir 3/dirs
mkdir 3/www
mkdir 3/db
mkdir 4
mkdir 4/dirs
mkdir 4/www
mkdir 4/db
mkdir 5
mkdir 5/dirs
mkdir 5/www
mkdir 5/db
mkdir 6
mkdir 6/dirs
mkdir 6/www
mkdir 6/db
mkdir 7
mkdir 7/dirs
mkdir 7/www
mkdir 7/db
bye
EOT

exit 0
