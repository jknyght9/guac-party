#!/usr/bin/env bash
# Create Proxmox automation user, role, and API token
# These 3 functions have been centralized, they are only needed for each other.

# Get the credentials needed to get our temporary ticket
prompt_root_credentials() {
  # Root credentials
  echo ""
  echo "Root credentials are needed to create the automation user/role."
  echo "They are NOT stored after bootstrap completes."
  read -rp "Proxmox root username @${FIRST_NODE_NAME} [root@pam]: " PVE_ROOT_USER
  PVE_ROOT_USER="${PVE_ROOT_USER:-root@pam}"
  export PVE_ROOT_USER

  read -rsp "Proxmox root password @${FIRST_NODE_NAME}: " PVE_ROOT_PASSWORD
  echo ""
  export PVE_ROOT_PASSWORD

  # Automation user
  read -rp "Automation username [terraform@pve]: " PVE_AUTO_USER
  PVE_AUTO_USER="${PVE_AUTO_USER:-terraform@pve}"
  export PVE_AUTO_USER

  pve_auth "$FIRST_NODE" "$PVE_ROOT_USER" "$PVE_ROOT_PASSWORD"
}

# Generate the temporary ticket
pve_auth() {
  local node="$1"
  local user="$2"
  local password="$3"

  local response
  response="$(curl -sk --connect-timeout 10 \
    -d "username=${user}&password=${password}" \
    "https://${node}:8006/api2/json/access/ticket")"

  PVE_TICKET="$(echo "$response" | grep -o '"ticket":"[^"]*"' | cut -d'"' -f4)"
  PVE_CSRF="$(echo "$response" | grep -o '"CSRFPreventionToken":"[^"]*"' | cut -d'"' -f4)"

  if [[ -z "$PVE_TICKET" ]]; then
    echo "ERROR: Authentication failed for ${user} on ${node}."
    echo "Response: ${response}"
    return 1
  fi

  export PVE_TICKET PVE_CSRF
  echo "OK: Authenticated to ${node} as ${user}."

  setup_proxmox_user "$node" "$PVE_AUTO_USER" "$SECRETS_DIR"
}

# Using the ticket setup a terraform user and generate api token
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
  privs+=",VM.Config.Options,VM.PowerMgmt,VM.Console,VM.Migrate"
  privs+=",VM.GuestAgent.Audit,VM.Audit"
  privs+=",Datastore.Allocate,Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit"
  privs+=",SDN.Allocate,SDN.Audit,SDN.Use"
  privs+=",Sys.Audit,Sys.Modify"

  echo "Creating role TerraformAdmin..."
  pve_post_ticket "$node" "/api2/json/access/roles" \
    "roleid=TerraformAdmin" \
    "privs=${privs}" 2>/dev/null || true

  # Create user (pve realm only)
  echo "Creating user ${auto_user}..."
  pve_post_ticket "$node" "/api2/json/access/users" \
    "userid=${auto_user}" \
    "comment=Terraform automation user (guac-party)" 2>/dev/null || true

  # Assign role at root path
  echo "Assigning TerraformAdmin role to ${auto_user} at /..."
  pve_put_ticket "$node" "/api2/json/access/acl" \
    "path=/" \
    "users=${auto_user}" \
    "roles=TerraformAdmin" \
    "propagate=1"

  # Create API token (no privilege separation)
  echo "Creating API token..."
  local token_response
  token_response="$(pve_post_ticket "$node" "/api2/json/access/users/${auto_user}/token/terraform" \
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

# This is a one off post method using tickets, no where else in the project 
# do we authenticate with temporary tickets
pve_post_ticket() {
  local node="$1"
  local path="$2"
  shift 2
  local data=("$@")

  local data_args=()
  for d in "${data[@]}"; do
    data_args+=(-d "$d")
  done

  curl -sk \
    -b "PVEAuthCookie=${PVE_TICKET}" \
    -H "CSRFPreventionToken: ${PVE_CSRF}" \
    "${data_args[@]}" \
    "https://${node}:8006${path}"
}

pve_put_ticket() {
  local node="$1"
  local path="$2"
  shift 2
  local data=("$@")

  local data_args=()
  for d in "${data[@]}"; do
    data_args+=(-d "$d")
  done

  curl -sk -X PUT \
    -b "PVEAuthCookie=${PVE_TICKET}" \
    -H "CSRFPreventionToken: ${PVE_CSRF}" \
    "${data_args[@]}" \
    "https://${node}:8006${path}"
}