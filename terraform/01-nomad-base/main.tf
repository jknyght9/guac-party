locals {
  node_names = keys(var.proxmox_nodes)
  node_count = length(local.node_names)
  all_nomad_ips = [for k, v in var.proxmox_nodes : v.nomad_ip]

  # Get master-peer ips
  nomad_master_ip = local.all_nomad_ips[0]
  nomad_peer_ips = slice(local.all_nomad_ips, 1, length(local.all_nomad_ips))
  # DNS entries that will go into each nodes /etc/hosts
  # This can possibly be deprecated, was previously used for the nomad node module
  # Need to double check where cloud init pulls host name entries
  host_entires = [
    for k, v in var.proxmox_nodes: "${v.nomad_ip} nomad-${k}.${var.internal_domain} nomad-${k}"
  ]

  # This contains records for unbound. Will resolve node specific domain names
  # i.e. nomad-saruman.internal 192.168.100.88
  # guac.nomad-saruman.internal 192.168.100.88
  # We need gauc to resolve node specific so users are sent to the gauc instance on the same node 
  # That their VMs are running on
  unbound_node_records = flatten([
    for name, ip in var.proxmox_nodes : [
      "nomad-${name}.${var.internal_domain}. ${ip.nomad_ip}",
      "guac.nomad-${name}.${var.internal_domain}. ${ip.nomad_ip}"
    ]
  ])
}

resource "random_password" "keepalived_mgmt_passwd" {
    length = 18
    special = true
    override_special = "!#$%&()-_+[]<>?"
}

# TODO, integrate proxmox SDN as part of the base latter
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

  mgmt_virtual_ip = var.mgmt_virtual_ip
  mgmt_passwd = random_password.keepalived_mgmt_passwd.result
}

module "nomad-jobs" {
  depends_on = [module.nomad_cluster.nomad_health_check]
  source = "./modules/nomad-jobs"

  unbound_node_records = local.unbound_node_records
  internal_domain = var.internal_domain
  virtual_ip = var.mgmt_virtual_ip
  mgmt_gateway = var.vm_gateway
}