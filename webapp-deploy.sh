#!/bin/bash
#
# Webapp deployment script

E_OPTERROR=85

if [ $# -ne "2" ] # Script invoked with wrong command-line args?
then
  echo "Usage: `basename $0` user password"
  exit $E_OPTERROR # Exit and explain usage.
fi  
FTP_USER=$1
FTP_PASSWORD=$2

# Webapp URL
WEBAPP="ftp://124.248.205.49/pollonius.zip"

# MySQL user that is used by the application
MYSQL_APP_USER="poll"
# MySQL password
MYSQL_APP_PWD=$(cat /root/.p.mysql.$MYSQL_APP_USER)

# Resin root directory
RESIN_ROOT="/var/www"

# Convenience user
USER="pollonius"

# Check the script is run by root user
if [ $EUID -ne 0 ]; then
    echo "This script must be run by root user"
    echo "Deployment aborted"
    exit 3
fi

pushd /home/$USER

wget --ftp-user=$FTP_USER --ftp-password=$FTP_PASSWORD $WEBAPP
if [ $? -ne 0 ]
then
    echo "Unable to download webapp"
    echo "Deployment aborted"
    exit 4
fi

archive=$(basename $WEBAPP)
unzip $archive -d pollonius/
if [ $? -ne 0 ]
then
    echo "Unable to unzip webapp"
    echo "Deployment aborted"
    exit 5
fi

echo "Setup webapp log"
sed -i -e 's/\x0D$//' \
    -e 's|^\(log4j\.appender\.Log\.File=\).*$|\1'"$RESIN_ROOT"'/log/pollonius.log|' \
    pollonius/WEB-INF/classes/log4j.properties
if [ $? -ne 0 ]
then
    echo "Unable to setup webapp log"
    echo "Deployment aborted"
    exit 6
fi

echo "Setup webapp upload temporary directory"
mkdir -p $RESIN_ROOT/temp
sed -i -e 's/\x0D$//' \
    -e 's|^\(webwork\.multipart\.saveDir=\).*$|\1'"$RESIN_ROOT"'/temp|' \
    pollonius/WEB-INF/classes/webwork.properties
if [ $? -ne 0 ]
then
    echo "Unable to setup webapp upload temporary directory"
    echo "Deployment aborted"
    exit 7
fi

echo "Setup webapp database connection"
sed -i -e 's/\x0D$//' \
    -e 's/^\(jdbc-0\.user=\).*$/\1'"$MYSQL_APP_USER"'/' \
    -e 's/^\(jdbc-0\.password=\).*$/\1'"$MYSQL_APP_PWD"'/' \
    pollonius/WEB-INF/classes/config/proxool.properties
if [ $? -ne 0 ]
then
    echo "Unable to setup webapp database connection"
    echo "Deployment aborted"
    exit 8
fi

chown -R $RESIN_USER:$RESIN_GROUP pollonius
cp -r pollonius $RESIN_ROOT/webapps

popd
echo "Deployment completed successfully"
exit 0

