provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true

  ssh {
    agent = true
    username = "root" 
  }
}

provider "authentik" {
  url = var.authentik_url
  token = local.authentik_token_hex
  insecure = true
}

provider "guacamole" {
  url = "https://guacamole.internal" #var.guacamole_url
  username = var.guacamole_admin_username
  password = var.guacamole_admin_password
  disable_tls_verification = true
}