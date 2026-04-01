# Create a Role for Traefik keys and certs
resource "vault_pki_secret_backend_role" "master_role" {
  backend          = vault_mount.pki_intermediate.path
  name             = "master-role"
  allowed_domains  = ["internal", "consul", "service.consul"]
  allow_subdomains = true
  key_type = "rsa"
  key_bits = 4096
  max_ttl          = "8760h" # 1 year
  allow_ip_sans    = true
}

# --- Global Certificate for all .internal domains ---
resource "vault_pki_secret_backend_cert" "master_internal" {
  depends_on  = [vault_pki_secret_backend_role.master_role]
  backend     = vault_mount.pki_intermediate.path
  name        = vault_pki_secret_backend_role.master_role.name
  common_name = "*.internal"
  
  # Add node-specific SANs
  alt_names = [
    "*.saruman.internal",
    "*.sauron.internal",
    "*.smeagol.internal"
  ]
}

resource "null_resource" "deploy_certs" {
  triggers = {
    traefik_cert = vault_pki_secret_backend_cert.master_internal.certificate
  }

  connection {
    host = var.leader_address
    type = "ssh"
    user = "ubuntu"
  }
  # Traefik 
  provisioner "file" {
    content     = "${vault_pki_secret_backend_cert.master_internal.certificate}\n${vault_pki_secret_backend_cert.master_internal.ca_chain}"
    destination = "/tmp/master.crt"
  }

  provisioner "file" {
    content     = vault_pki_secret_backend_cert.master_internal.private_key
    destination = "/tmp/master.key"
  }

  provisioner "file" {
    content     = vault_pki_secret_backend_root_cert.root_ca.certificate
    destination = "/tmp/root_ca.crt"
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      # Copy the updated Traefik keys and full chain to Gluster
      "sudo mv /tmp/master.crt /mnt/nomad-data/traefik/certs/master.crt",
      "sudo mv /tmp/master.key /mnt/nomad-data/traefik/certs/master.key",
      "sudo mv /tmp/root_ca.crt /mnt/nomad-data/traefik/certs/",

      "sudo chmod 400 /mnt/nomad-data/traefik/certs/master.key",
      "sudo chmod 600 /mnt/nomad-data/traefik/certs/master.crt",
      "sudo sh -c 'chown root:root /mnt/nomad-data/traefik/certs/*'"
    ]
  }
}