#!/usr/bin/env bash
# install.sh — set up the garden server on a Raspberry Pi Zero 2 W
# Run as root or with sudo: sudo bash install.sh
# Tested on: Raspberry Pi OS Lite 64-bit (Debian Bookworm)

set -euo pipefail

# ── Versions (update as needed) ───────────────────────────────────────────────
POCKETBASE_VERSION="0.22.20"
ZOLA_VERSION="0.19.2"
CLOUDFLARED_VERSION="2024.12.2"

# ── Paths ─────────────────────────────────────────────────────────────────────
GARDEN_USER="garden"
GARDEN_HOME="/home/garden"
SITE_DIR="$GARDEN_HOME/site"
OUTPUT_DIR="/var/www/garden"
LOG_DIR="$GARDEN_HOME/logs"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Helpers ───────────────────────────────────────────────────────────────────
green()  { echo -e "\033[0;32m✓ $*\033[0m"; }
yellow() { echo -e "\033[0;33m→ $*\033[0m"; }
die()    { echo -e "\033[0;31m✗ $*\033[0m" >&2; exit 1; }

[[ "$EUID" -eq 0 ]] || die "Run as root: sudo bash install.sh"

ARCH=$(uname -m)
[[ "$ARCH" == "aarch64" ]] || die "Expected aarch64 (Pi Zero 2 W with 64-bit OS), got: $ARCH"

yellow "Starting garden server installation..."

# ── System packages ───────────────────────────────────────────────────────────
yellow "Installing system packages..."
apt-get update -qq
apt-get install -y --no-install-recommends \
    curl jq unzip ca-certificates gnupg lsb-release

green "System packages installed"

# ── Create garden user ────────────────────────────────────────────────────────
if ! id "$GARDEN_USER" &>/dev/null; then
    yellow "Creating user: $GARDEN_USER"
    useradd --system --create-home --shell /bin/bash "$GARDEN_USER"
    green "User created: $GARDEN_USER"
else
    green "User already exists: $GARDEN_USER"
fi

# ── Create directories ────────────────────────────────────────────────────────
yellow "Creating directories..."
mkdir -p \
    "$GARDEN_HOME/pocketbase" \
    "$GARDEN_HOME/pocketbase/pb_hooks" \
    "$GARDEN_HOME/pocketbase/pb_migrations" \
    "$GARDEN_HOME/scripts" \
    "$GARDEN_HOME/.cloudflared" \
    "$LOG_DIR" \
    "$OUTPUT_DIR"

green "Directories created"

# ── Install Caddy ─────────────────────────────────────────────────────────────
yellow "Installing Caddy..."
if ! command -v caddy &>/dev/null; then
    curl -fsSL 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] \
https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
        | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -qq
    apt-get install -y caddy
fi
green "Caddy installed: $(caddy version)"

# ── Install Pocketbase ────────────────────────────────────────────────────────
yellow "Downloading Pocketbase v${POCKETBASE_VERSION}..."
PB_ZIP="pocketbase_${POCKETBASE_VERSION}_linux_arm64.zip"
PB_URL="https://github.com/pocketbase/pocketbase/releases/download/v${POCKETBASE_VERSION}/${PB_ZIP}"
curl -fsSL "$PB_URL" -o "/tmp/$PB_ZIP"
unzip -qo "/tmp/$PB_ZIP" -d "$GARDEN_HOME/pocketbase/"
rm "/tmp/$PB_ZIP"
chmod +x "$GARDEN_HOME/pocketbase/pocketbase"
green "Pocketbase installed: $($GARDEN_HOME/pocketbase/pocketbase --version)"

# ── Install Zola ──────────────────────────────────────────────────────────────
yellow "Downloading Zola v${ZOLA_VERSION}..."
ZOLA_TAR="zola-v${ZOLA_VERSION}-aarch64-unknown-linux-gnu.tar.gz"
ZOLA_URL="https://github.com/getzola/zola/releases/download/v${ZOLA_VERSION}/${ZOLA_TAR}"
curl -fsSL "$ZOLA_URL" -o "/tmp/$ZOLA_TAR"
tar -xzf "/tmp/$ZOLA_TAR" -C /usr/local/bin/ zola
rm "/tmp/$ZOLA_TAR"
chmod +x /usr/local/bin/zola
green "Zola installed: $(zola --version)"

# ── Install Cloudflared ───────────────────────────────────────────────────────
yellow "Downloading cloudflared v${CLOUDFLARED_VERSION}..."
CF_URL="https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-arm64"
curl -fsSL "$CF_URL" -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
green "Cloudflared installed: $(cloudflared --version)"

# ── Copy site files ───────────────────────────────────────────────────────────
yellow "Copying site files..."
rsync -av --delete "$REPO_ROOT/site/" "$SITE_DIR/" 2>/dev/null \
    || cp -r "$REPO_ROOT/site/." "$SITE_DIR/"
green "Site files copied to $SITE_DIR"

# ── Copy Pocketbase hooks and migrations ─────────────────────────────────────
yellow "Copying Pocketbase hooks and migrations..."
cp "$REPO_ROOT/server/pocketbase/pb_hooks/"*.js "$GARDEN_HOME/pocketbase/pb_hooks/"
cp "$REPO_ROOT/server/pocketbase/pb_migrations/"*.js "$GARDEN_HOME/pocketbase/pb_migrations/"
green "Hooks and migrations copied"

# ── Copy scripts ──────────────────────────────────────────────────────────────
yellow "Copying scripts..."
cp "$REPO_ROOT/server/scripts/rebuild.sh" "$GARDEN_HOME/scripts/rebuild.sh"
chmod +x "$GARDEN_HOME/scripts/rebuild.sh"
green "Scripts copied"

# ── Copy Caddy config ─────────────────────────────────────────────────────────
yellow "Configuring Caddy..."
mkdir -p /etc/caddy
cp "$REPO_ROOT/server/caddy/Caddyfile" /etc/caddy/Caddyfile
green "Caddyfile installed"

# ── Fix ownership ─────────────────────────────────────────────────────────────
yellow "Setting file ownership..."
chown -R "$GARDEN_USER:$GARDEN_USER" "$GARDEN_HOME" "$OUTPUT_DIR"
green "Ownership set"

# ── Install systemd services ──────────────────────────────────────────────────
yellow "Installing systemd services..."
cp "$REPO_ROOT/server/systemd/pocketbase.service"  /etc/systemd/system/
cp "$REPO_ROOT/server/systemd/cloudflared.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable pocketbase caddy
green "Systemd services installed"

# ── Initial Zola build ────────────────────────────────────────────────────────
yellow "Running initial Zola build..."
cd "$SITE_DIR"
su -c "zola build --output-dir $OUTPUT_DIR --force" "$GARDEN_USER" 2>&1 || true
green "Initial site built"

# ── Start services ────────────────────────────────────────────────────────────
yellow "Starting Pocketbase and Caddy..."
systemctl restart pocketbase caddy
sleep 2
systemctl is-active pocketbase && green "Pocketbase running" || echo "Warning: Pocketbase may not have started"
systemctl is-active caddy      && green "Caddy running"      || echo "Warning: Caddy may not have started"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────"
green "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Set up Cloudflare Tunnel (see README.md)"
echo "  2. Open Pocketbase admin: http://$(hostname -I | awk '{print $1}'):8090/_/"
echo "  3. Create your admin account and add contributor users"
echo "  4. Update site/config.toml with your domain"
echo "  5. Rebuild the site after updating config:"
echo "       sudo -u garden bash $GARDEN_HOME/scripts/rebuild.sh"
echo ""
echo "Logs:"
echo "  journalctl -u pocketbase -f"
echo "  journalctl -u caddy -f"
echo "  tail -f $LOG_DIR/rebuild.log"
echo "────────────────────────────────────────────────────"
