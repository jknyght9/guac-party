output "nomad_vm_ips" {
  description = "IP addresses of deployed Nomad VMs"
  value       = { for k, v in module.nomad_cluster.nodes : k => split("/", v.initialization[0].ip_config[0].ipv4[0].address)[0] }
}

output "nomad_url" {
  description = "NOMAD_ADDR for the first Nomad node"
  value       = "http://${split("/", values(module.nomad_cluster.nodes)[0].initialization[0].ip_config[0].ipv4[0].address)[0]}:4646"
}

output "nomad_fqdn_list" {
  description = "A list of all Nomad domain names"
  value       = { for k, v in module.nomad_cluster.nodes : k => v.name }
}

#output "sdn_zone" {
#  description = "SDN zone name"
#  value       = module.proxmox_sdn.zone_name
#}

#output "sdn_vnet" {
#  description = "SDN VNet name"
#  value       = module.proxmox_sdn.vnet_name
#}
