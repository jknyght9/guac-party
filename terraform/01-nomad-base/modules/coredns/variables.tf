variable "nomad_hosts" {
    type = list(string)
    description = "A list of nomad fqdn and ip addresses"
}

variable "internal_domain" {
  type = string
  description = "Top level domain for the cluster"
}

variable "mgmt_gateway" {
    type = string
    description = "The ip address of the management gateway"
}

variable "virtual_ip" {
    type = string
    description = "The virtual ip address with automatic failover"
}