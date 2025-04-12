#!/bin/bash
# MT5 Ultimate Hybrid Setup Script - Optimized for Speed and Low Resource Usage
# Save as: mt5-ultimate-setup.sh

# Configuration
LOG_DIR="/var/log/mt5_setup"
CONFIG_DIR="$HOME/.mt5_config"
SWAP_SIZE="2G"                  # Swap file size (match to available disk space)
OPT_PKGS="xvfb lxde-core x2goserver python3 python3-pip"
WINE_PKGS="winehq-stable winetricks"
DISABLED_SERVICES="snapd apache2 bluetooth cups avahi-daemon"
X2GO_COMPRESSION="nopack"       # Best for LAN: nopack, WAN: lzma
PYTHON_LIBS="MetaTrader5 pandas numpy" 

# System Tuning Parameters
VM_SWAPPINESS=10                 # Reduce swap tendency (0-100)
INODE_CACHE_PERCENT=50           # Balance between filesystem cache and memory
MAX_LOG_DAYS=7                   # Auto-clean logs older than X days

# Colors for output
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
    
    # Memory/swap optimization
    sudo sysctl -w vm.swappiness=$VM_SWAPPINESS
    sudo sysctl -w vm.vfs_cache_pressure=$INODE_CACHE_PERCENT
    echo "vm.swappiness=$VM_SWAPPINESS" | sudo tee -a /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=$INODE_CACHE_PERCENT" | sudo tee -a /etc/sysctl.conf

    # Create optimized swap
    sudo fallocate -l "$SWAP_SIZE" /swapfile || error "Swap allocation failed"
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile || error "Swap creation failed"
    sudo swapon /swapfile || error "Swap activation failed"
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

    # Disable services
    for service in $DISABLED_SERVICES; do
        if systemctl list-unit-files | grep -q "$service.service"; then
            sudo systemctl stop "$service"
            sudo systemctl disable "$service"
            success "Disabled service: $service"
        fi
    done

    # Schedule log cleanup
    (crontab -l 2>/dev/null; echo "0 3 * * * find $LOG_DIR -type f -mtime +$MAX_LOG_DAYS -delete") | crontab -
}

# Dependency Management
install_dependencies() {
    header "Installing Required Components"
    
    # Add WineHQ repository
    sudo dpkg --add-architecture i386
    wget -qO- https://dl.winehq.org/wine-builds/winehq.key | sudo apt-key add - || error "WineHQ key add failed"
    sudo apt-add-repository 'deb https://dl.winehq.org/wine-builds/ubuntu/ $(lsb_release -cs) main' || error "Repo add failed"

    # System update with retry logic
    for i in {1..3}; do
        sudo apt update && break
        [ $i -eq 3 ] && error "Failed to update packages after 3 attempts"
        sleep $((i*10))
    done

    # Fix broken dependencies first
    sudo apt --fix-broken install -y || error "Dependency fix failed"

    # Install packages with minimal recommendations
    sudo apt install -y --no-install-recommends $OPT_PKGS $WINE_PKGS || error "Package install failed"

    # Clean package cache
    sudo apt autoremove -y
    sudo apt clean
    sudo rm -rf /var/lib/apt/lists/*
}

# MT5 Configuration
configure_mt5() {
    header "Configuring MT5 Environment"
    
    # Wine optimizations
    export WINEDLLOVERRIDES="mscoree,mshtml="
    export WINEPREFIX="$CONFIG_DIR/mt5_wine"
    export WINEARCH=win64
    
    # Initialize Wine
    wineboot -i &>/dev/null
    winetricks -q corefonts || error "Winetricks failed"

    # Install MT5
    wget -qO "$CONFIG_DIR/mt5_installer.exe" "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe" || error "MT5 download failed"
    wine "$CONFIG_DIR/mt5_installer.exe" &>/dev/null || error "MT5 install failed"

    # Create desktop shortcut (for GUI access)
    echo "[Desktop Entry]
Name=MetaTrader 5 (Hybrid)
Exec=env DISPLAY=:0 wine \"C:\Program Files\MetaTrader 5\terminal64.exe\"
Type=Application
Categories=Finance;" > "$HOME/Desktop/mt5.desktop"
    chmod +x "$HOME/Desktop/mt5.desktop"
}

# Python Environment
setup_python() {
    header "Configuring Python Automation"
    
    python3 -m venv "$CONFIG_DIR/pyenv" || error "Python venv failed"
    source "$CONFIG_DIR/pyenv/bin/activate"
    pip install --no-cache-dir $PYTHON_LIBS || error "Python package install failed"
    
    # Create sample trading script
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
        # Example: Get EURUSD price
        price = mt5.symbol_info_tick("EURUSD").ask
        logging.info(f"Current EURUSD Price: {price}")
    finally:
        mt5.shutdown()

if __name__ == "__main__":
    main()' > "$CONFIG_DIR/mt5_trader.py"
}

# Post-Install Cleanup
final_cleanup() {
    header "Performing System Cleanup"
    
    # Remove temporary files
    sudo find /tmp -type f -atime +1 -delete
    
    # Clear package cache
    sudo apt clean
    
    # Remove old kernels
    sudo apt purge -y $(dpkg -l | awk '/linux-image-[0-9]/{print $2}' | sort -V | head -n -2)
    
    # Reset permissions
    sudo chown -R "$USER":"$USER" "$CONFIG_DIR"
}

# Main Execution
init_setup
tune_system
install_dependencies
configure_mt5
setup_python
final_cleanup

header "Installation Complete"
echo -e "${GREEN}Hybrid MT5 Setup Summary:${NC}"
echo -e "• Swap File:        ${SWAP_SIZE} (active)"
echo -e "• MT5 Installation: ${WINEPREFIX}"
echo -e "• Python Env:       ${CONFIG_DIR}/pyenv"
echo -e "• Log Directory:    ${LOG_DIR}"
echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. GUI Access: Use X2Go client with compression: ${X2GO_COMPRESSION}"
echo "2. Automation: Edit ${CONFIG_DIR}/mt5_trader.py"
echo "3. Schedule:   Add to crontab: 0 * * * * ${CONFIG_DIR}/pyenv/bin/python ${CONFIG_DIR}/mt5_trader.py"
