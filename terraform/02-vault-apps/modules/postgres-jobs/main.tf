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
    email_password = var.authentik_email_pw
  })
}
# =====================


# ===Guacamole Setup===
resource "postgresql_role" "guacamole" {
  name = "guacamole"
  login = true
  password = var.guacamole_db_pw
}

resource "postgresql_database" "guacamole" {
  name = "guacamole"
  owner  = postgresql_role.guacamole.name
}

# Guacamole Secrets
resource "vault_kv_secret_v2" "guacamole" {
  mount = var.secret_mount_path
  name = "guac/auth"

  data_json = jsonencode({
    mysql_password     = var.guacamole_db_pw
    guacadmin_password = var.guacamole_admin_pw
  })
}
# =====================