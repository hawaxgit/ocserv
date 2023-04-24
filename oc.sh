#!/bin/bash

# Check if the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Display information about the author, email, and website
echo "Script by SOROUSH"
echo "E-Mail: info@hawax.de"
echo "Website: https://hawax.de"
echo ""

# Ask for domain and email information
read -p "Please enter your website domain name: " domain_name
read -p "Please enter your email address: " owner_email

# Variables
CERT_DIR="/etc/ocserv/cert"

# Update and install packages
yum update -y
yum upgrade -y
yum install epel-release -y
yum install ocserv openssl -y
sudo yum install certbot -y

# Check if all required packages are installed
if ! rpm -q ocserv openssl; then
    echo "Required packages could not be installed"
    exit 1
fi

# Create certificate directory
mkdir -p $CERT_DIR

# Create user password file
touch /etc/ocserv/ocpasswd

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

# Set SELinux to permissive mode
setenforce 0

# Create certificate with certbot
certbot certonly --standalone --non-interactive --agree-tos --email $owner_email -d $domain_name

# Update configuration file
cat <<EOF > /etc/ocserv/ocserv.conf
#auth = "pam"
auth = "plain[/etc/ocserv/ocpasswd]"
tcp-port = 510
udp-port = 510
run-as-user = nobody
run-as-group = daemon
socket-file = /var/run/ocserv-socket
server-cert = /etc/letsencrypt/live/$domain_name/fullchain.pem
server-key = /etc/letsencrypt/live/$domain_name/privkey.pem
ca-cert = /etc/letsencrypt/live/$domain_name/chain.pem
#cert-user-oid = 0.9.2342.19200300.100.1.1
tls-priorities = "NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0"
auth-timeout = 240
min-reauth-time = 60
max-ban-score = 50
ban-reset-time = 300
cookie-timeout = 300
deny-roaming = false
rekey-time = 172800
rekey-method = ssl
use-utmp = true
pid-file = /var/run/ocserv.pid
device = vpns
predictable-ips = true
ipv4-network = 192.168.1.0
ipv4-netmask = 255.255.255.0
dns = 8.8.8.8
dns = 8.8.4.4
route = default
EOF
