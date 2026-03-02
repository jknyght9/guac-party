locals {
  node_names = keys(var.proxmox_nodes)
  node_count = length(local.node_names)
  all_nomad_ips = [for k, v in var.proxmox_nodes : v.nomad_ip]

  # Get master-peer ips
  nomad_master_ip = local.all_nomad_ips[0]
  nomad_peer_ips = slice(local.all_nomad_ips, 1, length(local.all_nomad_ips))
}

# SDN zone + VNet + subnet (for guest VMs, out of scope but provisioned)
# module "proxmox_sdn" {
#  source = "./modules/proxmox-sdn"
#
#  zone_name   = var.sdn_zone_name
#  vnet_name   = var.sdn_vnet_name
#  subnet_cidr = var.sdn_subnet_cidr
#  gateway     = var.sdn_gateway
#}

# One Nomad VM per Proxmox node
module "nomad_node" {
  source   = "./modules/nomad-node"
  for_each = var.proxmox_nodes

  node_name     = "nomad-${each.key}"
  proxmox_node  = each.key
  template_node = var.proxmox_first_node_name
  template_id   = 9000
  vm_id         = 9001 + index(local.node_names, each.key) 
  vm_ip         = each.value.nomad_ip
  vm_gateway    = var.mgmt_gateway
  vm_bridge     = var.mgmt_bridge
  subnet_cidr   = var.mgmt_subnet_cidr
  ssh_public_key = var.ssh_public_key
  template_name = var.vm_template_name
  vm_cores      = var.vm_cores
  vm_memory     = var.vm_memory
  vm_disk_size  = var.vm_disk_size

  # Nomad cluster config
  nomad_node_name    = "nomad-${each.key}.${var.internal_domain}"
  nomad_all_ips      = local.all_nomad_ips
  nomad_bootstrap_expect = local.node_count
  internal_domain    = var.internal_domain

  #depends_on = [module.proxmox_sdn]
}

# On the master node peer other nodes, create and start gluster volume
resource "null_resource" "gluster_master_init" {
  depends_on = [module.nomad_node]

  # Only trigger when number of nodes changed
  triggers = {
    cluster_size = local.node_count
  }

  provisioner "remote-exec" {
    inline = flatten([
      # Peer probe all other nodes
      [ for ip in local.nomad_peer_ips : "sudo gluster peer probe ${ip}"],

      # Create volume on replicated on every node
      [
      "sudo gluster volume create nomad-data replica ${length(local.all_nomad_ips)} ${join(" ", [for ip in local.all_nomad_ips : "${ip}:/srv/gluster/brick0/nomad-data"])}",
      "sudo gluster volume start nomad-data",
      ]
    ])
  }
  
  connection {
    host = local.nomad_master_ip
    type = "ssh"
    user = "ubuntu"
  }
}

resource "null_resource" "gluster_mount_all" {
  depends_on = [ null_resource.gluster_master_init ]

  for_each = var.proxmox_nodes

  # Format SDA 50gb disk and auto mount
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /mnt/nomad-data",
      "sudo mount -t glusterfs ${each.value.nomad_ip}:/nomad-data /mnt/nomad-data",
      "sudo sh -c 'echo \"${each.value.nomad_ip}:/nomad-data /mnt/nomad-data glusterfs defaults,_netdev 0 0\" >> /etc/fstab'",
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
      host = each.value.nomad_ip
    }
  }
}