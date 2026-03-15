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

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for Nomad VM access"
}

variable "vm_gateway" {
  type = string
  description = "Gateway address for Nomad"
  default = "192.168.100.1"
}

variable "vm_bridge" {
  type = string
  description = "Bridge device for Nomad to attach to"
  default = "vmbr0"
}

variable "subnet_cidr" {
  type        = string
  description = "Subnet CIDR for prefix length calculation"
  default = "192.168.100.0/24"
}

variable "template_node" {
  type = string
  description = "The hostname of the Proxmox node holding the template"
  default = "saruman"
}

variable "internal_domain" {
  type = string
  default = "internal"
  description = "Top level domain"
}

variable "mgmt_virtual_ip" {
    type = string
    description = "Virtual IP address of the Cluster. The shared ip address with automatic failover"
}
