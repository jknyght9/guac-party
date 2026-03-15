variable "zone_name" {
  type        = string
  description = "SDN Simple zone name"
}

variable "vnet_name" {
  type        = string
  description = "SDN VNet name"
}

variable "subnet_cidr" {
  type        = string
  description = "Subnet CIDR (e.g. 10.10.0.0/24)"
}

variable "gateway" {
  type        = string
  description = "Subnet gateway IP"
}
