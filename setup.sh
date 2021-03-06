#!/bin/bash

# This script is for Ubuntu 14.04.

if [[ $# != 2 ]]; then
    echo "Usage: `basename $0` <server name or ip>"
    exit 1
fi

server=$1

# Note: on Debian, replace strongswan-plugin-xauth-generic with
# libcharon-extra-plugins.
apt-get install -y strongswan strongswan-plugin-xauth-generic

# Generate certificates

mkdir -p cert
cd cert

# CA certificate
ipsec pki --gen --outform pem > caKey.pem
ipsec pki --self --in caKey.pem --dn "C=CH, O=strongSwan, CN=strongSwan CA" --ca --outform pem > caCert.pem

# Server (strongSwan VPN gateway) certificate
ipsec pki --gen --outform pem > serverKey.pem
ipsec pki --pub --in serverKey.pem | ipsec pki --issue --cacert caCert.pem --cakey caKey.pem \
          --dn "C=CH, O=strongSwan, CN=$server" --san="$server" \
          --flag serverAuth --flag ikeIntermediate --outform pem > serverCert.pem

# Client (iOS) certificate
ipsec pki --gen --outform pem > clientKey.pem
ipsec pki --pub --in clientKey.pem | ipsec pki --issue --cacert caCert.pem --cakey caKey.pem \
          --dn "C=CH, O=strongSwan, CN=strongSwan client" --outform pem > clientCert.pem

# PKCS#12 file, for iOS and OS X
openssl pkcs12 -export -inkey clientKey.pem -in clientCert.pem -name "strongSwan client" \
               -certfile caCert.pem -caname "strongSwan CA" -out clientCert.p12

# Install certificates
sudo cp caCert.pem /etc/ipsec.d/cacerts/
sudo cp serverCert.pem /etc/ipsec.d/certs/
sudo cp serverKey.pem /etc/ipsec.d/private/
sudo cp clientCert.pem /etc/ipsec.d/certs/
sudo cp clientKey.pem /etc/ipsec.d/private/

cd ..
sudo cp ./etc/* /etc/
sudo chmod 0600 /etc/ipsec.secrets

# iptables rules
echo "Setup iptables rules."
sudo iptables-restore <./iptables.rules

# Enable ip forwarding
echo "Enable ip forwarding, please check setting in /etc/sysctl.conf"
sudo sysctl -w net.ipv4.ip_forward=1

# Restart ipsec service
sudo ipsec stop
sudo ipsec start

# Other useful command
# After adding new user in ipsec.secrets
#   ipsec rereadsecrets
# Reload config
#   ipsec reload

