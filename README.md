# OneClick Installation OpenConnect VPN server with Let's Encrypt SSL certificate on CentOS7
This bash script automates the setup of an OpenConnect VPN server with Let's Encrypt SSL certificate.
It prompts the user to enter the domain name and owner email, installs required packages, creates a certificate with certbot, and updates the server configuration file. The script also sets up basic security features such as user authentication, IP forwarding, and SELinux permissive mode. With this script, you can quickly deploy a secure VPN server for your personal or business use.

# Download Script 

```
git clone https://github.com/hawaxgit/ocserv.git
```
# change directory and choise ocserv folder

```
cd ocserv 
```
# Changes the file permissions of the "ocserv_install.sh" file

```
chmod +x ocserv_install.sh
```
# Run the Script

```
bash ocserv_install.sh
```
