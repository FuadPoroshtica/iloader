#!/usr/bin/env bash

# iLoader Deployment to Proxmox
# Run this script from your local machine

set -e

PROXMOX_HOST="root@10.0.2.2"

header() {
  clear
  cat <<"EOF"
    _ _                 _
   (_) |               | |
    _| | ___   __ _  __| | ___ _ __
   | | |/ _ \ / _` |/ _` |/ _ \ '__|
   | | | (_) | (_| | (_| |  __/ |
   |_|_|\___/ \__,_|\__,_|\___|_|

   Proxmox Deployment Script

EOF
}

header

echo "🚀 iLoader Proxmox Deployment"
echo "=============================="
echo ""
echo "This will deploy iLoader to your Proxmox server at $PROXMOX_HOST"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

echo ""
echo "📋 Step 1: Checking Proxmox connectivity..."
if ! ping -c 1 -W 2 10.0.2.2 &> /dev/null; then
    echo "❌ Cannot reach Proxmox server at 10.0.2.2"
    exit 1
fi
echo "✅ Proxmox server is reachable"

echo ""
echo "📋 Step 2: Uploading scripts to Proxmox..."
scp install.sh setup.sh $PROXMOX_HOST:/root/

echo ""
echo "📋 Step 3: Running setup on Proxmox..."
echo "This will create an LXC container and install iLoader..."
echo ""

ssh -t $PROXMOX_HOST 'bash -c "
  chmod +x /root/setup.sh /root/install.sh
  bash /root/setup.sh
"'

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║        🎉 iLoader Deployed Successfully!          ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Next Steps:"
echo ""
echo "1. Get the LXC IP address:"
echo "   ssh $PROXMOX_HOST 'pct list | grep iloader'"
echo ""
echo "2. Configure Nginx Proxy Manager:"
echo "   - Domain: iloader.vemo.is"
echo "   - Forward to: http://<LXC-IP>:8080"
echo "   - Enable: WebSockets Support ✓"
echo "   - Add SSL certificate"
echo ""
echo "3. Access iLoader:"
echo "   https://iloader.vemo.is"
echo ""
echo "Useful Commands:"
echo "  • View LXC list: ssh $PROXMOX_HOST 'pct list'"
echo "  • Enter LXC: ssh $PROXMOX_HOST 'pct enter <ID>'"
echo "  • Check logs: ssh $PROXMOX_HOST 'pct exec <ID> -- supervisorctl status'"
echo ""
