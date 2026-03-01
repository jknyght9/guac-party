terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

locals {
  # Extract prefix length from CIDR (e.g. "192.168.1.0/24" -> "24")
  prefix_length = split("/", var.subnet_cidr)[1]

  cloud_init_config = templatefile("${path.module}/../../templates/cloud-init.yaml.tpl", {
    hostname           = var.nomad_node_name
    ssh_public_key     = var.ssh_public_key
    nomad_config       = templatefile("${path.module}/../../templates/nomad.hcl.tpl", {
      node_name         = var.nomad_node_name
      bind_addr         = var.vm_ip
      bootstrap_expect  = var.nomad_bootstrap_expect
      retry_join        = var.nomad_all_ips
      internal_domain   = var.internal_domain
    })
  })
}

resource "proxmox_virtual_environment_file" "cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data      = local.cloud_init_config
    file_name = "${var.nomad_node_name}-cloud-init.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "nomad" {
  name      = var.nomad_node_name
  node_name = var.proxmox_node
  vm_id     = var.vm_id

  agent {
    enabled = true
  }

  cpu {
    cores = var.vm_cores
    type  = "host"
  }

  memory {
    dedicated = var.vm_memory
  }

  clone {
    vm_id = var.template_id
    node_name = var.template_node
    full  = true

    # Resolve template by name (requires data source or known VM ID)
  }

  disk {
    interface    = "scsi0"
    size         = var.vm_disk_size
    datastore_id = var.storage_pool
    iothread     = true
  }

  network_device {
    bridge = var.vm_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.vm_ip}/${local.prefix_length}"
        gateway = var.vm_gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
  }

  on_boot = true

  lifecycle {
    ignore_changes = [
      disk[0].size,
    ]
  }

  tags = ["nomad", "guac-party"]
}
