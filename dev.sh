#!/bin/bash

set -euo pipefail

IMAGE_TAG="dev:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${SCRIPT_DIR}/dev.dockerfile"

# Allow user to select container runtime via env var; default prefers Podman.
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-}"
if [[ -z "${CONTAINER_RUNTIME}" ]]; then
    if command -v podman >/dev/null 2>&1; then
        CONTAINER_RUNTIME="podman"
    elif command -v docker >/dev/null 2>&1; then
        CONTAINER_RUNTIME="docker"
    else
        echo "Error: neither podman nor docker found in PATH." >&2
        exit 1
    fi
fi

# dev.sh --build rebuilds and exits. Extra args are passed to the build command.
# Example: CONTAINER_RUNTIME=podman ./dev.sh --build --no-cache
if [[ ${1-} == "--build" ]]; then
    shift || true
    DOCKER_BUILDKIT=1 "$CONTAINER_RUNTIME" build \
        --file "$DOCKERFILE" \
        --tag "$IMAGE_TAG" \
        "$@" \
        "$SCRIPT_DIR"
    exit 0
fi

MOUNT_FLAGS=()
add_mount() {
    local src="$1"
    local dest="$2"
    if [[ -d "$src" ]]; then
        MOUNT_FLAGS+=(-v "${src}:${dest}")
    else
        echo "Warning: skipping mount because host path is missing: ${src}" >&2
    fi
}

add_mount "$HOME/.codex" /home/vscode/.codex
add_mount "$HOME/.config/gh" /home/vscode/.config/gh
add_mount "$HOME/.cache/pip" /home/vscode/.cache/pip
add_mount "$HOME/.cache/uv" /home/vscode/.cache/uv
add_mount "$HOME/.npm" /home/vscode/.npm
add_mount "$HOME/.local/share/uv" /home/vscode/.local/share/uv

MOUNT_FLAGS+=(-v "$PWD:$PWD")

"$CONTAINER_RUNTIME" run --rm -i -t \
    -u 1000:1000 \
    -e HOME=/home/vscode \
    "${MOUNT_FLAGS[@]}" \
    -w "$PWD" \
    --entrypoint /bin/bash \
    "$IMAGE_TAG" \
    "$@"
