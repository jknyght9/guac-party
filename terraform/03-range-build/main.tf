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

  ranges = {
    for idx, user in local.usernames: user => {
      # Proxmox Node Placement
      node_idx  = idx % local.num_nodes
      node_name = local.node_names[idx % local.num_nodes]
      # Nomad IP local to the Range. Used for GUACD routing later
      nomad_ip  = local.nomad_list[local.node_names[idx % local.num_nodes]]

      # Range Identifiers, follows a XYZZ VM id pattern
      # X = Template digit, i.e. Kali 8xxx, Alpine 7xxx, Windows 6xxx
      # Y = Node number. Identifies physical Proxmox node
      # ZZ = Range id, starting at 11
      node_id  = (idx % local.num_nodes) + 1
      range_id = 11 + idx
      # A little ugly but works
      y_zz_suffix = ((((idx % local.num_nodes) + 1) * 100) + (11 + idx)) # Produces 111, 212, 313, etc
      # VLAN tag follows similar pattern, drops node # for 1000 + range_id
      vlan_tag = (1000 + ( 11 + idx ))

      # Alpine WAN IP, starts at 101 and continues. 
      router_wan_ip = "${var.range_wan_subnet_prefix}.${101 + idx}"

      # LAN addresses, all ranges share the same IP map on the LAN side
      router_lan_ip = "${var.range_lan_subnet_prefix}.1"
      kali_lan_ip   = "${var.range_lan_subnet_prefix}.${var.range_kali_octet}"
      windows_lan_ip   = "${var.range_lan_subnet_prefix}.${var.range_windows_octet}"
    }
  }
  # Microsoft OUI
  windows_oui = "30:59:B7"

  # Kali OUI - Easter egg hehe
  kali_oui = "04:BA:1C"

  ### We set MAC address ahead of time for Windows network interface
  ### Avoids waiting for Windows to spin up and then having to pull it
  windows_macs = {
    for key, suffix in random_bytes.windows_mac_suffix :
    key => format("%s:%s:%s:%s",
    local.windows_oui,
    substr(suffix.hex, 0, 2),
    substr(suffix.hex, 2, 2),
    substr(suffix.hex, 4, 2))
  }
  ### Kali can use cloud init to assign ip addresses. And I would prefer to do it
  ### That way. But I have been at this for literall hours with 
  ### Proxmox, Kali, Cloud-init, or all the above shitting the bed
  kali_macs = {
    for key, suffix in random_bytes.kali_mac_suffix :
    key => format("%s:%s:%s:%s",
    local.kali_oui,
    substr(suffix.hex, 0, 2),
    substr(suffix.hex, 2, 2),
    substr(suffix.hex, 4, 2))    
  }
}

resource "random_bytes" "windows_mac_suffix" {
  for_each = local.ranges
  length = 3
}

resource "random_bytes" "kali_mac_suffix" {
  for_each = local.ranges
  length = 3
}

resource "proxmox_network_linux_bridge" "vmbr_lan" {
  for_each = var.proxmox_nodes
  node_name = each.key
  name = "rangeLAN"

  autostart = true
  vlan_aware = true
  comment = "RCC Range LAN Bridge - Managed by Terraform"

  lifecycle {
    create_before_destroy = true
  }
}

/* # Cloud init for Kali
resource "proxmox_virtual_environment_file" "cloud_init_kali" {
  for_each = local.ranges
  content_type = "snippets"
  datastore_id = "local"
  node_name = each.value.node_name

  source_raw {
    file_name = "Demo-${each.value.range_id}-kali-cloud-init.yaml"
    data = templatefile("${path.root}/templates/kali-cloud-init.yaml.tpl", {
      hostname = "kali-${each.value.range_id}"
      username = var.kali_credentials
      kali_ip = "${each.value.kali_lan_ip}/24"
      gateway = each.value.router_lan_ip      
    })
  }
} */
# Thin clones evenly spread across N number of nodes
resource "proxmox_virtual_environment_vm" "kali_clones" {
  depends_on = [ time_sleep.wait_for_alpine ]
  for_each = local.ranges
  name = "kali-${each.key}"
  description = "Workshop Kali VM for ${each.key}"
  tags = ["workshop", "kali"]
  node_name = each.value.node_name
  vm_id = ( 8000 + ( 100 * each.value.node_id) + each.value.range_id )
  started = true
  agent { enabled = true }
  clone {
    vm_id = ( 8000 + ( 100 * each.value.node_id) ) # Node 1 has template 8001, node 2 8002, etc
    full = false
  }
  network_device {
    # This is the LAN bridge of the range. All LANs on a given node share this bridge but seperated by vlan
    bridge = proxmox_network_linux_bridge.vmbr_lan[each.value.node_name].name
    vlan_id = each.value.vlan_tag
    mac_address = local.kali_macs[each.key]
  }
  initialization {
    user_account {
      username = var.kali_credentials
      password = var.kali_credentials
    }
    dns {
      domain = "none"
      servers = [each.value.router_lan_ip]
    }
  }
}

# Cloud init for Alpine
resource "proxmox_virtual_environment_file" "cloud_init_alpine" {
  for_each = local.ranges
  content_type = "snippets"
  datastore_id = "local"
  node_name = each.value.node_name

  source_raw {
    file_name = "Demo-${each.value.range_id}-alpine-cloud-init.yaml"
    data = templatefile("${path.root}/templates/alpine-cloud-init.yaml.tpl", {
      hostname = "alpine-router-${each.value.range_id}"
      dnsmasq_conf = templatefile("${path.root}/templates/dnsmasq.conf.tpl", {
        windows_mac = local.windows_macs[each.key]
        kali_mac = local.kali_macs[each.key]
        range_id = each.value.range_id
      })
      setup_firewall = templatefile("${path.root}/templates/setup-firewall.sh", {
        # Intentionally blank, future might have IPs passed as vars
      })
    })
  }
}
# Thin clones evenly spread across N number of nodes
resource "proxmox_virtual_environment_vm" "alpine_clones" {
  for_each = local.ranges

  name = "alpine-${each.key}"
  description = "Workshop  VM for ${each.key}"
  tags = ["workshop", "alpine"]
  node_name = each.value.node_name
  agent { enabled = true }
  
  vm_id = ( 7000 + ( 100 * each.value.node_id) + each.value.range_id )
  started = true
  clone {
    vm_id = ( 7000 + ( 100 * each.value.node_id) )
    full = false
  }
  network_device { # WAN
    bridge = var.sdn_vnet_name
  }
  network_device { # LAN
    bridge = proxmox_network_linux_bridge.vmbr_lan[each.value.node_name].name
    vlan_id = each.value.vlan_tag
  }
  initialization {
    # Load cloud init file
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_alpine[each.key].id
    ip_config {
      ipv4 { # WAN
        address = "${each.value.router_wan_ip}/24"
      }
    }
    ip_config {
      ipv4 { # LAN
        address = "${each.value.router_lan_ip}/24"
      }
    }
  }
}
resource "time_sleep" "wait_for_alpine" {
  depends_on = [ proxmox_virtual_environment_vm.alpine_clones ]
  create_duration = "15s"
}
# Windows clones
resource "proxmox_virtual_environment_vm" "windows_clones" {
  # Depend on Alpine, so DHCP will be up
  depends_on = [ time_sleep.wait_for_alpine ]
  for_each = local.ranges
  name = "windows-${each.key}"
  description = "Workshop VM for ${each.key}"
  tags = ["workshop", "windows"]
  node_name = each.value.node_name
  agent { enabled = false }

  vm_id = ( 6000 + ( 100 * each.value.node_id) + each.value.range_id )
  started = true
  clone {
    vm_id = ( 6000 + ( 100 * each.value.node_id) )
    full = false
  }
  network_device {
    bridge = proxmox_network_linux_bridge.vmbr_lan[each.value.node_name].name
    vlan_id = each.value.vlan_tag
    model = "e1000"
    mac_address = local.windows_macs[each.key]
  }
}


# Adding Guacamole connection for each Kali node
resource "guacamole_connection_rdp" "kali_rdp" {
  for_each = local.ranges
  depends_on = [ 
    proxmox_virtual_environment_vm.kali_clones,
    proxmox_virtual_environment_vm.alpine_clones
    ]

  name = "Kali-${each.key}"
  parent_identifier = "ROOT"
  
  attributes {
    guacd_hostname = each.value.nomad_ip
  }

  parameters {
    hostname = each.value.router_wan_ip
    port = 3389
    username = var.kali_credentials
    password = var.kali_credentials

    security_mode = "any"
    ignore_cert = true

    color_depth = 16
  }
}

# Adding Guacamole connection for each Windows node
resource "guacamole_connection_rdp" "windows_rdp" {
  for_each = local.ranges
  depends_on = [ 
    proxmox_virtual_environment_vm.windows_clones,
    proxmox_virtual_environment_vm.alpine_clones
    ]

  name = "Windows-${each.key}"
  parent_identifier = "ROOT"
  
  attributes {
    guacd_hostname = each.value.nomad_ip
  }

  parameters {
    hostname = each.value.router_wan_ip
    port = 3390
    username = var.windows_credentials
    password = var.windows_credentials

    security_mode = "any"
    ignore_cert = true

    color_depth = 16
    enable_wallpaper = true
  }
}

# Create ghost user in Guacamole to map Authentik users and link specific RDP connections
resource "guacamole_user" "guac_users" {
  for_each = local.ranges
  depends_on = [
    guacamole_connection_rdp.kali_rdp,
    guacamole_connection_rdp.windows_rdp
   ]

  username = each.key

  connections = [
    guacamole_connection_rdp.kali_rdp[each.key].identifier,
    guacamole_connection_rdp.windows_rdp[each.key].identifier
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

output "workshop_range_allocations" {
  description = "A detailed map of every range, including node placement, VLAN isolation, and all associated VMs."
  
  value = {
    for k, v in local.ranges : "range-${v.range_id}" => {
      # Top-level range metadata
      assigned_user = k
      target_node   = v.node_name
      vlan_tag      = v.vlan_tag
      
      # Nested map of all VMs belonging to this specific range
      vms = {
        "windows_target" = {
          vm_id       = ( 6000 + ( 100 * v.node_id) + v.range_id )
          template_id = ( 6000 + ( 100 * v.node_id))
          lan_ip      = v.windows_lan_ip
        }
        
        "alpine_router" = {
          vm_id       = ( 7000 + ( 100 * v.node_id) + v.range_id )
          template_id = ( 7000 + ( 100 * v.node_id))
          wan_ip      = v.router_wan_ip
          lan_ip      = v.router_lan_ip
        }
        
        "kali_target" = {
          vm_id       = ( 8000 + ( 100 * v.node_id) + v.range_id )
          template_id = ( 8000 + ( 100 * v.node_id))
          lan_ip      = v.kali_lan_ip
        }       
      }
    }
  }
}