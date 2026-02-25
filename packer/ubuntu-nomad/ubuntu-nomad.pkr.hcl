packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "ubuntu-nomad" {
  username                 = var.proxmox_api_token_id
  proxmox_url              = var.proxmox_api_url
  token                    = var.proxmox_api_token_secret
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true
  
  vm_id   = var.vm_id
  vm_name = var.vm_name

  boot_iso {
    type         = "scsi"
    iso_file     = var.iso_local
    iso_checksum = var.iso_checksum
    unmount      = true
  }

  #iso_url          = var.iso_url
  #iso_checksum     = var.iso_checksum
  #iso_storage_pool = var.iso_storage_pool
  #unmount_iso      = true

  os       = "l26"
  cores    = var.vm_cores
  memory   = var.vm_memory
  cpu_type = "host"
  machine  = "q35"
  bios     = "ovmf"

  scsi_controller = "virtio-scsi-single"

  disks {
    type         = "virtio"
    discard      = true
    disk_size    = var.vm_disk_size
    storage_pool = var.vm_storage_pool
    format       = "raw"
    io_thread     = true
  }

  efi_config {
    efi_storage_pool  = var.vm_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = false
  }

  network_adapters {
    model  = "virtio"
    bridge = var.vm_bridge
  }

  cloud_init              = true
  cloud_init_disk_type    = "scsi"
  cloud_init_storage_pool = var.vm_storage_pool

  boot_command = [
    "<wait3s>e<down><down><down><end>",
    " autoinstall ds='nocloud-net;s=http://{{.HTTPIP}}:{{.HTTPPort}}/'",
    "<F10>"
  ]

  boot_wait = "5s"

  http_directory = "http"

  qemu_agent = true
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "20m"

  template_name        = var.vm_name
  template_description = "Ubuntu 24.04 with Docker CE and Nomad - built by guac-party Packer"

  tags = "template;ubuntu;nomad"
}

build {
  sources = ["source.proxmox-iso.ubuntu-nomad"]

  provisioner "shell" {
    scripts = ["scripts/setup.sh"]
    execute_command = "sudo bash '{{.Path}}'"
  }

  provisioner "shell" {
    inline = [
      "sudo cloud-init clean",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo sync"
    ]
  }
}
