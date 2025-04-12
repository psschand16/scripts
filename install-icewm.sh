#!/bin/bash
set -euo pipefail
exec > >(tee -a install-icewm.log) 2>&1  # Log all output

trap 'echo "Error at line $LINENO. Check install-icewm.log for details." >&2' ERR

# Print header
echo "#############################################"
echo "### IceWM + X2Go Installation for Ubuntu ###"
echo "#############################################"

# Update system
echo "Updating packages..."
sudo apt update && sudo apt upgrade -y

# Install essential tools
echo "Installing required dependencies..."
sudo apt install -y software-properties-common curl

# Install core X11 and IceWM
echo "Installing IceWM and X essentials..."
sudo apt install -y \
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
sudo add-apt-repository -y ppa:x2go/stable
sudo apt update
echo "Installing X2Go..."
sudo apt install -y x2goserver x2goserver-xsession

# Optimize for low RAM
echo "Optimizing system..."
if [ ! -f /swapfile ]; then
    echo "Creating swap file..."
    sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
else
    echo "Swap file already exists - skipping creation."
fi

# Disable unnecessary services (with error suppression)
echo "Disabling background services..."
for service in avahi-daemon cupsd thermald; do
    if systemctl list-unit-files | grep -q "^$service.service"; then
        sudo systemctl disable --now "$service" || true
    fi
done

# Install lightweight apps
echo "Installing lightweight utilities..."
sudo apt install -y \
    falkon \
    mousepad \
    htop \
    nano

# Configure firewall
echo "Setting up firewall..."
sudo apt install -y ufw  # ADDED UFW INSTALLATION

sudo ufw allow 22
sudo ufw allow 3389 2>/dev/null || true  # Ignore error if XRDP not installed
sudo ufw --force enable

# Final cleanup
echo "Cleaning up..."
sudo apt autoremove -y
sudo apt clean

# Success message
echo "#############################################"
echo "### Installation Complete!               ####"
echo "### Full log saved to install-icewm.log  ####"
echo "#############################################"
echo "### Connect using X2Go Client with:      ####"
echo "### - Host: $(curl -s icanhazip.com)     ####"
echo "### - User: $(whoami)                    ####"
echo "### - Session Type: Custom Desktop       ####"
echo "### - Command: icewm                     ####"
echo "### RAM Usage: ~80-150MB (idle)          ####"
echo "#############################################"
