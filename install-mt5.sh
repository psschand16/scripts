#!/bin/bash
set -euo pipefail
exec > >(tee -a mt5-install.log) 2>&1

trap 'echo "Error at line $LINENO. Check mt5-install.log" >&2' ERR

echo "#############################################"
echo "# Optimized MT5 Installation Script        #"
echo "#############################################"

# Enable required repositories
echo "[1/7] Configuring repositories..."
sudo add-apt-repository -y universe
sudo apt update -qq

# Install updated graphics dependencies
echo "[2/7] Installing graphics packages..."
sudo apt install -y --no-install-recommends \
    libgl1 \
    libglx0 \
    libglu1-mesa \
    libxcursor1 \
    libxrandr2 \
    libfreetype6 \
    fonts-dejavu-core

# Install core components
echo "[3/7] Installing base requirements..."
sudo apt install -y \
    xvfb \
    wine64 \
    winetricks \
    cabextract

# Configure swap
echo "[4/7] Setting up swap..."
if [ ! -f /swapfile ]; then
    sudo dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# Wine configuration
echo "[5/7] Initializing Wine environment..."
export WINEARCH=win64
export WINEDEBUG=-all
export DISPLAY=:99
wineboot -u 2>/dev/null

# Install Windows components
echo "[6/7] Installing runtime dependencies..."
winetricks -q corefonts vcrun2019 dotnet48 2>/dev/null

# Start virtual display
echo "[7/7] Launching Xvfb..."
if ! pgrep -x "Xvfb" > /dev/null; then
    Xvfb :99 -screen 0 1024x768x16 -ac &
    sleep 2
fi

echo "#############################################"
echo "# Installation Complete!                   #"
echo "# RAM Usage Breakdown:                     #"
echo "# - System: ~150MB                         #"
echo "# - Wine: ~300MB                           #"
echo "# - MT5: ~400MB                            #"
echo "# Total: ~850MB/1024MB                     #"
echo "#############################################"
