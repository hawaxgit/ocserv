#!/bin/bash

# Überprüfen, ob das Skript als Root-Benutzer ausgeführt wird
if [[ $EUID -ne 0 ]]; then
   echo "Dieses Skript muss als Root ausgeführt werden" 
   exit 1
fi

# Informationen zu Arthur, E-Mail und Website anzeigen
echo "Script by SOROUSH"
echo "E-Mail: info@hawax.de"
echo "Website: https://hawax.de"
echo ""

# Nach Domain- und E-Mail-Informationen fragen
read -p "Geben Sie bitte den Domain-Namen Ihrer Website ein: " domain_name
read -p "Geben Sie bitte Ihre E-Mail-Adresse ein: " owner_email

# Variablen
CERT_DIR="/etc/ocserv/cert"

# Pakete aktualisieren und installieren
yum update -y
yum upgrade -y
yum install epel-release -y
yum install ocserv openssl -y
sudo yum install certbot -y

# Überprüfen, ob alle erforderlichen Pakete installiert sind
if ! rpm -q ocserv openssl; then
    echo "Erforderliche Pakete konnten nicht installiert werden"
    exit 1
fi

# Zertifikats-Verzeichnis erstellen
mkdir -p $CERT_DIR

# Benutzer-Passwort-Datei erstellen
touch /etc/ocserv/ocpasswd

# IP-Weiterleitung aktivieren
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

# SELinux in den "permissive"-Modus versetzen
setenforce 0

# Zertifikat mit certbot erstellen
certbot certonly --standalone --non-interactive --agree-tos --email $owner_email -d $domain_name

# Konfigurationsdatei aktualisieren
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
dns = 8.8.4.8
route = default
EOF

