#!/bin/bash
set -e

PANEL_URL="${1:-}"
API_KEY="${2:-}"
NODE_ID="${3:-}"

if [ -z "$PANEL_URL" ] || [ -z "$API_KEY" ] || [ -z "$NODE_ID" ]; then
    echo "Usage: bash deploy_node.sh <PANEL_URL> <API_KEY> <NODE_ID>"
    echo "Example: bash deploy_node.sh http://3.112.68.113/api/v1 your-api-key 1"
    exit 1
fi

echo "=== Pioneer Node Deploy ==="
echo "Panel:   ${PANEL_URL}"
echo "Node ID: ${NODE_ID}"

# Idempotent: stop and clean any existing pioneer install before proceeding
echo "[0/5] Cleaning up old installation..."
if systemctl list-unit-files 2>/dev/null | grep -q '^pioneer\.service'; then
    sudo systemctl stop pioneer 2>/dev/null || true
    sudo systemctl disable pioneer 2>/dev/null || true
fi
sudo rm -f /etc/systemd/system/pioneer.service
sudo rm -f /opt/pioneer/xray /opt/pioneer/config.json
sudo systemctl daemon-reload 2>/dev/null || true
# Kill any stray xray process bound to /opt/pioneer in case systemd was bypassed
sudo pkill -f "/opt/pioneer/xray" 2>/dev/null || true
sleep 1

echo "[1/5] Downloading xray from GitHub..."
sudo mkdir -p /opt/pioneer
sudo curl -sL -o /opt/pioneer/xray "https://github.com/skwoksn12/testetete/raw/main/xray-linux?t=$(date +%s)"
sudo chmod +x /opt/pioneer/xray

echo "[2/5] Downloading geosite.dat and geoip.dat..."
GEODAT_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download"
sudo curl -sL -o /opt/pioneer/geosite.dat "${GEODAT_URL}/geosite.dat"
sudo curl -sL -o /opt/pioneer/geoip.dat "${GEODAT_URL}/geoip.dat"
echo "  geosite.dat: $(du -h /opt/pioneer/geosite.dat | cut -f1)"
echo "  geoip.dat:   $(du -h /opt/pioneer/geoip.dat | cut -f1)"

echo "[3/5] Creating config..."
sudo bash -c "cat > /opt/pioneer/config.json << EOF
{
  \"apiUrl\": \"${PANEL_URL}\",
  \"apiKey\": \"${API_KEY}\",
  \"nodeId\": ${NODE_ID}
}
EOF"

echo "[4/5] Writing systemd unit..."
sudo bash -c 'cat > /etc/systemd/system/pioneer.service << SEOF
[Unit]
Description=Pioneer Node
After=network.target

[Service]
WorkingDirectory=/opt/pioneer
ExecStart=/opt/pioneer/xray run -c /opt/pioneer/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
SEOF'

echo "[5/5] Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable pioneer
sudo systemctl restart pioneer
sleep 5

echo ""
echo "======================================="
echo "  Pioneer Node Deployed Successfully"
echo "======================================="
echo "Status:  $(sudo systemctl is-active pioneer)"
echo "Panel:   ${PANEL_URL}"
echo "Node ID: ${NODE_ID}"
echo ""
echo "Logs: sudo journalctl -u pioneer -f"
echo "======================================="
