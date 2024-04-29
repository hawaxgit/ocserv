#!/bin/bash

# Funktion zum Ermitteln der ausgehenden Netzwerkschnittstelle
get_outgoing_interface() {
    # Ermittle die ausgehende Netzwerkschnittstelle anhand der Standardroute
    interface=$(ip route | grep default | awk '{print $5}')
    echo "$interface"
}

# Funktion zum Deinstallieren von Ocserv und zugehörigen Komponenten
uninstall_ocserv() {
    echo "Uninstalling Ocserv and related components..."
    echo "[  OK  ] Stopping Ocserv..."
    systemctl stop ocserv
    echo "[  OK  ] Disabling Ocserv..."
    systemctl disable ocserv
    echo "[  OK  ] Removing Ocserv..."
    apt remove --purge ocserv -y
    echo "[  OK  ] Removing dependencies..."
    apt autoremove -y
    echo "[  OK  ] Removing firewall rules..."
    if [ "$FIREWALL" = "ufw" ]; then
        ufw delete allow 510/tcp
        ufw delete allow 510/udp
    elif [ "$FIREWALL" = "iptables" ]; then
        iptables -D INPUT -p tcp --dport 510 -j ACCEPT
        iptables -D INPUT -p udp --dport 510 -j ACCEPT
    fi
    echo "[  OK  ] Uninstallation complete"
    read -p "Press Enter to continue..."
}

# Funktion zum Anzeigen der VPN-Benutzer
show_vpn_users() {
    echo "VPN users:"
    echo "-----------"
    cat "$OCPASSWD_FILE"
    echo "-----------"
    read -p "Press Enter to continue..."
}

# Funktion zum Löschen eines VPN-Benutzers
delete_vpn_user() {
    echo "Deleting VPN user..."
    read -p "Please enter the username of the VPN user to delete: " vpn_username
    sed -i "/^$vpn_username:.*$/d" "$OCPASSWD_FILE"
    echo "[  OK  ] VPN user deleted successfully"
}

# Funktion zum Erstellen eines VPN-Benutzers
create_vpn_user() {
    echo "Creating VPN user..."
    read -p "Please enter the username for the VPN user: " vpn_username
    ocpasswd -c "/etc/ocserv/ocpasswd" "$vpn_username"
    echo "VPN user created successfully"
}

# Funktion zum Erneuern des SSL-Zertifikats
renew_ssl_certificate() {
    echo "Renewing SSL certificate..."
    certbot renew
    systemctl restart ocserv
    echo "[  OK  ] SSL certificate renewed successfully"
}

# Funktion zum Installieren des One Touch Ocserv VPN
install_one_touch_vpn() {
    echo "Installing One Touch Ocserv VPN..."
    # Add your installation steps for One Touch Ocserv VPN here
    if [ "$(id -u)" -ne 0 ]; then
       echo "This script must be run as root" 
       exit 1
    fi

    # Informationen über den Autor, die E-Mail und die Website anzeigen
    echo "==================================================="
    echo " OpenConnect VPN-Server with Let's Encrypt SSL-Certificate"
    echo " Introducing Ubuntu/Debian"
    echo " Autor: Soroush at Hawax IT"
    echo " Website: www.hawax.de"
    echo " E-Mail: info@hawax.de"
    echo ""
    echo "==================================================="

    # Nach Domain, E-Mail und Benutzerinformationen fragen
    read -p "Please enter your domain name: " domain_name
    read -p "Please enter your e-mail address: " owner_email

    # Variablen
    OCPASSWD_FILE="/etc/ocserv/ocpasswd"

    # Funktion zum Installieren von Paketen
    install_packages() {
        echo "Updating and installing packages..."
        apt update
        apt upgrade -y
        apt install nano ocserv openssl certbot $FIREWALL -y

        # Überprüfen, ob alle erforderlichen Pakete installiert sind
        if ! dpkg -l ocserv openssl certbot $FIREWALL; then
            echo "Required packages could not be installed"
            exit 1
        fi
    }

    # Funktion zum Erstellen des Zertifikats
    create_certificate() {
        echo "Creating the certificate with certbot..."
        certbot certonly --standalone --non-interactive --agree-tos --email "$owner_email" -d "$domain_name"
        echo "[  OK  ] Certificate created successfully"
    }

    # Funktion zum Aktualisieren der Konfigurationsdatei
    update_config_file() {
        echo "Updating the configuration file..."
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
pre-login-banner = "Open up the web - https://github.com/hawaxgit/"
EOF
        echo "[  OK  ] Configuration file updated successfully"
    }

    # Funktion zum Konfigurieren der Firewall
    configure_firewall() {
        echo "Configuring the firewall..."
        if [ "$FIREWALL" = "ufw" ]; then
            ufw allow 510/tcp
            ufw allow 510/udp
            ufw enable
            ufw default allow outgoing
        elif [ "$FIREWALL" = "iptables" ]; then
            iptables -A INPUT -p tcp --dport 510 -j ACCEPT
            iptables -A INPUT -p udp --dport 510 -j ACCEPT
            iptables-save > /etc/iptables/rules.v4
            interface=$(get_outgoing_interface)
            iptables -t nat -A POSTROUTING -o "$interface" -j MASQUERADE
            apt install iptables-persistent -y
            systemctl enable netfilter-persistent
            systemctl start netfilter-persistent
        fi
        echo "[  OK  ] Firewall configured successfully"
    }

    # Funktion zum Ermitteln der ausgehenden Netzwerkschnittstelle
    get_outgoing_interface() {
        # Ermittle die ausgehende Netzwerkschnittstelle anhand der Standardroute
        interface=$(ip route | grep default | awk '{print $5}')
        echo "$interface"
    }

    # Hauptskript
    systemctl enable ocserv
    systemctl start ocserv

    # Zertifikatsverzeichnis erstellen
    mkdir -p "$CERT_DIR"

    # Benutzerpasswortdatei erstellen
    touch "$OCPASSWD_FILE"

    # IP-Weiterleitung aktivieren
    echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf && sysctl -p

    # Pakete installieren
    echo "Installing required packages..."
    install_packages

    # Zertifikat erstellen
    create_certificate

    # Konfigurationsdatei aktualisieren
    update_config_file

    # Firewall konfigurieren
    configure_firewall

    echo "[  OK  ] OpenConnect SSL VPN installed successfully"
}

# Hauptmenü
display_menu() {
    clear
    echo "===============<Hawax>================"
    echo " OpenConnect VPN server configuration"
    echo "======================================"
    echo "1. Install One Touch Ocserv VPN"
    echo "2. Create VPN user"
    echo "3. Renew SSL certificate"
    echo "4. Delete VPN user"
    echo "5. Show VPN users"
    echo "6. Uninstall Ocserv and related components"
    echo "7. Exit"
    echo "======================================"
    read -p "Please choose an option [1-7]: " menu_option
}

# Menüoptionen auswerten
while true; do
    display_menu
    case "$menu_option" in
        1) install_one_touch_vpn ;;
        2) create_vpn_user ;;
        3) renew_ssl_certificate ;;
        4) delete_vpn_user ;;
        5) show_vpn_users ;;
        6) uninstall_ocserv ;;
        7) exit 0 ;;
        *) echo "Invalid option. Please choose a valid option." ;;
    esac
done
