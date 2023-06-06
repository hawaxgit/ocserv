#!/bin/bash

# Check the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

# Variables
CERT_DIR="/etc/ocserv/cert"
OCPASSWD_FILE="/etc/ocserv/ocpasswd"

# Function to display the menu
display_menu() {
    clear
    echo "===============<Hawax>================"
    echo " OpenConnect VPN server configuration"
    echo "======================================"
    echo "1. OneClick Installation OpenConnect VPN"
    echo "2. Create VPN user"
    echo "3. Renew SSL certificate"
    echo "4. Configure Radius and PAM authentication"
    echo "5. Delete VPN user"   # New option for deleting a VPN user
    echo "6. Exit"   # Updated option for exiting the script
    echo "======================================"
    read -p "Please choose an option [1-6]: " menu_option
}

# Function to delete VPN user
delete_vpn_user() {
    echo "Deleting VPN user..."
    read -p "Please enter the username of the VPN user to delete: " vpn_username
    sed -i "/^$vpn_username:.*$/d" "$OCPASSWD_FILE"
    echo "VPN user deleted successfully"
}

# Function to create VPN user
create_vpn_user() {
    echo "Creating VPN user..."
    read -p "Please enter the username for the VPN user: " vpn_username
    ocpasswd -c "/etc/ocserv/ocpasswd" "$vpn_username"
    echo "VPN user created successfully"
}

# Function to renew SSL certificate
renew_ssl_certificate() {
    echo "Renewing SSL certificate..."
    certbot renew
    systemctl restart ocserv
    echo "SSL certificate renewed successfully"
}

# Function to configure Radius and PAM authentication
configure_radius_pam_auth() {
    echo "Configuring Radius and PAM authentication..."
    # PAM RADIUS authentication setup for ocserv
    # Check if the script is being run as root
    if [[ $EUID -ne 0 ]]; then
       echo "This script must be run as root" 
       exit 1
    fi

    # Display information about the author, email, and website
    echo "==================================================="
    echo " PAM RADIUS authentication setup for ocserv"
    echo " Introduction for CentOS7"
    echo " Author: Hawax IT"
    echo " website:www.hawax.de"
    echo " Email: info@hawax.de"
    echo ""
    echo "==================================================="

    # Install required dependencies
    yum install autoconf automake gcc libtasn1-devel zlib zlib-devel trousers trousers-devel gmp-devel gmp xz texinfo libnl-devel libnl tcp_wrappers-libs tcp_wrappers-devel tcp_wrappers dbus dbus-devel ncurses-devel pam-devel readline-devel bison bison-devel flex gcc automake autoconf wget -y

    # Install Nettle
    cd && wget http://www.lysator.liu.se/~nisse/archive/nettle-2.7.tar.gz
    tar xvf nettle-2.7.tar.gz && cd nettle-2.7
    ./configure --prefix=/opt/ && make && make install

    # Install GnuTLS
    cd && wget ftp://ftp.gnutls.org/gcrypt/gnutls/v3.2/gnutls-3.2.12.tar.xz
    unxz gnutls-3.2.12.tar.xz && tar xvf gnutls-3.2.12.tar && cd gnutls-3.2.12
    export LD_LIBRARY_PATH=/opt/lib/:/opt/lib64/
    NETTLE_CFLAGS="-I/opt/include/" NETTLE_LIBS="-L/opt/lib64/ -lnettle"
    HOGWEED_CFLAGS="-I/opt/include" HOGWEED_LIBS="-L/opt/lib64/ -lhogweed"
    ./configure --prefix=/opt/ && make && make install

    # Install libnl
    cd && wget https://src.fedoraproject.org/lookaside/pkgs/libnl3/libnl-3.2.24.tar.gz/6e0e7bad0674749d930dd9f285343d55/libnl-3.2.24.tar.gz
    tar xvf libnl-3.2.24.tar.gz && cd libnl-3.2.24
    ./configure --prefix=/opt/ && make && make install

    # Install pam_radius
    cd && wget http://pkgs.fedoraproject.org/repo/pkgs/pam_radius/pam_radius-1.3.17.tar.gz/a5d27ccbaaad9d9fb254b01a3c12bd06/pam_radius-1.3.17.tar.gz
    tar -xvf pam_radius-1.3.17.tar.gz && cd pam_radius-1.3.17
    make && mkdir -p /lib/security && cp pam_radius_auth.so /lib/security/
    mkdir -p /etc/raddb/ && cp pam_radius_auth.conf /etc/raddb/server

    # Configure pam_radius
    if [ ! -d "/lib/security/" ]; then
        mkdir -p /lib/security/
    fi
    echo "auth required /lib/security/pam_radius_auth.so" >> /etc/pam.d/ocserv
    echo "account required /lib/security/pam_radius_auth.so" >> /etc/pam.d/ocserv
    echo "session required /lib/security/pam_radius_auth.so" >> /etc/pam.d/ocserv

    # Configure ocserv
    sed -i 's/^auth = "plain\[passwd=\/etc\/ocserv\/ocpasswd\]"/#auth = "plain[passwd=\/etc\/ocserv\/ocpasswd]"/g' /etc/ocserv/ocserv.conf
    sed -i 's/^#auth = "pam"/auth = "pam"/g' /etc/ocserv/ocserv.conf
    systemctl restart ocserv
    echo "Radius and PAM authentication configured successfully"
}

# Function to install One Touch Ocserv VPN
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
    echo " Introducing CentOS 7"
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
        sudo yum update -y
        sudo yum upgrade -y
        sudo yum install nano -y
        sudo yum install epel-release -y
        sudo yum install ocserv openssl -y
        sudo yum install certbot -y
        sudo yum install firewalld -y
        yum groupinstall "Development Tools" -y

        # Überprüfen, ob alle erforderlichen Pakete installiert sind
        if ! rpm -q ocserv openssl; then
            echo "Required packages could not be installed"
            exit 1
        fi
    }

    # Funktion zum Erstellen des Zertifikats
    create_certificate() {
        echo "Creating the certificate with certbot..."
        certbot certonly --standalone --non-interactive --agree-tos --email "$owner_email" -d "$domain_name"
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
    }

    # Funktion zum Konfigurieren der Firewall
    configure_firewall() {
        echo "Configuring the firewall..."
        sudo systemctl start firewalld
        sudo systemctl enable firewalld
        sudo firewall-cmd --add-masquerade
        sudo firewall-cmd --permanent --add-masquerade
        sudo firewall-cmd --zone=public --add-service={http,https} --permanent
        sudo firewall-cmd --zone=public --add-port={22,443,510}/tcp --permanent
        sudo firewall-cmd --zone=public --add-port={22,443,510}/udp --permanent
        sudo firewall-cmd --reload
        echo "Firewall configured successfully"
    }

    # Hauptskript
    sudo systemctl enable ocserv
    sudo systemctl start ocserv

    # Zertifikatsverzeichnis erstellen
    mkdir -p "$CERT_DIR"

    # Benutzerpasswortdatei erstellen
    touch "$OCPASSWD_FILE"

    # IP-Weiterleitung aktivieren
    echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

    # SELinux auf "permissive" setzen
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

    # Pakete installieren
    install_packages

    # Zertifikat erstellen
    create_certificate

    # Konfigurationsdatei aktualisieren
    update_config_file

    # Firewall konfigurieren
    configure_firewall

    echo "OpenConnect SSL VPN installed successfully"
}

# Hauptmenü
display_menu

# Menüoptionen auswerten
case "$menu_option" in
    1) install_one_touch_vpn ;;
    2) create_vpn_user ;;
    3) renew_ssl_certificate ;;
    4) configure_radius_pam_auth ;;
    5) delete_vpn_user ;;   # New case for deleting a VPN user
    6) exit 0 ;;   # Updated case for exiting the script
    *) echo "Invalid option. Please choose a valid option." ;;
esac

