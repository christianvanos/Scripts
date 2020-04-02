#!/bin/bash

##############################
## made by Christian van Os ##
##############################

######## Variables ########

EXIT=false;

######## Passwords ########

PASSWORD=$(date +%s | sha224sum | base64 | head -c 10);

######## Arguments ########

while getopts ":u:d:" opt; do
        case $opt in
                u) USERNAME="$OPTARG";;		# SFTP USERNAME		REQUIRED
                d) DIRECTORY="$OPTARG";;	# CONTAINER DIRECTORY	REQUIRED
		\?) echo "Invalid option -$OPTARG" >&2; exit 1;;
                :) echo "Missing option argument for -$OPTARG">&2; exit 1;;
                *) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
        esac
done


if [[ $USERNAME == '' ]]; then echo "-u flag is missing (username)"; EXIT=true; fi
if [[ $DIRECTORY == '' ]]; then echo "-d flag is missing (container directory)"; EXIT=true; fi
if [[ $EXIT == true ]]; then exit 1; fi

######### Functions  ########

install() {
	sudo apt-get install sshpass -y;
}

pw() {
	sudo printf "SFTP\n$USERNAME => $PASSWORD" >> ~/pw-sftp;
	sudo echo "Password: $PASSWORD";
}

addnewuser() {
	sudo adduser --disabled-password --gecos "" $USERNAME;
	sudo printf "$PASSWORD\n$PASSWORD\n" | sudo passwd $USERNAME;
	sudo mkdir -p $DIRECTORY/$USERNAME;
	
	sudo chown root:root $DIRECTORY;
	sudo chmod 755 $DIRECTORY;
	
	sudo chown -R $USERNAME:$USERNAME $DIRECTORY/$USERNAME;
	sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak;
	printf "Match User $USERNAME\nForceCommand internal-sftp\nPasswordAuthentication yes\nChrootDirectory $DIRECTORY\nPermitTunnel no\nAllowAgentForwarding no\nAllowTcpForwarding no\nX11Forwarding no\n" >> /etc/ssh/sshd_config;

	sudo systemctl restart sshd;

	sudo echo "====================================";
	sudo echo "TEST SSH... we should not get access";
	sudo sshpass -p $PASSWORD ssh $USERNAME@localhost;

	sudo echo "====================================";
	sudo echo "TEST SFTP... we should get access";
	sudo printf "ls\nquit\n" | sudo sshpass -p $PASSWORD sftp $USERNAME@localhost;
}

deinstall() {
	sudo apt-get remove sshpass -y;
}

######### Script ########
install;
pw;
addnewuser;
deinstall;
