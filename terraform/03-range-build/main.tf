terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.100.0"
    }
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.1"
    }
    guacamole = {
      source  = "techBeck03/guacamole"
      version = "1.4.1"
    }

  }
}

locals {
  usernames = sort(keys(var.workshop_users))
  node_names = sort(keys(var.proxmox_nodes))
  num_nodes = length(local.node_names)

  

  kali_clones = {
    for idx, user in local.usernames: user => {
      node_idx  = idx % local.num_nodes
      node_name = local.node_names[idx % local.num_nodes]
      nomad_ip  = local.nomad_list[local.node_names[idx % local.num_nodes]]

      template_id = 8001 + (idx % local.num_nodes)
      ip_address = "${var.range_wan_subnet_prefix}.${100 + idx}"

      vm_id = 8101 + idx
    }
  }
}
# Thin clones evenly spread across N number of nodes
resource "proxmox_virtual_environment_vm" "kali_clones" {
  for_each = local.kali_clones
  name = "kali-${each.key}"
  description = "Wokeshop Kali VM for ${each.key}"
  tags = ["workshop", "kali"]
  node_name = each.value.node_name
  vm_id = each.value.vm_id
  started = true
  clone {
    vm_id = each.value.template_id
    full = false
  }
  network_device {
    bridge = var.sdn_vnet_name
  }
  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip_address}/24"
      }
    }
    user_account {
      username = var.kali_credentials
      password = var.kali_credentials
    }
  }
}

# Thin clones evenly spread across N number of nodes
resource "proxmox_virtual_environment_vm" "alpine_clones" {
  for_each = local.kali_clones
  name = "kali-${each.key}"
  description = "Wokeshop Kali VM for ${each.key}"
  tags = ["workshop", "kali"]
  node_name = each.value.node_name
  vm_id = each.value.vm_id
  started = true
  clone {
    vm_id = each.value.template_id
    full = false
  }
  network_device {
    bridge = var.sdn_vnet_name
  }
  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip_address}/24"
      }
    }
    user_account {
      username = var.kali_credentials
      password = var.kali_credentials
    }
  }
}


# Adding Guacamole connection for each node
resource "guacamole_connection_rdp" "kali_rdp" {
  for_each = local.kali_clones
  depends_on = [ proxmox_virtual_environment_vm.kali_clones ]

  name = "Kali-Workspae-${each.key}"
  parent_identifier = "ROOT"
  
  attributes {
    guacd_hostname = each.value.nomad_ip
  }

  parameters {
    hostname = each.value.ip_address
    port = 3389
    username = var.kali_credentials
    password = var.kali_credentials

    security_mode = "any"
    ignore_cert = true

    color_depth = 16
  }
}

# Create ghost user in Guacamole to map Authentik users and link specific RDP connections
resource "guacamole_user" "guac_users" {
  for_each = local.kali_clones
  depends_on = [ guacamole_connection_rdp.kali_rdp ]

  username = each.key

  connections = [
    guacamole_connection_rdp.kali_rdp[each.key].identifier
  ]
}

resource "authentik_group" "workshop_group" {
  name = "Workshop Attendees"
}

resource "authentik_user" "workshop_users" {
  for_each = var.workshop_users
  username = each.key
  name = "Workshop User - ${each.key}"
  password = each.value.password
  groups = [authentik_group.workshop_group.id]
}

output "workshop_vm_allocations" {
  value = {
    for k, v in local.kali_clones : k => {
      target_node = v.node_name
      template    = v.template_id
      ip_address  = v.ip_address
    }
  }
}