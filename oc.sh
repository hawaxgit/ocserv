#!/bin/bash

# Überprüfen, ob das Skript als Root-Benutzer ausgeführt wird
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Variablen
WEBSITE_NAME="https://hawax.de"
OWNER_NAME="Soroush Tavanaei"
OWNER_EMAIL="info@hawax.de"
DOMAIN=""
CERT_DIR="/etc/ocserv/cert"

# Funktion zur Überprüfung, ob eine Eingabe gemacht wurde
function get_input {
    read -p "$1: " value
    while [[ -z "$value" ]]; do
        echo "Please enter a value"
        read -p "$1: " value
    done
    echo "$value"
}

# Funktion zur Anzeige von Informationen
function display_info {
    echo "Website: $WEBSITE_NAME"
    echo "Owner: $OWNER_NAME"
    echo "Email: $OWNER_EMAIL"
}

# Pakete aktualisieren und installieren
apt-get update -y
apt-get upgrade -y
apt-get install ocserv openssl certbot -y

# Überprüfen, ob alle erforderlichen Pakete installiert sind
if ! dpkg -s ocserv openssl certbot; then
    echo "Unable to install required packages"
    exit 1
fi

# Zertifikats-Verzeichnis erstellen
mkdir -p $CERT_DIR

# Benutzer-Passwort-Datei erstellen
touch /etc/ocserv/ocpasswd

# IP-Weiterleitung aktivieren
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

# SELinux in den "permissive"-Modus versetzen (für CentOS/RHEL-Systeme)
# sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
# sudo echo 0 >/selinux/enforce

# Fragt nach Domain und E-Mail für Zertifikatserstellung
DOMAIN=$(get_input "Enter domain name for SSL certificate")
EMAIL=$(get_input "Enter email for SSL certificate")

# Erstellung des Zertifikats mit certbot
certbot certonly --standalone -n --agree-tos --email $EMAIL -d $DOMAIN

# Konfigurationsdatei aktualisieren
cat <<EOF > /etc/ocserv/ocserv.conf
#auth = "pam"
auth = "plain[/etc/ocserv/ocpasswd]"
tcp-port = 510
udp-port = 510
run-as-user = nobody
run-as-group = daemon
socket-file = /var/run/ocserv-socket
server-cert = $CERT_DIR/live/$DOMAIN/fullchain.pem
server-key = $CERT_DIR/live/$DOMAIN/privkey.pem 
ca-cert = $CERT_DIR/live/$DOMAIN/chain.pem
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
