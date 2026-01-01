# iLoader Proxmox Deployment Guide

Deploy iLoader to your Proxmox server and access it via `iloader.vemo.is`

## Quick Start

### Automated LXC Deployment (Recommended)

```bash
./deploy-to-proxmox.sh
```

This script will:
1. Build iLoader for Linux
2. Create LXC container on Proxmox (ID: 200)
3. Install all dependencies and iLoader
4. Configure noVNC for web access
5. Start the service on port 8080

**Default Configuration:**
- LXC ID: 200
- LXC Name: iloader
- Memory: 2GB
- CPU Cores: 2
- Password: iloader123 (change in script!)

Edit the script to customize these settings.

### Manual Deployment

If you prefer manual deployment:

```bash
# 1. Build the application
npm install
npm run build
cd src-tauri
cargo build --release
cd ..

# 2. Transfer files to Proxmox
scp -r dist src-tauri/target/release/iloader Dockerfile docker-compose.yml docker root@10.0.2.2:/opt/iloader/

# 3. SSH into Proxmox and deploy
ssh root@10.0.2.2
cd /opt/iloader
docker-compose up -d --build
```

## Architecture

```
┌─────────────────┐
│ Your Browser    │
│ iloader.vemo.is │
└────────┬────────┘
         │ HTTPS
         ▼
┌─────────────────┐
│ Nginx Proxy Mgr │
│ Port 443        │
└────────┬────────┘
         │ HTTP
         ▼
┌─────────────────┐
│ Docker noVNC    │
│ Port 8080       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ iLoader App     │
│ (Desktop in VNC)│
└─────────────────┘
```

## Nginx Proxy Manager Configuration

1. **Access NPM**: `http://10.0.2.2:81` (or your NPM URL)

2. **Add Proxy Host**:
   - **Domain Names**: `iloader.vemo.is`
   - **Scheme**: `http`
   - **Forward Hostname/IP**: `10.0.2.2`
   - **Forward Port**: `8080`
   - **Cache Assets**: ✅ Enabled
   - **Block Common Exploits**: ✅ Enabled
   - **Websockets Support**: ✅ **REQUIRED - Must be enabled!**

3. **SSL** (optional but recommended):
   - **SSL Certificate**: Let's Encrypt or your cert
   - **Force SSL**: ✅ Enabled
   - **HTTP/2 Support**: ✅ Enabled

4. **Advanced** (optional):
   ```nginx
   # Add these custom headers for better noVNC performance
   proxy_set_header Upgrade $http_upgrade;
   proxy_set_header Connection "upgrade";
   proxy_http_version 1.1;
   proxy_read_timeout 86400;
   ```

## USB Device Passthrough

To use iOS devices for sideloading:

### Option 1: USB Passthrough to Container (Recommended)

The Docker container is already configured with USB access. Just:

1. **Connect iOS device** to Proxmox host USB port

2. **Verify detection**:
   ```bash
   docker exec -it iloader idevice_id -l
   ```

### Option 2: USB/IP Network Sharing

If you want to connect devices from another machine:

```bash
# On machine with iOS device:
sudo apt install usbip
sudo modprobe usbip-host
usbip list -l
sudo usbip bind -b <bus-id>

# On Proxmox:
docker exec -it iloader bash
apt install usbip
modprobe vhci-hcd
usbip attach -r <remote-ip> -b <bus-id>
```

## Accessing iLoader

Once deployed and NPM configured:

- **Public URL**: `https://iloader.vemo.is`
- **Direct IP**: `http://10.0.2.2:8080`
- **VNC Client**: `vnc://10.0.2.2:5900` (if you prefer VNC app)

## Container Management

```bash
# View logs
ssh root@10.0.2.2
cd /opt/iloader
docker-compose logs -f

# Restart container
docker-compose restart

# Stop container
docker-compose down

# Rebuild after changes
docker-compose up -d --build

# Access container shell
docker exec -it iloader bash
```

## Troubleshooting

### 1. Can't access iloader.vemo.is

**Check NPM proxy**:
- Verify WebSockets Support is enabled
- Check forward port is 8080
- Ensure DNS points iloader.vemo.is to your Proxmox IP

**Check container status**:
```bash
ssh root@10.0.2.2
docker ps | grep iloader
docker logs iloader
```

### 2. iOS Device Not Detected

**Check USB passthrough**:
```bash
# On Proxmox host
lsusb | grep -i apple

# In container
docker exec -it iloader lsusb
docker exec -it iloader idevice_id -l
```

**Restart usbmuxd**:
```bash
docker exec -it iloader systemctl restart usbmuxd
```

### 3. Black Screen or No Display

**Check noVNC**:
```bash
docker exec -it iloader ps aux | grep novnc
docker logs iloader | grep novnc
```

**Restart display**:
```bash
docker-compose restart
```

### 4. Login Fails (Anisette)

The app is pre-configured with working anisette servers. If login fails:

1. Try different server from Settings dropdown
2. Test connectivity:
   ```bash
   curl https://ani.sidestore.app/v3/client_info
   ```

## Updating iLoader

To update to a newer version:

```bash
# Pull latest changes
git pull

# Redeploy
./deploy-to-proxmox.sh
```

## Performance Tuning

### Reduce Latency

In `docker-compose.yml`, adjust noVNC quality:

```yaml
environment:
  - DISPLAY=:99
  - NOVNC_QUALITY=9  # 1-9, lower = faster, higher = better quality
```

### Increase Resolution

In `docker/supervisord.conf`, change Xvfb resolution:

```ini
command=/usr/bin/Xvfb :99 -screen 0 2560x1440x24
```

## Security Considerations

1. **Enable SSL** in NPM for iloader.vemo.is
2. **Firewall**: Only allow port 8080 from NPM
3. **Authentication**: iLoader uses Apple ID - no additional auth needed
4. **Updates**: Keep Docker and iLoader updated

## Backup

Backup your iLoader data:

```bash
# Backup configuration and data
ssh root@10.0.2.2
docker cp iloader:/root/.local/share/iloader ./iloader-backup-$(date +%Y%m%d).tar.gz
```

## System Requirements

- **Proxmox Host**: 10.0.2.2
- **RAM**: 2GB minimum for container
- **CPU**: 2 cores recommended
- **Storage**: 5GB for Docker image + app data
- **Network**: Access to port 8080

## Support

If you encounter issues:

1. Check logs: `docker logs iloader`
2. Verify USB: `docker exec -it iloader idevice_id -l`
3. Test NPM: Access `http://10.0.2.2:8080` directly
4. Review `FIXES_APPLIED.md` for known issues

---

**Quick Command Reference**:
```bash
# Deploy
./deploy-to-proxmox.sh

# Check status
ssh root@10.0.2.2 'docker ps | grep iloader'

# View logs
ssh root@10.0.2.2 'docker logs -f iloader'

# Restart
ssh root@10.0.2.2 'cd /opt/iloader && docker-compose restart'

# Update
git pull && ./deploy-to-proxmox.sh
```

Access at: **https://iloader.vemo.is** 🎉
