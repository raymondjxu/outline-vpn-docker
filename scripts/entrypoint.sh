#!/bin/sh
set -eu

log() {
  printf '%s\n' "[outline-bootstrap] $*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

is_true() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    true|1|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

normalize_bool() {
  if is_true "$1"; then
    printf '%s' "true"
  else
    printf '%s' "false"
  fi
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

detect_hostname() {
  for url in https://icanhazip.com/ https://ipinfo.io/ip https://domains.google.com/checkip; do
    value="$(curl --silent --show-error --fail --ipv4 "$url" 2>/dev/null || true)"
    value="$(printf '%s' "$value" | tr -d '\r\n[:space:]')"
    if [ -n "$value" ]; then
      printf '%s' "$value"
      return 0
    fi
  done

  value="$(hostname 2>/dev/null || true)"
  value="$(printf '%s' "$value" | tr -d '\r\n[:space:]')"
  if [ -n "$value" ]; then
    printf '%s' "$value"
    return 0
  fi

  printf '%s' "127.0.0.1"
}

generate_api_prefix() {
  value="$(openssl rand -base64 16 2>/dev/null || true)"
  if [ -n "$value" ]; then
    printf '%s' "$value" | tr '/+' '_-' | tr -d '=\n'
    return 0
  fi

  head -c 16 /dev/urandom | base64 | tr '/+' '_-' | tr -d '=\n'
}

validate_port() {
  port="$1"
  name="$2"

  case "$port" in
    ''|*[!0-9]*)
      log "$name must be a number between 1 and 65535."
      exit 1
      ;;
  esac

  if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    log "$name must be between 1 and 65535."
    exit 1
  fi
}

certificate_fingerprint() {
  openssl x509 -in "$SB_CERTIFICATE_FILE" -noout -sha256 -fingerprint | sed 's/.*=//' | tr -d ':'
}

write_server_config() {
  config_file="$SB_STATE_DIR/shadowbox_server_config.json"
  hostname_json="$(json_escape "$SB_HOSTNAME")"
  metrics_json="$(normalize_bool "${SB_METRICS_ENABLED:-false}")"
  server_name="${SB_SERVER_NAME:-}"

  {
    printf '{'
    printf '"hostname":"%s"' "$hostname_json"

    if [ -n "$server_name" ]; then
      printf ',"name":"%s"' "$(json_escape "$server_name")"
    fi

    if [ -n "${SB_KEYS_PORT:-}" ]; then
      validate_port "$SB_KEYS_PORT" "SB_KEYS_PORT"
      printf ',"portForNewAccessKeys":%s' "$SB_KEYS_PORT"
    fi

    printf ',"metricsEnabled":%s' "$metrics_json"
    printf '}\n'
  } > "$config_file"
}

bootstrap_access_key() {
  retries="${BOOTSTRAP_RETRIES:-120}"
  validate_port "$SB_API_PORT" "SB_API_PORT"

  api_url="https://localhost:${SB_API_PORT}/${SB_API_PREFIX}"
  count=0
  while [ "$count" -lt "$retries" ]; do
    keys_json="$(curl --silent --show-error --insecure --fail "$api_url/access-keys" 2>/dev/null || true)"
    if [ -n "$keys_json" ]; then
      if printf '%s' "$keys_json" | grep -q '"id"[[:space:]]*:'; then
        log "Access keys already exist. Skipping bootstrap key creation."
      else
        created_json="$(curl --silent --show-error --insecure --fail -X POST "$api_url/access-keys" 2>/dev/null || true)"
        access_url="$(printf '%s' "$created_json" | sed -n 's/.*"accessUrl"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
        if [ -n "$access_url" ]; then
          log "First access key: $access_url"
        else
          log "Created first access key."
        fi
      fi

      cert_sha256="$(certificate_fingerprint)"
      connection_json="$(printf '{"apiUrl":"https://%s:%s/%s","certSha256":"%s"}' "$SB_HOSTNAME" "$SB_API_PORT" "$SB_API_PREFIX" "$cert_sha256")"
      log "Outline Manager connection: $connection_json"
      return 0
    fi

    count=$((count + 1))
    sleep 1
  done

  log "Timed out waiting for Outline API after ${retries}s."
}

main() {
  require_cmd curl
  require_cmd openssl

  umask 0007

  SB_STATE_DIR="${SB_STATE_DIR:-/opt/outline/persisted-state}"
  SB_API_PORT="${SB_API_PORT:-8081}"
  SB_HOSTNAME="${SB_HOSTNAME:-$(detect_hostname)}"
  SB_API_PREFIX="${SB_API_PREFIX:-$(generate_api_prefix)}"
  SB_CERTIFICATE_FILE="${SB_CERTIFICATE_FILE:-$SB_STATE_DIR/shadowbox-selfsigned.crt}"
  SB_PRIVATE_KEY_FILE="${SB_PRIVATE_KEY_FILE:-$SB_STATE_DIR/shadowbox-selfsigned.key}"
  SB_PUBLIC_IP="${SB_PUBLIC_IP:-$SB_HOSTNAME}"

  validate_port "$SB_API_PORT" "SB_API_PORT"

  mkdir -p "$SB_STATE_DIR"

  if [ ! -s "$SB_CERTIFICATE_FILE" ] || [ ! -s "$SB_PRIVATE_KEY_FILE" ]; then
    log "Generating self-signed certificate."
    openssl req \
      -x509 \
      -nodes \
      -days 36500 \
      -newkey rsa:4096 \
      -subj "/CN=${SB_HOSTNAME}" \
      -keyout "$SB_PRIVATE_KEY_FILE" \
      -out "$SB_CERTIFICATE_FILE" \
      >/dev/null 2>&1
  fi

  write_server_config

  export SB_STATE_DIR
  export SB_API_PORT
  export SB_API_PREFIX
  export SB_CERTIFICATE_FILE
  export SB_PRIVATE_KEY_FILE
  export SB_PUBLIC_IP

  log "Starting Outline server."
  log "State dir: $SB_STATE_DIR"
  log "API URL prefix: $SB_API_PREFIX"

  bootstrap_access_key &

  exec /cmd.sh
}

main "$@"
