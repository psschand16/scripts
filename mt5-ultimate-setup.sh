#!/bin/bash
# MT5 Ultimate Hybrid Setup Script v2.1 - Complete Robust Version
# Save as: mt5-ultimate-setup.sh

# Configuration
LOG_DIR="/var/log/mt5_setup"
CONFIG_DIR="$HOME/.mt5_config"
SWAP_SIZE="2G"                  # Swap file size (2G recommended for 1GB RAM)
OPT_PKGS="xvfb lxde-core x2goserver python3 python3-pip"
WINE_PKGS="winehq-stable winetricks"
DISABLED_SERVICES="snapd apache2 bluetooth cups avahi-daemon"
X2GO_COMPRESSION="nopack"       # LAN: nopack, WAN: lzma
PYTHON_LIBS="MetaTrader5 pandas numpy"
SWAP_RETRIES=3                  # Number of swap creation attempts
SWAP_BACKOFF=5                  # Seconds between retries

# System Tuning
VM_SWAPPINESS=10                 # 0-100 (lower = less swap usage)
INODE_CACHE_PERCENT=50           # 50-100 (lower = prioritize file cache)
MAX_LOG_DAYS=7                   # Auto-delete logs older than X days

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Initialization
init_setup() {
    echo -e "${GREEN}=== MT5 Hybrid Setup (Headless + GUI) ===${NC}"
    sudo mkdir -p "$LOG_DIR" "$CONFIG_DIR"
    sudo chown "$USER":"$USER" "$LOG_DIR" "$CONFIG_DIR"
    exec > >(tee -a "${LOG_DIR}/mt5_install.log") 2>&1
}

header() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

error() {
    echo -e "${RED}✗ Error: $1${NC}"
    exit 1
}

# System Optimization
tune_system() {
    header "Tuning System Performance"
    
    # Kernel parameters
    sudo sysctl -w vm.swappiness=$VM_SWAPPINESS
    sudo sysctl -w vm.vfs_cache_pressure=$INODE_CACHE_PERCENT
    echo "vm.swappiness=$VM_SWAPPINESS" | sudo tee -a /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=$INODE_CACHE_PERCENT" | sudo tee -a /etc/sysctl.conf

    # Swap configuration with retry logic
    header "Configuring Swap Space"
    if [ -f "/swapfile" ]; then
        sudo swapoff /swapfile 2>/dev/null
        sudo rm -f /swapfile || error "Failed to remove old swapfile"
    fi

    for ((i=1; i<=SWAP_RETRIES; i++)); do
        if sudo fallocate -l "$SWAP_SIZE" /swapfile 2>/dev/null; then
            success "Swap allocated via fallocate"
            break
        else
            header "Fallback to dd (attempt $i)"
            swap_mb=$((${SWAP_SIZE%G}*1024))
            sudo dd if=/dev/zero of=/swapfile bs=1M count=$swap_mb status=none
            [ $? -eq 0 ] && break
            [ $i -eq $SWAP_RETRIES ] && error "Swap creation failed after $SWAP_RETRIES attempts"
            sleep $SWAP_BACKOFF
        fi
    done

    sudo chmod 600 /swapfile || error "Swap permissions failed"
    sudo mkswap /swapfile || error "Swap formatting failed"
    sudo swapon /swapfile || error "Swap activation failed"
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

    # Disable unnecessary services
    for service in $DISABLED_SERVICES; do
        if systemctl list-unit-files | grep -q "$service.service"; then
            sudo systemctl stop "$service" 2>/dev/null
            sudo systemctl disable "$service" 2>/dev/null
            success "Disabled service: $service"
        fi
    done

    # Schedule log rotation
    (crontab -l 2>/dev/null; echo "0 3 * * * find $LOG_DIR -type f -mtime +$MAX_LOG_DAYS -delete") | crontab -
}

# Dependency Management
install_dependencies() {
    header "Installing System Packages"
    
    # Add WineHQ repository
    sudo dpkg --add-architecture i386
    wget -qO- https://dl.winehq.org/wine-builds/winehq.key | sudo apt-key add - || error "WineHQ key add failed"
    sudo apt-add-repository "deb https://dl.winehq.org/wine-builds/ubuntu/ $(lsb_release -cs) main" || error "Repo add failed"

    # Update with retry logic
    for i in {1..3}; do
        sudo apt update && break
        [ $i -eq 3 ] && error "Failed to update packages"
        sleep $((i*5))
    done

    # Install packages
    sudo apt install -y --no-install-recommends $OPT_PKGS $WINE_PKGS || error "Package install failed"
    sudo apt --fix-broken install -y || error "Dependency fix failed"
    
    # Cleanup
    sudo apt autoremove -y
    sudo apt clean
    sudo rm -rf /var/lib/apt/lists/*
}

# MT5 Configuration
configure_mt5() {
    header "Setting Up MT5 Environment"
    
    export WINEDLLOVERRIDES="mscoree,mshtml="
    export WINEPREFIX="$CONFIG_DIR/mt5_wine"
    export WINEARCH=win64
    
    wineboot -i &>/dev/null
    winetricks -q corefonts || error "Winetricks corefonts failed"

    # Install MT5
    wget -qO "$CONFIG_DIR/mt5_installer.exe" "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe" || error "MT5 download failed"
    wine "$CONFIG_DIR/mt5_installer.exe" &>/dev/null || error "MT5 installation failed"

    # Desktop shortcut
    echo "[Desktop Entry]
Name=MetaTrader 5 (Hybrid)
Exec=env DISPLAY=:0 wine \"C:\Program Files\MetaTrader 5\terminal64.exe\"
Type=Application
Categories=Finance;" > "$HOME/Desktop/mt5.desktop"
    chmod +x "$HOME/Desktop/mt5.desktop"
}

# Python Environment
setup_python() {
    header "Configuring Python Stack"
    
    python3 -m venv "$CONFIG_DIR/pyenv" || error "Python venv creation failed"
    source "$CONFIG_DIR/pyenv/bin/activate"
    pip install --no-cache-dir $PYTHON_LIBS || error "Python package install failed"
    
    # Sample trading script
    echo 'import MetaTrader5 as mt5
import logging
import os

logging.basicConfig(
    filename=os.path.expanduser("~/mt5_trades.log"),
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

def main():
    if not mt5.initialize():
        logging.error("MT5 initialization failed")
        return
    
    try:
        price = mt5.symbol_info_tick("EURUSD").ask
        logging.info(f"EURUSD Price: {price}")
    finally:
        mt5.shutdown()

if __name__ == "__main__":
    main()' > "$CONFIG_DIR/mt5_trader.py"
}

# Final Cleanup
final_cleanup() {
    header "Performing System Cleanup"
    
    sudo find /tmp -type f -atime +1 -delete
    sudo apt clean
    sudo apt purge -y $(dpkg -l | awk '/linux-image-[0-9]/{print $2}' | sort -V | head -n -2)
    sudo chown -R "$USER":"$USER" "$CONFIG_DIR"
}

# Main Execution Flow
init_setup
tune_system
install_dependencies
configure_mt5
setup_python
final_cleanup

# Completion Message
header "Installation Complete"
echo -e "${GREEN}System Ready for Hybrid MT5 Operation${NC}"
echo -e "• Swap File: ${SWAP_SIZE} | Python Env: ${CONFIG_DIR}/pyenv"
echo -e "• MT5 Prefix: ${WINEPREFIX} | Logs: ${LOG_DIR}"
echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. GUI Access: Use X2Go with ${X2GO_COMPRESSION} compression"
echo "2. Automation: Edit ${CONFIG_DIR}/mt5_trader.py"
echo "3. Scheduling: Add to crontab: */5 * * * * ${CONFIG_DIR}/pyenv/bin/python ${CONFIG_DIR}/mt5_trader.py"
