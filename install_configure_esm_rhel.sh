#!/bin/bash

#
# This script is for RHEL8 Linux to configure XRDP for enhanced session mode
# Should work on Centos 8 too.
#

###############################################################################
# Hyperv tools
#
dnf install -y hyperv-tools

# Load the Hyper-V kernel module
echo "hv_sock" | tee -a /etc/modules-load.d/hv_sock.conf > /dev/null

###############################################################################
# Install XRDP
#
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
dnf install -y xrdp xrdp-selinux


###############################################################################
# Configure XRDP
#
systemctl enable xrdp
systemctl enable xrdp-sesman

# Configure the installed XRDP ini files.
# use vsock transport.
sed -i_orig -e 's/port=3389/port=vsock:\/\/-1:3389/g' /etc/xrdp/xrdp.ini
# use rdp security.
sed -i_orig -e 's/security_layer=negotiate/security_layer=rdp/g' /etc/xrdp/xrdp.ini
# remove encryption validation.
sed -i_orig -e 's/crypt_level=high/crypt_level=none/g' /etc/xrdp/xrdp.ini
# disable bitmap compression since its local its much faster
sed -i_orig -e 's/bitmap_compression=true/bitmap_compression=false/g' /etc/xrdp/xrdp.ini

# rename the redirected drives to 'shared-drives'
sed -i_orig -e 's/FuseMountName=thinclient_drives/FuseMountName=shared-drives/g' /etc/xrdp/sesman.ini

# Change the allowed_users
echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# Open port
firewall-cmd --add-port=3389/tcp --permanent
firewall-cmd --reload
