#!/usr/bin/env bash
# setup.sh — get The Garden running on a Raspberry Pi Zero 2 W (aarch64)
# Usage: sudo bash setup.sh

set -euo pipefail

green()  { echo -e "\033[0;32m✓ $*\033[0m"; }
yellow() { echo -e "\033[0;33m→ $*\033[0m"; }
die()    { echo -e "\033[0;31m✗ $*\033[0m" >&2; exit 1; }

[[ "$EUID" -eq 0 ]] || die "Run as root: sudo bash setup.sh"
[[ "$(uname -m)" == "aarch64" ]] || die "Expected aarch64 (Pi Zero 2 W with 64-bit OS)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WWW_DIR="/var/www/garden"

# ── Caddy ─────────────────────────────────────────────────────────────────────
if ! command -v caddy &>/dev/null; then
    yellow "Installing Caddy..."
    apt-get update -qq
    apt-get install -y --no-install-recommends curl gnupg
    curl -fsSL 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] \
https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
        | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -qq
    apt-get install -y caddy
fi
green "Caddy: $(caddy version | head -1)"

# ── cloudflared ───────────────────────────────────────────────────────────────
if ! command -v cloudflared &>/dev/null; then
    yellow "Installing cloudflared..."
    curl -fsSL \
        "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" \
        -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
fi
green "cloudflared: $(cloudflared --version)"

# ── Site files ────────────────────────────────────────────────────────────────
yellow "Deploying site files..."
mkdir -p "$WWW_DIR"
cp -r "$SCRIPT_DIR/www/." "$WWW_DIR/"
green "Site deployed to $WWW_DIR"

# ── Caddy config ──────────────────────────────────────────────────────────────
yellow "Configuring Caddy..."
cat > /etc/caddy/Caddyfile << 'EOF'
:80 {
    root * /var/www/garden
    file_server
}
EOF
systemctl enable caddy
systemctl restart caddy
green "Caddy running"

# ── Done ──────────────────────────────────────────────────────────────────────
PI_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
green "Setup complete!"
echo ""
echo "  Local:  http://$PI_IP"
echo ""
echo "  To get a public URL, run:"
echo "  cloudflared tunnel --url http://localhost:80"
echo ""
echo "  Look for a line like:"
echo "  https://xxxx-xxxx.trycloudflare.com"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
