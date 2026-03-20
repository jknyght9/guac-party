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
  default     = env("PVE_FIRST_NODE_NAME")
}

variable "iso_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-live-server-amd64.iso"
}
variable "iso_local" {
  type    = string
  default = "nfs-tnhs-isostore:iso/ubuntu-24.04.4-live-server-amd64.iso"
}
variable "iso_checksum" {
  type    = string
  default = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"
}

variable "iso_storage_pool" {
  type    = string
  default = "nfs-tnhs-isostore"
}

variable "vm_id" {
  type    = number
  default = env("NOMAD_TEMPLATE_ID")
}

variable "vm_name" {
  type    = string
  default = "ubuntu-nomad-template"
}

variable "vm_cores" {
  type    = number
  default = 4
}

variable "vm_memory" {
  type    = number
  default = 4096
}

variable "vm_disk_size" {
  type    = string
  default = "8G"
}

variable "vm_storage_pool" {
  type    = string
  default = "ScratchDisk1"
}

variable "vm_bridge" {
  type    = string
  default = env("MGMT_BRIDGE")
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
