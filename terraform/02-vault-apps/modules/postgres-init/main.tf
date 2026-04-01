terraform {
  # Explicitly pass this provider. Terraform gets mad when a provider is not from hashicorp
  # And will not implicitly pass it to the module. Others such as Nomad, Vault, and Random do get implicitly passed
  required_providers {
    postgresql = {
      source  = "doctolib/postgresql"
      version = "2.26.2"
    }
  }
}

# ===Authentik Setup===
resource "postgresql_role" "authentik" {
  name = "authentik"
  login = true
  password = var.authentik_db_pw
}

resource "postgresql_database" "authentik" {
  name = "authentik"
  owner  = postgresql_role.authentik.name
}

# Authentik Secrets
resource "vault_kv_secret_v2" "authentik" {
  mount = var.secret_mount_path
  name  = "authentik/auth"
  
  data_json = jsonencode({
    db_name        = postgresql_database.authentik.name
    db_username    = postgresql_role.authentik.name
    db_password    = var.authentik_db_pw
    secret_key     = var.authentik_secret_key
    admin_password = var.bootstrap_password
    admin_email    = var.bootstrap_email
    admin_token    = var.bootstrap_token
  })
}

# =====================


# ===Guacamole Setup===
# Have Guacamole secrets loaded into vault before starting
resource "postgresql_role" "guacamole" {
  name = "guacamole"
  login = true
  password = var.guacamole_db_pw
}

resource "postgresql_database" "guacamole_db" {
  depends_on = [ postgresql_role.guacamole ]
  name = "guacamole"
  owner  = postgresql_role.guacamole.name
}

# Guacamole Secrets
resource "vault_kv_secret_v2" "guacamole" {
  mount = var.secret_mount_path
  name = "guacamole/auth"

  data_json = jsonencode({
    postgres_database  = postgresql_database.guacamole_db.name
    postgres_username  = postgresql_role.guacamole.name
    postgres_password  = var.guacamole_db_pw
    guacadmin_username = var.guacamole_admin_user
    guacadmin_password = var.guacamole_admin_pw
  })
}

data "vault_generic_secret" "guac" {
  depends_on = [ vault_kv_secret_v2.guacamole ]
  path = "secret/guacamole/auth"
}

resource "random_id" "guac_salt" {
  byte_length = 32
}

locals {
  raw_password = data.vault_generic_secret.guac.data["guacadmin_password"]
  salt_upper = upper(random_id.guac_salt.hex)
  guac_hash = sha256("${local.raw_password}${local.salt_upper}")
}

# Create database schema
resource "null_resource" "bootstrap_guac_db" {
  depends_on = [ postgresql_database.guacamole_db ]

  provisioner "file" {
    source = "${path.root}/templates/001-create-schema.sql"
    destination = "/tmp/001-create-schema.sql"
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "export PGPASSWORD='${data.vault_generic_secret.guac.data["postgres_password"]}'",
      "psql -h postgres.internal -U ${postgresql_role.guacamole.name} -d ${postgresql_database.guacamole_db.name} -f /tmp/001-create-schema.sql",
      "rm /tmp/001-create-schema.sql"
    ]
  }
  connection {
    host = var.leader_address
    type = "ssh"
    user = "ubuntu"
  }
}
# Create guac admin user with credentials pulled from global.tfvars
resource "null_resource" "bootstrap_guac_admin" {
  depends_on = [
    data.vault_generic_secret.guac,
    null_resource.bootstrap_guac_db
    ]

  provisioner "file" {
    content = templatefile("${path.root}/templates/002-create-admin-user.sql.tpl", {
      password_hash = upper(local.guac_hash)
      password_salt = local.salt_upper
    })
    destination = "/tmp/002-create-admin-user.sql"
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "export PGPASSWORD='${data.vault_generic_secret.guac.data["postgres_password"]}'",
      "psql -h postgres.internal -U ${postgresql_role.guacamole.name} -d ${postgresql_database.guacamole_db.name} -f /tmp/002-create-admin-user.sql",
      "rm /tmp/002-create-admin-user.sql"
    ]
  }
  connection {
    host = var.leader_address
    type = "ssh"
    user = "ubuntu"
  }
}

# =====================