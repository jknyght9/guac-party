# Guacamole Secrets
resource "vault_kv_secret_v2" "guacamole" {
  mount = vault_mount.secret.path
  name = "guac/auth"

  data_json = jsonencode({
    mysql_password    = var.guacamole_db_pw
    guacadmin_password = var.guacamole_admin_pw
  })
}

# Authentik Secrets
resource "vault_kv_secret_v2" "authentik" {
  mount = vault_mount.secret.path
  name  = "authentik/auth"
  
  data_json = jsonencode({
    secret_key     = var.authentik_secret_key
    postgresql_password = var.postgres_root_pw # Authentik's connection to PG
    email_password = var.authentik_email_pw
  })
}