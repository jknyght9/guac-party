output "usernet_bridge_name" {
    description = "Bridge name of the Usernet"
    # The bridge name is garunteed to be the same accross all names. Grab the first index name
    value = values(proxmox_network_linux_bridge.vmbr30)[0].name
}

output "range_bridge_name" {
    description = "Bridge name of the Cyber Range"
    value = proxmox_sdn_vnet.vm_vnet.id
}