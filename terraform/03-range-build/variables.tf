variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL (e.g. https://pve1:8006)"
}

variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "Proxmox API token in format user@realm!tokenid=secret"
}

variable "proxmox_nodes" {
  type = map(object({
    address  = string
    nomad_ip = string
  }))
  description = "Map of Proxmox node name -> {address, nomad_ip}"
}

variable "proxmox_first_node_name" {
  type = string
  description = "Primary node hostname, i.e. pve0"
}

variable "guacamole_admin_username" {
  default = "guacadmin"
  type = string
}

variable "guacamole_admin_password" {
  sensitive = true
  type = string
}

variable "authentik_url" {
  type = string
  default = "https://authentik.internal"
  description = "URL to reach Authentik API"
}

variable "guacamole_url" {
  type = string
  default = "guacamole.internal"
  description = "URL to reach Guacamole API"
}

variable "range_wan_subnet_prefix" {
  type = string
  default = "10.40.0"
  description = "Frist 3 octets of the range WAN network"
}

variable "kali_credentials" {
  type = string
  default = "kali"
  description = "Kali credentials. Same username and password"
}

variable "workshop_users" {
  description = "Map of users to create. Keys are usernames, values are configuration objects."
  type = map(object({
    password = string
  }))
}

variable "sdn_vnet_name" {
  description = "VNet for Cyber Ranges. Used as the name to idenitify the bridge"
}

# LAN Side Variables
variable "range_lan_subnet_prefix" {
  type = string
  default = "192.168.30"
  description = "The subnet prefix used to the LAN of the cyber range. Does not have a trailing dot"
}

variable "range_kali_octet" {
  type = string
  default = "55"
  description = "The host octet for Kali"
}

variable "range_windows_octet" {
  type = string
  default = "215"
  description = "The host octet for Windows"
}