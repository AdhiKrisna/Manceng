#!/bin/sh

set -e

echo "========== Downloading Core Assets =========="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CORE_DIR="$REPO_ROOT/Manceng/Domains"

mkdir -p "$CORE_DIR"

curl -L "$CORE_ASSETS_URL" \
     -o /tmp/Cores.zip

unzip -o /tmp/Cores.zip -d "$CORE_DIR"

echo "========== Core Assets Ready =========="

ls "$CORE_DIR/Cores"
