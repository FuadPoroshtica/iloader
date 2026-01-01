#!/bin/bash

# iLoader Proxmox LXC Deployment Script
# Creates LXC container on Proxmox and deploys iLoader with noVNC

set -e

PROXMOX_HOST="root@10.0.2.2"
LXC_ID="200"  # Change if this ID is already in use
LXC_NAME="iloader"
LXC_PASSWORD="iloader123"  # Change this!
LXC_MEMORY="2048"
LXC_CORES="2"
LXC_STORAGE="local-lvm"

echo "🚀 iLoader Proxmox LXC Deployment"
echo "===================================="
echo ""
echo "Configuration:"
echo "  Proxmox Host: $PROXMOX_HOST"
echo "  LXC ID: $LXC_ID"
echo "  LXC Name: $LXC_NAME"
echo "  Memory: ${LXC_MEMORY}MB"
echo "  CPU Cores: $LXC_CORES"
echo ""
read -p "Continue with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi
echo ""

# Step 1: Build the application
echo "📦 Step 1: Building iLoader for Linux..."
echo "This will take 5-10 minutes..."
npm install
npm run build

echo "Building Rust backend..."
cd src-tauri
cargo build --release
cd ..

echo "✅ Build complete!"
echo ""

# Step 2: Create deployment package
echo "📦 Step 2: Creating deployment package..."
rm -rf deploy-package
mkdir -p deploy-package
cp -r dist deploy-package/
cp src-tauri/target/release/iloader deploy-package/
cp Dockerfile deploy-package/
cp docker-compose.yml deploy-package/
cp -r docker deploy-package/

# Create install script for LXC
cat > deploy-package/install.sh << 'INSTALL_EOF'
#!/bin/bash
set -e

echo "🔧 Installing dependencies..."

# Update and install base packages
apt-get update
apt-get install -y \
    curl wget supervisor net-tools \
    xfce4 xfce4-goodies x11vnc xvfb novnc websockify \
    libwebkit2gtk-4.1-0 libayatana-appindicator3-1 \
    libusbmuxd-tools usbmuxd libimobiledevice6

# Set up noVNC
ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Copy files
cp iloader /usr/local/bin/
chmod +x /usr/local/bin/iloader
mkdir -p /app/dist
cp -r dist/* /app/dist/

# Set up supervisor
mkdir -p /var/log/supervisor
cp -r docker/supervisord.conf /etc/supervisor/conf.d/

# Enable and start services
systemctl enable supervisor
systemctl start supervisor

echo "✅ Installation complete!"
echo "iLoader is now running on port 8080"
INSTALL_EOF

chmod +x deploy-package/install.sh

echo "✅ Package created!"
echo ""

# Step 3: Create LXC on Proxmox
echo "🐳 Step 3: Creating LXC container on Proxmox..."

ssh $PROXMOX_HOST << EOF
set -e

# Check if LXC already exists
if pct status $LXC_ID &> /dev/null; then
    echo "⚠️  LXC $LXC_ID already exists. Stopping and removing..."
    pct stop $LXC_ID || true
    pct destroy $LXC_ID || true
    sleep 2
fi

echo "Creating LXC container..."

# Download Ubuntu template if not exists
if [ ! -f /var/lib/vz/template/cache/ubuntu-22.04-standard_22.04-1_amd64.tar.zst ]; then
    echo "Downloading Ubuntu 22.04 template..."
    pveam update
    pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
fi

# Create LXC container
pct create $LXC_ID \
    local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
    --hostname $LXC_NAME \
    --memory $LXC_MEMORY \
    --cores $LXC_CORES \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp,firewall=1 \
    --storage $LXC_STORAGE \
    --rootfs $LXC_STORAGE:8 \
    --password "$LXC_PASSWORD" \
    --unprivileged 0 \
    --features nesting=1

# Enable USB passthrough
echo "lxc.cgroup2.devices.allow: c 189:* rwm" >> /etc/pve/lxc/${LXC_ID}.conf
echo "lxc.mount.entry: /dev/bus/usb dev/bus/usb none bind,optional,create=dir" >> /etc/pve/lxc/${LXC_ID}.conf

# Start the container
pct start $LXC_ID

echo "✅ LXC container created and started"
echo "Waiting for container to boot..."
sleep 5

# Get LXC IP
LXC_IP=\$(pct exec $LXC_ID -- hostname -I | awk '{print \$1}')
echo "LXC IP: \$LXC_IP"
echo "\$LXC_IP" > /tmp/iloader_lxc_ip.txt
EOF

LXC_IP=$(ssh $PROXMOX_HOST cat /tmp/iloader_lxc_ip.txt)
echo "✅ LXC container ready at $LXC_IP"
echo ""

# Step 4: Transfer files to LXC
echo "📤 Step 4: Transferring files to LXC..."

# Transfer via Proxmox host
scp -r deploy-package/* $PROXMOX_HOST:/tmp/iloader-deploy/

ssh $PROXMOX_HOST << EOF
pct push $LXC_ID /tmp/iloader-deploy /root/iloader-deploy -perms 755
rm -rf /tmp/iloader-deploy
EOF

echo "✅ Files transferred!"
echo ""

# Step 5: Install and start iLoader in LXC
echo "🚀 Step 5: Installing iLoader in LXC..."

ssh $PROXMOX_HOST << EOF
pct exec $LXC_ID -- bash -c "cd /root/iloader-deploy && ./install.sh"
EOF

echo "✅ Installation complete!"
echo ""

# Cleanup
rm -rf deploy-package

# Final status
echo "╔════════════════════════════════════════════════════╗"
echo "║        🎉 iLoader Deployed Successfully!          ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Access Information:"
echo "  • LXC ID: $LXC_ID"
echo "  • LXC IP: $LXC_IP"
echo "  • LXC Password: $LXC_PASSWORD"
echo "  • Web Interface: http://$LXC_IP:8080"
echo "  • VNC Port: 5900"
echo ""
echo "Next Steps:"
echo ""
echo "1. Configure Nginx Proxy Manager:"
echo "   - Domain: iloader.vemo.is"
echo "   - Forward to: http://$LXC_IP:8080"
echo "   - Enable WebSockets Support ✓"
echo "   - Add SSL certificate"
echo ""
echo "2. Access iLoader:"
echo "   - Direct: http://$LXC_IP:8080"
echo "   - Domain: https://iloader.vemo.is (after NPM config)"
echo ""
echo "3. Connect iOS device to Proxmox USB port"
echo ""
echo "Useful Commands:"
echo "  • View LXC console: ssh $PROXMOX_HOST 'pct enter $LXC_ID'"
echo "  • Check logs: ssh $PROXMOX_HOST 'pct exec $LXC_ID -- supervisorctl status'"
echo "  • Restart iLoader: ssh $PROXMOX_HOST 'pct exec $LXC_ID -- supervisorctl restart iloader'"
echo "  • Stop LXC: ssh $PROXMOX_HOST 'pct stop $LXC_ID'"
echo "  • Start LXC: ssh $PROXMOX_HOST 'pct start $LXC_ID'"
echo ""
