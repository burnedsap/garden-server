# The Garden

A self-hosted project showcase site for you and your friends. Built on a Raspberry Pi Zero 2 W.

**Stack:**
- [Pocketbase](https://pocketbase.io/) — backend, file storage, auth
- [Zola](https://www.getzola.org/) — static site generator
- [Caddy](https://caddyserver.com/) — web server
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/) — expose Pi without opening ports

**Contributor workflow:**
```bash
garden publish ./my-project/   # that's it
```

---

## Hardware Requirements

- Raspberry Pi Zero 2 W
- MicroSD card (8GB+) **or** USB SSD (recommended for reliability)
- Power supply
- Network connection (WiFi or USB ethernet adapter)

---

## Part 1 — Prepare the Pi

### 1.1 Flash the OS

Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) to flash **Raspberry Pi OS Lite (64-bit)** to your card/SSD.

In the imager settings (gear icon) before flashing:
- Enable SSH with a password or public key
- Set your WiFi credentials
- Set a hostname (e.g. `garden`)

### 1.2 First boot

```bash
# Find the Pi on your network
ssh pi@garden.local   # or use the IP shown on your router

# Update everything
sudo apt-get update && sudo apt-get upgrade -y

# Recommended: if booting from USB SSD, verify with
lsblk
```

---

## Part 2 — Clone this repo onto the Pi

```bash
# On the Pi
sudo apt-get install -y git
git clone https://github.com/YOUR_USERNAME/md-blog.git ~/garden-repo
cd ~/garden-repo
```

Or copy it from your machine:
```bash
# On your local machine
scp -r ./md-blog pi@garden.local:~/garden-repo
```

---

## Part 3 — Run the installer

```bash
cd ~/garden-repo
sudo bash server/install.sh
```

This script will:
- Create a `garden` system user
- Download and install Pocketbase, Zola, Caddy, and cloudflared
- Copy site files, hooks, and scripts into place
- Set up and start systemd services

Takes about 3-5 minutes. You'll see coloured output for each step.

---

## Part 4 — Set up Pocketbase

### 4.1 Create admin account

Open a browser and go to:
```
http://garden.local:8090/_/
```

Create your admin account (email + password). This is for site administration only — keep it separate from contributor accounts.

### 4.2 Verify the migration ran

Go to **Collections** in the admin UI. You should see a `projects` collection with fields:
`title`, `slug`, `contributor`, `description`, `content`, `images`, `attachments`, `tags`

If it's missing, run it manually:
```bash
sudo -u garden /home/garden/pocketbase/pocketbase migrate up \
    --dir /home/garden/pocketbase
```

### 4.3 Create contributor accounts

For each friend, create a user in **Collections → users**:

- Go to **Collections → users → New record**
- Set email and a temporary password
- Tell them their credentials — they'll use these with `garden login`

---

## Part 5 — Set up Cloudflare Tunnel

This lets the Pi be reachable on the internet without exposing your home IP or opening router ports.

### 5.1 Cloudflare prerequisites

- A free [Cloudflare account](https://cloudflare.com)
- A domain added to Cloudflare (even a cheap one works, e.g. from Porkbun/Namecheap)

### 5.2 Authenticate cloudflared on the Pi

```bash
sudo -u garden cloudflared tunnel login
# Opens a browser URL — paste it on your laptop and authorise
```

### 5.3 Create the tunnel

```bash
sudo -u garden cloudflared tunnel create garden
# Note the Tunnel ID printed — you'll need it next
```

### 5.4 Configure the tunnel

Edit the config file:
```bash
nano /home/garden/.cloudflared/config.yml
```

Replace `<TUNNEL_ID>` and `<YOUR_DOMAIN>`:
```yaml
tunnel: abc123-your-tunnel-id
credentials-file: /home/garden/.cloudflared/abc123-your-tunnel-id.json

ingress:
  - hostname: garden.yourdomain.com
    service: http://localhost:80
  - service: http_status:404
```

### 5.5 Add DNS record

```bash
sudo -u garden cloudflared tunnel route dns garden garden.yourdomain.com
```

### 5.6 Start the tunnel service

```bash
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
sudo systemctl status cloudflared
```

Your site should now be live at `https://garden.yourdomain.com`.

---

## Part 6 — Update site config

Edit `site/config.toml` with your real domain:
```toml
base_url = "https://garden.yourdomain.com"
title = "The Garden"
description = "A shared space for projects and ideas."
```

Then push the change to the Pi and rebuild:
```bash
# Copy updated config.toml to Pi
scp site/config.toml pi@garden.local:/home/garden/site/config.toml

# Rebuild the site
ssh pi@garden.local "sudo -u garden bash /home/garden/scripts/rebuild.sh"
```

---

## Part 7 — Install the CLI (for each contributor)

Each person runs this on their own machine (macOS or Linux):

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/md-blog.git
cd md-blog

# Install the CLI
sudo cp cli/garden /usr/local/bin/garden
sudo chmod +x /usr/local/bin/garden

# Verify
garden help
```

**Dependencies:** `curl` and `jq` (both available via Homebrew or apt)
```bash
# macOS
brew install curl jq

# Linux
sudo apt-get install curl jq
```

---

## Part 8 — Contributor workflow

### 8.1 Login (once)

```bash
garden login
# Site URL: https://garden.yourdomain.com
# Email: your@email.com
# Password: ●●●●●●●●
```

Credentials are saved to `~/.config/garden/config` (readable only by you).

### 8.2 Create a project folder

```
my-synth-build/
├── index.md        ← main writeup (required)
├── overview.jpg    ← images (jpg, png, gif, webp)
├── wiring.png
└── schematic.pdf   ← PDFs (optional)
```

**index.md** with optional front matter:
```markdown
+++
title = "DIY Synth Build"
description = "Building a modular synthesiser from scratch"
tags = ["hardware", "audio", "diy"]
+++

## What is it?

A from-scratch modular synthesiser using...
```

If you skip the front matter, the CLI will use the first `# Heading` as the title and the folder name as the slug.

### 8.3 Publish

```bash
garden publish ./my-synth-build/
```

Output:
```
→ Publishing new project: DIY Synth Build
→ Uploading: 1 markdown, 2 image(s), 1 PDF(s)...

Published: DIY Synth Build
URL:       https://garden.yourdomain.com/projects/my-synth-build/

The site will rebuild in a moment.
```

The site auto-rebuilds in ~2 seconds. Refresh and your project is live.

### 8.4 Update a project

Just run `garden publish` again from the same folder — it detects the existing project by slug and updates it.

```bash
garden publish ./my-synth-build/
# → Updating existing project: DIY Synth Build
```

---

## Maintenance

### Check service status

```bash
sudo systemctl status pocketbase caddy cloudflared
```

### View logs

```bash
# Pocketbase
journalctl -u pocketbase -f

# Caddy
journalctl -u caddy -f

# Site rebuilds
tail -f /home/garden/logs/rebuild.log
```

### Manually trigger a rebuild

```bash
ssh pi@garden.local "sudo -u garden bash /home/garden/scripts/rebuild.sh"
```

### Backup Pocketbase data

Pocketbase data lives in `/home/garden/pocketbase/pb_data/`. Back it up with:
```bash
# From your local machine
rsync -av pi@garden.local:/home/garden/pocketbase/pb_data/ ./backups/pb_data/
```

### Update Pocketbase

```bash
# Download new version
PB_VERSION="X.Y.Z"
curl -fsSL "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_arm64.zip" -o /tmp/pb.zip
sudo systemctl stop pocketbase
sudo -u garden unzip -qo /tmp/pb.zip -d /home/garden/pocketbase/
sudo systemctl start pocketbase
```

---

## Project structure

```
md-blog/
├── README.md
├── cli/
│   └── garden                  # upload CLI script
├── server/
│   ├── install.sh              # Pi setup script
│   ├── caddy/
│   │   └── Caddyfile
│   ├── cloudflared/
│   │   └── config.yml          # template (edit with your tunnel ID)
│   ├── pocketbase/
│   │   ├── pb_hooks/
│   │   │   └── main.pb.js      # auto-rebuild on project change
│   │   └── pb_migrations/
│   │       └── 1_init.js       # creates the projects collection
│   ├── scripts/
│   │   └── rebuild.sh          # fetches from Pocketbase, runs Zola
│   └── systemd/
│       ├── pocketbase.service
│       └── cloudflared.service
└── site/                       # Zola site
    ├── config.toml
    ├── content/
    │   ├── _index.md
    │   └── projects/
    │       └── _index.md       # project pages generated by rebuild.sh
    ├── static/
    │   └── style.css
    └── templates/
        ├── base.html
        ├── index.html
        └── projects/
            ├── list.html
            └── single.html
```

---

## Troubleshooting

**Site not rebuilding after publish**
```bash
# Check Pocketbase hook logs
journalctl -u pocketbase -n 50

# Run rebuild manually
sudo -u garden bash /home/garden/scripts/rebuild.sh
```

**`garden login` fails**
- Check the URL has no trailing slash
- Verify Pocketbase is running: `systemctl status pocketbase`
- Verify the tunnel is up: `systemctl status cloudflared`

**Images not showing**
- Images are served via Caddy → Pocketbase proxy at `/api/files/...`
- Check Caddy is running and the Caddyfile has the `/api/*` handler

**Pi runs out of space**
```bash
df -h /home/garden
# Pocketbase stores all uploaded files in pb_data/storage/
# Delete old/unused records via the admin UI to free space
```
