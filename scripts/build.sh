#!/bin/sh
set -eu

IMAGE_NAME="${IMAGE_NAME:-outline-vpn-docker}"
IMAGE_TAGS="${IMAGE_TAGS:-latest}"
PUSH_IMAGE="${PUSH_IMAGE:-false}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
CONTEXT_DIR="${CONTEXT_DIR:-.}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

tag_args=""
for tag in ${IMAGE_TAGS}; do
  tag_args="${tag_args} -t ${IMAGE_NAME}:${tag}"
done

# shellcheck disable=SC2086
eval "docker build -f \"${DOCKERFILE}\" ${tag_args} \"${CONTEXT_DIR}\""

case "$(printf '%s' "$PUSH_IMAGE" | tr '[:upper:]' '[:lower:]')" in
  true|1|yes|on)
    for tag in ${IMAGE_TAGS}; do
      echo "Pushing ${IMAGE_NAME}:${tag}"
      docker push "${IMAGE_NAME}:${tag}"
    done
    ;;
  *)
    echo "Build complete (push disabled)."
    ;;
esac
