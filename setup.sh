#!/usr/bin/env bash

# Copyright (c) 2024 Fuad Poroshtica
# Author: Fuad Poroshtica
# License: MIT
# https://github.com/FuadPoroshtica/iloader

# Setup script for iLoader LXC on Proxmox
# Run this on your Proxmox host

source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

function header_info {
clear
cat <<"EOF"
    _ _                 _
   (_) |               | |
    _| | ___   __ _  __| | ___ _ __
   | | |/ _ \ / _` |/ _` |/ _ \ '__|
   | | | (_) | (_| | (_| |  __/ |
   |_|_|\___/ \__,_|\__,_|\___|_|

EOF
}

header_info
echo -e "Loading..."

APP="iLoader"
var_disk="8"
var_cpu="2"
var_ram="2048"
var_os="ubuntu"
var_version="22.04"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
header_info
if [[ ! -d /opt ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
msg_info "Updating ${APP} LXC"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
msg_ok "Updated Successfully"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL.
         ${BL}http://${IP}:8080${CL} \n"
echo -e "Configure Nginx Proxy Manager:
         - Domain: iloader.vemo.is
         - Forward to: ${BL}http://${IP}:8080${CL}
         - Enable WebSockets Support ✓"
