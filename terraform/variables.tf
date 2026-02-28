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


variable "proxmox_primary_node" {
  type = string
  description = "Primary node hostname, i.e. pve0"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for Nomad VM access"
}

variable "mgmt_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Management network bridge name"
}

variable "mgmt_gateway" {
  type        = string
  description = "Management network gateway IP"
}

variable "mgmt_subnet_cidr" {
  type        = string
  description = "Management network CIDR (e.g. 192.168.1.0/24)"
}

variable "sdn_zone_name" {
  type        = string
  default     = "guestzone"
  description = "SDN Simple zone name"
}

variable "sdn_vnet_name" {
  type        = string
  default     = "guestvnet"
  description = "SDN VNet name"
}

variable "sdn_subnet_cidr" {
  type        = string
  default     = "10.10.0.0/24"
  description = "SDN subnet CIDR"
}

variable "sdn_gateway" {
  type        = string
  default     = "10.10.0.1"
  description = "SDN gateway IP"
}

variable "internal_domain" {
  type        = string
  default     = "internal"
  description = "Internal DNS domain"
}

variable "vm_template_name" {
  type        = string
  default     = "ubuntu-nomad-template"
  description = "Name of the Packer-built VM template"
}

variable "vm_cores" {
  type    = number
  default = 4
}

variable "vm_memory" {
  type    = number
  default = 8192
}

variable "vm_disk_size" {
  type    = number
  default = 50
}
