output "nodes" {
  description = "Full details of all nomad VMs"
  value = proxmox_virtual_environment_vm.nomad
}

output "node_ips" {
  description = "List of all IPs for easy join/retry logic"
  value       = [for vm in proxmox_virtual_environment_vm.nomad : vm.initialization[0].ip_config[0].ipv4[0].address]
}