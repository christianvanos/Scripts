#!/bin/bash

##############################
## made by Christian van Os ##
##############################

######## Variables ########

EXIT=false;
PHP_version='7.4';
MX_subdomain='mail';
WEBMAIL_subdomain='webmail';
POSTFIXADMIN_subdomain='postfixadmin';

######## Passwords ########

DB_postfixadmin="abcde"; DB_postfixadmin+=$(date +%s | sha224sum | base64 | head -c 15); DB_postfixadmin+="012"
ADMIN_postfixadmin="fghij"; ADMIN_postfixadmin+=$(date +%s | sha256sum | base64 | head -c 15); ADMIN_postfixadmin+="345";
ADMIN_webmail="klmno"; ADMIN_webmail+=$(date +%s | sha384sum | base64 | head -c 15); ADMIN_webmail+="678";
ADMIN_rainloop="pqrst"; ADMIN_rainloop+=$(date +%s | sha384sum | base64 | head -c 15); ADMIN_rainloop+="901";

######## Arguments ########

while getopts ":d:k:i:v:m:w:p:" opt; do
	case $opt in 
		d) DOMAIN="$OPTARG";;			# HOST DOMAIN		REQUIRED!
		i) IP_address="$OPTARG";;		# TARGET PUBLIC IP	REQUIRED!
		v) PHP_version="$OPTARG";;		# PHP VERSION
		m) MX_subdomain="$OPTARG";;		# MX SUBDOMAIN
		w) WEBMAIL_subdomain="$OPTARG";;	# WEBMAIL SUBDOMAIN
		p) POSTFIXADMIN_subdomain="$OPTARG";;	# POSTFIXADMIN SUBDOMAIN
		\?) echo "Invalid option -$OPTARG" >&2; exit 1;;
		:) echo "Missing option argument for -$OPTARG">&2; exit 1;; 
		*) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
	esac
done


if [[ $DOMAIN == '' ]]; then echo "-d flag is missing (domain)"; EXIT=true; fi
if [[ $IP_address == '' ]]; then echo "-i flag is missing (target ip addr)"; EXIT=true; fi
if [[ $EXIT == true ]]; then exit 1; fi

######### Functions  ########

pw() {
	sudo printf "DATABASE\npostfixadmin => $DB_postfixadmin\n\n" > ./pw-mail
	sudo printf "POSTFIXADMIN\nadmin@$DOMAIN => $ADMIN_postfixadmin\n\n" >> ./pw-mail
	sudo printf "WEBMAIL\nadmin@$DOMAIN => $ADMIN_webmail\n\n" >> ./pw-mail
	sudo printf "WEBMAIL ADMIN\nadmin => $ADMIN_rainloop\n\n" >> ./pw-mail
}

pre-records-dns() {
	echo "Add the following dns records if they don't exists:";
	echo "| TYPE | VALUE					| NAME";
	echo "|  A   | $IP_address   			| $MX_subdomain.$DOMAIN";
	echo "|  A   | $IP_address   			| $WEBMAIL_subdomain.$DOMAIN";
	echo "|  A   | $IP_address   			| $POSTFIXADMIN_subdomain.$DOMAIN";
	echo "| MX   | 10 $MX_subdomain.$DOMAIN		| $DOMAIN";
	echo "| TXT  | v=spf1 a mx ip4:$IP_address -all	| $DOMAIN";
}

update-upgrade() {
	sudo apt-get -y update && apt-get -y upgrade;
	sudo apt-get -y install software-properties-common;
	sudo add-apt-repository -y ppa:ondrej/php;
	sudo add-apt-repository -y ppa:certbot/certbot;
	sudo apt-get -y update && apt-get -y upgrade;
	
	sudo service sendmail stop;
	sudo update-rc.d -f sendmail remove;
}

apt-get-install() {
	sudo apt-get install -y software-properties-common lsb-release;
	sudo apt-get install -y apache2 apache2-utils libapache2-mod-php${PHP_version} \
				mariadb-server;
	sudo apt-get install -y php${PHP_version} php${PHP_version}-fpm \
				php${PHP_version}-cli php${PHP_version}-imap \
				php${PHP_version}-json php${PHP_version}-mysql \
				php${PHP_version}-opcache php${PHP_version}-mbstring \
				php${PHP_version}-readline php${PHP_version}-common \
				php${PHP_version}-curl php${PHP_version}-zip \
				php${PHP_version}-xml php${PHP_version}-bz2 \
				php${PHP_version}-intl php${PHP_version}-gmp;
	sudo apt-get install -y certbot python3-certbot-apache;
	sudo debconf-set-selections <<< "postfix postfix/mailname string $MX_subdomain.$DOMAIN"
	sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
	sudo apt-get install -y postfix postfix-mysql dovecot-imapd \
				dovecot-lmtpd dovecot-pop3d dovecot-mysql;
	
	sudo a2enmod php${PHP_version};
	sudo systemctl restart apache2;

	sudo tar xzf mail.tar.gz;	
	sudo sed -i "s/your_secret_password/$DB_postfixadmin/g" config.local.php;
	sudo sed -i "s/example.com/$DOMAIN/g" config.local.php;
	sudo sed -i "s/example.com/$DOMAIN/g" mail.example.com.conf;	
	sudo sed -i "s/example.com/$DOMAIN/g" webmail.example.com.conf;
	sudo sed -i "s/example.com/$DOMAIN/g" postfixadmin.example.com.conf;
	sudo sed -i "s/mail/$MX_subdomain/g" mail.example.com.conf;
	sudo sed -i "s/webmail/$WEBMAIL_subdomain/g" webmail.example.com.conf;
	sudo sed -i "s/postfixadmin/$POSTFIXADMIN_subdomain/g" postfixadmin.example.com.conf;
	sudo sed -i "s/your_secret_password/$DB_postfixadmin/g" mysql_virtual_domains_maps.cf;
	sudo sed -i "s/your_secret_password/$DB_postfixadmin/g" mysql_virtual_alias_maps.cf;
	sudo sed -i "s/your_secret_password/$DB_postfixadmin/g" mysql_virtual_alias_domain_catchall_maps.cf;
	sudo sed -i "s/your_secret_password/$DB_postfixadmin/g" mysql_virtual_alias_domain_maps.cf;
	sudo sed -i "s/your_secret_password/$DB_postfixadmin/g" mysql_virtual_mailbox_maps.cf;
	sudo sed -i "s/your_secret_password/$DB_postfixadmin/g" mysql_virtual_alias_domain_mailbox_maps.cf;
	sudo sed -i "s/your_secret_password/$DB_postfixadmin/g" dovecot-sql.conf.ext;
	sudo sed -i "s/example.com/$DOMAIN/g" 10-ssl.conf;
	sudo sed -i "s/mail/$MX_subdomain/g" 10-ssl.conf;
	sudo sed -i "s/example.com/$DOMAIN/g" 20-lmtp.conf;
	sudo sed -i "s/your_secret_password/$DB_postfixadmin/g" dovecot-dict-sql.conf.ext;
	sudo sed -i "s/example.com/$DOMAIN/g" quota-warning.sh;
	sudo sed -i "s/your_secret_password/$ADMIN_rainloop/g" rainloop.php
	sudo sed -i "s/example.com/$DOMAIN/g" rainloop.php
	sudo sed -i "s/webmail/$WEBMAIL_subdomain/g" rainloop.php
	sudo sed -i "s/mail/$MX_subdomain/g" example.com.ini
	sudo sed -i "s/example.com/$DOMAIN/g" example.com.ini
}

secure-mysql() {
	sudo mysql -u root -e "DELETE FROM mysql.user WHERE User='';";
	sudo mysql -u root -e "DROP DATABASE IF EXISTS test;";
	sudo mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';";
	sudo mysql -u root -e "FLUSH PRIVILEGEs;";

	sudo mysql -u root -e "CREATE DATABASE postfixadmin;";
	sudo mysql -u root -e "GRANT ALL ON postfixadmin.* TO 'postfixadmin'@'localhost' IDENTIFIED BY '$DB_postfixadmin';";
	sudo mysql -u root -e "FLUSH PRIVILEGES;";
}

apache() {
	# Mail
	sudo mkdir -p /var/www/$MX_subdomain.$DOMAIN;
	sudo chown -R www-data: /var/www/$MX_subdomain.$DOMAIN;
	sudo mv mail.example.com.conf /etc/apache2/sites-available/$MX_subdomain.$DOMAIN.conf;
	sudo a2ensite $MX_subdomain.$DOMAIN.conf;

	# Webmail
	sudo mkdir -p /var/www/$WEBMAIL_subdomain.$DOMAIN;
	sudo chown -R www-data: /var/www/$WEBMAIL_subdomain.$DOMAIN;
	sudo mv ./webmail.example.com.conf /etc/apache2/sites-available/$WEBMAIL_subdomain.$DOMAIN.conf;
	sudo a2ensite $WEBMAIL_subdomain.$DOMAIN.conf;

	# Postfixadmin
	sudo mkdir -p /var/www/$POSTFIXADMIN_subdomain.$DOMAIN;
	sudo chown -R www-data: /var/www/$POSTFIXADMIN_subdomain.$DOMAIN;
	sudo mv ./postfixadmin.example.com.conf /etc/apache2/sites-available/$POSTFIXADMIN_subdomain.$DOMAIN.conf;
	sudo a2ensite $POSTFIXADMIN_subdomain.$DOMAIN.conf;
	
	# CERTBOT
	sudo systemctl reload apache2.service;
	sudo certbot --apache --agree-tos --no-eff-email --redirect --hsts --staple-ocsp --email admin@$DOMAIN -d $MX_subdomain.$DOMAIN;
	sudo certbot --agree-tos --no-eff-email --redirect --hsts --staple-ocsp --email admin@$DOMAIN -d $WEBMAIL_subdomain.$DOMAIN;
	sudo certbot --agree-tos --no-eff-email --redirect --hsts --staple-ocsp --email admin@$DOMAIN -d $POSTFIXADMIN_subdomain.$DOMAIN;
	sudo systemctl reload apache2.service;

	sudo crontab -l > ./mycron;
	sudo echo "30 3 * * * /usr/bin/certbot renew  >> /var/log/le-renewal.log" >> ./mycron;
	sudo crontab ./mycron;
	sudo rm ./mycron;
}

postfixadmin() {
	# USER VMAIL
	sudo groupadd -g 5000 vmail;
	sudo useradd -u 5000 -g vmail -s /usr/sbin/nologin -d /var/mail/vmail -m vmail;

	# POSTFIXADMIN
	sudo mv postfixadmin-3.2/* /var/www/$POSTFIXADMIN_subdomain.$DOMAIN;
	sudo mv postfixadmin-3.2/.* /var/www/$POSTFIXADMIN_subdomain.$DOMAIN;
	sudo rm -f postfixadmin-3.2.tar.gz;
	sudo mkdir /var/www/$POSTFIXADMIN_subdomain.$DOMAIN/templates_c;
	sudo chown -R www-data: /var/www/$POSTFIXADMIN_subdomain.$DOMAIN;

	sudo mv config.local.php /var/www/$POSTFIXADMIN_subdomain.$DOMAIN/;
	sudo -u www-data php /var/www/$POSTFIXADMIN_subdomain.$DOMAIN/public/upgrade.php;

	sudo printf "admin@$DOMAIN\n$ADMIN_postfixadmin\n$ADMIN_postfixadmin\ny\n$DOMAIN\ny" | sudo bash /var/www/$POSTFIXADMIN_subdomain.$DOMAIN/scripts/postfixadmin-cli admin add;
	sudo printf "$DOMAIN\n\n0\n0\n0\n0\nn\ny\ny" | bash /var/www/$POSTFIXADMIN_subdomain.$DOMAIN/scripts/postfixadmin-cli domain add;
	sudo printf "admin@$DOMAIN\n$ADMIN_webmail\n$ADMIN_webmail\nadmin\n0\ny\ny\n\n" |  bash /var/www/$POSTFIXADMIN_subdomain.$DOMAIN/scripts/postfixadmin-cli mailbox add;

	sudo rm -r postfixadmin-3.2;
}

postfix() {
	sudo mkdir -p /etc/postfix/sql;

	sudo mv mysql_virtual_domains_maps.cf /etc/postfix/sql/mysql_virtual_domains_maps.cf;
	sudo mv mysql_virtual_alias_maps.cf /etc/postfix/sql/mysql_virtual_alias_maps.cf;
	sudo mv mysql_virtual_alias_domain_catchall_maps.cf /etc/postfix/sql/mysql_virtual_alias_domain_catchall_maps.cf;
	sudo mv mysql_virtual_alias_domain_maps.cf /etc/postfix/sql/mysql_virtual_alias_domain_maps.cf;
	sudo mv mysql_virtual_mailbox_maps.cf /etc/postfix/sql/mysql_virtual_mailbox_maps.cf;
	sudo mv mysql_virtual_alias_domain_mailbox_maps.cf  /etc/postfix/sql/mysql_virtual_alias_domain_mailbox_maps.cf;

	sudo postconf -e "virtual_mailbox_domains = mysql:/etc/postfix/sql/mysql_virtual_domains_maps.cf";
	sudo postconf -e "virtual_alias_maps = mysql:/etc/postfix/sql/mysql_virtual_alias_maps.cf, mysql:/etc/postfix/sql/mysql_virtual_alias_domain_maps.cf, mysql:/etc/postfix/sql/mysql_virtual_alias_domain_catchall_maps.cf";
	sudo postconf -e "virtual_mailbox_maps = mysql:/etc/postfix/sql/mysql_virtual_mailbox_maps.cf, mysql:/etc/postfix/sql/mysql_virtual_alias_domain_mailbox_maps.cf";

	sudo postconf -e "virtual_transport = lmtp:unix:private/dovecot-lmtp";
	sudo postconf -e 'smtp_tls_security_level = may';
	sudo postconf -e 'smtpd_tls_security_level = may';
	sudo postconf -e 'smtp_tls_note_starttls_offer = yes';
	sudo postconf -e 'smtpd_tls_loglevel = 1';
	sudo postconf -e 'smtpd_tls_received_header = yes';
	sudo postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/$MX_subdomain.$DOMAIN/fullchain.pem";
	sudo postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/$MX_subdomain.$DOMAIN/privkey.pem";

	sudo postconf -e 'smtpd_sasl_type = dovecot';
	sudo postconf -e 'smtpd_sasl_path = private/auth';
	sudo postconf -e 'smtpd_sasl_local_domain =';
	sudo postconf -e 'smtpd_sasl_security_options = noanonymous';
	sudo postconf -e 'broken_sasl_auth_clients = yes';
	sudo postconf -e 'smtpd_sasl_auth_enable = yes';
	sudo postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination';
	sudo postconf -e "myhostname = $MX_subdomain.$DOMAIN";
	myhostname = '$myhostname';
	sudo postconf -e "mydestination = $myhostname, $MX_subdomain.$DOMAIN, localhost.$DOMAIN, localhost";
	echo "$DOMAIN" > /etc/mailname;

	
	sudo cp /etc/postfix/master.cf /etc/postfix/master.cf.orig;
	sudo mv master.cf /etc/postfix/master.cf;
	sudo systemctl restart postfix;
}

dovecot() {
	sudo cp /etc/dovecot/dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext.orig;
	sudo mv dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext;

	sudo cp /etc/dovecot/conf.d/10-mail.conf /etc/dovecot/conf.d/10-mail.conf.orig;
	sudo mv 10-mail.conf /etc/dovecot/conf.d/10-mail.conf;

	sudo cp /etc/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/10-auth.conf.orig;
	sudo mv 10-auth.conf /etc/dovecot/conf.d/10-auth.conf;

	sudo cp /etc/dovecot/conf.d/10-master.conf /etc/dovecot/conf.d/10-master.conf.orig;
	sudo mv 10-master.conf /etc/dovecot/conf.d/10-master.conf;

	sudo cp /etc/dovecot/conf.d/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf.orig;
	sudo mv 10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf;

	sudo cp /etc/dovecot/conf.d/20-imap.conf /etc/dovecot/conf.d/20-imap.conf.orig;
	sudo mv 20-imap.conf /etc/dovecot/conf.d/20-imap.conf;

	sudo cp /etc/dovecot/conf.d/20-lmtp.conf /etc/dovecot/conf.d/20-lmtp.conf.orig;
	sudo mv 20-lmtp.conf /etc/dovecot/conf.d/20-lmtp.conf;

	sudo cp /etc/dovecot/conf.d/15-mailboxes.conf /etc/dovecot/conf.d/15-mailboxes.conf.orig;
	sudo mv 15-mailboxes.conf /etc/dovecot/conf.d/15-mailboxes.conf;

	sudo cp /etc/dovecot/conf.d/90-quota.conf /etc/dovecot/conf.d/90-quota.conf.orig;
	sudo mv 90-quota.conf /etc/dovecot/conf.d/90-quota.conf;
	
	sudo cp /etc/dovecot/dovecot-dict-sql.conf.ext /etc/dovecot/dovecot-dict-sql.conf.ext.orig;
	sudo mv dovecot-dict-sql.conf.ext /etc/dovecot/dovecot-dict-sql.conf.ext;

	sudo mv quota-warning.sh /usr/local/bin/quota-warning.sh;
	sudo chmod +x /usr/local/bin/quota-warning.sh;

	systemctl restart dovecot;
}

rainloop() {
	sudo mkdir -p ~/$WEBMAIL_subdomain.$DOMAIN;
	cd ~/$WEBMAIL_subdomain.$DOMAIN;
	sudo curl -sL https://repository.rainloop.net/installer.php | php;
	cd ~/;
	sudo mv ./$WEBMAIL_subdomain.$DOMAIN /var/www/;

	sudo php ./rainloop.php;
	sudo rm ./rainloop.php;

	sudo mkdir -p /var/www/$WEBMAIL_subdomain.$DOMAIN/data/_data_/_default_/domains;
	sudo mv ./example.com.ini /var/www/$WEBMAIL_subdomain.$DOMAIN/data/_data_/_default_/domains/$DOMAIN.ini;

	sudo chown -R www-data: /var/www/$MX_subdomain.$DOMAIN;
	sudo chown -R www-data: /var/www/$WEBMAIL_subdomain.$DOMAIN;
	sudo chown -R www-data: /var/www/$POSTFIXADMIN_subdomain.$DOMAIN;
	sudo systemctl reload apache2.service;

	sudo printf "\nn\ny\ny\ny\ny\ny" | mysql_secure_installation;
}

todo() {
	sudo cat ./pw-mail;
	sudo echo "Remember to test the webmail (send and recieve)";
	sudo rm ./mail.tar.gz;
	sudo rm ./mail.sh;
}

######### Script ########
pre-records-dns;
pw;
update-upgrade;
apt-get-install;
secure-mysql;
update-upgrade;	
apache;
postfixadmin;
postfix;
dovecot;
rainloop;
todo;
