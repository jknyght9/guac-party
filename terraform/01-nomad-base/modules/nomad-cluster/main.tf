terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

locals {
    node_names = keys(var.proxmox_nodes)
    all_ips = [for v in var.proxmox_nodes : v.nomad_ip ]
    master_ip = local.all_ips[0]
    peer_ips = slice(local.all_ips, 1, length(local.all_ips))

    prefix_length = split("/", var.subnet_cidr)[1]

    host_entries = [
        for k, v in var.proxmox_nodes: "${v.nomad_ip} ${k}.${var.internal_domain}"
    ]
}

# 1. Define Cloud init
resource "proxmox_virtual_environment_file" "cloud_init" {
    for_each = var.proxmox_nodes
    content_type = "snippets"
    datastore_id = "local"
    node_name = each.key

    source_raw {
        data = templatefile("${path.module}/../../templates/cloud-init.yaml.tpl", {
            hostname = "nomad-${each.key}.${var.internal_domain}"
            sshd_config = templatefile("${path.module}/../../templates/sshd_config.tpl", {
              nomad_ip = "${each.value.nomad_ip}"
            })
            ssh_public_key = var.ssh_public_key
            # Nomad configuration
            nomad_config = templatefile("${path.module}/../../templates/nomad.hcl.tpl", {
                node_name = "${each.key}.${var.internal_domain}"
                bind_addr = "${each.value.nomad_ip}"
                bootstrap_expect = length(local.node_names)
                retry_join = local.all_ips
                internal_domain = var.internal_domain
            })
            consul_config = templatefile("${path.module}/../../templates/consul.hcl.tpl", {
                node_name = "${each.key}.${var.internal_domain}"
                bind_addr = "${each.value.nomad_ip}"
                bootstrap_expect = length(local.node_names)
                retry_join = local.all_ips
                internal_domain = var.internal_domain
                node_ip = "${each.value.nomad_ip}"
            })
            # Keepalived configuration
            keepalived_config = templatefile("${path.module}/../../templates/keepalived.conf.tpl", {
                mgmt_virtual_ip = var.mgmt_virtual_ip
                mgmt_passwd     = var.mgmt_passwd
                user_virtual_ip = var.user_virtual_ip
                user_passwd     = var.user_passwd                
                priority        = (100 - index(local.node_names, each.key) * 20)
            })
            # Resolved configuration
            resolved_config = templatefile("${path.module}/../../templates/resolved.conf.tpl", {
              vm_gateway = var.vm_gateway
            })
            # Add Docker registry cache
            docker_daemon_json = templatefile("${path.module}/../../templates/docker-registry.json.tpl", {})
        })
        file_name = "${each.key}-cloud-init.yaml"
    }
}

# 2. Clone all Nomad nodes
resource "proxmox_virtual_environment_vm" "nomad" {

    for_each = var.proxmox_nodes
    name = "nomad-${each.key}.${var.internal_domain}"
    node_name     = "${each.key}"
    #proxmox_node  = each.key

    vm_id = 9001 + index(local.node_names, each.key)

    agent { enabled = true }

    cpu {
        cores = var.vm_cores
        type = "host"
    }

    memory { dedicated = var.vm_memory }

    clone {
        vm_id = var.template_id
        node_name = var.template_node
        full = true
    }

    disk {
        interface = "scsi0"
        size = var.vm_disk_size
        datastore_id = var.storage_pool
        iothread = true
    }
    # Management Bridge
    network_device {
        bridge = var.vm_bridge
        model = "virtio"
    }
    # User Bridge
    network_device {
      bridge = var.user_bridge_name
      model = "virtio"
    }
    # Cyber Range Bridge
    network_device {
      bridge = var.range_bridge_name
      model = "virtio"
    }

    initialization {
        # Management Network
        ip_config {            
            ipv4 {
                address = "${each.value.nomad_ip}/${local.prefix_length}"
                gateway = var.vm_gateway
            }
        }
        # User Network
        ip_config {
            ipv4 {                # Yes this is ugly, deal with it
              address = "10.30.0.${element(split(".", each.value.nomad_ip), 3)}/${local.prefix_length}"
            }
        }
        # Range Network
        ip_config {
            ipv4 {
              address = "10.40.0.${element(split(".", each.value.nomad_ip), 3)}/${local.prefix_length}"
            }
        }
        dns {
            servers = [var.vm_gateway, "1.1.1.1"]
            domain = var.internal_domain
        }
        user_data_file_id = proxmox_virtual_environment_file.cloud_init[each.key].id
    }

    on_boot = true

    # Per-node provisioning (Local disks & /etc/hosts)
    provisioner "remote-exec" {
        inline = flatten([
            # Partition extra disk
            "sudo parted /dev/sda --script mklabel gpt",
            "sudo parted /dev/sda --script mkpart primary xfs 1MiB 20GiB",
            "sudo parted /dev/sda --script mkpart primary 20GiB 100%",
            "sudo parted /dev/sda --script set 2 lvm on",
            "sleep 2",
            # Glusterfs
            "sudo mkfs.xfs -f /dev/sda1",
            "sudo mkdir -p /srv/gluster/brick0",
            "sudo mount /dev/sda1 /srv/gluster/brick0",
            "sudo sh -c 'echo \"/dev/sda1 /srv/gluster/brick0 xfs defaults 0 0\" >> /etc/fstab'",
            "sudo mkdir -p /srv/gluster/brick0/nomad-data",
            # Extra LVM space
            "export VG_NAME=$(sudo vgs --noheadings -o name | tr -d ' ')",
            "export LV_NAME=$(sudo lvs --noheadings -o lv_name | tr -d ' ' | head -n 1)",
            "sudo pvcreate /dev/sda2",
            "sudo vgextend $VG_NAME /dev/sda2",
            "sudo lvextend -l +100%FREE /dev/$VG_NAME/$LV_NAME",
            "sudo resize2fs /dev/$VG_NAME/$LV_NAME",
            # DNS Controls
            [
            for entry in local.host_entries :
            "grep -q '${entry}' /etc/hosts || echo '${entry}' | sudo tee -a /etc/hosts"
            ],
            # Create Vault directory and set permissions.
            "sudo mkdir -p /opt/vault/data",
            "sudo chown -R 100:100 /opt/vault",
            # Enabled nonlocal ip binding for keepalived
            "sudo sysctl net.ipv4.ip_nonlocal_bind=1",
            # Persist through reboots
            "sudo sh -c 'echo \"net.ipv4.ip_nonlocal_bind=1\" >> /etc/sysctl.d/98-keepalived.conf'"
        ])

        connection {
            type = "ssh"
            user = "ubuntu"
            host = each.value.nomad_ip
        }
    }

    tags = ["nomad", "guac-party"]
}

# 3. Initialize Gluster Cluster on the Master Node
#    And generate ssl cert stored on gluster
resource "null_resource" "gluster_master_init" {
  depends_on = [proxmox_virtual_environment_vm.nomad]

  triggers = {
    cluster_ips = join(",", local.all_ips)
  }

  provisioner "remote-exec" {
    inline = flatten([
      # Peer probe all other nodes
      [for ip in local.peer_ips : "sudo gluster peer probe ${ip}"],

      # Create and start the replicated volume
      "sudo gluster volume create nomad-data replica ${length(local.all_ips)} ${join(" ", [for ip in local.all_ips : "${ip}:/srv/gluster/brick0/nomad-data"])} force",
      "sudo gluster volume start nomad-data",

      # Mount locally on master
      "sudo mkdir -p /mnt/nomad-data",
      "sudo mount -t glusterfs ${local.master_ip}:/nomad-data /mnt/nomad-data",
      "sudo sh -c 'echo \"${local.master_ip}:/nomad-data /mnt/nomad-data glusterfs defaults,_netdev 0 0\" >> /etc/fstab'",

      # Directory structure
      "sudo mkdir -p /mnt/nomad-data/traefik/certs",
      "sudo chmod -R 700 /mnt/nomad-data/traefik/certs",
      "sudo mkdir -p /mnt/nomad-data/authentik/assets/public",
      "sudo chown 1000:1000 /mnt/nomad-data/authentik/assets",
      "sudo chmod ug+rwx /mnt/nomad-data/authentik/assets",
      # Generate certs one time on the master node'
      flatten([
      "sudo sh -c ' \\",
      "openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \\",
        " -keyout /mnt/nomad-data/traefik/certs/master.key \\",
        " -out /mnt/nomad-data/traefik/certs/master.crt \\",
        " -days 3650 -nodes \\",
        " -subj '/CN=*.${var.internal_domain}' \\",
        " -addext 'subjectAltName=DNS:*.${var.internal_domain},DNS:${var.internal_domain}''",
      ]),
      "sudo chmod 644 /mnt/nomad-data/traefik/certs/master.crt",
      "sudo chmod 600 /mnt/nomad-data/traefik/certs/master.key"
    ])

    connection {
      host = local.master_ip
      type = "ssh"
      user = "ubuntu"
    }
  }
}

# 4. Mount the volume on all other nodes
resource "null_resource" "gluster_secondary_mounts" {
  for_each   = { for k, v in var.proxmox_nodes : k => v if v.nomad_ip != local.master_ip }
  depends_on = [null_resource.gluster_master_init]

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /mnt/nomad-data",
      "sudo mount -t glusterfs ${each.value.nomad_ip}:/nomad-data /mnt/nomad-data",
      "sudo sh -c 'echo \"${each.value.nomad_ip}:/nomad-data /mnt/nomad-data glusterfs defaults,_netdev 0 0\" >> /etc/fstab'"
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
      host = each.value.nomad_ip
    }
  }
}

# 5. Wait for Nomad to start
resource "null_resource" "nomad_health_check" {
  depends_on = [null_resource.gluster_secondary_mounts]

  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ubuntu"
      host = local.master_ip
    }

    # Curls Nomad API until it gets a 200 OK or times out. Forces Terraform to wait before deploying Vault
    inline = [
      "echo 'Starting Nomad health check loop...'",
      <<-EOT
      for i in $(seq  1 30); do
        if [ $(curl -s -w "%%{http_code}" -o /dev/null "http://localhost:4646/v1/agent/self") = "200" ]; then
          echo "Nomad API is responding with 200 OK!"
          exit 0
        fi
        echo "Attempt $i: Nomad API not ready. Waiting 5s..."
        sleep 5
      done
      echo "Nomad failed to start within timeout period."
      exit 1
      EOT
    ]
  }
}