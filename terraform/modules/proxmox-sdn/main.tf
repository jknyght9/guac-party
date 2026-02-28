terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_sdn_zone_simple" "zone" {
  id = var.zone_name
}

resource "proxmox_virtual_environment_sdn_vnet" "vnet" {
  id = var.vnet_name
  zone = proxmox_virtual_environment_sdn_zone_simple.zone.id

  depends_on = [proxmox_virtual_environment_sdn_applier.apply]
}

resource "proxmox_virtual_environment_sdn_subnet" "subnet" {
  cidr = var.subnet_cidr
  vnet   = proxmox_virtual_environment_sdn_vnet.vnet.id

  gateway = var.gateway
  snat    = false

  depends_on = [proxmox_virtual_environment_sdn_applier.apply]
}

resource "proxmox_virtual_environment_sdn_applier" "apply" {
}
