#!/bin/bash
set -euo pipefail
trap 'echo "Error at line $LINENO. Exit code: $?" >&2' ERR

# Print header
echo "#############################################"
echo "### IceWM + X2Go Installation for Ubuntu ###"
echo "#############################################"

# Update system
echo "Updating packages..."
sudo apt update -qq && sudo apt upgrade -y -qq

# Install essential tools first (FIX ADDED HERE)
echo "Installing required dependencies..."
sudo apt install -y -qq software-properties-common curl

# Install core X11 and IceWM
echo "Installing IceWM and X essentials..."
sudo apt install -y -qq \
    xorg \
    icewm \
    xinit \
    xterm \
    pcmanfm \
    lxterminal

# Configure IceWM as default
echo "Configuring IceWM session..."
echo "exec icewm" > ~/.xsession

# Install X2Go Server
echo "Adding X2Go repository..."
sudo add-apt-repository -y ppa:x2go/stable >/dev/null
sudo apt update -qq
echo "Installing X2Go..."
sudo apt install -y -qq x2goserver x2goserver-xsession

# [Rest of the script remains unchanged...]


# Optimize for low RAM
echo "Optimizing system..."
# Create swap file (2GB) only if it doesn't exist
if [ ! -f /swapfile ]; then
    echo "Creating swap file..."
    sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile >/dev/null
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
else
    echo "Swap file already exists - skipping creation."
fi

# Disable unnecessary services
echo "Disabling background services..."
sudo systemctl disable --now avahi-daemon cupsd thermald >/dev/null 2>&1

# Install lightweight apps
echo "Installing lightweight utilities..."
sudo apt install -y -qq \
    falkon \
    mousepad \
    htop \
    nano

# Configure firewall
echo "Setting up firewall..."
sudo ufw allow 22    # SSH
sudo ufw allow 3389  # XRDP (optional)
sudo ufw --force enable

# Final cleanup
echo "Cleaning up..."
sudo apt autoremove -y -qq
sudo apt clean

# Success message
echo "#############################################"
echo "### Installation Complete!               ####"
echo "### Connect using X2Go Client with:      ####"
echo "### - Host: $(curl -s icanhazip.com)     ####"
echo "### - User: $(whoami)                    ####"
echo "### - Session Type: Custom Desktop       ####"
echo "### - Command: icewm                     ####"
echo "### RAM Usage: ~80-150MB (idle)          ####"
echo "#############################################"
