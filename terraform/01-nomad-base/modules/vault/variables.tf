variable "internal_domain" {
    description = "internal domain for cluster"
    type = string
}

variable "nomad_all_ips" {
    description = "a map of all nomad ips"
    type = list(string)
}