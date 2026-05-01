#!/data/data/com.termux/files/usr/bin/bash

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Custom Banner ---
clear
echo -e "${PURPLE}"
echo "##############################################"
echo "#                                            #"
echo "#        🚀 TERMUX UBUNTU XFCE SETUP         #"
echo "#             CREATED BY SOBUJ               #"
echo "#                                            #"
echo "##############################################"
echo -e "${NC}"

# --- Function for Progress Bar ---
show_progress() {
    local duration=$1
    local task=$2
    echo -ne "${YELLOW}[*] $task... ${NC}"
    echo -ne "\n["
    for ((i=0; i<=20; i++)); do
        echo -ne "${GREEN}#${NC}"
        sleep $duration
    done
    echo -e "] ${GREEN}Done!${NC}\n"
}

# --- User Input Section ---
echo -e "${CYAN}>> Account Configuration${NC}"
read -p "Enter Username: " USER_NAME
read -s -p "Enter Password: " USER_PASS
echo -e "\n"

# 1. Update and Repositories
echo -e "${BLUE}[1/5] Updating Termux Repositories...${NC}"
pkg update && pkg upgrade -y
pkg install x11-repo tur-repo -y
show_progress 0.05 "Finalizing Repository Setup"

# 2. Core Packages Installation
echo -e "${BLUE}[2/5] Installing Core Packages...${NC}"
pkg install termux-x11-nightly virglrenderer-android mesa-zink proot-distro pulseaudio -y
show_progress 0.05 "Installing Graphics & PRoot"

# 3. Ubuntu Installation
if [ ! -d "$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu" ]; then
    echo -e "${BLUE}[3/5] Installing Ubuntu Distro...${NC}"
    proot-distro install ubuntu
else
    echo -e "${YELLOW}[!] Ubuntu is already installed. Skipping...${NC}"
fi

# 4. Ubuntu Internal Configuration
echo -e "${BLUE}[4/5] Configuring Ubuntu Environment...${NC}"
proot-distro login ubuntu --shared-tmp -- bash -c "
# Update Ubuntu
apt update && apt upgrade -y

# Optimized Package Installation (No Recommends for speed)
apt install xfce4 xfce4-terminal sudo dbus-x11 libgl1-mesa-dri mesa-utils --no-install-recommends -y

# Remove and Block Snap (Optimization)
apt purge snapd -y
apt-mark hold snapd
rm -rf ~/snap /var/snap /var/cache/snapd
echo -e 'Package: snapd\nPin: release a=*\nPin-Priority: -10' > /etc/apt/preferences.d/nosnap.pref

# User & Permission Setup
if ! id -u $USER_NAME >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,audio,video $USER_NAME
    echo '$USER_NAME:$USER_PASS' | chpasswd
    echo '$USER_NAME ALL=(ALL:ALL) ALL' >> /etc/sudoers
fi
"
show_progress 0.1 "Configuring GUI & Users"

# 5. Launcher Script (x.sh) Generation
echo -e "${BLUE}[5/5] Creating Optimized Launcher...${NC}"
cat <<EOF > x.sh
#!/bin/bash

# Cleanup previous sessions
pkill -f termux-x11
pkill -f pulseaudio
pkill -f virgl
rm -rf /tmp/.X11-unix/*

# Start Sound Server
pulseaudio --start --exit-idle-time=-1
pactl load-module module-native-protocol-tcp auth-anonymous=1 address=127.0.0.1 auth-cookie-enabled=0

# Start Graphics Server (Adreno 825 Optimization)
MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink ZINK_DESCRIPTORS=lazy virgl_test_server_android &

# Start Termux-X11
termux-x11 :0 -ac &

sleep 3

# Boot Ubuntu with Hardware Acceleration
proot-distro login ubuntu --shared-tmp --user $USER_NAME -- bash -c "
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
export GALLIUM_DRIVER=virpipe
export MESA_GL_VERSION_OVERRIDE=4.0
export MESA_GLES_VERSION_OVERRIDE=3.2
dbus-launch --exit-with-session startxfce4"
EOF

chmod +x x.sh

clear
echo -e "${GREEN}"
echo "=============================================="
echo "    INSTALLATION FINISHED SUCCESSFULLY!      "
echo "           CREATED BY SOBUJ                  "
echo "=============================================="
echo -e "${NC}"
echo -e "To start your Linux Desktop, run: ${YELLOW}./x.sh${NC}"
