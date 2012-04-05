#!/bin/bash
#
# Database upgrade script
# The SQL upgrade scripts MUST have been downloaded before running this.

if [ $EUID -ne 0 ] # Script invoked by root user?
then
    echo "This script must be run by root user"
    echo "Database upgrade aborted"
    exit 1
fi

source $(dirname $0)/pollonius-settings.sh

# Be sure to backup the database before upgrading
$(dirname $0)/backup-db.sh
if [ $? -ne 0 ]
then
    echo "Unable to backup current database"
    echo "Database upgrade aborted"
    exit 3
fi

# MySQL password
MYSQL_APP_PWD=$(cat /root/.p.mysql.$MYSQL_APP_USER)

# User home directory
APP_USER_HOME=$(cat /etc/passwd | grep $APP_USER | cut -d':' -f6)
pushd $APP_USER_HOME/$WEBAPP_NAME/sql
if [ $? -ne 0 ]
then
    echo "SQL script directory not found: $APP_USER_HOME/$WEBAPP_NAME/sql"
    echo "Database upgrade aborted"
    exit 4
fi

# CREATE TABLE upgrades (
#  revision int NOT NULL,
#  upgraded_on datetime not null,
#  PRIMARY KEY (revision)
# ) ENGINE=InnoDB;

upgrades=$(ls -1 $DB_UPGRADE.*)
last=$(mysql --user=$MYSQL_APP_USER --password=$MYSQL_APP_PWD --database=$MYSQL_DB_NAME --batch --skip-column-names -e "SELECT MAX(revision) FROM upgrades")
for upgrade in $upgrades 
do
    revision=${upgrade#*.}
    if [ "$revision" -gt "$last" ]
    then
        echo "Upgrading database to revision $revision"
        mysql --user=$MYSQL_APP_USER --password=$MYSQL_APP_PWD --database=$MYSQL_DB_NAME < $upgrade
        if [ $? -ne 0 ]
        then
            echo "Unable to upgrade database to revision $revision"
            echo "Database upgrade aborted"
            exit 5
        fi
        upgraded_on=$(date '+%Y-%m-%d %H:%M:%S')
        echo "Database upgraded at $upgraded_on"
        mysql --user=$MYSQL_APP_USER --password=$MYSQL_APP_PWD --database=$MYSQL_DB_NAME -e "INSERT INTO upgrades (revision, upgraded_on) VALUES ($revision, '$upgraded_on')"
        last=$revision
    fi 
done    

popd
echo "Database upgrade completed successfully"
exit 0