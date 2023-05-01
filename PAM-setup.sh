#!/bin/bash
#PAM RADIUS authentication setup for ocserv
# Check if the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Display information about the author, email, and website
echo "==================================================="
echo " PAM RADIUS authentication setup for ocserv"
echo " Introduction for CentOS7"
echo " Author: SOROUSH"
echo " website:www.hawax.de"
echo " Telegram: @hawaxit"
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
service ocserv restart
