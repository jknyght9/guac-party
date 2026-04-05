terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.100.0"
    }
  }
}
# Create a bridge on each node using VLAN 30
resource "proxmox_network_linux_bridge" "vmbr30" {
  for_each = var.proxmox_nodes
  node_name = each.key
  name = "vmbr30"

  ports = [ "${var.access_port}.30" ] # i.e. eno2.30
  autostart = true

  comment = "RCC User VLAN - Managed by Terraform"

  lifecycle {
    create_before_destroy = true
  }
}

resource "proxmox_sdn_zone_simple" "vm_zone" {
  id = "cybercon"
}

resource "proxmox_sdn_vnet" "vm_vnet" {
  id = "cybernet"
  zone = proxmox_sdn_zone_simple.vm_zone.id
  alias = "Vnet for RCC cyber ranges. Managed by Terraform"
}

resource "proxmox_sdn_subnet" "vm_subnet" {
  cidr = "10.40.0.0/24"
  vnet = proxmox_sdn_vnet.vm_vnet.id
}

# Trigger SDN apply on change
resource "proxmox_sdn_applier" "apply_sdn" {
  lifecycle {
    replace_triggered_by = [
      proxmox_sdn_zone_simple.vm_zone.id,
      proxmox_sdn_vnet.vm_vnet.id,
      proxmox_sdn_subnet.vm_subnet.id,
    ]
  }
}