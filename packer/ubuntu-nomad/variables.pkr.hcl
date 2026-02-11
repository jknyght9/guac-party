variable "proxmox_api_url" {
  type    = string
  default = env("PVE_API_URL")
}

variable "proxmox_api_token_id" {
  type    = string
  default = env("PVE_API_TOKEN_ID")
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
  default   = env("PVE_API_TOKEN_SECRET")
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build the template on"
  default     = ""
}

variable "iso_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "none"
}

variable "iso_storage_pool" {
  type    = string
  default = "local"
}

variable "vm_id" {
  type    = number
  default = 9000
}

variable "vm_name" {
  type    = string
  default = "ubuntu-nomad-template"
}

variable "vm_cores" {
  type    = number
  default = 2
}

variable "vm_memory" {
  type    = number
  default = 2048
}

variable "vm_disk_size" {
  type    = string
  default = "20G"
}

variable "vm_storage_pool" {
  type    = string
  default = "local-lvm"
}

variable "vm_bridge" {
  type    = string
  default = "vmbr0"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ssh_password" {
  type      = string
  sensitive = true
  default   = "ubuntu"
}
