#!/bin/bash



launch_dir=`pwd`
readonly START_TIME=`date +%Y-%m-%dT%H:%M:%S`
readonly LOG_DIR="logs"
readonly LOG_FILE="build_$START_TIME.log"
readonly LOG_OUT="$launch_dir/$LOG_DIR/$LOG_FILE"
readonly WEB_APP_URL="https://dminti.deploy.qwellco.de"

readonly KIOSK_DESKTOP_RC="\
[Desktop]\n\
Session=kiosk\n"

readonly KIOSK_AUTOLOGIN="\
[Seat:*]\n\
allow-guest=false\n\
greeter-hide-users=true\n\
autologin-guest=false\n\
autologin-user=kiosk\n\
autologin-user-timeout=0\n"

readonly KIOSK_DEFAULT_SESSION="\
[Seat:*]\n\
user-session=kiosk\n"

readonly KIOSK_XSESSION="\
[Desktop Entry]\n\
Type=Application\n\
Encoding=UTF-8\n\
Name=Kiosk\n\
Comment=Start a Chrome-based Kiosk session\n\
Exec=/bin/bash /home/kiosk/start-chrome.sh\n\
Icon=google=chrome"

readonly START_CHROME="\
#!/bin/bash\n\n\
X_RES=\`xrandr | grep \"*\" | awk -Fx '{ print \$1 }' | sed 's/[^0-9]*//g'\`\n\
Y_RES=\`xrandr | grep \"*\" | awk -Fx '{ print \$2 }' | awk '{ print \$1 }'\`\n\n\
/usr/bin/google-chrome --kiosk --start-fullscreen --window-position=0,0 \
--window-size=\$X_RES,\$Y_RES --no-first-run --incognito --no-default-browser-check \
--disable-translate $WEB_APP_URL\n"

###############################################################################

# Configuration steps
do_install_openssh=y
do_install_chrome=y
do_create_kiosk_user=y
do_create_kiosk_xsession=y
do_enable_kiosk_autologin=y
do_write_chrome_startup=y

###############################################################################

msg() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S%z)]: $@" >&2
}

###############################################################################

install_openssh() {
    msg "Installing openssh-server"
    apt-get install openssh-server
    systemctl enable ssh
    systemctl start ssh
}
###############################################################################

create_kiosk_user() {
    msg "Creating kiosk group and user"
    getent group kiosk || (
        groupadd kiosk
        useradd kiosk -s /bin/bash -m -g kiosk -p '*'
        passwd -d kiosk # Delete kiosk's password
        # Lock kiosk's account so that kiosk can't login using SSH or by
        # switching tty. However, lightdm can still start a session with this
        # user
        passwd -l kiosk
    )
}

###############################################################################

create_kiosk_xsession() {
    msg "Creating Kiosk Xsession"
    echo -e $KIOSK_XSESSION > /usr/share/xsessions/kiosk.desktop
}

###############################################################################

install_chrome() {
    msg "Installing Chrome browser"
    grep chrome /etc/apt/sources.list.d/google-chrome.list >&/dev/null || (
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add
        echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list
        apt-get update
        apt-get install -y --no-install-recommends google-chrome-stable
    )
}

###############################################################################

enable_kiosk_autologin() {
    msg "Enabling Kiosk autologin"
    echo -e $KIOSK_AUTOLOGIN > /etc/lightdm/lightdm.conf
    echo -e $KIOSK_DEFAULT_SESSION > /etc/lightdm/lightdm.conf.d/99-kiosk.conf
}

###############################################################################

write_chrome_startup() {
    msg "Writing script which starts Chrome with dynamic window size"
    echo -e $START_CHROME > /home/kiosk/start-chrome.sh
    chown kiosk:kiosk /home/kiosk/start-chrome.sh
    chmod +x /home/kiosk/start-chrome.sh
}

###############################################################################
# Start execution
###############################################################################

# Provide an opportunity to stop installation
msg "Configure Kiosk"
read -p "Press ENTER to continue (c to cancel) ..." entry
if [ ! -z $entry ]; then
    if [ $entry = "c" ]; then
        msg "Install cancelled"
        exit 0
    fi
fi

if [ $do_install_openssh = "y" ]; then
    install_openssh
fi

if [ $do_install_chrome = "y" ]; then
    install_chrome
fi

if [ $do_create_kiosk_user = "y" ]; then
    create_kiosk_user
fi

if [ $do_create_kiosk_xsession = "y" ]; then
    create_kiosk_xsession
fi

if [ $do_enable_kiosk_autologin = "y" ]; then
    enable_kiosk_autologin
fi

if [ $do_write_chrome_startup = "y" ]; then
    write_chrome_startup
fi

msg "Installation complete, press ENTER to reboot!"
if [ ! -z $entry ]; then
    if [ $entry = "c" ]; then
        msg "Reboot cancelled"
        exit 0
    fi
fi
sudo reboot

exit 0

###############################################################################
# End execution
###############################################################################
