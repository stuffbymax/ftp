#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Detect package manager
if command -v apt >/dev/null; then
    PKG_MANAGER="apt"
    UPDATE_CMD="apt update -y && apt upgrade -y"
    INSTALL_CMD="apt install -y"
elif command -v dnf >/dev/null; then
    PKG_MANAGER="dnf"
    UPDATE_CMD="dnf update -y"
    INSTALL_CMD="dnf install -y"
elif command -v yum >/dev/null; then
    PKG_MANAGER="yum"
    UPDATE_CMD="yum update -y"
    INSTALL_CMD="yum install -y"
elif command -v pacman >/dev/null; then
    PKG_MANAGER="pacman"
    UPDATE_CMD="pacman -Syu --noconfirm"
    INSTALL_CMD="pacman -S --noconfirm"
else
    echo "Unsupported package manager"
    exit 1
fi

echo "Updating package database..."
eval "$UPDATE_CMD"

echo "Installing vsftpd..."
eval "$INSTALL_CMD vsftpd"

echo "Backing up the original configuration file..."
cp /etc/vsftpd.conf /etc/vsftpd.conf.bak

echo "Writing a new vsftpd configuration file..."
cat <<EOL > /etc/vsftpd.conf
# Basic Configurations
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_file=/var/log/vsftpd.log
xferlog_std_format=YES
ftpd_banner=Welcome to Secure FTP Server.
chroot_local_user=YES
allow_writeable_chroot=NO
secure_chroot_dir=/var/run/vsftpd/empty

# Passive Mode Configuration
pasv_enable=YES
pasv_min_port=10000
pasv_max_port=10100
pasv_address=$(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1)

# Logging
log_ftp_protocol=YES
vsftpd_log_file=/var/log/vsftpd.log

# Security Settings
ssl_enable=YES
rsa_cert_file=/etc/ssl/certs/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.key
EOL

echo "Generating SSL certificates..."
mkdir -p /etc/ssl/private
openssl req -newkey rsa:2048 -nodes -keyout /etc/ssl/private/vsftpd.key -x509 -days 365 -out /etc/ssl/certs/vsftpd.pem -subj "/CN=FTPServer"

echo "Creating FTP directories for the example user..."
useradd -m ftpuser || echo "User already exists"
echo "Enter a custom password for ftpuser:"
read -s FTP_PASSWORD
echo "ftpuser:$FTP_PASSWORD" | chpasswd
mkdir -p /home/ftpuser/ftp/upload
chown -R ftpuser:ftpuser /home/ftpuser/ftp
chmod -R 750 /home/ftpuser/ftp

echo "Enabling and starting the vsftpd service..."
systemctl enable vsftpd
systemctl restart vsftpd

echo "Configuring firewall rules..."
if command -v ufw >/dev/null; then
    ufw allow 21/tcp
    ufw allow 10000:10100/tcp
elif command -v firewall-cmd >/dev/null; then
    firewall-cmd --add-port=21/tcp --permanent
    firewall-cmd --add-port=10000-10100/tcp --permanent
    firewall-cmd --reload
elif command -v iptables >/dev/null; then
    iptables -A INPUT -p tcp --dport 21 -j ACCEPT
    iptables -A INPUT -p tcp --dport 10000:10100 -j ACCEPT
else
    echo "No recognized firewall manager found. Configure ports manually."
fi

echo "Setup complete!"
echo "You can now connect to the FTP server using the following credentials:"
echo "  Username: ftpuser"
echo "  Password: <your_password>"
echo "  Local IP Address: $(hostname -I | awk '{print $1}')"
echo "Make sure to change the password and customize configurations for production use."
