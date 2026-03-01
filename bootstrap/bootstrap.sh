#!/usr/bin/env bash
# Guac-Party Bootstrap Script
# Sets up Proxmox automation user, SDN, generates secrets, and builds infrastructure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SECRETS_DIR="${SCRIPT_DIR}/secrets"

# Source library functions
source "${SCRIPT_DIR}/lib/validation.sh"
source "${SCRIPT_DIR}/lib/prompts.sh"
source "${SCRIPT_DIR}/lib/proxmox-api.sh"
source "${SCRIPT_DIR}/lib/ssh-keygen.sh"
source "${SCRIPT_DIR}/lib/user-setup.sh"
source "${SCRIPT_DIR}/lib/sdn-setup.sh"

# Source any existing variables
source "${PROJECT_ROOT}/.env"

echo "============================================"
echo "  Guac-Party Bootstrap"
echo "  HA Apache Guacamole on Proxmox via Nomad"
echo "============================================"
echo ""

# Get inital cluster information
prompt_nodeIP_list
prompt_hostname_list

# Step 2: Pre-flight checks
IFS=',' read -ra NODE_ARRAY <<< "$PVE_NODES"
FIRST_NODE="$(echo "${NODE_ARRAY[0]}" | xargs)"

IFS=',' read -ra HOST_ARRAY <<< "$PVE_HOSTNAMES"
PVE_FIRST_NODE_NAME="$(echo "${HOST_ARRAY[0]}" | xargs)"

#run_preflight "$PVE_NODES"


# If a token does not exist ask user for root credentials
if [[ -z $PVE_API_TOKEN_ID ]]; then
  prompt_root_credentials
else
  echo "Found existing token, attempting to authenticate..."
  # Get the version as a test of our token
  RESPONSE="$(pve_get "$FIRST_NODE" "/api2/json/version")"

  # Trim data from the return code {"data":null}XXX
  STATUS="${RESPONSE: -3}"

  # If we do not authenticate successfully create our automation user
  if [[ $STATUS -ne 200 ]]; then
    echo "Authentication failed, generating new tickets..."
    echo "If you already have an automation user, please delete it!"
    prompt_root_credentials
  else
    echo "Authentication successful!"
  fi
fi


# Step 3: Generate SSH key pair
generate_ssh_key "$SECRETS_DIR"

# Step 6: Setup SDN
prompt_sdn_info
setup_sdn "$FIRST_NODE" "$SDN_ZONE_NAME" "$SDN_VNET_NAME" "$SDN_SUBNET_CIDR" "$SDN_GATEWAY"

# Step X: Gather MGMT net info
prompt_mgmt_info

# Step 7: Generate terraform.tfvars
echo "=== Generating terraform.tfvars ==="
NOMAD_IPS=()
IFS='.' read -ra OCTETS <<< "$NOMAD_IP_START"
LAST_OCTET="${OCTETS[3]}"
BASE="${OCTETS[0]}.${OCTETS[1]}.${OCTETS[2]}"

for i in $(seq 0 $(( PVE_NODE_COUNT - 1 ))); do
  NOMAD_IPS+=("${BASE}.$(( LAST_OCTET + i ))")
done

# Build the proxmox_nodes map for tfvars
NODES_MAP="{"
for i in $(seq 0 $(( PVE_NODE_COUNT - 1 ))); do
  node_name="$(echo "${NODE_ARRAY[$i]}" | xargs)"
  # Extract short hostname (before first dot)
  short_name="${node_name%%.*}"
  [[ $i -gt 0 ]] && NODES_MAP+=", "
  NODES_MAP+="\"$(echo "${HOST_ARRAY[$i]}" | xargs)\" = { address = \"${node_name}\", nomad_ip = \"${NOMAD_IPS[$i]}\" }"
done
NODES_MAP+="}"

cat > "${PROJECT_ROOT}/terraform/terraform.tfvars" <<EOF
proxmox_first_node_name = "${PVE_FIRST_NODE_NAME}"
proxmox_api_url    = "https://${FIRST_NODE}:8006/api2/json"
proxmox_api_token  = "${PVE_API_TOKEN_ID}=${PVE_API_TOKEN_SECRET}"

proxmox_nodes = ${NODES_MAP}

ssh_public_key = "${SSH_PUBLIC_KEY}"

mgmt_bridge     = "${MGMT_BRIDGE}"
mgmt_gateway    = "${MGMT_GATEWAY}"
mgmt_subnet_cidr = "${MGMT_SUBNET_CIDR}"

sdn_zone_name   = "${SDN_ZONE_NAME}"
sdn_vnet_name   = "${SDN_VNET_NAME}"
sdn_subnet_cidr = "${SDN_SUBNET_CIDR}"
sdn_gateway     = "${SDN_GATEWAY}"

internal_domain = "${INTERNAL_DOMAIN}"
EOF

echo "OK: terraform.tfvars written."

# Step 8: Generate .env for Docker wrappers
cat > "${PROJECT_ROOT}/.env" <<EOF
PVE_FIRST_NODE_NAME=${PVE_FIRST_NODE_NAME}
PVE_NODES="${PVE_NODES}"
PVE_HOSTNAMES="${PVE_HOSTNAMES}"
PVE_API_URL=https://${FIRST_NODE}:8006/api2/json
PVE_API_TOKEN_ID=${PVE_API_TOKEN_ID}
PVE_API_TOKEN_SECRET=${PVE_API_TOKEN_SECRET}
SDN_ZONE_NAME=${SDN_ZONE_NAME}
SDN_VNET_NAME=${SDN_VNET_NAME}
SDN_SUBNET_CIDR=${SDN_SUBNET_CIDR}
SDN_GATEWAY=${SDN_GATEWAY}
MGMT_BRIDGE=${MGMT_BRIDGE}
MGMT_SUBNET_CIDR=${MGMT_SUBNET_CIDR}
MGMT_GATEWAY=${MGMT_GATEWAY}
NOMAD_TEMPLATE_ID=${NOMAD_TEMPLATE_ID}
NOMAD_IP_START=${NOMAD_IP_START}
INTERNAL_DOMAIN=${INTERNAL_DOMAIN}
EOF

echo "OK: .env written."

# Step 9: Build Packer template
RESPONSE=$(pve_get "$FIRST_NODE" "/api2/json/nodes/${PVE_FIRST_NODE_NAME}/qemu/{$NOMAD_TEMPLATE_ID}/status/current")
if [[ ${RESPONSE: -3} -ne 200 ]]; then
  echo ""
  echo "=== Building VM template with Packer ==="
  "${PROJECT_ROOT}/docker/packer.sh" init /workspace/packer/ubuntu-nomad
  "${PROJECT_ROOT}/docker/packer.sh" build /workspace/packer/ubuntu-nomad
else
  echo ""
  echo "Nomad Template ID already found, skipping packer"
fi

# Step 10: Deploy with Terraform
echo ""
echo "=== Deploying Nomad VMs with Terraform ==="
"${PROJECT_ROOT}/docker/terraform.sh" init
"${PROJECT_ROOT}/docker/terraform.sh" apply -auto-approve

# Step 11: Print next steps
echo ""
echo "============================================"
echo "  Bootstrap Complete!"
echo "============================================"
echo ""
echo "Nomad VMs deployed. Next steps:"
echo ""
echo "  1. Wait ~60s for Nomad cluster to form."
echo "  2. Set NOMAD_ADDR to any Nomad VM IP:"
echo "     export NOMAD_ADDR=http://${NOMAD_IPS[0]}:4646"
echo ""
echo "  3. Deploy services:"
echo "     ./nomad/deploy.sh"
echo ""
echo "  4. After deploy, access services at:"
echo "     https://vault.${INTERNAL_DOMAIN}"
echo "     https://authentik.${INTERNAL_DOMAIN}"
echo "     https://guacamole.${INTERNAL_DOMAIN}"
echo ""
echo "  (Point DNS for *.${INTERNAL_DOMAIN} to any Nomad VM IP)"
echo ""
