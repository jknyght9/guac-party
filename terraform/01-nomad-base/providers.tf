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
    address = "http://${values(module.nomad_node)[0].vm_ip}:4646"
}