#!/bin/bash

##############################
## made by Christian van Os ##
##############################

######## Variables ########

easyrsa_country="country";
easyrsa_province="province";
easyrsa_city="city";
easyrsa_organisation="organistion_name";
easyrsa_email="email@example.com";
easyrsa_organisation_unit="organisation-unit";

path_easyrsa_ca="/root/ca/";
path_easyrsa_client="/root/client/";

common_server_name="server";
common_client_name="client1";

push_route="10.69.69.0"
protocol="udp"

######## Arguments ########



######### Functions  ########

pre() {
	echo "Start...";

	cd /root/;
	sudo mkdir -p ${path_easyrsa_ca};
	sudo mkdir -p ${path_easyrsa_client};

	sudo tar xvzf openvpn.tar.gz;
	sudo sed -i "s/EASYRSA-COUNTRY/${easyrsa_country}/g" vars;
	sudo sed -i "s/EASYRSA-PROVINCE/${easyrsa_province}/g" vars;
	sudo sed -i "s/EASYRSA-CITY/${easyrsa_city}/g" vars;
	sudo sed -i "s/EASYRSA-ORGANISATION/${easyrsa_organisation}/g" vars;
	sudo sed -i "s/EASYRSA-EMAIL/${easyrsa_email}/g" vars;
	sudo sed -i "s/EASYRSA-ORGANISATION-UNIT/${easyrsa_organisation_unit}/g" vars;
}

update-upgrade() {
	cd /root/;
	sudo apt-get -y update && apt-get -y upgrade;
}

apt-get-install() {
	cd /root/;
	sudo apt-get -y install software-properties-common lsb-release;
	sudo apt-get install -y openvpn;

	sudo debconf-set-selections <<< "iptables-persistent iptables-persistent/autosave_v4 boolean true";
	sudo debconf-set-selections <<< "iptables-persistent iptables-persistent/autosave_v6 boolean true";
	sudo apt-get install -y iptables-persistent;
	
	cd ${path_easyrsa_ca};
	sudo wget -P ${path_easyrsa_ca} https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.7/EasyRSA-3.0.7.tgz;
	sudo tar xvf EasyRSA-3.0.7.tgz;

	cd ${path_easyrsa_client};
	sudo wget -P ${path_easyrsa_client} https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.7/EasyRSA-3.0.7.tgz;
	sudo tar xvf EasyRSA-3.0.7.tgz;
}

easyrsa-ca() {
	cd /root/;
	cd ${path_easyrsa_ca}/EasyRSA-3.0.7/;
	sudo mv /root/vars ${path_easyrsa_ca}/EasyRSA-3.0.7/vars;
	sudo bash ./easyrsa init-pki;
	sudo bash ./easyrsa build-ca nopass;
}

easyrsa-client() {
	cd /root/;
	cd ${path_easyrsa_client}/EasyRSA-3.0.7/;
	sudo bash ./easyrsa init-pki;
	sudo bash ./easyrsa gen-req ${common_server_name} nopass;
	sudo cp ${path_easyrsa_client}/EasyRSA-3.0.7/pki/private/${common_server_name}.key /etc/openvpn/;
	sudo cp ${path_easyrsa_client}/EasyRSA-3.0.7/pki/reqs/${common_server_name}.req /tmp/;
}

easyrsa-sign() {
	cd /root/;
	cd ${path_easyrsa_ca}/EasyRSA-3.0.7/;
	sudo bash ./easyrsa import-req /tmp/${common_server_name}.req server;
	sudo bash ./easyrsa sign-req server ${common_server_name};
	sudo cp ${path_easyrsa_ca}/EasyRSA-3.0.7/pki/issued/${common_server_name}.crt /tmp/;
	sudo cp ${path_easyrsa_ca}/EasyRSA-3.0.7/pki/ca.crt /tmp/;
}

easyrsa-place() {
	cd /root/;
	cd ${path_easyrsa_client}/EasyRSA-3.0.7/;
	sudo cp /tmp/{${common_server_name}.crt,ca.crt} /etc/openvpn/;
	sudo bash ./easyrsa gen-dh;
	sudo openvpn --genkey --secret ta.key;
	sudo cp ${path_easyrsa_client}/EasyRSA-3.0.7/ta.key /etc/openvpn/;
	sudo cp ${path_easyrsa_client}/EasyRSA-3.0.7/pki/dh.pem /etc/openvpn/;
}

vpn-client-config() {
	cd /root/;
	sudo mkdir -p ${path_easyrsa_client}/client-configs/keys/;
	sudo chmod -R 700 ${path_easyrsa_client}/client-configs/;
}

vpn-client-cert() {
	cd /root/;
	cd ${path_easyrsa_client}/EasyRSA-3.0.7/;
	sudo bash ./easyrsa gen-req ${common_client_name} nopass;
	sudo cp ${path_easyrsa_client}/EasyRSA-3.0.7/pki/private/${common_client_name}.key ${path_easyrsa_client}/client-configs/keys/;
	sudo cp ${path_easyrsa_client}/EasyRSA-3.0.7/pki/reqs/${common_client_name}.req /tmp/;
	
	cd ${path_easyrsa_ca}/EasyRSA-3.0.7/;
	sudo bash ./easyrsa import-req /tmp/${common_client_name}.req ${common_client_name};
	sudo bash ./easyrsa sign-req client ${common_client_name};
	sudo cp ${path_easyrsa_ca}/EasyRSA-3.0.7/pki/issued/${common_client_name}.crt /tmp/;

	cd ${path_easyrsa_client}/EasyRSA-3.0.7/;
	sudo cp /tmp/${common_client_name}.crt ${path_easyrsa_client}/client-configs/keys/;
	sudo cp ${path_easyrsa_client}/EasyRSA-3.0.7/ta.key ${path_easyrsa_client}/client-configs/keys/;
	sudo cp /etc/openvpn/ca.crt ${path_easyrsa_client}/client-configs/keys/;
}

configure-openvpn() {
	cd /root/;
	sudo mv /root/server.conf /etc/openvpn/;
}

configure-network() {
	sudo sysctl net.ipv4.ip_forward=1;
	sudo sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" /etc/sysctl.conf;

	default_route=$(sudo ip route | grep default | sed 's/^.*dev //' | awk '{print $1}');
	

	####iptables -t nat -A POSTROUTING -o <local_lan_interface_name> -j MASQUERADE
	####apt-get install iptables-persistent
	####/sbin/iptables-save > /etc/iptables/rules.v4
}

post() {
	echo "End...";
}

######### Script ########
pre;

update-upgrade;
apt-get-install;
update-upgrade;
easyrsa-ca;
easyrsa-client;
easyrsa-sign;
easyrsa-place;
vpn-client-config;
vpn-client-cert;
#configure-openvpn;

post;