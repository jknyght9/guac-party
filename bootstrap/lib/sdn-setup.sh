#!/usr/bin/env bash
# Create Proxmox SDN Simple zone, VNet, and subnet

setup_sdn() {
  local node="$1"
  local zone_name="$2"
  local vnet_name="$3"
  local subnet_cidr="$4"
  local gateway="$5"

  echo "=== Setting up SDN ==="

  # Create Simple zone
  echo "Creating Simple zone: ${zone_name}..."
  pve_post "$node" "/api2/json/cluster/sdn/zones" \
    "zone=${zone_name}" \
    "type=simple" 2>/dev/null || echo "  (zone may already exist)"

  # Create VNet
  echo "Creating VNet: ${vnet_name} in zone ${zone_name}..."
  pve_post "$node" "/api2/json/cluster/sdn/vnets" \
    "vnet=${vnet_name}" \
    "zone=${zone_name}" 2>/dev/null || echo "  (vnet may already exist)"

  # Create subnet
  # URL-encode the CIDR (/ -> %2F) for the subnet ID
  local subnet_id="${vnet_name}-${subnet_cidr//\//-}"
  echo "Creating subnet: ${subnet_cidr} on ${vnet_name}..."
  pve_post "$node" "/api2/json/cluster/sdn/vnets/${vnet_name}/subnets" \
    "subnet=${subnet_cidr}" \
    "type=subnet" \
    "gateway=${gateway}" \
    "snat=0" 2>/dev/null || echo "  (subnet may already exist)"

  # Apply SDN configuration across the cluster
  echo "Applying SDN configuration..."
  pve_put "$node" "/api2/json/cluster/sdn" 2>/dev/null

  echo "OK: SDN configured (${zone_name}/${vnet_name}/${subnet_cidr})."
}
