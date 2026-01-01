# iLoader Deployment Guide for Proxmox/Internal Network

This guide explains how to deploy iLoader to your Proxmox server for internal network access.

## Overview

iLoader has been enhanced with:
1. **Fixed certificate parsing** - Made `machine_id` field optional
2. **Working anisette server** - Default changed to `ani.sidestore.app`

## Deployment Options

### Option 1: Linux Desktop on Proxmox (Recommended)

Run iLoader as a desktop app on a Proxmox Linux VM, accessible via web browser using noVNC or Guacamole.

#### Prerequisites
- Proxmox server
- Linux VM (Ubuntu/Debian recommended)
- Desktop environment (XFCE/GNOME)

#### Steps:

1. **Build the Linux AppImage**:
   ```bash
   cd /Users/fuad/Documents/PersonalProjects/iloader
   npm run build
   cd src-tauri
   cargo build --release
   ```

2. **Transfer to Proxmox**:
   ```bash
   scp target/release/iloader user@proxmox-ip:/home/user/
   ```

3. **Set up USB passthrough** (for iOS devices):
   - In Proxmox, pass through USB controller to the VM
   - Add your user to the `plugdev` group:
     ```bash
     sudo usermod -aG plugdev $USER
     ```

4. **Install required dependencies** on the VM:
   ```bash
   sudo apt update
   sudo apt install -y libwebkit2gtk-4.1-0 libayatana-appindicator3-1 \
                       libusbmuxd-tools usbmuxd
   ```

5. **Run iLoader**:
   ```bash
   chmod +x ./iloader
   ./iloader
   ```

6. **Access via noVNC**:
   - Install noVNC on Proxmox
   - Access via: `http://proxmox-ip:6080/vnc.html`

###Option 2: Docker Container with X11

Run iLoader in a Docker container with X11 forwarding.

#### Dockerfile:
```dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \\
    libwebkit2gtk-4.1-0 \\
    libayatana-appindicator3-1 \\
    libusbmuxd-tools \\
    usbmuxd \\
    x11vnc \\
    xvfb

COPY target/release/iloader /usr/local/bin/

EXPOSE 5900

CMD ["x11vnc", "-create", "-forever"]
```

### Option 3: macOS on Proxmox (Advanced)

If your Proxmox supports macOS VMs, you can:
1. Build the macOS `.app` bundle
2. Run it in a macOS VM
3. Access via VNC

## Building for Production

### macOS (.dmg):
```bash
npm run tauri build
# Output: src-tauri/target/release/bundle/dmg/iloader_1.1.6_universal.dmg
```

### Linux (AppImage):
```bash
npm run tauri build
# Output: src-tauri/target/release/bundle/appimage/iloader_1.1.6_amd64.AppImage
```

## Network Configuration

### Allow network access to iLoader on VM:
1. Configure Proxmox VM network in bridge mode
2. Assign static IP to the VM
3. Access the VM desktop via:
   - VNC: `vnc://vm-ip:5900`
   - noVNC web: `http://vm-ip:6080`
   - Guacamole: `http://proxmox-ip:8080/guacamole`

## USB Device Access

For iOS device sideloading over the network:

1. **USB/IP** (recommended for remote iOS devices):
   ```bash
   # On the machine with iOS device connected:
   sudo apt install usbip
   sudo modprobe usbip-host
   usbip list -l
   sudo usbip bind -b <bus-id>

   # On Proxmox VM:
   sudo apt install usbip
   sudo modprobe vhci-hcd
   usbip attach -r <remote-ip> -b <bus-id>
   ```

2. **Proxmox USB Passthrough**:
   - Attach iOS device to Proxmox host
   - Pass through to VM via Proxmox web UI

## Troubleshooting

### iOS device not detected:
```bash
# Check usbmuxd status
sudo systemctl status usbmuxd
sudo systemctl restart usbmuxd

# List devices
idevice_id -l
```

### Certificate parsing errors:
- Already fixed in this version (machine_id made optional)

### Anisette server connection issues:
- Default server: `ani.sidestore.app`
- Alternatives available in Settings dropdown
- Test connectivity: `curl https://ani.sidestore.app/v3/client_info`

## Summary

**Current Status**:
✅ Certificate parsing bug fixed
✅ Working anisette server configured
✅ Desktop app fully functional

**For Network Access**:
- Deploy to Linux VM on Proxmox
- Use VNC/noVNC for web-based access
- Configure USB passthrough for iOS devices

This approach keeps all your existing code working while providing network access through remote desktop protocols.
