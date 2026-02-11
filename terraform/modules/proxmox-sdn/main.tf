terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_sdn_zone" "zone" {
  zone = var.zone_name
  type = "simple"
}

resource "proxmox_virtual_environment_sdn_vnet" "vnet" {
  vnet = var.vnet_name
  zone = proxmox_virtual_environment_sdn_zone.zone.zone
}

resource "proxmox_virtual_environment_sdn_subnet" "subnet" {
  subnet = var.subnet_cidr
  vnet   = proxmox_virtual_environment_sdn_vnet.vnet.vnet

  gateway = var.gateway
  snat    = false
}

resource "proxmox_virtual_environment_sdn_applier" "apply" {
  depends_on = [
    proxmox_virtual_environment_sdn_subnet.subnet,
  ]
}
