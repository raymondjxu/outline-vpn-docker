#!/bin/sh
set -eu

OFFICIAL_INSTALL_URL="${OFFICIAL_INSTALL_URL:-https://raw.githubusercontent.com/OutlineFoundation/outline-apps/master/server_manager/install_scripts/install_server.sh}"

if [ -z "${SB_IMAGE:-}" ]; then
  echo "SB_IMAGE is required (example: ghcr.io/<owner>/outline-vpn-docker:latest)" >&2
  exit 1
fi

if command -v curl >/dev/null 2>&1; then
  INSTALL_SCRIPT_CONTENT="$(curl --silent --show-error --fail "$OFFICIAL_INSTALL_URL")"
elif command -v wget >/dev/null 2>&1; then
  INSTALL_SCRIPT_CONTENT="$(wget -qO- "$OFFICIAL_INSTALL_URL")"
else
  echo "curl or wget is required" >&2
  exit 1
fi

if [ -z "$INSTALL_SCRIPT_CONTENT" ]; then
  echo "Failed to download official install script" >&2
  exit 1
fi

echo "Running official Outline install script with SB_IMAGE=$SB_IMAGE"

if command -v sudo >/dev/null 2>&1; then
  sudo --preserve-env=SB_IMAGE,SB_DEFAULT_SERVER_NAME,SB_METRICS_ENABLED,WATCHTOWER_REFRESH_SECONDS,CONTAINER_NAME,SHADOWBOX_DIR,ACCESS_CONFIG,SB_API_PORT,SB_PUBLIC_IP \
    bash -c "$INSTALL_SCRIPT_CONTENT" install_server.sh "$@"
else
  bash -c "$INSTALL_SCRIPT_CONTENT" install_server.sh "$@"
fi
