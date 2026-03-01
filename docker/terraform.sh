#!/usr/bin/env bash
# Wrapper: runs HashiCorp Terraform inside a Docker container.
# Usage: ./docker/terraform.sh [terraform args...]
# Example: ./docker/terraform.sh -chdir=/workspace/terraform init

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
  -w /workspace/terraform \
  -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent \
  --network host \
  "${ENV_ARGS[@]}" \
  hashicorp/terraform:1.9 \
  "$@"
