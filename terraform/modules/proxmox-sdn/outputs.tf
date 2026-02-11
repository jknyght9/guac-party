output "zone_name" {
  value = proxmox_virtual_environment_sdn_zone.zone.zone
}

output "vnet_name" {
  value = proxmox_virtual_environment_sdn_vnet.vnet.vnet
}

output "subnet_cidr" {
  value = proxmox_virtual_environment_sdn_subnet.subnet.subnet
}
