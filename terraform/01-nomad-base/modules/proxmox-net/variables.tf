variable "proxmox_nodes" {
  type = map(object({
    address  = string
    nomad_ip = string
  }))
  description = "A map of Proxmox node hostnames and ips"
}

variable "access_port" {
  type = string
  description = "The name of the interface user traffic enters"
  default = "eno2"
}