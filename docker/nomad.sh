#!/usr/bin/env bash
# Wrapper: runs HashiCorp Nomad CLI inside a Docker container.
# Usage: ./docker/nomad.sh [nomad args...]
# Example: ./docker/nomad.sh job run /workspace/nomad/jobs/vault.nomad.hcl

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

# Pass through Nomad address if set
for var in NOMAD_ADDR NOMAD_TOKEN VAULT_ADDR VAULT_TOKEN; do
  if [[ -n "${!var:-}" ]]; then
    ENV_ARGS+=(--env "${var}=${!var}")
  fi
done

exec docker run --rm -it \
  --net=host \
  -v "${PROJECT_ROOT}:/workspace" \
  -w /workspace \
  "${ENV_ARGS[@]}" \
  hashicorp/nomad:1.9 \
  "$@"
