terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.100.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "2.5.2"
    }
  }
}

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
    for k, v in var.proxmox_nodes: "${v.nomad_ip} ${k}.${var.internal_domain} ${k}"
  ]

  # This contains records for unbound. Will resolve node specific domain names
  # i.e. nomad-saruman.internal 192.168.100.88
  # guac.nomad-saruman.internal 192.168.100.88
  # We need gauc to resolve node specific so users are sent to the gauc instance on the same node 
  # That their VMs are running on
  unbound_node_records = flatten([
    for name, ip in var.proxmox_nodes : [
      "${name}.${var.internal_domain}. ${ip.nomad_ip}",
      #"guac.nomad-${name}.${var.internal_domain}. ${ip.nomad_ip}"
    ]
  ])
}

resource "random_password" "keepalived_mgmt_passwd" {
    length = 24
    special = false
}

resource "random_password" "keepalived_user_passwd" {
    length = 24
    special = false
}


module "nomad_cluster" {
  source = "./modules/nomad-cluster"
  depends_on = [ module.proxmox-net ]

  proxmox_nodes = var.proxmox_nodes
  ssh_public_key = var.ssh_public_key

  internal_domain = var.internal_domain
  vm_gateway = var.vm_gateway
  vm_bridge  = var.vm_bridge
  subnet_cidr = var.mgmt_subnet_cidr

  template_node = var.template_node

  mgmt_virtual_ip = var.mgmt_virtual_ip
  mgmt_passwd = random_password.keepalived_mgmt_passwd.result

  user_passwd = random_password.keepalived_user_passwd.result
  user_bridge_name = module.proxmox-net.usernet_bridge_name

  range_bridge_name = module.proxmox-net.range_bridge_name
}

module "nomad-jobs" {
  depends_on = [module.nomad_cluster.nomad_health_check]
  source = "./modules/nomad-jobs"

  unbound_node_records = local.unbound_node_records
  internal_domain = var.internal_domain
  mgmt_subnet_cidr = var.mgmt_subnet_cidr
  mgmt_virtual_ip = var.mgmt_virtual_ip
  mgmt_gateway = var.vm_gateway

  user_subnet_cidr = var.user_subnet_cidr
  user_virtual_ip = var.user_virtual_ip
}

module "proxmox-net" {
  source = "./modules/proxmox-net"
  proxmox_nodes = var.proxmox_nodes
}

# These credentials need to survive layer 02 being destryoed
# Postgres data lives on disk and a destroy will keep the original credentials
# Recreating the creds in layer 02 will result in you getting locked out, as terraform regenerates them but the data still uses orignal
resource "random_password" "postgres_root_pw" {
    length = 24
    special = false
}

resource "random_password" "postgres_repl_pw" {
    length = 24
    special = false
}

resource "random_password" "postgres_rewind_pw" {
    length = 24
    special = false
}