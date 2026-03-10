variable "node_name" {
  type        = string
  description = "Logical name for this Nomad node"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node to deploy on"
}

variable "vm_ip" {
  type        = string
  description = "Static IP for the Nomad VM"
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
  type        = string
  description = "Subnet CIDR for prefix length calculation"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
}

variable "template_name" {
  type        = string
  description = "Packer-built VM template name"
}

variable "vm_id" {
  type = number
  description = "Virtual machine id"
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
  type    = string
}

variable "template_id" {
  type    = number
  default = 9000
}

variable "nomad_all_ips" {
  type        = list(string)
  description = "All Nomad node IPs for retry_join"
}

variable "nomad_bootstrap_expect" {
  type        = number
  description = "Number of servers expected for bootstrap"
}

variable "internal_domain" {
  type        = string
  default     = "internal"
  description = "Internal DNS domain"
}

variable "storage_pool" {
  type    = string
  default = "ScratchDisk1"
}

variable "cluster_host_entries" {
  type    = list(string)
  description = "A formatted list of nomad ips and their domain names. To be put in /etc/hosts"
}

variable "node_fqdn" {
  type = string
  description = "A fully qualified domain name of the nomad node"
}