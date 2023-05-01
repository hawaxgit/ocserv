#!/bin/bash

# Display information about the author, email, and website
echo "==================================================="
echo " PAM RADIUS authentication setup for ocserv"
echo " Introduction for CentOS7"
echo " Author: SOROUSH"
echo " website:www.hawax.de"
echo " Email: info@hawax.de"
echo ""
echo "==================================================="
# This script helps to issue SSL certificates using ACME

# Function to issue SSL certificate
ssl_cert_issue() {
  local method=""
  echo ""
  echo "********Usage********"
  echo "This shell script uses ACME to issue SSL certificates."
  echo "Here, we provide two methods for issuing certificates:"
  echo "Method 1: ACME standalone mode (requires port 80 to be open)"
  echo "Method 2: ACME DNS API mode (requires Cloudflare Global API Key)"
  echo "We recommend Method 2, but if it fails, you can try Method 1."
  echo "Certificates will be installed in /root/cert directory."
  read -p "Please choose which method you want to use (type 1 or 2): " method
  echo "You have chosen Method ${method}."

  if [ "${method}" == "1" ]; then
    ssl_cert_issue_standalone
  elif [ "${method}" == "2" ]; then
    ssl_cert_issue_by_cloudflare
  else
    echo "Invalid input. Please check your selection and try again."
    exit 1
  fi
}

# Function to install acme.sh
install_acme() {
  cd ~ || exit 1
  echo "Installing acme.sh..."
  curl https://get.acme.sh | sh
  if [ $? -ne 0 ]; then
    echo "Installation of acme.sh failed. Please check the logs."
    return 1
  else
    echo "Installation of acme.sh succeeded."
  fi
  return 0
}

# Function to issue SSL certificate using standalone mode
ssl_cert_issue_standalone() {
  # Check if acme.sh is installed
  if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
    echo "acme.sh not found. Installing now."
    install_acme
    if [ $? -ne 0 ]; then
      echo "Installation of acme.sh failed. Please check the logs."
      exit 1
    fi
  fi
  
  # Install socat if not already installed
  if [[ x"${release}" == x"centos" ]]; then
    yum install socat -y
  else
    apt install socat -y
  fi
  
  if [ $? -ne 0 ]; then
    echo "Installation of socat failed. Please check the logs."
    exit 1
  else
    echo "Installation of socat succeeded."
  fi
  
  # Create directory for certificates
  certPath=/root/cert
  if [ ! -d "$certPath" ]; then
    mkdir "$certPath"
  else
    rm -rf "$certPath"
    mkdir "$certPath"
  fi
  
  # Get domain name from user input
  local domain=""
  read -p "Please enter your domain name: " domain
  echo "Your domain name is: ${domain}. Verifying it now..."
  
  # Verify domain
  local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')
  if [ "${currentCert}" == "${domain}" ]; then
    local certInfo=$(~/.acme.sh/acme.sh --list)
    echo "There is already a certificate issued for this domain. Certificate details:"
    echo "$certInfo"
    exit 1
  else
    echo "Your domain name is ready for certificate issuance."
  fi
}

# Function to issue SSL certificate using DNS API mode
ssl_cert_issue
