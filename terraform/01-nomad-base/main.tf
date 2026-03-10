locals {
  node_names = keys(var.proxmox_nodes)
  node_count = length(local.node_names)
  all_nomad_ips = [for k, v in var.proxmox_nodes : v.nomad_ip]

  # Get master-peer ips
  nomad_master_ip = local.all_nomad_ips[0]
  nomad_peer_ips = slice(local.all_nomad_ips, 1, length(local.all_nomad_ips))
  # DNS entries that will go into each nodes /etc/hosts
  host_entires = [
    for k, v in var.proxmox_nodes: "${v.nomad_ip} nomad-${k}.${var.internal_domain} nomad-${k}"
  ]
}

# SDN zone + VNet + subnet (for guest VMs, out of scope but provisioned)
# module "proxmox_sdn" {
#  source = "./modules/proxmox-sdn"
#
#  zone_name   = var.sdn_zone_name
#  vnet_name   = var.sdn_vnet_name
#  subnet_cidr = var.sdn_subnet_cidr
#  gateway     = var.sdn_gateway
#}


module "nomad_cluster" {
  source = "./modules/nomad-cluster"

  proxmox_nodes = var.proxmox_nodes
  ssh_public_key = var.ssh_public_key

  internal_domain = var.internal_domain
  vm_gateway = var.vm_gateway
  vm_bridge  = var.vm_bridge
  subnet_cidr = var.subnet_cidr

  template_node = var.template_node
}

module "vault" {
  # Only deploy vault after gluster is finished
  depends_on = [module.nomad_cluster.nomad_health_check]
  source = "./modules/vault"
  
  # Each vault is tagged as vault.nomad-{hostname}.internal
  internal_domain = var.internal_domain
  nomad_all_ips = local.all_nomad_ips
}
