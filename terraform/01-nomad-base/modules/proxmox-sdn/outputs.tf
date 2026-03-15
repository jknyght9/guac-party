output "zone_name" {
  value = proxmox_virtual_environment_sdn_zone_simple.zone.id
}

output "vnet_name" {
  value = proxmox_virtual_environment_sdn_vnet.vnet.id
}

output "subnet_cidr" {
  value = proxmox_virtual_environment_sdn_subnet.subnet.cidr
}
