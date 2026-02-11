#!/usr/bin/env bash
# Wrapper: runs HashiCorp Packer inside a Docker container.
# Usage: ./docker/packer.sh [packer args...]
# Example: ./docker/packer.sh build /workspace/packer/ubuntu-nomad

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load environment if present
ENV_ARGS=()
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    ENV_ARGS+=(--env "$line")
  done < "${PROJECT_ROOT}/.env"
fi

# Pass through Proxmox credentials if set in shell
for var in PVE_API_URL PVE_API_TOKEN_ID PVE_API_TOKEN_SECRET; do
  if [[ -n "${!var:-}" ]]; then
    ENV_ARGS+=(--env "${var}=${!var}")
  fi
done

exec docker run --rm -it \
  -v "${PROJECT_ROOT}:/workspace" \
  -w /workspace/packer/ubuntu-nomad \
  "${ENV_ARGS[@]}" \
  hashicorp/packer:1.11 \
  "$@"
