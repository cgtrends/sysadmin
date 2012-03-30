#!/bin/bash -x
#
# Webapp upgrades deployment script

if [ $EUID -ne 0 ] # Script invoked by root user?
then
    echo "This script must be run by root user"
    echo "Deployment aborted"
    exit 1
fi

E_OPTERROR=85
if [ $# -ne "2" ] # Script invoked with wrong command-line args?
then
  echo "Usage: `basename $0` user password"
  exit $E_OPTERROR # Exit and explain usage.
fi  
FTP_USER=$1
FTP_PASSWORD=$2

source $(dirname $0)/pollonius-settings.sh

# MySQL password
MYSQL_APP_PWD=$(cat /root/.p.mysql.$MYSQL_APP_USER)

# User home directory
APP_USER_HOME=$(cat /etc/passwd | grep $APP_USER | cut -d':' -f6)
pushd $APP_USER_HOME

archive=$(basename $WEBAPP)
rm -f $archive
if [ $? -ne 0 ]
then
    echo "Unable to delete webapp archive"
    echo "Deployment aborted"
    exit 3
fi

wget --ftp-user=$FTP_USER --ftp-password=$FTP_PASSWORD $WEBAPP
if [ $? -ne 0 ]
then
    echo "Unable to download webapp"
    echo "Deployment aborted"
    exit 4
fi

rm -rf $WEBAPP_NAME
if [ $? -ne 0 ]
then
    echo "Unable to delete working webapp directory"
    echo "Deployment aborted"
    exit 5
fi

unzip $archive -d $WEBAPP_NAME
if [ $? -ne 0 ]
then
    echo "Unable to unzip webapp"
    echo "Deployment aborted"
    exit 6
fi

echo "Setup webapp log"
sed -i -e 's/\x0D$//' \
    -e 's|^\(log4j\.appender\.Log\.File=\).*$|\1'"$RESIN_ROOT"'/log/pollonius.log|' \
    $WEBAPP_NAME/WEB-INF/classes/log4j.properties
if [ $? -ne 0 ]
then
    echo "Unable to setup webapp log"
    echo "Deployment aborted"
    exit 7
fi

echo "Setup webapp upload temporary directory"
mkdir -p $RESIN_ROOT/temp
sed -i -e 's/\x0D$//' \
    -e 's|^\(webwork\.multipart\.saveDir=\).*$|\1'"$RESIN_ROOT"'/temp|' \
    $WEBAPP_NAME/WEB-INF/classes/webwork.properties
if [ $? -ne 0 ]
then
    echo "Unable to setup webapp upload temporary directory"
    echo "Deployment aborted"
    exit 8
fi

echo "Setup webapp database connection"
sed -i -e 's/\x0D$//' \
    -e 's/^\(jdbc-0\.user=\).*$/\1'"$MYSQL_APP_USER"'/' \
    -e 's/^\(jdbc-0\.password=\).*$/\1'"$MYSQL_APP_PWD"'/' \
    $WEBAPP_NAME/WEB-INF/classes/config/proxool.properties
if [ $? -ne 0 ]
then
    echo "Unable to setup webapp database connection"
    echo "Deployment aborted"
    exit 9
fi

chown -R $APP_USER:$APP_GROUP $WEBAPP_NAME

# Be sure to delete the content of new webapp temp directory
# to prevent from overriding existing content of the running webapp
rm -rf $WEBAPP_NAME/temp/*
if [ $? -ne 0 ]
then
    echo "Unable to delete content of the temp directory"
    echo "Deployment aborted"
    exit 10
fi

# Be sure to delete the content of new webapp logs directory
# to prevent from overriding existing content of the running webapp
rm -rf $WEBAPP_NAME/logs/*
if [ $? -ne 0 ]
then
    echo "Unable to delete content of the logs directory"
    echo "Deployment aborted"
    exit 11
fi

# Come back to script directory
popd

# Be sure to backup the running webapp before upgrading
$(dirname $0)/backup-www.sh
if [ $? -ne 0 ]
then
    echo "Unable to backup current webapp"
    echo "Deployment aborted"
    exit 12
fi

cp -r $APP_USER_HOME/$WEBAPP_NAME $RESIN_ROOT/webapps/.

echo "Deployment completed successfully"
exit 0

