# Outline VPN Docker

Preconfigured Docker image for running an Outline VPN server using the official
Outline Shadowbox image.

This project keeps most logic in portable shell scripts so it can be reused in
different CI systems, not only GitHub Actions.

Deployment uses the official Outline installer script, with `SB_IMAGE` pointing
to this preconfigured image.

## What This Image Does

- Uses `quay.io/outline/shadowbox:stable` as the base.
- Bootstraps runtime config using patterns from the official Outline deployment
	script.
- Auto-generates:
	- API secret prefix (`SB_API_PREFIX`)
	- self-signed TLS certificate
	- server config file
- Waits for server readiness and creates the first access key when no keys
	exist.
- Prints Outline Manager connection JSON to container logs.

## Quick Start (Official Installer)

1. Build and publish this image to your registry (for example GHCR).

2. On your Linux server, deploy with the official installer via this wrapper:

```bash
SB_IMAGE=ghcr.io/raymondjxu/outline-vpn-docker:latest \
sh scripts/deploy.sh --hostname <server-ip-or-hostname>
```

This runs the official script from Outline:

- https://raw.githubusercontent.com/OutlineFoundation/outline-apps/master/server_manager/install_scripts/install_server.sh

3. Copy the connection JSON printed by the installer into Outline Manager.

## Quick Start (Direct Docker Run)

Replace `raymondjxu` with your GitHub org/user:

```bash
docker run -d \
	--name outline-vpn \
	--restart unless-stopped \
	--net host \
	-v /opt/outline/persisted-state:/opt/outline/persisted-state \
	-e SB_STATE_DIR=/opt/outline/persisted-state \
	ghcr.io/raymondjxu/outline-vpn-docker:latest
```

View startup logs:

```bash
docker logs -f outline-vpn
```

Look for a line like:

```json
{"apiUrl":"https://<host>:<api-port>/<api-prefix>","certSha256":"<hex>"}
```

Paste that JSON into Outline Manager (Step 2) to manage your server.

## Runtime Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `SB_STATE_DIR` | `/opt/outline/persisted-state` | Persistent state directory |
| `SB_HOSTNAME` | Auto-detected public IPv4 | Hostname/IP used in server config and connection JSON |
| `SB_API_PORT` | `8081` | Management API port (TCP) |
| `SB_KEYS_PORT` | unset | Access key port for new keys (TCP+UDP). If unset, Outline manages ports. |
| `SB_SERVER_NAME` | unset | Optional display name for server |
| `SB_API_PREFIX` | Auto-generated | Secret API path prefix |
| `SB_METRICS_ENABLED` | `false` | Enables anonymous metrics when `true` |
| `SB_CERTIFICATE_FILE` | `$SB_STATE_DIR/shadowbox-selfsigned.crt` | TLS cert path |
| `SB_PRIVATE_KEY_FILE` | `$SB_STATE_DIR/shadowbox-selfsigned.key` | TLS key path |
| `BOOTSTRAP_RETRIES` | `120` | Seconds to wait for API readiness |

## Build And Publish Scripts

All logic is script-based and portable.

Compute tags from git ref/sha:

```bash
CI_REF="refs/heads/main" CI_SHA="$(git rev-parse HEAD)" sh scripts/tags.sh
```

Build image locally:

```bash
IMAGE_NAME=outline-vpn-docker IMAGE_TAGS="latest" sh scripts/build.sh
```

Build and push image (after `docker login`):

```bash
IMAGE_NAME=ghcr.io/raymondjxu/outline-vpn-docker \
IMAGE_TAGS="latest sha-$(git rev-parse --short HEAD)" \
PUSH_IMAGE=true \
sh scripts/build.sh
```

Deploy on a server using the official installer and your image:

```bash
SB_IMAGE=ghcr.io/raymondjxu/outline-vpn-docker:latest \
sh scripts/deploy.sh --hostname <server-ip-or-hostname>
```

Pass-through installer flags are supported:

```bash
SB_IMAGE=ghcr.io/raymondjxu/outline-vpn-docker:latest \
sh scripts/deploy.sh --hostname vpn.example.com --api-port 443 --keys-port 8443
```

## GitHub Actions

Workflow file:

- `.github/workflows/docker-publish.yml`

Behavior:

- Pull requests: build only (no push)
- Push to `main`: build and push `latest` + `sha-<short>`
- Push tag `v*`: build and push `v*` + `sha-<short>`

Skip this workflow for specific commits/PRs by adding one of these markers to
the commit message (push) or PR title:

- `[ci-skip]`
- `[skip ci]`
- `[ci skip]`
- `[no ci]`

## Notes

- Outline commonly runs with host networking for simplicity.
- Open firewall ports for your chosen access key port(s), TCP and UDP.
- Use the official clients and manager from https://getoutline.org/.
- Official installer target host requirement: Linux `x86_64` with Docker daemon.
