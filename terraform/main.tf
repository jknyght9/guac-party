locals {
  node_names = keys(var.proxmox_nodes)
  node_count = length(local.node_names)
  all_nomad_ips = [for k, v in var.proxmox_nodes : v.nomad_ip]
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

# One Nomad VM per Proxmox node
module "nomad_node" {
  source   = "./modules/nomad-node"
  for_each = var.proxmox_nodes

  node_name     = "nomad-${each.key}"
  proxmox_node  = each.key
  vm_ip         = each.value.nomad_ip
  vm_gateway    = var.mgmt_gateway
  vm_bridge     = var.mgmt_bridge
  subnet_cidr   = var.mgmt_subnet_cidr
  ssh_public_key = var.ssh_public_key
  template_name = var.vm_template_name
  vm_cores      = var.vm_cores
  vm_memory     = var.vm_memory
  vm_disk_size  = var.vm_disk_size

  # Nomad cluster config
  nomad_node_name    = "nomad-${each.key}.${var.internal_domain}"
  nomad_all_ips      = local.all_nomad_ips
  nomad_bootstrap_expect = local.node_count
  internal_domain    = var.internal_domain

  #depends_on = [module.proxmox_sdn]
}
