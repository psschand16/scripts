###How to Use:
##Save as install-icewm.sh

Make executable:

##bash

chmod +x install-icewm.sh
Run with sudo:

##bash

sudo ./install-icewm.sh

###Key Features:
RAM Usage:

IceWM: 15-30MB

X2Go Server: 30MB

Total idle: ~80-100MB

Preinstalled Apps:

Falkon (lightweight browser)

PCManFM (file manager)

Mousepad (text editor)

Htop (system monitor)

Optimizations:

2GB swap file

Disabled resource-heavy services

Minimal Xorg installation

Post-Install Steps:
Remote Access:

Use X2Go Client with:

Session Type: Custom Desktop

Command: icewm

Keyboard Shortcuts:

Ctrl+Alt+T: New terminal

Alt+Tab: Switch windows

Alt+F3: Run dialog

Customize IceWM:

Edit config files in ~/.icewm/

Get themes from IceWM Themes

Troubleshooting:
Black screen on login:

###bash

# Verify session config
cat ~/.xsession  # Should show "exec icewm"

# Restart X2Go
sudo systemctl restart x2goserver
Missing apps:

bash

sudo apt install --no-install-recommends <package>
This setup leaves ~700MB free RAM for applications on a 1GB server. Let me know if you need adjustments! 🐧
