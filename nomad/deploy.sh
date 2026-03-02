#!/usr/bin/env bash
# Deploy Nomad jobs in order with health checks between each step.
# Usage: ./nomad/deploy.sh
# Requires: NOMAD_ADDR environment variable set to a Nomad node.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
JOBS_DIR="/workspace/nomad/jobs"
NOMAD="${PROJECT_ROOT}/docker/nomad.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[deploy]${NC} $*"; }
warn()  { echo -e "${YELLOW}[deploy]${NC} $*"; }
error() { echo -e "${RED}[deploy]${NC} $*" >&2; }

wait_for_job() {
  local job_name="$1"
  local max_wait="${2:-120}"
  local interval=5
  local elapsed=0

  log "Waiting for job '${job_name}' to be healthy (max ${max_wait}s)..."

  while [[ $elapsed -lt $max_wait ]]; do
    local status
    status="$($NOMAD job status -short "$job_name" 2>/dev/null | grep -i "status" | head -1 || true)"

    if echo "$status" | grep -qi "running"; then
      # Check all allocations are healthy
      local unhealthy
      unhealthy="$($NOMAD job status "$job_name" 2>/dev/null | grep -c "unhealthy\|pending\|failed" || true)"
      if [[ "$unhealthy" -eq 0 ]]; then
        log "Job '${job_name}' is healthy."
        return 0
      fi
    fi

    sleep "$interval"
    elapsed=$((elapsed + interval))
    warn "  ...waiting (${elapsed}s)"
  done

  error "Job '${job_name}' did not become healthy within ${max_wait}s."
  $NOMAD job status "$job_name" || true
  return 1
}

# Pre-flight check
if [[ -z "${NOMAD_ADDR:-}" ]]; then
  error "NOMAD_ADDR is not set. Example: export NOMAD_ADDR=http://192.168.1.50:4646"
  exit 1
fi

log "Using NOMAD_ADDR=${NOMAD_ADDR}"
log ""

# ============================================================
# Step 1: Deploy Vault
# ============================================================
log "=== Step 1: Deploying Vault ==="
$NOMAD job run "${JOBS_DIR}/vault.nomad.hcl"
wait_for_job "vault" 180

echo ""
warn "============================================"
warn "  Vault is running but needs initialization!"
warn "============================================"
warn ""
warn "  1. Initialize Vault:"
warn "     export VAULT_ADDR=http://<any-nomad-ip>:8200"
warn "     vault operator init -key-shares=1 -key-threshold=1"
warn ""
warn "  2. Unseal Vault on each node:"
warn "     vault operator unseal <unseal-key>"
warn ""
warn "  3. Login and configure:"
warn "     vault login <root-token>"
warn "     vault secrets enable -path=secret kv-v2"
warn ""
warn "  4. Store required secrets:"
warn "     vault kv put secret/authentik/db password=<generated>"
warn "     vault kv put secret/authentik/secret key=<generated>"
warn "     vault kv put secret/guacamole/db password=<generated>"
warn "     vault kv put secret/guacamole/oidc client_id=<from-authentik>"
warn ""
warn "  5. Create Vault policies:"
warn "     vault policy write authentik - <<'POLICY'"
warn '     path "secret/data/authentik/*" { capabilities = ["read"] }'
warn "     POLICY"
warn "     vault policy write guacamole - <<'POLICY'"
warn '     path "secret/data/guacamole/*" { capabilities = ["read"] }'
warn "     POLICY"
warn ""
warn "  6. Create a Nomad server token:"
warn "     vault token create -policy=nomad-server -orphan -period=72h"
warn "     (Then update /etc/nomad.d/nomad.hcl with vault stanza on each node)"
warn ""
warn "Press Enter after Vault is initialized and secrets are stored..."
read -r

# ============================================================
# Step 2: Deploy Traefik
# ============================================================
log "=== Step 2: Deploying Traefik ==="
$NOMAD job run "${JOBS_DIR}/traefik.nomad.hcl"
wait_for_job "traefik" 60

# ============================================================
# Step 3: Deploy Authentik
# ============================================================
log "=== Step 3: Deploying Authentik ==="
$NOMAD job run "${JOBS_DIR}/authentik.nomad.hcl"
wait_for_job "authentik" 180

echo ""
warn "Authentik is running. Access at: https://authentik.<domain>/if/flow/initial-setup/"
warn "Create admin account, then set up OIDC provider for Guacamole."
warn ""
warn "Press Enter to continue to Guacamole deployment..."
read -r

# ============================================================
# Step 4: Deploy Guacamole
# ============================================================
log "=== Step 4: Deploying Guacamole ==="
$NOMAD job run "${JOBS_DIR}/guacamole.nomad.hcl"
wait_for_job "guacamole" 180

# ============================================================
# Done
# ============================================================
log ""
log "============================================"
log "  All services deployed!"
log "============================================"
log ""
log "Services:"
log "  Vault:     https://vault.<domain>"
log "  Traefik:   http://<any-node>:8081 (dashboard)"
log "  Authentik: https://authentik.<domain>"
log "  Guacamole: https://guacamole.<domain>"
log ""
log "To enable SSO, update the guacamole.nomad.hcl OIDC template"
log "with your Authentik OIDC provider details and re-deploy:"
log "  $NOMAD job run ${JOBS_DIR}/guacamole.nomad.hcl"
log ""
