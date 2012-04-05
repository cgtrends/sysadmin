#!/bin/bash
#
# Common settings of Pollonius scripts

# Webapp distribution server
WEBAPP_DIST_SERVER="124.248.205.49"

# Webapp name
WEBAPP_NAME="pollonius"

# Webapp URL
WEBAPP="ftp://${WEBAPP_DIST_SERVER}/${WEBAPP_NAME}.zip"

# MySQL database name
MYSQL_DB_NAME="poll"

# MySQL user that is used by the application
MYSQL_APP_USER="poll"

# Resin root directory
RESIN_ROOT="/var/www"

# user/group in charge of application deployment and maintenance
APP_USER="pollonius"
APP_GROUP="www-data"

# Database upgrade script basename
DB_UPGRADE="db-upgrade"
