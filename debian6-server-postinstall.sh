#!/bin/bash
#
# Post-installation script for all-in-one application server
# to be run on Debian 6 (squeeze)

# MySQL root user
MYSQL_ROOT_USER="root"
# MySQL user that is used by the application
MYSQL_APP_USER="poll"
# Database name
MYSQL_DB_NAME="poll"
# URL of the SQL script used to create the database and initialize it
MYSQL_DB_SCRIPT="http://124.248.205.49/sql/pollonius.sql"

# URL of Resin. Must be a tar or tar gzip file.
RESIN="http://www.caucho.com/download/resin-3.1.12.tar.gz"
# Resin install path (no trailing slash)
RESIN_INSTALL_PATH="/usr/local/share"
# User under which Resin will run
RESIN_USER="www-data"
# Group of the user
RESIN_GROUP="www-data"
# Resin root directory
RESIN_ROOT="/var/www"
# Resin configuration path (no trailing slash)
RESIN_CONFIG_PATH="/etc/resin"

USER="goriol"

# URL of the JDK. Must be a tar or tar gzip file.
JDK="http://download.oracle.com/otn-pub/java/jdk/7u3-b04/jdk-7u3-linux-x64.tar.gz"
# Location of the Java virtual machines, without trailing slash
JDK_INSTALL_PATH="/usr/lib/jvm"

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
    
    apt-get upgrade
    if [ $? -ne 0 ]
    then
        echo "Unable to upgrade Debian packages"
        echo "Post-install aborted"
        exit 11
    fi
}

# ------------------------------------------------------------------------------
generatePasswords() {
    echo "Generating passwords..."
    
    apt-get install makepasswd
    if [ $? -ne 0 ]
    then
        echo "Unable to get makepasswd"
        echo "Post-install aborted"
        exit 20
    fi
    
    MYSQL_ROOT_PWD=$(makepasswd --chars 8)
    echo $MYSQL_ROOT_PWD >/root/mysql_$MYSQL_ROOT_USER.txt
    chmod 600 /root/mysql_$MYSQL_ROOT_USER.txt
    
    MYSQL_APP_PWD=$(makepasswd --chars 8)
    echo $MYSQL_APP_PWD >/root/mysql_$MYSQL_APP_USER.txt
    chmod 600 /root/mysql_$MYSQL_APP_USER.txt
}

# ------------------------------------------------------------------------------
# url string URL of the archive to download 
# dir string Directory to expand archive in
#
downloadAndExpand() {
    local url=$1
    local dir=$2
    local archive=`basename $url`
    
    echo "Dowloading $url into $dir"
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
    fi

    popd
    return 0
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

    echo "JAVA_HOME=$JDK_INSTALL_PATH/$install_dir
export JAVA_HOME

JRE_HOME=\$JAVA_HOME/jre
export JRE_HOME

PATH=$PATH:\$JAVA_HOME/bin
export PATH

CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
export CLASSPATH" >/etc/profile.d/jdk.sh

    . /etc/profile.d/jdk.sh
}

# ------------------------------------------------------------------------------
installMysql() {
    echo "Installing MySQL server..."
    
    echo mysql-server mysql-server/root_password password $MYSQL_ROOT_PWD | debconf-set-selections
    echo mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PWD | debconf-set-selections
    apt-get -y install mysql-server mysql-client
    if [ $? -ne 0 ]
    then
        echo "Unable to install MySQL"
        echo "Post-install aborted"
        exit 40
    fi
    
    mysqladmin --user=$MYSQL_ROOT_USER --password=$MYSQL_ROOT_PWD status >/dev/null
    if [ $? -ne 0 ]
    then
        /etc/init.d/mysql start
    fi
    mysqladmin --user=$MYSQL_ROOT_USER --password=$MYSQL_ROOT_PWD status >/dev/null
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
    
    local gid=$(grep "^$RESIN_GROUP" /etc/group | cut -d':' -f3)
    useradd -d /home/$USER -m -g $gid $USER
}

# ------------------------------------------------------------------------------
initDatabase() {
    echo "Initializing database..."
    
    local sql=`basename MYSQL_DB_SCRIPT`
    wget $MYSQL_DB_SCRIPT -P /home/$USER
    if [ $? -ne 0 ]
    then
        echo "Unable to get database init script"
        echo "Post-install aborted"
        exit 50
    fi
    mysql --user=$MYSQL_ROOT_USER --password=$MYSQL_ROOT_PWD < /home/$USER/$sql
    mysql --user=$MYSQL_ROOT_USER --password=$MYSQL_ROOT_PWD -e "CREATE USER '$MYSQL_APP_USER'@'localhost' IDENTIFIED BY '$MYSQL_APP_PWD';"
    mysql --user=$MYSQL_ROOT_USER --password=$MYSQL_ROOT_PWD -e "GRANT ALL PRIVILEGES ON $MYSQL_DB_NAME.* TO '$MYSQL_APP_USER'@'localhost' WITH GRANT OPTION;"
    mysql --user=$MYSQL_ROOT_USER --password=$MYSQL_ROOT_PWD -e "FLUSH PRIVILEGES;"
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
    RESIN_HOME=$RESIN_INSTALL_PATH/$install_dir
    ln -s -f $RESIN_HOME $RESIN_INSTALL_PATH/resin
    
    cd $RESIN_HOME
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
    mkdir -p $RESIN_ROOT
    chown $RESIN_USER:$RESIN_GROUP $RESIN_ROOT
    
    local host='\
    <host id="www.pollonius.com" root-directory=".">\
      <host-alias>pollonius.com</host-alias>\
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
    cp $RESIN_HOME/conf/resin.conf $RESIN_CONFIG_PATH/resin.conf.dist
    sed -e 's/^\(\s*<http address="\*" port="\)8080\(.*\)$/\180\2/' \
        -e '/^\s*<jvm-arg>-Dcom.sun.management.jmxremote<\/jvm-arg>\s*$/a \      <jvm-arg>-d64</jvm-arg>' \
        -e 's/^\(\s*<web-app id="\)\/\(".*\)$/\1\/root\2/' \
        -e '/\s*<host id="" root-directory="\.">\s*$/i '"$host" \
        $RESIN_CONFIG_PATH/resin.conf.dist >$RESIN_CONFIG_PATH/resin.conf
}

# ------------------------------------------------------------------------------
configureResinStartup() {
    echo "Configuring Resin startup script..."
    
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

    sed -e '/^#!\/bin\/sh\s*$/a '"$lsb" \
        -e 's/^USER=\(.*\)$/USER="'"$RESIN_USER"'"/' \
        -e '/^USER=.*$/a '"$args" \
        -e 's/^ARGS=".*"\s*$/ARGS="$RESIN_CONF $RESIN_ROOT $SERVER"/' \
        $RESIN_HOME/contrib/init.resin > /etc/init.d/resin
        
    chmod 755 /etc/init.d/resin
        
    update-rc.d resin defaults
}

# ------------------------------------------------------------------------------
# Check the script is run by root user
if [ $EUID -ne 0 ]; then
    echo "This post-install script must be run by root user"
    echo "Post-install aborted"
    exit 1
fi

updatePackages
generatePasswords
installJDK
installMysql
createUserAccounts
initDatabase
installCompiler
installResin
configureResin
configureResinStartup

echo "Post-install completed successfully"
exit 0