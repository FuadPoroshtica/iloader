#!/usr/bin/env bash

# Copyright (c) 2024 Fuad Poroshtica
# Author: Fuad Poroshtica
# License: MIT
# https://github.com/FuadPoroshtica/iloader

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y git
msg_ok "Installed Dependencies"

msg_info "Installing Desktop Environment"
$STD apt-get install -y \
  xfce4 \
  xfce4-goodies \
  xfce4-terminal \
  dbus-x11
msg_ok "Installed Desktop Environment"

msg_info "Installing VNC Server"
$STD apt-get install -y \
  x11vnc \
  xvfb
msg_ok "Installed VNC Server"

msg_info "Installing noVNC"
$STD apt-get install -y \
  novnc \
  websockify \
  net-tools
ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html
msg_ok "Installed noVNC"

msg_info "Installing iLoader Dependencies"
$STD apt-get install -y \
  libwebkit2gtk-4.1-0 \
  libayatana-appindicator3-1 \
  libusbmuxd-tools \
  usbmuxd \
  libimobiledevice6
msg_ok "Installed iLoader Dependencies"

msg_info "Installing Supervisor"
$STD apt-get install -y supervisor
mkdir -p /var/log/supervisor
msg_ok "Installed Supervisor"

msg_info "Downloading iLoader Binary"
RELEASE_URL="https://github.com/FuadPoroshtica/iloader/releases/latest/download/iloader-linux-x86_64"
if ! curl -L -o /usr/local/bin/iloader "$RELEASE_URL"; then
  msg_error "Failed to download iLoader binary. Please build manually."
  msg_info "Building iLoader from source..."

  # Install build dependencies
  $STD apt-get install -y \
    curl \
    wget \
    build-essential \
    libssl-dev \
    pkg-config \
    libwebkit2gtk-4.1-dev \
    libayatana-appindicator3-dev

  # Install Rust
  msg_info "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"

  # Install Node.js
  msg_info "Installing Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  $STD apt-get install -y nodejs

  # Clone and build
  msg_info "Cloning iLoader repository..."
  cd /opt
  git clone https://github.com/FuadPoroshtica/iloader.git
  cd iloader

  msg_info "Building iLoader (this will take 10-15 minutes)..."
  npm install
  npm run build
  cd src-tauri
  cargo build --release

  # Copy binary
  cp target/release/iloader /usr/local/bin/

  msg_ok "Built iLoader from source"
fi

chmod +x /usr/local/bin/iloader
msg_ok "Installed iLoader"

msg_info "Configuring Supervisor"
cat <<'EOF' >/etc/supervisor/conf.d/iloader.conf
[supervisord]
nodaemon=false
user=root

[program:xvfb]
command=/usr/bin/Xvfb :99 -screen 0 1920x1080x24
autorestart=true
stdout_logfile=/var/log/supervisor/xvfb.log
stderr_logfile=/var/log/supervisor/xvfb_err.log
priority=10

[program:x11vnc]
command=/usr/bin/x11vnc -display :99 -forever -shared -rfbport 5900 -nopw
autorestart=true
stdout_logfile=/var/log/supervisor/x11vnc.log
stderr_logfile=/var/log/supervisor/x11vnc_err.log
priority=20

[program:novnc]
command=/usr/share/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 0.0.0.0:8080
autorestart=true
stdout_logfile=/var/log/supervisor/novnc.log
stderr_logfile=/var/log/supervisor/novnc_err.log
priority=30

[program:xfce]
command=/usr/bin/startxfce4
environment=DISPLAY=":99"
autorestart=true
stdout_logfile=/var/log/supervisor/xfce.log
stderr_logfile=/var/log/supervisor/xfce_err.log
priority=40

[program:iloader]
command=/usr/local/bin/iloader
environment=DISPLAY=":99"
autorestart=true
stdout_logfile=/var/log/supervisor/iloader.log
stderr_logfile=/var/log/supervisor/iloader_err.log
priority=50
startsecs=10
EOF
msg_ok "Configured Supervisor"

msg_info "Starting Services"
systemctl enable supervisor
systemctl start supervisor
sleep 5
supervisorctl reread
supervisorctl update
supervisorctl start all
msg_ok "Started Services"

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"

motd_ssh
customize

msg_info "Access iLoader via noVNC at:"
IP=$(hostname -I | awk '{print $1}')
echo -e "${CL}${BL}http://${IP}:8080${CL}"
echo -e "${CL}${BL}Configure Nginx Proxy Manager to forward iloader.vemo.is to http://${IP}:8080${CL}"
echo -e "${CL}${BL}Remember to enable WebSockets Support in NPM!${CL}"
