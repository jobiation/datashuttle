#!/bin/bash

# Set variables
    standarduser="tony";
    phpversion="8.3";

# Start with an apt-get update and upgrade
    echo -e "\nStart with an update and upgrade? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        apt-get -y update;
        apt-get -y upgrade;
    fi

# Make user read notes
    echo -e "\n--- Make sure all CSV files read by this script have a trailing LF"
    echo -e "--- If you will be mounting an external disk that is not yet partitioned and formatted, exit this script and use fdisk to partiton and 'mkfs -t ext4 /var/local/externaldisk' to partition.";
    echo -e "--- Look over all files in the root of this backup and set options before deploying this script.";
    echo -e "\nPress any key to continue.";
    read pause;

#Check $standarduser and $phpversion variable values.
    echo -e "\nThe standard user variable value is '$standarduser' and PHP is $phpversion. Continue? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        echo -e "\nContinuing as $standarduser with PHP $phpversion.";
    else exit;
    fi

# Open UFW ports
    echo -e "\nAre there any ports to open on UFW? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        echo -e "\nSpecify a space delimited list of ports. Example 65022 65080 65443";
        read ports;
        portsArr=(${ports})
        for port in "${portsArr[@]}"
            do
                ufw allow $port;
            done
    fi

# Execute commands in precommands.csv
    echo -e "\nExecute commands in precommands.csv [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        while read -r command
        do
            echo -e "#/bin/bash" > temp.sh;
            echo -e $command >> temp.sh;
            chmod 770 temp.sh;
            source ./temp.sh;
            rm temp.sh;
        done < precommands.csv
    fi

# Create another user and make sudoer if desired
    echo -e "\nWould you like to create another Unix user? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        echo -e "\nWhat is the new user's username? ";
        read newuser;
        mkdir "/home/$newuser";
        useradd -d "/home/$newuser" $newuser;
        chmod 770 "/home/$newuser";
        chown $newuser:$newuser "/home/$newuser";
        passwd $newuser;
        
        echo -e "\nShould $newuser be a sudoer? [y/n] ";
        read answer;
        if [ $answer == "y" ]; then
            usermod -aG sudo $newuser;
        fi
    fi

# Create important directories
    echo -e "\nCreate the directories listed in important_dir.csv? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        while IFS="," read -r path permission owner
        do
            mkdir -p $path;
            chmod -R $permission $path;
            chown -R $owner $path; 
        done < important_dir.csv
    fi

# Mount external disk at startup
    echo -e "\nWould you like to mount an already partitioned and formatted external disk at startup? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        echo -e "\nWhat is the full path of the local directory on which you would like to mount the disk? ";
        read localdir;
        if [ ! -d "$localdir" ]; then
            mkdir -p $localdir;
        fi

        echo -e "\n";
        ls -l /dev | grep disk;
        echo -e "\nSee output above. What is the full /dev path to the disk? ";
        read devpath;

        echo -e "\n";
        blkid
        echo -e "\nCopy the UUID, without quotes, from the output above and press ENTER: ";
        read uuid;

        echo "UUID=$uuid $localdir ext4 defaults 0 0" >> /etc/fstab;
        echo -e "\nMount it now? [y/n] ";
        read answer;
        if [ $answer == "y" ]; then
            mount $devpath $localdir;
        fi
    fi

# Give standard user onwership of /var/local
    echo -e "\nGive $standarduser ownership of /var/local? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        chmod -R 770 /var/local;
        chown -R $standarduser:$standarduser /var/local;
    fi

# Configure SSH
    echo -e "\nWould you like to run SSH on a port other than 22? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        echo -e "\nOn what port would you like to run SSH? ";
        read sshport;
        findport="#Port 22";
        replaceport="Port $sshport";

        mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bak;
        touch /etc/ssh/sshd_config;

        while IFS='' read -r line
        do
            if [[ "$line" == *"$findport"* ]]; then
                echo $replaceport >> /etc/ssh/sshd_config;
            else
                echo $line >> /etc/ssh/sshd_config;
            fi 
        done < /etc/ssh/sshd_config.bak
    fi

    echo -e "\nWould you like to restrict SSH to only certain IPs? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        echo -e "Specify a comma separated list of IPs and networks that will be able to access this server via ssh. Example: 10.0.1.0/24,10.0.0.4 ";
        read sshpermit;
        echo "sshd: $sshpermit" >> /etc/hosts.allow
        echo "sshd: ALL" >> /etc/hosts.deny
    fi

# Install Samba
    echo -e "\nInstall Samba? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        apt-get -y install samba;
        echo -e "\nSetting password for $standarduser: ";
        smbpasswd -a $standarduser;
        
        echo -e "\nWould you like to set a Samba password for another user? [y/n] ";
        read answer;
        if [ $answer == "y" ]; then
            echo -e "\nWhat is the name of the user for which you would like to set a Samba password? ";
            read newsmbpwd;
            smbpasswd -a $newsmbpwd;
        fi

        echo -e "\nWould you like to create Samba shares for /var/www and /var/local? [y/n]";
        read answer;
        if [ $answer == "y" ]; then

            echo -e "\nSpecify a space delimited list of users who can access the shares: ";
            read smbusers;
            echo -e "\nSpecify a space delimited list of hosts and networks that can access the shares. Example: 10.0.1.0/24 10.0.0.4 ";
            read smbhosts;

            echo -e "[local]" >> /etc/samba/smb.conf
            echo -e "  comment = local directory" >> /etc/samba/smb.conf
            echo -e "  browseable = yes" >> /etc/samba/smb.conf
            echo -e "  path = /var/local" >> /etc/samba/smb.conf
            echo -e "  guest ok = no" >> /etc/samba/smb.conf
            echo -e "  read only = no" >> /etc/samba/smb.conf
            echo -e "  create mask = 0660" >> /etc/samba/smb.conf
            echo -e "  directory mask = 0770" >> /etc/samba/smb.conf
            echo -e "  valid users = $smbusers" >> /etc/samba/smb.conf
            echo -e "  hosts allow = $smbhosts" >> /etc/samba/smb.conf

            echo -e "\n[www]" >> /etc/samba/smb.conf
            echo -e "  comment = www directory" >> /etc/samba/smb.conf
            echo -e "  browseable = yes" >> /etc/samba/smb.conf
            echo -e "  path = /var/www" >> /etc/samba/smb.conf
            echo -e "  guest ok = no" >> /etc/samba/smb.conf
            echo -e "  read only = no" >> /etc/samba/smb.conf
            echo -e "  create mask = 0664" >> /etc/samba/smb.conf
            echo -e "  directory mask = 0775" >> /etc/samba/smb.conf
            echo -e "  valid users = $smbusers" >> /etc/samba/smb.conf
            echo -e "  hosts allow = $smbhosts" >> /etc/samba/smb.conf
        fi
    fi

# Install Apache
    echo -e "\nInstall Apache? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        apt-get -y install apache2;
        a2enmod ssl;
        service apache2 restart;
        a2ensite default-ssl;
        service apache2 restart;
        chown -R $standarduser:$standarduser /var/www;

        mv /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf.bak2;
        mv /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.bak2;

        finddocroot="DocumentRoot /var/www/html";
        replacedocroot="        DocumentRoot /var/www";

        while IFS='' read -r line
        do
            if [[ "$line" == *"$finddocroot"* ]]; then
                echo $replacedocroot >> /etc/apache2/sites-available/default-ssl.conf;
            else
                echo $line >> /etc/apache2/sites-available/default-ssl.conf;
            fi 
        done < /etc/apache2/sites-available/default-ssl.conf.bak2

        while IFS='' read -r line
        do
            if [[ "$line" == *"$finddocroot"* ]]; then
                echo $replacedocroot >> /etc/apache2/sites-available/000-default.conf;
            else
                echo $line >> /etc/apache2/sites-available/000-default.conf;
            fi 
        done < /etc/apache2/sites-available/000-default.conf.bak2

        echo -e "\nWould you like to run HTTP and HTTPS on a ports other than 80 and 443? [y/n] ";
        read answer;
        if [ $answer == "y" ]; then
            echo -e "\nOn what port would you like to run HTTP? ";
            read httpport;
            echo -e "\nOn what port would you like to run HTTPS? ";
            read httpsport;

            mv /etc/apache2/ports.conf /etc/apache2/ports.conf.bak;

            echo -e "Listen $httpport" > /etc/apache2/ports.conf;
            echo -e "<IfModule ssl_module>" >> /etc/apache2/ports.conf;
            echo -e "	Listen $httpsport" >> /etc/apache2/ports.conf;
            echo -e "</IfModule>" >> /etc/apache2/ports.conf;
            echo -e "<IfModule mod_gnutls.c>" >> /etc/apache2/ports.conf;
            echo -e "	Listen $httpsport" >> /etc/apache2/ports.conf;
            echo -e "</IfModule>" >> /etc/apache2/ports.conf;

            mv /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf.bak;
            mv /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.bak;

            findhttp="<VirtualHost *:80>";
            replacehttp="<VirtualHost *:$httpport>";
            findhttps="<VirtualHost *:443>";
            replacehttps="<VirtualHost *:$httpsport>";

            while IFS='' read -r line
            do
                if [[ "$line" == *"$findhttps"* ]]; then
                    echo $replacehttps >> /etc/apache2/sites-available/default-ssl.conf;
                else
                    echo $line >> /etc/apache2/sites-available/default-ssl.conf;
                fi 
            done < /etc/apache2/sites-available/default-ssl.conf.bak

            while IFS='' read -r line
            do
                if [[ "$line" == *"$findhttp"* ]]; then
                    echo $replacehttp >> /etc/apache2/sites-available/000-default.conf;
                else
                    echo $line >> /etc/apache2/sites-available/000-default.conf;
                fi 
            done < /etc/apache2/sites-available/000-default.conf.bak

        fi
    fi

# Generate a self-signed TLS certificate for web traffic
    echo -e "\nGenerate a self-signed TLS certificate for web traffic? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        echo -e "\nYou will be prompted for a certificate password, type one even if you don't want one.";
        echo -e "What do you want to name the certificate? Recommendation: mycert: ";
        read certname;
        openssl genrsa -des3 -out $certname.key 4096;
        openssl req -new -key $certname.key -out $certname.csr;
        openssl x509 -req -days 9999 -in $certname.csr -signkey $certname.key -out $certname.crt;
        openssl rsa -in $certname.key -out $certname.key.new;
        mv $certname.key.new $certname.key;
        rm $certname.csr;
        
        mv $certname.crt /etc/ssl/certs;
        mv $certname.key /etc/ssl/private;
        chmod 640 "/etc/ssl/private/$certname.key";
        chgrp ssl-cert "/etc/ssl/private/$certname.key";

        echo -e "\n$certname.cer copied to /etc/ssl/certs.";
        echo -e "$certname.key copied to /etc/ssl/private.";

        echo -e "\nIf default-ssl.conf is at it's defaults referencing the snakeoil certs, this script can update it.";
        echo -e "Change default-ssl.conf to reference the new certificate? [y/n] ";
        read answer;
        if [ $answer == "y" ]; then
            findcert="/etc/ssl/certs/ssl-cert-snakeoil.pem";
            replacecert="	SSLCertificateFile      /etc/ssl/certs/mycert.crt";
            findkey="/etc/ssl/private/ssl-cert-snakeoil.key";
            replacekey="	SSLCertificateKeyFile   /etc/ssl/private/mycert.key";

            mv /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf.bak;
            touch /etc/apache2/sites-available/default-ssl.conf;

            while IFS='' read -r line
            do
                if [[ "$line" == *"$findcert"* ]]; then
                    echo $replacecert >> /etc/apache2/sites-available/default-ssl.conf;
                elif [[ "$line" == *"$findkey"* ]]; then
                    echo $replacekey >> /etc/apache2/sites-available/default-ssl.conf;
                else
                    echo $line >> /etc/apache2/sites-available/default-ssl.conf;
                fi 
            done < /etc/apache2/sites-available/default-ssl.conf.bak
        fi

        echo -e "\nOpen /etc/apache2/sites-available/default-ssl.conf to make sure the certificate path is correct? [y/n] ";
        read answer;
        if [ $answer == "y" ]; then
            nano /etc/apache2/sites-available/default-ssl.conf;
        fi

        echo -e "\nRestart Apache? [y/n]";
        read answer;
        if [ $answer == "y" ]; then
            service apache2 restart;
        fi
    fi

# Install PHP
    echo -e "\nInstall PHP? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        apt-get -y install php;
        apt-get -y install php$phpversion-ldap;
    fi

# Install MySQL
    echo -e "\nInstall MySQL? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        apt-get -y install mysql-server;
        apt-get install python3-mysql.connector;

        echo -e "\nWhat do you want to use for a MySQL admin username? ";
        read mysqluser;
        echo -e "\nType a MySQL password for $mysqluser";
        read -s mysqlpass;

        mysql --user=root mysql -e "CREATE USER '$mysqluser'@'localhost' IDENTIFIED BY '$mysqlpass';";
        mysql --user=root mysql -e "GRANT ALL PRIVILEGES ON *.* TO '$mysqluser'@'localhost' WITH GRANT OPTION;";
        mysql --user=root mysql -e "FLUSH PRIVILEGES;";

        mysql --user=root mysql -e "set persist local_infile = 1;";

        echo -e "\nType a username for a PHP / Python MySQL user? Recommended: mysqlappadmin";
        read php_mysqluser;
        echo -e "\nType a MySQL password for $php_mysqluser";
        read -s php_mysqlpass;

        mysql --user=root mysql -e "CREATE USER '$php_mysqluser'@'localhost' IDENTIFIED BY '$php_mysqlpass';";

        echo -e "\nType a username for a CLI MySQL user? Recommended: mysqlcliadmin";
        read cli_mysqluser;
        echo -e "\nType a MySQL password for $cli_mysqluser";
        read -s cli_mysqlpass;

        mysql --user=root mysql -e "CREATE USER '$cli_mysqluser'@'localhost' IDENTIFIED BY '$cli_mysqlpass';";
        mysql --user=root mysql -e "GRANT PROCESS ON *.* TO '$cli_mysqluser'@'localhost';";

        echo -e "\nWould you like to import the MySQL databases in mysqldbs.csv? [y/n] ";
        read answer;
        if [ $answer == "y" ]; then
            while read -r mysqldb
            do
                mysql --user=root mysql -e "create database $mysqldb";
                cat ../$mysqldb.sql | mysql -D $mysqldb --user=root;

                mysql --user=root mysql -e "GRANT SELECT,INSERT,UPDATE,DELETE ON $mysqldb.* TO '$php_mysqluser'@'localhost';";
                mysql --user=root mysql -e "GRANT LOCK TABLES,SELECT,INSERT,UPDATE,DELETE ON $mysqldb.* TO '$cli_mysqluser'@'localhost';";
                mysql --user=root mysql -e "FLUSH PRIVILEGES;";

            done < mysqldbs.csv
        fi

        rm -rf /var/cons;
        mkdir /var/cons;
        chmod 775 /var/cons;
        chown $standarduser:$standarduser /var/cons;

        echo -e "<?php" > "/var/cons/inc-db.php";
        echo -e "\$servername = 'localhost';" >> "/var/cons/inc-db.php";
        echo -e "\$username = '$php_mysqluser';" >> "/var/cons/inc-db.php";
        echo -e "\$password = '$php_mysqlpass';" >> "/var/cons/inc-db.php";
        echo -e "\$con = new mysqli(\$servername, \$username, \$password, \$db);" >> "/var/cons/inc-db.php";
        echo -e "if (\$con->connect_error) {die(\"Connection failed: \" . \$con->connect_error);}" >> "/var/cons/inc-db.php";
        echo -e "?>" >> "/var/cons/inc-db.php";

        echo -e "#!/bin/bash" > "/var/cons/inc-db.sh";
        echo -e "mysqluser='$cli_mysqluser';" >> "/var/cons/inc-db.sh";
        echo -e "mysqlpass='$cli_mysqlpass';" >> "/var/cons/inc-db.sh";

        echo -e "#!/usr/bin/python3" > "/var/cons/incdb.py";
        echo -e "import mysql.connector;" > "/var/cons/incdb.py";
        echo -e "con = mysql.connector.connect(user='$php_mysqluser', password='$php_mysqlpass', host='localhost', database='\$db', ssl_disabled=True);" > "/var/cons/incdb.py";

        chmod 640 "/var/cons/inc-db.sh";
        chmod 640 "/var/cons/inc-db.php";
        chmod 640 "/var/cons/incdb.py";
        chown $standarduser:www-data "/var/cons/inc-db.php";
        chown $standarduser:$standarduser "/var/cons/inc-db.sh";
        chown $standarduser:$standarduser "/var/cons/incdb.py";
    fi

#######################Python CRUD script
#!/usr/bin/python3

    # import mysql.connector;
    # import sys;
    # sys.path.insert(1, '/var/cons');
    # import incdb;

    # mysql_query = incdb.con.cursor();

    ##### Create
    # mysql_query.execute("INSERT INTO jobitable (jobifield1, jobifield2) VALUES ('insert into field1a', 'insert into field2a')");

    # ##### Update
    # mysql_query.execute("UPDATE mytable SET myfield = 'Updated myfield1' WHERE id = 7");

    # ##### Read
    # mysql_query.execute("SELECT * FROM testtable1");
    # records = mysql_query.fetchall();

    # for rec in records:
    #     print(str(rec[1]));
    #     print(str(rec[2]));
    
    # ##### Read One
    # mysql_query.execute("SELECT myfield FROM mytable WHERE id = 8");
    # record = mysql_query.fetchone();

    # print(record[0]);
    
    # ##### Delete
    # mysql_query.execute("DELETE FROM mytable WHERE id > 0");

    # incdb.con.commit();incdb.con.close();


# Install PHPMyAdmin
    echo -e "\nInstall PHPMyAdmin? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        apt-get -y install phpmyadmin;
        echo -e "Would you like to restrict PHPMyAdmin to a specific network? [y/n] ";
        read answer;
        if [ $answer == "y" ]; then
            echo -e "What network should be allowed to access PHPMyAdmin. For example, 10.0.0.0/255.255.255.0: ";
            read phpmyadminpermit;
            echo -e "\n<Directory /usr/share/phpmyadmin>" >> /etc/apache2/apache2.conf;
            echo -e "        AllowOverride None" >> /etc/apache2/apache2.conf;
            echo -e "        Require all granted" >> /etc/apache2/apache2.conf;
            echo -e "        Order Deny,Allow" >> /etc/apache2/apache2.conf;
            echo -e "        Deny from all" >> /etc/apache2/apache2.conf;
            echo -e "        Allow from 127.0.0.1" >> /etc/apache2/apache2.conf;
            echo -e "        Allow from $phpmyadminpermit" >> /etc/apache2/apache2.conf;
            echo -e "</Directory>" >> /etc/apache2/apache2.conf;
        fi
    fi

# Restore files and directories
    echo -e "\nRestore files and directories specified in backup_files.csv? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        while IFS="," read -r type path name permission owner
        do
        if [ $type == "d" ]; then
            cp -R "../$name" "$path";
            chown -R $owner "$path/$name";
            permissionArr=(${permission});
            find "$path/$name" -type d -print0 | xargs -I {} -0 chmod "0${permissionArr[0]}" {}
            find "$path/$name" -type f -print0 | xargs -I {} -0 chmod "0${permissionArr[1]}" {}
        elif [ $type == "f" ]; then
            cp "../$name" $path;
            chmod $permission "$path/$name";
            chown $owner "$path/$name";   
        fi
        done < backup_files.csv
    fi

# Restore file permissions
    echo -e "\nRestore file permissions specified in file_permissions.csv? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        while IFS="," read -r path permission owner
        do
            chown $owner $path;
            chmod $permission $path;
        done < file_permissions.csv
    fi

# Restore crontabs
    echo -e "\nRestore crontabs specified in crontabs.csv? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        while read -r user
        do
            crontab -u $user "../crontab_$user.txt";
        done < crontabs.csv
    fi

# Restart Samba and Apache
    echo -e "\nRestart Samba and Apache? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        service apache2 restart;
        service samba restart;
    fi

# Install MUTT
    echo -e "\nInstall Mutt? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        # apt-get -y install mutt;

        echo -e "\n....................................................................................................................";
        echo -e "\nMUTT will be setup to work with a Gmail account. If you are using another provider, you can tweak the settings later.";
        echo -e "\nType the portion of the sending gmail address before the @. In other words, do not write the @gmail.com part.";
        read sender_email;

        echo -e "\nYou can generate an app specific password at https://myaccount.google.com/apppasswords";
        echo -e "Your app specific password should have no spaces in it.";
        echo -e "You will not see the app sepecific password as you type it or paste it.";
        echo -e "What is the app specific password? ";

        read -s sender_app_pass;

        echo -e "\nWhat is the sender's display name?";
        read sender_display_name;

        echo -e "\nWhat is the name of the unix user who will be sending emails? Example: tony";
        read unix_emailer;
        echo -e "\nWhat is the name of the unix group that will be sending emails? Recommended: www-data";
        read unix_group;
        echo -e "\nWhat is the MUTT home directory? Recommended: /var/cons";
        read mutthome;

        echo "set ssl_force_tls=yes" > "$mutthome/muttrc";
        echo "set realname='$sender_display_name'" >> "$mutthome/muttrc";
        echo "set from='$sender_email@gmail.com'" >> "$mutthome/muttrc";
        echo "set smtp_url='smtps://$sender_email@smtp.gmail.com'" >> "$mutthome/muttrc";
        echo "set smtp_pass='$sender_app_pass'" >> "$mutthome/muttrc";

        chmod 660 "$mutthome/muttrc";
        chown $unix_emailer:$unix_group "$mutthome/muttrc";
    
        echo "echo \"\$3\" | /usr/bin/mutt -s \"\$2\" -F $mutthome/muttrc \"\$1\"" > $mutthome/muttsend.sh;
        echo -e "\n";
        echo -e "# To use this script from BASH, type $mutthome/muttsend.sh recipeint@gmail.com 'subject' 'body'" >> $mutthome/muttsend.sh;
        echo -e "# For example: sudo -u tony $mutthome/muttsend.sh tony@me.com 'Test Submect' 'Test message.'" >> $mutthome/muttsend.sh;
        
        chmod 770 $mutthome/muttsend.sh;
        chown $unix_emailer:$unix_group $mutthome/muttsend.sh;

        echo -e "\nA script for sending email was placed in $mutthome/muttsend.sh";
        echo -e "Nano the script for instructions on how to use.";

        echo -e "\nSend a test email? [y/n]";
        read answer;
        if [ $answer == "y" ]; then
            echo -e "\nWhat address should receive the email?";
            read recipient;
            sudo -u $unix_emailer $mutthome/muttsend.sh "$recipient" "Test from muttsend.sh" "It worked";
        fi
        echo -e "\nLook at the code of this script for information on how to use MUTT with PHP and Python.";
    fi

##### Using the muttsend.sh script via PHP
    # <?php
    # echo "You must execute this script as the user for whom MUTT was configured.";
    # $notify_script = "/var/cons/muttsend.sh";
    # $notify_recipients = "me@yahoo.com";
    # $notify_subject = "TheSubject2";
    # $message = "TheBody2";
    # exec("{$notify_script} {$notify_recipients} '{$notify_subject}' '{$message}'");
    # ?>

    ##### Using the muttsend.sh script via Python
    # #!/usr/bin/env python3
    # import subprocess;
    # notify_script = "sudo -u tony /var/cons/muttsend.sh";
    # notify_recipients = "me@gmail.com";
    # notify_subject = "This is the subject.";
    # message = "This is the message";
    # subprocess.call(notify_script+" '"+notify_recipients+"' '"+notify_subject+"' '"+message+"'",shell=True);


# Execute commands in postcommands.csv
    echo -e "\nExecute commands in postcommands.csv? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        while read -r command
        do
            echo -e "#/bin/bash" > temp.sh;
            echo -e $command >> temp.sh;
            chmod 770 temp.sh;
            source ./temp.sh;
            rm temp.sh;
        done < postcommands.csv
    fi

#Create an HTAccess Directory
    echo -e "\nWould you like to create an HTAccess directory? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        echo -e "\nWhat is the path to the directory that you want to protect? Example: /var/www/private";
        read htpath;
        echo -e "\nWhat do you want to use for htpassword file name? Example: htpasswd ";
        read htfile;
        echo -e "\nWhat do you want to use for a username? ";
        read htuser;
        
        mkdir -p $htpath;
        chmod 755 $htpath;
        chown $standarduser:$standarduser $htpath;

        htpasswd -c /var/cons/$htfile $htuser;
        chmod 640 /var/cons/$htfile;
        chown $standarduser:www-data /var/cons/$htfile;

        echo -e "AuthName 'Private'" > $htpath/.htaccess;
        echo -e "AuthType Basic" >> $htpath/.htaccess;
        echo -e "AuthUserFile /var/cons/$htfile" >> $htpath/.htaccess;
        echo -e "require valid-user" >> $htpath/.htaccess;
        chmod 640 $htpath/.htaccess;
        chown $standarduser:www-data $htpath/.htaccess;

        echo -e "\n<Directory $htpath>" >> /etc/apache2/apache2.conf;
        echo -e "        Options Indexes FollowSymLinks" >> /etc/apache2/apache2.conf;
        echo -e "        AllowOverride All" >> /etc/apache2/apache2.conf;
        echo -e "        Require all granted" >> /etc/apache2/apache2.conf;
        echo -e "</Directory>" >> /etc/apache2/apache2.conf;

        service apache2 restart;
    fi

# Remove history
    history -c && history -w;
    unset HISTFILE;
    rm /root/.bash_history;

# Final Notes
    echo -e "\n..............................FINAL NOTES................";
    echo -e "--- Test MUTT and the connection to the DB for PHP, Python, and BASH.";
    echo -e "--- Test the database connection at http://ipaddress/misc/testdb.php";
    echo -e "--- Make sure the database is backing up and time is correct.";
    echo -e "--- Get the /var/local/externaldisk/remotebackup folder backing up offsite.";
    
# Restart the server
    echo -e "\nYou might need to restart for some setting to take affect. Restart? [y/n] ";
    read answer;
    if [ $answer == "y" ]; then
        shutdown -r now;
    fi
