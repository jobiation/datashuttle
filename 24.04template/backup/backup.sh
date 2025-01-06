#!/bin/bash

# Set variables
    delolderthan=7200; #In minutes
    currentdate=`date '+%Y%m%d'`;
    local_backup_dir="/var/local/externaldisk/localbackup";
    current_backup_dir="$local_backup_dir/$currentdate";
    remote_backup_dir="/var/local/externaldisk/remotebackup";
    db_con="/var/cons/inc-db.sh";
    standarduser="tony";

# Change directory to /var/local/backup
    cd /var/local/backup;

# Include DB variables
    . $db_con;

# Remove current backup directory if it already exists
    if [ -d $current_backup_dir ]; then
        rm -rf $current_backup_dir;
    fi

# Make the current backup directory
    mkdir $current_backup_dir;

# Backup all specified files
    while IFS="," read -r type path name permission owner
    do
    if [ $type == "d" ]; then
        cp -R "$path/$name" "$current_backup_dir"
    elif [ $type == "f" ]; then
        cp "$path/$name" "$current_backup_dir"
    fi
    done < backup_files.csv

# Insert the time in the database
    /usr/bin/php8.3 /var/local/backup/inserttime.php;

# Export databases
    while IFS="," read -r mysqldb
    do
        /usr/bin/mysqldump -u $mysqluser -p$mysqlpass $mysqldb > $current_backup_dir/$mysqldb.sql
    done < mysqldbs.csv

# Backup crontabs
    while IFS="," read -r user
    do
        echo "Backing up crontab for $user";
        crontab -u $user -l > "$current_backup_dir/crontab_$user.txt";
    done < crontabs.csv

# Make sure you are at the local backup directory
    cd $local_backup_dir;

# Clean local backup archives
    for i in `find $local_backup_dir -maxdepth 1 -mindepth 1 -type d -mmin +$delolderthan -print`; do rm -rf $i; done

# Remove tarchive if it already exists
    if [ -f $remote_backup_dir/$currentdate.tar ]; then
        rm $remote_backup_dir/$currentdate.tar;
    fi

# Create tarchive in the remote backup directory
    tar -cf $remote_backup_dir/$currentdate.tar $current_backup_dir;

# Make sure you are at the remote backup directory
    cd $remote_backup_dir;

# Clean the remote backup directory
    for i in `find $remote_backup_dir -maxdepth 1 -mindepth 1 -type f -mmin +$delolderthan -print`; do rm $i; done

# Set permissions on archives
    chown -R $standarduser:$standarduser $current_backup_dir;
    chown -R $standarduser:$standarduser $remote_backup_dir;
    find $current_backup_dir -type f -print0 | xargs -I {} -0 chmod 0660 {}
    find $current_backup_dir -type d -print0 | xargs -I {} -0 chmod 0770 {}
    find $remote_backup_dir -type f -print0 | xargs -I {} -0 chmod 0660 {}
    find $remote_backup_dir -type d -print0 | xargs -I {} -0 chmod 0770 {}

# Overwrite permissions on clone and push scripts.
    chmod 770 $remote_backup_dir/push.sh;

# Remove history
    history -c && history -w;
    unset HISTFILE;
    rm /root/.bash_history;