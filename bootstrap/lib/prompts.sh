#!/usr/bin/env bash
# Interactive prompts to collect cluster configuration


prompt_nodeIP_list() {
  # Node IPs/domain names
  read -rp "Proxmox node IPs or domain names (comma-separated) [${PVE_NODES:-}]: " PVE_NODES_USER
  # If the user provides input, update PVE_NODES. Otherwise if PVE_NODES is unset and user did not provide input default to ""
  PVE_NODES="${PVE_NODES_USER:-${PVE_NODES:-}}"
  if [[ -z "$PVE_NODES" ]]; then
    echo "ERROR: At least one Proxmox node is required."
    return 1
  fi

  export PVE_NODES
}

prompt_hostname_list() {
  # Node Hostnames
  read -rp "Proxmox node hostnames (comma-separated) [${PVE_HOSTNAMES:-}]: " PVE_HOSTNAMES_USER
  # If the user provides input, update PVE_HOSTNAMES. Otherwise if PVE_HOSTNAMES is unset and user did not provide input default to ""
  PVE_HOSTNAMES="${PVE_HOSTNAMES_USER:-${PVE_HOSTNAMES:-}}"
  # Check that # of hostnames matches # of IPS
  # Count nodes
  IFS=',' read -ra NODE_ARRAY <<< "$PVE_NODES"
  PVE_NODE_COUNT="${#NODE_ARRAY[@]}"

  # Count hostnames
  IFS=',' read -ra HOST_ARRAY <<< "$PVE_HOSTNAMES"
  PVE_HOSTNAME_COUNT="${#HOST_ARRAY[@]}"

  # Compare the # of Hostnames and # of IP addresses are equal
  if [[ "$PVE_NODE_COUNT" -ne "$PVE_HOSTNAME_COUNT" ]]; then
    echo "ERROR: Number of hostnames must match number of nodes!"
    return 1
  fi
  export PVE_HOSTNAMES
}

prompt_sdn_info() {
  # SDN config
  echo ""
  echo "=== SDN Configuration (guest VM network - out of scope but provisioned) ==="
  read -rp "SDN zone name [${SDN_ZONE_NAME:-cybercon}]: " SDN_ZONE_NAME_USER
  SDN_ZONE_NAME="${SDN_ZONE_NAME_USER:-${SDN_ZONE_NAME:-cybercon}}"
  export SDN_ZONE_NAME

  read -rp "SDN VNet name [${SDN_VNET_NAME:-cybernet}]: " SDN_VNET_NAME_USER
  SDN_VNET_NAME="${SDN_VNET_NAME_USER:-${SDN_VNET_NAME:-cybernet}}"
  export SDN_VNET_NAME

  read -rp "SDN subnet CIDR [${SDN_SUBNET_CIDR:-10.75.0.0/24}]: " SDN_SUBNET_CIDR_USER
  SDN_SUBNET_CIDR="${SDN_SUBNET_CIDR_USER:-${SDN_SUBNET_CIDR:-10.75.0.0/24}}"
  export SDN_SUBNET_CIDR

  read -rp "SDN gateway (first usable IP) [${SDN_GATEWAY:-10.75.0.1}]: " SDN_GATEWAY_USER
  SDN_GATEWAY="${SDN_GATEWAY_USER:-${SDN_GATEWAY:-10.75.0.1}}"
  export SDN_GATEWAY
}

prompt_mgmt_info() {
  # Management network (for Nomad VMs)
  echo "=== Management Network (Nomad VMs) ==="
  read -rp "Management bridge [${MGMT_BRIDGE:-vmbr0}]: " MGMT_BRIDGE_USER
  MGMT_BRIDGE="${MGMT_BRIDGE_USER:-${MGMT_BRIDGE:-vmbr0}}"
  export MGMT_BRIDGE

  read -rp "Management subnet CIDR [${MGMT_SUBNET_CIDR:-192.168.100.0/24}]: " MGMT_SUBNET_CIDR_USER
  MGMT_SUBNET_CIDR="${MGMT_SUBNET_CIDR_USER:-${MGMT_SUBNET_CIDR:-192.168.100.0/24}}"
  export MGMT_SUBNET_CIDR

  read -rp "Management gateway [192.168.100.1]: " MGMT_GATEWAY
  MGMT_GATEWAY="${MGMT_GATEWAY:-192.168.100.1}"
  export MGMT_GATEWAY

  read -rp "Nomad Template VM ID [9000]: " NOMAD_TEMPLATE_ID_USER
  NOMAD_TEMPLATE_ID="${NOMAD_TEMPLATE_ID_USER:-9000}"
  export NOMAD_TEMPLATE_ID

  read -rp "First Nomad VM IP [192.168.100.87]: " NOMAD_IP_START
  NOMAD_IP_START="${NOMAD_IP_START:-192.168.100.87}"
  export NOMAD_IP_START

  # Internal domain
  read -rp "Internal DNS domain [internal]: " INTERNAL_DOMAIN
  INTERNAL_DOMAIN="${INTERNAL_DOMAIN:-internal}"
  export INTERNAL_DOMAIN
}

promt_confirmation() {
  echo ""
  echo "=== Configuration Summary ==="
  echo "  Nodes:           ${PVE_NODES}"
  echo "  Hosts:           ${PVE_HOSTNAMES}"
  echo "  Automation user: ${PVE_AUTO_USER}"
  echo "  SDN zone:        ${SDN_ZONE_NAME} (${SDN_SUBNET_CIDR})"
  echo "  Mgmt network:    ${MGMT_BRIDGE} (${MGMT_SUBNET_CIDR})"
  echo "  Nomad VM IPs:    ${NOMAD_IP_START}+"
  echo "  Domain:          ${INTERNAL_DOMAIN}"
  echo ""
  read -rp "Continue? [Y/n]: " CONFIRM
  if [[ "${CONFIRM,,}" == "n" ]]; then
    echo "Aborted."
    return 1
  fi
}

prompt_cluster_info() {
  echo "=== Proxmox Cluster Configuration ==="
  echo ""

  # Node IPs/hostnames
  read -rp "Proxmox node IPs or hostnames (comma-separated): " PVE_NODES
  if [[ -z "$PVE_NODES" ]]; then
    echo "ERROR: At least one Proxmox node is required."
    return 1
  fi
  export PVE_NODES

  # Count nodes
  IFS=',' read -ra NODE_ARRAY <<< "$PVE_NODES"
  export PVE_NODE_COUNT="${#NODE_ARRAY[@]}"
  echo "  -> ${PVE_NODE_COUNT} node(s) detected."

  IFS=',' read -ra NODE_ARRAY <<< "$PVE_NODES"
  FIRST_NODE="$(echo "${NODE_ARRAY[0]}" | xargs)"

  read -rp "Hostname of node @${FIRST_NODE} [pve0]: " PVE_PRIMARY_NODE
  PVE_PRIMARY_NODE="${PVE_PRIMARY_NODE:-pve0}"
  export PVE_PRIMARY_NODE

  # Root credentials
  echo ""
  echo "Root credentials are needed to create the automation user/role."
  echo "They are NOT stored after bootstrap completes."
  read -rp "Proxmox root username @${PVE_PRIMARY_NODE} [root@pam]: " PVE_ROOT_USER
  PVE_ROOT_USER="${PVE_ROOT_USER:-root@pam}"
  export PVE_ROOT_USER

  read -rsp "Proxmox root password @${PVE_PRIMARY_NODE}: " PVE_ROOT_PASSWORD
  echo ""
  export PVE_ROOT_PASSWORD

  # Automation user
  read -rp "Automation username [terraform@pve]: " PVE_AUTO_USER
  PVE_AUTO_USER="${PVE_AUTO_USER:-terraform@pve}"
  export PVE_AUTO_USER

  # SDN config
  echo ""
  echo "=== SDN Configuration (guest VM network - out of scope but provisioned) ==="
  read -rp "SDN zone name [cybercon]: " SDN_ZONE_NAME
  SDN_ZONE_NAME="${SDN_ZONE_NAME:-cybercon}"
  export SDN_ZONE_NAME

  read -rp "SDN VNet name [cybernet]: " SDN_VNET_NAME
  SDN_VNET_NAME="${SDN_VNET_NAME:-cybernet}"
  export SDN_VNET_NAME

  read -rp "SDN subnet CIDR [10.75.0.0/24]: " SDN_SUBNET_CIDR
  SDN_SUBNET_CIDR="${SDN_SUBNET_CIDR:-10.75.0.0/24}"
  export SDN_SUBNET_CIDR

  read -rp "SDN gateway (first usable IP) [10.75.0.1]: " SDN_GATEWAY
  SDN_GATEWAY="${SDN_GATEWAY:-10.75.0.1}"
  export SDN_GATEWAY

  # Management network (for Nomad VMs)
  echo "=== Management Network (Nomad VMs) ==="
  read -rp "Management bridge [vmbr0]: " MGMT_BRIDGE
  MGMT_BRIDGE="${MGMT_BRIDGE:-vmbr0}"
  export MGMT_BRIDGE

  read -rp "Management subnet CIDR [192.168.100.0/24]: " MGMT_SUBNET_CIDR
  MGMT_SUBNET_CIDR="${MGMT_SUBNET_CIDR:-192.168.100.0/24}"
  export MGMT_SUBNET_CIDR

  read -rp "Management gateway [192.168.100.1]: " MGMT_GATEWAY
  MGMT_GATEWAY="${MGMT_GATEWAY:-192.168.100.1}"
  export MGMT_GATEWAY

  read -rp "First Nomad VM IP [192.168.100.87]: " NOMAD_IP_START
  NOMAD_IP_START="${NOMAD_IP_START:-192.168.100.87}"
  export NOMAD_IP_START

  # Internal domain
  read -rp "Internal DNS domain [internal]: " INTERNAL_DOMAIN
  INTERNAL_DOMAIN="${INTERNAL_DOMAIN:-internal}"
  export INTERNAL_DOMAIN

  echo ""
  echo "=== Configuration Summary ==="
  echo "  Nodes:           ${PVE_NODES}"
  echo "  Automation user: ${PVE_AUTO_USER}"
  echo "  SDN zone:        ${SDN_ZONE_NAME} (${SDN_SUBNET_CIDR})"
  echo "  Mgmt network:    ${MGMT_BRIDGE} (${MGMT_SUBNET_CIDR})"
  echo "  Nomad VM IPs:    ${NOMAD_IP_START}+"
  echo "  Domain:          ${INTERNAL_DOMAIN}"
  echo ""
  read -rp "Continue? [Y/n]: " CONFIRM
  if [[ "${CONFIRM,,}" == "n" ]]; then
    echo "Aborted."
    return 1
  fi
}
