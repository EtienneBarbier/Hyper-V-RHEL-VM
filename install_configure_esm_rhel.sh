#!/bin/bash

#
# This script is for RHEL based distribution to configure XRDP for enhanced session mode
# RHEL8, Rocky 8, RHEL9, Rocky 9, Fedora, ...
#

echo "Hyper-V Enhanced Session Mode for RHEL based distribution"

# Check root
if [ `id -u` -ne 0 ]; then 
    echo Please run this script as root or using sudo!
    exit 1
fi

# Check OS
if [ ! -f /etc/os-release ]; then
    echo "File /etc/os-release not present, cannot determine OS. Exiting..."
    exit 1
fi

platform=$(grep '^PLATFORM_ID=' /etc/os-release | awk -F'=' '{ print $2 }' | tr -d '"' | awk -F':' '{ print $2 }')
platform_array=( $(grep -Eo '[^[:digit:]]+|[[:digit:]]+' <<< "$platform") )
platform_name=$(echo "${platform_array[0]}")
platform_version=$(echo "${platform_array[1]}")

el_supported=("8", "9")
fedora_tested=("40")

echo "Platform: ${platform}"
echo "Platform name: ${platform_name}"
echo "Platform version: ${platform_version}"

if [ "$platform_name" == "el" ]; then
    if [[ ! ${el_supported[*]} =~ "$platform_version" ]]; then
        echo "RHEL version ($platform_version) not supported, exiting..."
        exit 1
    fi
elif [ "$platform_name" == "f" ]; then
    if [[ ! ${fedora_tested[*]} =~ "$platform_version" ]]; then
        read -p "Fedora version ($platform_version) not tested, continue ? (y/n)" fedora_continue
        if [ "$fedora_continue" != "y" ]; then
            echo "Exiting..."
            exit 1
        fi
    fi
else
    echo "Platform not supported. Exiting..."
    exit 1
fi

###############################################################################
# Hyperv tools
#
echo "Installing Hyper-V tools"
dnf install -y hyperv-tools

# Load the Hyper-V kernel module
echo "Load Hyper-V kernel module"
echo "hv_sock" | tee -a /etc/modules-load.d/hv_sock.conf > /dev/null

###############################################################################
# Install XRDP
#
if [ "$platform_name" == "el" ]; then
echo "Installing EPEL"
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${platform_version}.noarch.rpm
fi
echo "Installing XRDP"
dnf install -y xrdp xrdp-selinux xorgxrdp


###############################################################################
# Configure XRDP
#
echo "Configuration of XRDP"
systemctl enable --now xrdp
systemctl enable --now xrdp-sesman

# Configure the installed XRDP ini files.
# use vsock transport.
sed -i_orig -e 's/port=3389/port=vsock:\/\/-1:3389/g' /etc/xrdp/xrdp.ini
# use rdp security.
sed -i_orig -e 's/security_layer=negotiate/security_layer=rdp/g' /etc/xrdp/xrdp.ini
# remove encryption validation.
sed -i_orig -e 's/crypt_level=high/crypt_level=none/g' /etc/xrdp/xrdp.ini
# disable bitmap compression since its local its much faster
sed -i_orig -e 's/bitmap_compression=true/bitmap_compression=false/g' /etc/xrdp/xrdp.ini

# Add Xorg option
sed -i_orig -e 's/#\[Xorg\]/\
[Xorg]\
name=Xorg\
lib=libxup.so\
username=ask\
password=ask\
port=-1\
code=20/g' /etc/xrdp/xrdp.ini

# rename the redirected drives to 'shared-drives'
sed -i_orig -e 's/FuseMountName=thinclient_drives/FuseMountName=shared-drives/g' /etc/xrdp/sesman.ini

# Change the allowed_users
echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# Open port
firewall-cmd --add-port=3389/tcp --permanent
firewall-cmd --reload

###############################################################################
# Configure Audio (RHEL 9, Rocky Linux 9, Fedora >= 38) With Pipewire, without pulseaudio
#
echo "Configuration Audio"

# Check pulseaudio is absent
command -v pulseaudio

if [ $? -eq 1 ]; then
    echo "Install audio support"
    # Install build environment
    sudo dnf install git gcc make autoconf libtool automake pkgconfig

    # Install dependencies
    sudo dnf install pipewire-devel
    
    # Build and install
    pushd /tmp
    git clone https://github.com/neutrinolabs/pipewire-module-xrdp.git
    pushd pipewire-module-xrdp
    ./bootstrap
    ./configure
    make
    sudo make install
    popd
    rm -rf pipewire-module-xrdp
    popd

else
    echo "Cannnot fix audio with pulseaudio and xrdp, please follow README for manual install"
fi

echo "Done, please reboot to apply all changes"