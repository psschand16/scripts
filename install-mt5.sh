#!/bin/bash
set -euo pipefail
exec > >(tee -a mt5-install.log) 2>&1

# Error handler
trap 'echo "Error at line $LINENO. Check mt5-install.log" >&2' ERR

echo "#############################################"
echo "# MetaTrader 5 Headless Installation Script #"
echo "#############################################"

# Install dependencies
echo "[1/6] Installing required packages..."
sudo apt update && sudo apt install -y \
    xvfb \
    wine-stable \
    winetricks \
    libgl1-mesa-glx \
    libxcursor1 \
    libxrandr2 \
    libfreetype6 \
    fonts-dejavu-core

# Configure swap
echo "[2/6] Configuring swap..."
if [ ! -f /swapfile ]; then
    sudo dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# Configure Wine
echo "[3/6] Setting up Wine environment..."
export WINEARCH=win64
export WINEDEBUG=-all
export DISPLAY=:99

# Initialize Wine
echo "[4/6] Initializing Wine..."
wineboot -u 2>/dev/null

# Install required Windows components
echo "[5/6] Installing Windows dependencies..."
winetricks -q corefonts vcrun2019

# Start Xvfb if not running
echo "[6/6] Starting virtual display..."
if ! pgrep -x "Xvfb" > /dev/null; then
    Xvfb :99 -screen 0 1024x768x16 -ac &
    sleep 2
fi

echo "#############################################"
echo "# Installation Complete!                   #"
echo "# To run MetaTrader 5:                     #"
echo "# 1. Connect via X2Go                      #"
echo "# 2. In terminal:                          #"
echo "#    export DISPLAY=:99                    #"
echo "#    wine /path/to/mt5setup.exe            #"
echo "#                                          #"
echo "# Monitor resources with: htop             #"
echo "#############################################"
