#!/bin/bash

# iLoader Proxmox Deployment Script
# This script deploys iLoader to your Proxmox server at 10.0.2.2

set -e

PROXMOX_HOST="root@10.0.2.2"
DEPLOY_DIR="/opt/iloader"

echo "🚀 iLoader Deployment to Proxmox"
echo "=================================="
echo ""

# Step 1: Build the application
echo "📦 Step 1: Building iLoader..."
npm install
npm run build
cd src-tauri
cargo build --release
cd ..

echo "✅ Build complete!"
echo ""

# Step 2: Create deployment package
echo "📦 Step 2: Creating deployment package..."
mkdir -p deploy-package
cp -r dist deploy-package/
cp src-tauri/target/release/iloader deploy-package/
cp Dockerfile deploy-package/
cp docker-compose.yml deploy-package/
cp -r docker deploy-package/

echo "✅ Package created!"
echo ""

# Step 3: Transfer to Proxmox
echo "📤 Step 3: Transferring to Proxmox..."
ssh $PROXMOX_HOST "mkdir -p $DEPLOY_DIR"
scp -r deploy-package/* $PROXMOX_HOST:$DEPLOY_DIR/

echo "✅ Transfer complete!"
echo ""

# Step 4: Deploy on Proxmox
echo "🐳 Step 4: Deploying Docker container..."
ssh $PROXMOX_HOST << 'EOF'
cd /opt/iloader

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# Install Docker Compose if not already installed
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Stop existing container if running
docker-compose down 2>/dev/null || true

# Build and start the container
docker-compose up -d --build

echo ""
echo "✅ iLoader deployed successfully!"
echo ""
echo "Access your iLoader instance at:"
echo "  - Local: http://10.0.2.2:8080"
echo "  - Domain: http://iloader.vemo.is (configure in Nginx Proxy Manager)"
echo ""
echo "Nginx Proxy Manager Configuration:"
echo "  1. Add new Proxy Host"
echo "  2. Domain: iloader.vemo.is"
echo "  3. Forward to: 10.0.2.2:8080"
echo "  4. Enable WebSockets"
echo "  5. Add SSL certificate if needed"
EOF

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Configure Nginx Proxy Manager:"
echo "   - Domain: iloader.vemo.is"
echo "   - Forward to: http://10.0.2.2:8080"
echo "   - Enable: Cache Assets, Websockets Support"
echo "2. Access iLoader at: http://iloader.vemo.is"
echo "3. Connect iOS device via USB to Proxmox host"
echo ""
