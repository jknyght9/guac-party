
variable "proxmox_nodes" {
  type = map(object({
    address  = string
    nomad_ip = string
  }))
  description = "A map of Proxmox node hostnames and ips"
}

variable "internal_domain" {
  type = string
  description = "Top level domain"
}

variable "vm_gateway" {
  type        = string
  description = "Network gateway"
}

variable "vm_bridge" {
  type        = string
  description = "Bridge interface"
}

variable "subnet_cidr" {
  type = string
  description = "The subnet Nomad will be in CIDR notation"
  default = "10.75.0.0/24"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
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

variable "template_node" {
  type = string
  description = "The hostname of the Proxmox node holding the template"
}

variable "template_id" {
  type    = number
  default = 9000
}

variable "storage_pool" {
  type    = string
  default = "ScratchDisk1"
}
