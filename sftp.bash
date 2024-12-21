#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo "Updating package database..."
pacman -Syu --noconfirm

echo "Installing vsftpd..."
pacman -S vsftpd --noconfirm

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
ftpd_banner=Welcome to Public FTP Server.
chroot_local_user=YES
allow_writeable_chroot=YES

# Passive Mode Configuration
pasv_enable=YES
pasv_min_port=10000
pasv_max_port=10100
pasv_address=$(curl ifconfig.me) # Automatically fetch private IP

# Logging
log_ftp_protocol=YES
vsftpd_log_file=/var/log/vsftpd.log

# Security Settings
ssl_enable=NO
EOL

echo "Creating FTP directories for the example user..."
useradd -m ftpuser
echo "ftpuser:123" | chpasswd
mkdir -p /home/ftpuser/ftp/upload
chown -R ftpuser:ftpuser /home/ftpuser/ftp
chmod -R 750 /home/ftpuser/ftp
chmod 550 /home/ftpuser

echo "Enabling and starting the vsftpd service..."
systemctl enable vsftpd
systemctl restart vsftpd

echo "Setup complete!"
echo "You can now connect to the FTP server using the following credentials:"
echo "  Username: ftpuser"
echo "  Password: 123"
echo "  private IP Address: $(curl ifconfig.me)"
echo "Make sure to change the password and customize configurations for production use."
