variable "unbound_node_records" {
    type = list(string)
    description = "A list of node specific domain names and ip addresses. ex: nomad-saruman.internal. 192.168.100.87"
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