#!/usr/bin/env bash
# rebuild.sh — fetch projects from Pocketbase and rebuild the Zola site
set -euo pipefail

PB_URL="http://127.0.0.1:8090"
GARDEN_DIR="/home/garden"
SITE_DIR="$GARDEN_DIR/site"
CONTENT_DIR="$SITE_DIR/content/projects"
OUTPUT_DIR="/var/www/garden"
LOG_DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$LOG_DATE] Starting rebuild..."

# Ensure content dir exists and clear old generated files
mkdir -p "$CONTENT_DIR"
find "$CONTENT_DIR" -name "*.md" ! -name "_index.md" -delete

# Fetch all projects sorted by newest first
PROJECTS=$(curl -sf \
    "$PB_URL/api/collections/projects/records?perPage=500&sort=-created" \
    || echo '{"items":[]}')

COUNT=$(echo "$PROJECTS" | jq '.items | length')
echo "[$LOG_DATE] Found $COUNT project(s)"

# Write a markdown file for each project
echo "$PROJECTS" | jq -c '.items[]' | while IFS= read -r project; do
    id=$(echo "$project" | jq -r '.id')
    title=$(echo "$project" | jq -r '.title')
    slug=$(echo "$project" | jq -r '.slug')
    contributor=$(echo "$project" | jq -r '.contributor')
    description=$(echo "$project" | jq -r '.description // ""')
    content=$(echo "$project" | jq -r '.content // ""')
    created=$(echo "$project" | jq -r '.created' | cut -c1-10)
    tags=$(echo "$project" | jq -r '.tags // [] | join(", ")')

    # Build image URL list (served via Caddy → Pocketbase proxy)
    images_toml=""
    while IFS= read -r img; do
        [[ -z "$img" ]] && continue
        images_toml+="  \"/api/files/projects/$id/$img\","$'\n'
    done < <(echo "$project" | jq -r '.images[]? // empty')

    # Build attachment URL list
    attachments_toml=""
    while IFS= read -r att; do
        [[ -z "$att" ]] && continue
        attachments_toml+="  \"/api/files/projects/$id/$att\","$'\n'
    done < <(echo "$project" | jq -r '.attachments[]? // empty')

    # Write front matter + content
    cat > "$CONTENT_DIR/$slug.md" <<MDEOF
+++
title = "$title"
date = "$created"

[extra]
contributor = "$contributor"
description = "$description"
tags = "$tags"
images = [
$(echo -n "$images_toml")
]
attachments = [
$(echo -n "$attachments_toml")
]
+++

$content
MDEOF

    echo "[$LOG_DATE]   → wrote $slug.md"
done

# Build the static site
cd "$SITE_DIR"
zola build --output-dir "$OUTPUT_DIR" --force 2>&1

echo "[$LOG_DATE] Rebuild complete. Output: $OUTPUT_DIR"
