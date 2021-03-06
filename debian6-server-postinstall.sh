#!/bin/bash
#
# Post-installation script for all-in-one application server
# to be run on Debian 6 (squeeze)

# Domain Name
DOMAIN_NAME="pollonius.com"

# Server configuration
SOFWARE_RAID_ENABLED=false

# MySQL root user
MYSQL_ROOT_USER="root"
MYSQL_ROOT_PWD_STORE="/root/.p.mysql.$MYSQL_ROOT_USER"
# MySQL user that is used by the application
MYSQL_APP_USER="poll"
MYSQL_APP_PWD_STORE="/root/.p.mysql.$MYSQL_APP_USER"
# MySQL user that is used to backup databases
MYSQL_BACKUP_USER="backup"
MYSQL_BACKUP_PWD_STORE="/root/.p.mysql.$MYSQL_BACKUP_USER"
# Database name
MYSQL_DB_NAME="poll"
# URL of the SQL script used to create the database and initialize it
#MYSQL_DB_SCRIPT="http://124.248.205.49/sql/pollonius.sql"
MYSQL_DB_SCRIPT="http://dl.dropbox.com/u/69660680/pollonius.sql"

# URL of Resin. Must be a tar or tar gzip file.
RESIN="http://www.caucho.com/download/resin-3.1.12.tar.gz"
# Resin install path (no trailing slash)
RESIN_INSTALL_PATH="/usr/local/share"
RESIN_HOME_STORE="/root/.resin.home"
# User under which Resin will run
RESIN_USER="www-data"
# Group of the user
RESIN_GROUP="www-data"
# Resin root directory
RESIN_ROOT="/var/www"
# Resin configuration path (no trailing slash)
RESIN_CONFIG_PATH="/etc/resin"

# Convenience user
USER="pollonius"
USER_PWD_STORE="/root/.p.shell.$USER"

# URL of the JDK. Must be a tar or tar gzip file.
# Oracle
#JDK="http://download.oracle.com/otn-pub/java/jdk/7u3-b04/jdk-7u3-linux-x64.tar.gz"
# Personal Dropbox
#JDK="http://dl.dropbox.com/u/3279745/jdk-7u3-linux-x64.tar.gz"
# Pollonius Dropbox
JDK="http://dl.dropbox.com/u/69660680/jdk-7u3-linux-x64.tar.gz"
# Location of the Java virtual machines, without trailing slash
JDK_INSTALL_PATH="/usr/lib/jvm"

# Base URL of the sysadmin scripts
SYSADMIN_BASE="https://raw.github.com/cgtrends/sysadmin/master"
BACKUP_DIRS="backup-dirs.sh"
BACKUP_WWW="backup-www.sh"
BACKUP_DB="backup-db.sh"
BACKUP_INIT="backup-init.sh"
BACKUP_SEND="backup-send.sh"
BACKUP_NIGHTLY="backup-nightly.sh"
BACKUP_CRONTAB="crontab.dist"
WEBAPP_SETTINGS="pollonius-settings.sh"
WEBAPP_DB_UPGRADE="db-upgrade.sh"
WEBAPP_DEPLOY="webapp-deploy.sh"

# ------------------------------------------------------------------------------
# url string URL of the archive to download 
# dir string Directory to expand archive in
#
downloadAndExpand() {
    local url=$1
    local dir=$2
    local archive=$(basename $url)
    
    echo "Dowloading $url into $dir"
    mkdir -p $dir
    pushd $dir
    wget $url
    if [ $? -ne 0 ]
    then
        echo "Unable to download file $url"
        return 1
    fi
    
    echo "Testing if $archive is a Gzip file"
    gunzip --list $archive >/dev/null
    if [ $? -eq 0 ]
    then
        # If so, get the uncompressed filename
        local gz_archive=$archive
        archive=$(gunzip --list $gz_archive | \
            tail -1 | \
            sed -e 's/^[[:space:]]*\([[:digit:]]*\)[[:space:]]*\([[:digit:]]*\)[[:space:]]*\([0-9.%]*\)[[:space:]]*\(.*\)[[:space:]]*$/\4/')

        echo "Decompressing archive $gz_archive to $archive"
        gunzip -f $gz_archive
        if [ $? -ne 0 ]
        then
            echo "Unable to decompress gzip archive $archive"
            return 2
        fi
    fi

    echo "Testing if $archive is a Tar file"
    tar --list -f $archive >/dev/null
    if [ $? -eq 0 ]
    then
        # It is a Tar archive
        install_dir=$(tar --list -f $archive | sed -n '1p' | cut -d'/' -f1)
        
        echo "Expanding $archive to install directory $install_dir"
        tar -xf $archive
        if [ $? -ne 0 ]
        then
            echo "Unable to expand tar archive $archive"
            return 3
        fi
        rm $archive
    else
        echo "Not a tar archive: $archive"
        return 4
    fi

    popd
    return 0
}

# ------------------------------------------------------------------------------
setHostName() {
    echo "Setting host name..."
    
    system_name=$(grep -o "^[^.]*" /etc/hostname)
    fqdn="$system_name.$DOMAIN_NAME"
    echo $fqdn >/etc/hostname
    invoke-rc.d hostname.sh stop
    invoke-rc.d hostname.sh start
    
    sed -i -e 's/^\([0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}[[:space:]]\+\)\('"$system_name"'\).*$/\1'"$fqdn"'/' /etc/hosts
}

# ------------------------------------------------------------------------------
updatePackages() {
    echo "Updating Debian packages..."
    
    apt-get update
    if [ $? -ne 0 ]
    then
        echo "Unable to update Debian packages"
        echo "Post-install aborted"
        exit 10
    fi
    
    # Software RAID setup
    if $SOFTWARE_RAID_ENABLED
    then
        echo mdadm mdadm/initrdstart string all | debconf-set-selections
    fi
    
    apt-get -y upgrade
    if [ $? -ne 0 ]
    then
        echo "Unable to upgrade Debian packages"
        echo "Post-install aborted"
        exit 11
    fi
}

# ------------------------------------------------------------------------------
installNtp() {
    echo "Synchronizing with a time server..."
    
    apt-get -y install ntpdate
    ntpdate pool.ntp.org
    
    apt-get -y install ntp
    if [ $? -ne 0 ]
    then
        echo "Unable to install NTP"
        echo "Post-install aborted"
        exit 80
    fi
}

# ------------------------------------------------------------------------------
secureRootAccount() {
    echo "Securing root account..."
    
#    rm /root/.ssh/authorized_keys2
#    rm /root/.p
#    rm /root/.email
    
    # Discovered unowned files installed by OVH RTM. Fix it.
    if [ -e "/usr/local/rtm/scripts" ]
    then
        chown -R root:root /usr/local/rtm/scripts
    fi
    
    # @todo Disable root account login
        
    apt-get -y install fail2ban
}

# ------------------------------------------------------------------------------
generatePasswords() {
    echo "Generating passwords..."
    
    apt-get -y install makepasswd
    if [ $? -ne 0 ]
    then
        echo "Unable to get makepasswd"
        echo "Post-install aborted"
        exit 20
    fi
    
    user_pwd=$(makepasswd --chars 12)
    echo $user_pwd >$USER_PWD_STORE
    chmod 400 $USER_PWD_STORE
    
    mysql_root_pwd=$(makepasswd --chars 12)
    echo $mysql_root_pwd >$MYSQL_ROOT_PWD_STORE
    chmod 400 $MYSQL_ROOT_PWD_STORE
    
    mysql_app_pwd=$(makepasswd --chars 12)
    echo $mysql_app_pwd >$MYSQL_APP_PWD_STORE
    chmod 400 $MYSQL_APP_PWD_STORE
    
    mysql_backup_pwd=$(makepasswd --chars 12)
    echo $mysql_backup_pwd >$MYSQL_BACKUP_PWD_STORE
    chmod 400 $MYSQL_BACKUP_PWD_STORE
}

# ------------------------------------------------------------------------------
installJDK() {
    echo "Installing JDK..."
    downloadAndExpand $JDK $JDK_INSTALL_PATH
    if [ $? -ne 0 ]
    then
        echo "Unable to install JDK"
        exit 30
    fi

    chown -R root:root $JDK_INSTALL_PATH/$install_dir
    
    echo "JAVA_HOME=$JDK_INSTALL_PATH/$install_dir
export JAVA_HOME

JRE_HOME=\$JAVA_HOME/jre
export JRE_HOME

PATH=$PATH:\$JAVA_HOME/bin
export PATH

CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar
export CLASSPATH" >/etc/profile.d/jdk.sh

    . /etc/profile.d/jdk.sh
}

# ------------------------------------------------------------------------------
installMysql() {
    echo "Installing MySQL server..."
    
    mysql_root_pwd=$(cat $MYSQL_ROOT_PWD_STORE)
    echo mysql-server mysql-server/root_password password $mysql_root_pwd | debconf-set-selections
    echo mysql-server mysql-server/root_password_again password $mysql_root_pwd | debconf-set-selections
    apt-get -y install mysql-server mysql-client
    if [ $? -ne 0 ]
    then
        echo "Unable to install MySQL"
        echo "Post-install aborted"
        exit 40
    fi
    
    mysqladmin --user=$MYSQL_ROOT_USER --password=$mysql_root_pwd status >/dev/null
    if [ $? -ne 0 ]
    then
        invoke-rc.d mysql start
    fi
    mysqladmin --user=$MYSQL_ROOT_USER --password=$mysql_root_pwd status >/dev/null
    if [ $? -ne 0 ]
    then
        echo "Unable to run MySQL"
        echo "Post-install aborted"
        exit 41
    fi
}

# ------------------------------------------------------------------------------
createUserAccounts() {
    echo "Creating user accounts..."
    
    user_pwd=$(cat $USER_PWD_STORE)
    local gid=$(grep "^$RESIN_GROUP" /etc/group | cut -d':' -f3)
    useradd -d /home/$USER -m -g $gid --shell /bin/bash $USER
    echo "$USER:$user_pwd" | chpasswd
}

# ------------------------------------------------------------------------------
initDatabase() {
    echo "Initializing database..."
    
    local sql=$(basename $MYSQL_DB_SCRIPT)
    wget $MYSQL_DB_SCRIPT -P /home/$USER
    if [ $? -ne 0 ]
    then
        echo "Unable to get database init script"
        echo "Post-install aborted"
        exit 50
    fi
    
    mysql_root_pwd=$(cat $MYSQL_ROOT_PWD_STORE)
    mysql_app_pwd=$(cat $MYSQL_APP_PWD_STORE)
    mysql_backup_pwd=$(cat $MYSQL_BACKUP_PWD_STORE)
    
    mysql --user=$MYSQL_ROOT_USER --password=$mysql_root_pwd < /home/$USER/$sql

    mysql --user=$MYSQL_ROOT_USER --password=$mysql_root_pwd -e "CREATE USER '$MYSQL_APP_USER'@'localhost' IDENTIFIED BY '$mysql_app_pwd';"
    mysql --user=$MYSQL_ROOT_USER --password=$mysql_root_pwd -e "GRANT ALL PRIVILEGES ON $MYSQL_DB_NAME.* TO '$MYSQL_APP_USER'@'localhost' WITH GRANT OPTION;"

    mysql --user=$MYSQL_ROOT_USER --password=$mysql_root_pwd -e "CREATE USER '$MYSQL_BACKUP_USER'@'localhost' IDENTIFIED BY '$mysql_backup_pwd';"
    mysql --user=$MYSQL_ROOT_USER --password=$mysql_root_pwd -e "GRANT SELECT, LOCK TABLES ON *.* TO '$MYSQL_BACKUP_USER'@'localhost';"

    mysql --user=$MYSQL_ROOT_USER --password=$mysql_root_pwd -e "FLUSH PRIVILEGES;"
}

# ------------------------------------------------------------------------------
installCompiler() {
    echo "Installing GCC compiler..."
    
    apt-get -y install build-essential libtool libssl-dev unzip
    if [ $? -ne 0 ]
    then
        echo "Unable to get build essentials"
        echo "Post-install aborted"
        exit 60
    fi
}

# ------------------------------------------------------------------------------
installResin() {
    echo "Installing Resin..."
    downloadAndExpand $RESIN $RESIN_INSTALL_PATH
    if [ $? -ne 0 ]
    then
        echo "Unable to install Resin"
        echo "Post-install aborted"
        exit 70
    fi
    resin_home="$RESIN_INSTALL_PATH/$install_dir"
    cat $resin_home >$RESIN_HOME_STORE
    ln -s -f $resin_home $RESIN_INSTALL_PATH/resin
    
    cd $resin_home
    ./configure --enable-64bit --enable-ssl    
    if [ $? -ne 0 ]
    then
        echo "Unable to configure Resin"
        echo "Post-install aborted"
        exit 71
    fi
    
    make
    if [ $? -ne 0 ]
    then
        echo "Unable to compile Resin"
        echo "Post-install aborted"
        exit 72
    fi
    
    make install
    if [ $? -ne 0 ]
    then
        echo "Unable to install Resin"
        echo "Post-install aborted"
        exit 73
    fi
}

# ------------------------------------------------------------------------------
configureResin() {
    echo "Configuring Resin..."
    resin_home=$(cat $RESIN_HOME_STORE)

    mkdir -p $RESIN_ROOT
    mkdir -p $RESIN_ROOT/webapps
    chown $RESIN_USER:$RESIN_GROUP $RESIN_ROOT/webapps
    
    local host='\
    <host id="www.'"$DOMAIN_NAME"'" root-directory=".">\
      <host-alias>'"$DOMAIN_NAME"'</host-alias>\
      <web-app id="/" document-directory="webapps/pollonius">\
        <welcome-file-list>index.html</welcome-file-list>\
        <session-config>\
          <session-max>4096</session-max>\
          <session-timeout>300</session-timeout>\
          <enable-cookies>true</enable-cookies>\
          <enable-url-rewriting>true</enable-url-rewriting>\
          <file-store>WEB-INF/sessions</file-store>\
        </session-config>\
        <error-page error-code="403" location="/template/error.html"/>\
        <error-page error-code="404" location="/template/error.html"/>\
        <error-page error-code="500" location="/template/error.html"/>\
        <error-page error-code="503" location="/template/error.html"/>\
      </web-app>\
    </host>\
'
    
    mkdir -p $RESIN_CONFIG_PATH
    cp $resin_home/conf/resin.conf $RESIN_CONFIG_PATH/resin.conf.dist
    sed -e 's/^\(\s*<http address="\*" port="\)8080\(.*\)$/\180\2/' \
        -e '/^\s*<jvm-arg>-Dcom.sun.management.jmxremote<\/jvm-arg>\s*$/a \      <jvm-arg>-d64</jvm-arg>' \
        -e 's/^\(\s*<web-app id="\)\/\(".*\)$/\1\/root\2/' \
        -e '/\s*<host id="" root-directory="\.">\s*$/i '"$host" \
        $RESIN_CONFIG_PATH/resin.conf.dist >$RESIN_CONFIG_PATH/resin.conf
}

# ------------------------------------------------------------------------------
configureResinStartup() {
    echo "Configuring Resin startup script..."
    resin_home=$(cat $RESIN_HOME_STORE)
    
    local lsb='### BEGIN INIT INFO\
# Provides:          resin\
# Required-Start:    $remote_fs $network\
# Required-Stop:     $remote_fs $network\
# Default-Start:     2 3 4 5\
# Default-Stop:      0 1 6\
# Short-Description: The Resin Java Application Server\
### END INIT INFO'
    
    local args='\
RESIN_ROOT="-root-directory '"$RESIN_ROOT"'"\
RESIN_CONF="-conf '"$RESIN_CONFIG_PATH"'/resin.conf"'

    # We can't use USER= when Resin is bound to port 80
    sed -e '/^#!\/bin\/sh\s*$/a '"$lsb" \
        -e '/^USER=.*$/a '"$args" \
        -e 's/^ARGS=".*"\s*$/ARGS="$RESIN_CONF $RESIN_ROOT $SERVER"/' \
        $resin_home/contrib/init.resin > /etc/init.d/resin
        
    chmod 755 /etc/init.d/resin
        
    update-rc.d resin defaults
    invoke-rc.d resin start
}

# ------------------------------------------------------------------------------
installExim() {
    echo "Installing basic Exim server..."

    apt-get -y install exim4-daemon-light
    if [ $? -ne 0 ]
    then
        echo "Unable to install NTP"
        echo "Post-install aborted"
        exit 81
    fi
    
    fqdn=$(cat /etc/hostname)
    echo $fqdn >/etc/mailname
    echo "# /etc/exim4/update-exim4.conf.conf
#
# Edit this file and /etc/mailname by hand and execute update-exim4.conf
# yourself or use 'dpkg-reconfigure exim4-config'
#
# Please note that this is _not_ a dpkg-conffile and that automatic changes
# to this file might happen. The code handling this will honor your local
# changes, so this is usually fine, but will break local schemes that mess
# around with multiple versions of the file.
#
# update-exim4.conf uses this file to determine variable values to generate
# exim configuration macros for the configuration file.
#
# Most settings found in here do have corresponding questions in the
# Debconf configuration, but not all of them.
#
# This is a Debian specific file

dc_eximconfig_configtype='internet'
dc_other_hostnames='$fqdn'
dc_local_interfaces='127.0.0.1 ; ::1'
dc_readhost=''
dc_relay_domains=''
dc_minimaldns='false'
dc_relay_nets=''
dc_smarthost=''
CFILEMODE='644'
dc_use_split_config='false'
dc_hide_mailname=''
dc_mailname_in_oh='true'
dc_localdelivery='maildir_home'
" >/etc/exim4/update-exim4.conf.conf
    
    update-exim4.conf
}

# ------------------------------------------------------------------------------
prepareSysAdmin() {
    mkdir -p /root/scripts
    mkdir -p /var/log/backup
    mkdir -p /backup/dirs
    mkdir -p /backup/www
    mkdir -p /backup/db
    
    wget $SYSADMIN_BASE/$BACKUP_DIRS -P /root/scripts
    if [ $? -ne 0 ]
    then
        echo "Unable to get $BACKUP_DIRS"
        echo "Post-install aborted"
        exit 90
    fi
    chmod 700 /root/scripts/$BACKUP_DIRS
    
    wget $SYSADMIN_BASE/$BACKUP_WWW -P /root/scripts
    if [ $? -ne 0 ]
    then
        echo "Unable to get $BACKUP_WWW"
        echo "Post-install aborted"
        exit 91
    fi
    chmod 700 /root/scripts/$BACKUP_WWW
    
    wget $SYSADMIN_BASE/$BACKUP_DB -P /root/scripts
    if [ $? -ne 0 ]
    then
        echo "Unable to get $BACKUP_DB"
        echo "Post-install aborted"
        exit 92
    fi
    chmod 700 /root/scripts/$BACKUP_DB
    
    wget $SYSADMIN_BASE/$BACKUP_INIT -P /root/scripts
    if [ $? -ne 0 ]
    then
        echo "Unable to get $BACKUP_INIT"
        echo "Post-install aborted"
        exit 93
    fi
    chmod 700 /root/scripts/$BACKUP_INIT
    
    wget $SYSADMIN_BASE/$BACKUP_SEND -P /root/scripts
    if [ $? -ne 0 ]
    then
        echo "Unable to get $BACKUP_SEND"
        echo "Post-install aborted"
        exit 94
    fi
    chmod 700 /root/scripts/$BACKUP_SEND
    
    wget $SYSADMIN_BASE/$BACKUP_NIGHTLY -P /root/scripts
    if [ $? -ne 0 ]
    then
        echo "Unable to get $BACKUP_NIGHTLY"
        echo "Post-install aborted"
        exit 95
    fi
    chmod 700 /root/scripts/$BACKUP_NIGHTLY
    
    wget $SYSADMIN_BASE/$BACKUP_CRONTAB -P /root/scripts
    if [ $? -ne 0 ]
    then
        echo "Unable to get $BACKUP_CRONTAB"
        echo "Post-install aborted"
        exit 96
    fi
    chmod 400 /root/scripts/$BACKUP_CRONTAB
    crontab /root/scripts/$BACKUP_CRONTAB
    
    wget $SYSADMIN_BASE/$WEBAPP_DEPLOY -P /root/scripts
    if [ $? -ne 0 ]
    then
        echo "Unable to get $WEBAPP_DEPLOY"
        echo "Post-install aborted"
        exit 97
    fi
    chmod 700 /root/scripts/$WEBAPP_DEPLOY
}

# ------------------------------------------------------------------------------
# Check the script is run by root user
if [ $EUID -ne 0 ]; then
    echo "This post-install script must be run by root user"
    echo "Post-install aborted"
    exit 1
fi

setHostName
updatePackages
installNtp
secureRootAccount
generatePasswords
installJDK
installMysql
createUserAccounts
initDatabase
installCompiler
installResin
configureResin
configureResinStartup
installExim
prepareSysAdmin

echo "Post-install completed successfully"
exit 0
