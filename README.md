# The Garden

A simple site hosted on a Raspberry Pi.

## Setup

Clone the repo on your Pi, then run:

```bash
sudo bash setup.sh
```

That's it. Installs Caddy, deploys the site, and prints your local IP.

## Get a public URL

After setup, run this on the Pi:

```bash
cloudflared tunnel --url http://localhost:80
```

Look for a `trycloudflare.com` link in the output — that's your public URL.

> Note: the URL changes each time you restart the command. A permanent URL can be set up later.

## Update the site

Edit files in `www/`, commit and push, then on the Pi:

```bash
git pull
sudo cp -r www/. /var/www/garden/
```
