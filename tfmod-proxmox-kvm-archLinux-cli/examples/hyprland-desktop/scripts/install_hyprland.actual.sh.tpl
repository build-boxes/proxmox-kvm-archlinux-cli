#!/usr/bin/env bash
set -eu

sudo pacman --noconfirm -S kitty hyprland waybar dolphin wofi otf-font-awesome woff2-font-awesome swaync
mkdir -p /home/${USER}/.config/hypr
mkdir -p /home/${USER}/.config/waybar

# sudo pacman --noconfirm -S gdm
# sudo systemctl enable gdm.service

sudo pacman --noconfirm -S sddm
# sudo mkdir -p /etc/sddm.conf.d
# sudo tee /etc/sddm.conf.d/hyprland.conf > /dev/null <<'EO2L'
# [General]
# DefaultSession=hyprland.desktop
# DisplayServer=wayland
# GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
# HaltCommand=/run/current-system/systemd/bin/systemctl poweroff
# InputMethod=
# Numlock=none
# RebootCommand=/run/current-system/systemd/bin/systemctl reboot

# [Theme]
# Current=tokyo-night-sddm

# [Wayland]
# CompositorCommand=hyprland
# EnableHiDPI=true
# SessionDir=/usr/share/wayland-sessions
# EO2L

sudo systemctl enable sddm.service

# sudo pacman --noconfirm -S x11vnc
# sudo x11vnc -storepasswd ${PASSWORD} /etc/x11vnc.passwd
# sudo cat > /etc/systemd/system/x11vnc.service.d/override.conf <<EO1L
# # /etc/systemd/system/x11vnc.service.d/override.conf
# [Service]
# ExecStart=
# ExecStart=/bin/bash -c "/usr/bin/x11vnc -auth /var/run/sddm/* -display :0 -forever -noxdamage -repeat -ssl -shared -rfbauth /etc/x11vnc.passwd"
# Restart=always
# RestartSec=2

# [Install]
# WantedBy=multi-user.target
# EO1L
# sudo systemctl enable x11vnc.service

# sudo pacman --noconfirm -S lightdm lightdm-gtk-greeter
# sudo systemctl enable lightdm.service


sudo pacman --noconfirm -S wayvnc
mkdir -p /home/${USER}/.config/wayvnc
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
	-keyout /home/${USER}/.config/wayvnc/key.pem -out /home/${USER}/.config/wayvnc/cert.pem -subj /CN=localhost \
	-addext subjectAltName=DNS:localhost,DNS:localhost,IP:127.0.0.1
cat > /home/${USER}/.config/wayvnc/config <<EOL
address=0.0.0.0
port=5900
enable_auth=true
username=${USER}
password=${PASSWORD}
private_key_file=/home/${USER}/.config/wayvnc/key.pem
certificate_file=/home/${USER}/.config/wayvnc/cert.pem
EOL
echo "WAYLAND_DISPLAY=wayland-0" | sudo tee -a /etc/environment
