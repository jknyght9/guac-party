#!/usr/bin/env bash
# Create Proxmox automation user, role, and API token

setup_proxmox_user() {
  local node="$1"
  local auto_user="$2"
  local secrets_dir="$3"

  local username="${auto_user%%@*}"
  local realm="${auto_user##*@}"

  echo "=== Setting up automation user: ${auto_user} ==="

  # Create role with required privileges
  local privs="VM.Allocate,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit"
  privs+=",VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network"
  privs+=",VM.Config.Options,VM.Monitor,VM.Audit,VM.PowerMgmt"
  privs+=",Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit"
  privs+=",SDN.Allocate,SDN.Audit,SDN.Use"
  privs+=",Sys.Audit,Sys.Modify"

  echo "Creating role TerraformAdmin..."
  pve_post "$node" "/api2/json/access/roles" \
    "roleid=TerraformAdmin" \
    "privs=${privs}" 2>/dev/null || true

  # Create user (pve realm only)
  echo "Creating user ${auto_user}..."
  pve_post "$node" "/api2/json/access/users" \
    "userid=${auto_user}" \
    "comment=Terraform automation user (guac-party)" 2>/dev/null || true

  # Assign role at root path
  echo "Assigning TerraformAdmin role to ${auto_user} at /..."
  pve_put "$node" "/api2/json/access/acl" \
    "path=/" \
    "users=${auto_user}" \
    "roles=TerraformAdmin" \
    "propagate=1"

  # Create API token (no privilege separation)
  echo "Creating API token..."
  local token_response
  token_response="$(pve_post "$node" "/api2/json/access/users/${auto_user}/token/terraform" \
    "privsep=0" \
    "comment=guac-party automation token")"

  local token_value
  token_value="$(echo "$token_response" | grep -o '"value":"[^"]*"' | cut -d'"' -f4)"

  if [[ -z "$token_value" ]]; then
    echo "WARNING: Could not extract token value. Token may already exist."
    echo "  If re-running bootstrap, delete the existing token first:"
    echo "  Datacenter -> Permissions -> API Tokens -> ${auto_user}!terraform"
    echo "Response: ${token_response}"
    return 1
  fi

  # Write token to secrets
  local token_file="${secrets_dir}/proxmox-api-token.env"
  cat > "$token_file" <<EOF
PVE_API_TOKEN_ID=${auto_user}!terraform
PVE_API_TOKEN_SECRET=${token_value}
EOF
  chmod 600 "$token_file"

  export PVE_API_TOKEN_ID="${auto_user}!terraform"
  export PVE_API_TOKEN_SECRET="${token_value}"

  echo "OK: API token written to ${token_file}"
}
