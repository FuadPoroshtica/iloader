# iLoader Proxmox Deployment

Deploy iLoader to Proxmox LXC and access via `iloader.vemo.is`

## Quick Start

### One-Command Deployment

From your Mac, run:

```bash
bash deploy.sh
```

That's it! The script will:
1. ✅ Check Proxmox connectivity
2. ✅ Upload installation scripts
3. ✅ Create LXC container (Ubuntu 22.04)
4. ✅ Install all dependencies
5. ✅ Install iLoader with noVNC
6. ✅ Start services on port 8080

**Time**: ~10-15 minutes total

## What Gets Installed

### LXC Configuration
- **OS**: Ubuntu 22.04
- **RAM**: 2GB
- **CPU**: 2 cores
- **Disk**: 8GB
- **Network**: DHCP (bridged)

### Services
- **XFCE4** - Desktop environment
- **X11VNC** - VNC server (port 5900)
- **noVNC** - Web-based VNC client (port 8080)
- **iLoader** - iOS sideloading application
- **Supervisor** - Process manager
- **usbmuxd** - USB device support

### Ports Exposed
- `8080` - noVNC web interface (HTTP)
- `5900` - VNC direct access (optional)

## Post-Deployment Setup

### 1. Find Your LXC IP

```bash
ssh root@10.0.2.2 'pct list | grep iloader'
```

Example output:
```
200   iloader   running   192.168.1.100
```

### 2. Configure Nginx Proxy Manager

Access your NPM dashboard and add:

**Proxy Host Configuration:**
```
Domain Names:        iloader.vemo.is
Scheme:              http
Forward Hostname/IP: 192.168.1.100  (your LXC IP)
Forward Port:        8080
Cache Assets:        ✓
Block Exploits:      ✓
Websockets Support:  ✓ REQUIRED!
```

**SSL Certificate:**
```
SSL Certificate:     Let's Encrypt (or your cert)
Force SSL:           ✓
HTTP/2 Support:      ✓
HSTS:                ✓
```

**Advanced (Optional):**
```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_http_version 1.1;
proxy_read_timeout 86400;
```

### 3. Access iLoader

Open your browser:
```
https://iloader.vemo.is
```

You'll see the XFCE desktop with iLoader running!

## USB Device Support

### Connect iOS Device

1. **Plug iOS device** into Proxmox host USB port

2. **Check detection** in LXC:
   ```bash
   ssh root@10.0.2.2 'pct exec <LXC-ID> -- idevice_id -l'
   ```

3. **Trust computer** on iOS device when prompted

### USB Passthrough to LXC

The LXC is pre-configured with USB passthrough. If you need to manually configure:

```bash
# On Proxmox host
echo "lxc.cgroup2.devices.allow: c 189:* rwm" >> /etc/pve/lxc/<ID>.conf
echo "lxc.mount.entry: /dev/bus/usb dev/bus/usb none bind,optional,create=dir" >> /etc/pve/lxc/<ID>.conf

# Restart LXC
pct stop <ID>
pct start <ID>
```

## Management Commands

### From Your Mac

```bash
# SSH to Proxmox
ssh root@10.0.2.2

# List all containers
ssh root@10.0.2.2 'pct list'

# Check iLoader status
ssh root@10.0.2.2 'pct exec <ID> -- supervisorctl status'

# View logs
ssh root@10.0.2.2 'pct exec <ID> -- tail -f /var/log/supervisor/iloader.log'

# Restart iLoader
ssh root@10.0.2.2 'pct exec <ID> -- supervisorctl restart iloader'

# Enter LXC shell
ssh root@10.0.2.2 'pct enter <ID>'
```

### Inside LXC

```bash
# Check all services
supervisorctl status

# Restart a service
supervisorctl restart iloader
supervisorctl restart novnc

# View logs
tail -f /var/log/supervisor/iloader.log
tail -f /var/log/supervisor/novnc.log

# Check iOS devices
idevice_id -l

# Check network
ip addr show
```

## Troubleshooting

### Can't Access Web Interface

**Check LXC is running:**
```bash
ssh root@10.0.2.2 'pct status <ID>'
```

**Check noVNC is listening:**
```bash
ssh root@10.0.2.2 'pct exec <ID> -- netstat -tlnp | grep 8080'
```

**Check logs:**
```bash
ssh root@10.0.2.2 'pct exec <ID> -- supervisorctl status'
```

### iOS Device Not Detected

**Check USB on Proxmox host:**
```bash
ssh root@10.0.2.2 'lsusb | grep -i apple'
```

**Check USB in LXC:**
```bash
ssh root@10.0.2.2 'pct exec <ID> -- lsusb'
```

**Restart usbmuxd:**
```bash
ssh root@10.0.2.2 'pct exec <ID> -- systemctl restart usbmuxd'
```

### Black Screen / No Desktop

**Restart display services:**
```bash
ssh root@10.0.2.2 'pct exec <ID> -- supervisorctl restart xvfb x11vnc xfce'
```

**Or restart entire LXC:**
```bash
ssh root@10.0.2.2 'pct reboot <ID>'
```

### Login Fails (Anisette Server)

The default anisette server is `ani.sidestore.app`. If it fails:

1. Try alternative servers from Settings dropdown
2. Test connectivity from LXC:
   ```bash
   ssh root@10.0.2.2 'pct exec <ID> -- curl https://ani.sidestore.app/v3/client_info'
   ```

## Updating iLoader

To update to a newer version:

```bash
# 1. Rebuild on your Mac
npm run build
cd src-tauri
cargo build --release

# 2. Copy new binary to Proxmox
scp target/release/iloader root@10.0.2.2:/tmp/

# 3. Update in LXC
ssh root@10.0.2.2 'pct push <ID> /tmp/iloader /usr/local/bin/iloader'
ssh root@10.0.2.2 'pct exec <ID> -- chmod +x /usr/local/bin/iloader'
ssh root@10.0.2.2 'pct exec <ID> -- supervisorctl restart iloader'
```

## Backup & Restore

### Backup LXC

```bash
# Create backup
ssh root@10.0.2.2 'vzdump <ID> --dumpdir /var/lib/vz/dump'

# Download backup
scp root@10.0.2.2:/var/lib/vz/dump/vzdump-lxc-<ID>-*.tar.zst ./
```

### Restore from Backup

```bash
# Upload backup
scp backup.tar.zst root@10.0.2.2:/var/lib/vz/dump/

# Restore
ssh root@10.0.2.2 'pct restore <NEW-ID> /var/lib/vz/dump/backup.tar.zst'
```

## Uninstall

To completely remove iLoader:

```bash
# Stop and destroy LXC
ssh root@10.0.2.2 'pct stop <ID> && pct destroy <ID>'

# Remove from NPM
# Delete the proxy host in NPM dashboard
```

## Architecture

```
┌─────────────────────┐
│   Your Browser      │
│ iloader.vemo.is     │
└──────────┬──────────┘
           │ HTTPS (443)
           ▼
┌─────────────────────┐
│ Nginx Proxy Manager │
│    (NPM)            │
└──────────┬──────────┘
           │ HTTP (8080)
           ▼
┌─────────────────────┐
│  Proxmox LXC        │
│  ┌───────────────┐  │
│  │ noVNC :8080   │  │
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │ X11VNC :5900  │  │
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │ Xvfb :99      │  │
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │ XFCE Desktop  │  │
│  │   + iLoader   │  │
│  └───────────────┘  │
└─────────────────────┘
```

## Performance Tuning

### Increase Resolution

Edit `/etc/supervisor/conf.d/iloader.conf` in LXC:

```ini
[program:xvfb]
command=/usr/bin/Xvfb :99 -screen 0 2560x1440x24
```

Then restart:
```bash
supervisorctl restart xvfb x11vnc xfce iloader
```

### Reduce Latency

Use VNC client directly instead of noVNC:
```
vnc://your-lxc-ip:5900
```

## Support

- **Documentation**: See `FIXES_APPLIED.md` for known fixes
- **Logs**: `/var/log/supervisor/` in LXC
- **GitHub**: https://github.com/FuadPoroshtica/iloader

---

**Quick Reference:**

```bash
# Deploy
bash deploy.sh

# Find LXC IP
ssh root@10.0.2.2 'pct list | grep iloader'

# Check status
ssh root@10.0.2.2 'pct exec <ID> -- supervisorctl status'

# View logs
ssh root@10.0.2.2 'pct exec <ID> -- tail -f /var/log/supervisor/iloader.log'

# Restart
ssh root@10.0.2.2 'pct exec <ID> -- supervisorctl restart iloader'
```

**Access**: `https://iloader.vemo.is` 🎉
