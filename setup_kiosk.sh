#!/bin/bash

# Step 1: Update Ubuntu
sudo apt update
sudo apt upgrade -y

# Step 2: Install required packages
sudo apt install chromium-browser sed xdotool unclutter -y

# Step 3: Create a user called "kiosk"
sudo useradd -m kiosk

# Step 4: Enable automatic login and disable Wayland
sudo sed -i 's/#  AutomaticLoginEnable = true/AutomaticLoginEnable = true/' /etc/gdm3/custom.conf
sudo sed -i 's/#  AutomaticLogin = user1/AutomaticLogin = kiosk/' /etc/gdm3/custom.conf
sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf

# Step 5: Create cleanup script
sudo mkdir -p /opt/kiosk/
sudo tee /opt/kiosk/cleanup_kiosk.sh > /dev/null << EOF
#!/bin/bash
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/kiosk/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' /home/kiosk/.config/chromium/Default/Preferences
EOF
sudo chmod +x /opt/kiosk/cleanup_kiosk.sh

# Step 6: Create systemd service
sudo tee /lib/systemd/system/kiosk.service > /dev/null << EOF
[Unit]
Description=Chromium Kiosk
Wants=graphical.target
After=graphical.target

[Service]
Environment=DISPLAY=:0
Type=simple
ExecStartPre=/opt/kiosk/cleanup_kiosk.sh
ExecStart=/usr/bin/chromium-browser -noerrdialogs --disable-infobars --no-first-run --start-maximized --kiosk https://dminti.deploy.qwellco.de
Restart=always
User=kiosk
Group=kiosk

[Install]
WantedBy=graphical.target
EOF

# Step 7: Enable the kiosk service
sudo systemctl enable kiosk

echo "Setup complete. Rebooting now..."
sudo reboot
