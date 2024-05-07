#!/bin/bash

readonly WEB_APP_URL="https://dminti.deploy.qwellco.de"

# Step 1: Update Ubuntu
sudo apt update
sudo apt upgrade -y

# Step 2: Install required packages
sudo apt install chromium-browser sed unclutter -y

# Step 3: Disable Wayland
sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf

# Step 4: Create cleanup script
sudo mkdir -p /opt/kiosk/
sudo tee /opt/kiosk/cleanup_kiosk.sh > /dev/null << EOF
#!/bin/bash
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/dminti/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' /home/dminti/.config/chromium/Default/Preferences
EOF
sudo chmod +x /opt/kiosk/cleanup_kiosk.sh

# Step 5: Create systemd service
sudo tee /lib/systemd/system/kiosk.service > /dev/null << EOF
[Unit]
Description=Chromium Kiosk
Wants=graphical.target
After=graphical.target

[Service]
Environment=DISPLAY=:0
Type=simple
ExecStartPre=/opt/kiosk/cleanup_kiosk.sh
ExecStart=/usr/bin/chromium-browser -noerrdialogs --no-sandbox --disable-infobars --no-first-run --start-maximized --kiosk $WEB_APP_URL
Restart=always
User=dminti
Group=dminti

[Install]
WantedBy=graphical.target
EOF

# Step 6: Enable the kiosk service
sudo systemctl enable kiosk

echo "Setup complete. Rebooting now..."
sudo reboot
