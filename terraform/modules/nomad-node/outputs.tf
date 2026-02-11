output "vm_ip" {
  value = var.vm_ip
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.nomad.vm_id
}

output "vm_name" {
  value = proxmox_virtual_environment_vm.nomad.name
}
