output "nomad_vm_ips" {
  description = "IP addresses of deployed Nomad VMs"
  value       = { for k, v in module.nomad_node : k => v.vm_ip }
}

output "nomad_url" {
  description = "NOMAD_ADDR for the first Nomad node"
  value       = "http://${values(module.nomad_node)[0].vm_ip}:4646"
}

output "nomad_fqdn_list" {
  description = "A list of all Nomad domain names"
  value       = { for k, v in module.nomad_node : k => v.vm_name }
}

#output "sdn_zone" {
#  description = "SDN zone name"
#  value       = module.proxmox_sdn.zone_name
#}

#output "sdn_vnet" {
#  description = "SDN VNet name"
#  value       = module.proxmox_sdn.vnet_name
#}
