locals {
  first_node_name = keys(var.proxmox_nodes)[0]
  first_node_ip = var.proxmox_nodes[local.first_node_name].nomad_ip
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true

  ssh {
    agent = true
    username = "root" 
  }
}

provider "nomad" {
    address = "http://${split("/", values(module.nomad_cluster.nodes)[0].initialization[0].ip_config[0].ipv4[0].address)[0]}:4646"
}

provider "random" {}