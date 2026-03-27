# 1. Renewing token for Nomad
resource "vault_token" "nomad_mgmt" {
    policies = ["nomad-server", "authentik", "postgres"]
    renewable = true
    no_parent = true
    period = "24h"
}

# 3. Nomad Management Role
resource "vault_nomad_secret_role" "management" {
  backend = var.vault_nomad_path
  role    = "management-role"
  type    = "management"
}

# 5. Create the Role that maps Nomad Identity to postgres Vault Policies
resource "vault_jwt_auth_backend_role" "postgres_admin" {
  backend        = var.jwt_backend_path
  role_name      = "postgres-role"
  token_policies = ["postgres", "default"]

  # These 'claims' ensure ONLY your cluster can use this role
  bound_audiences = ["vault.io"]
  user_claim      = "nomad_job_id"
  role_type       = "jwt"
}

# 5. Create the Role that maps Nomad Identity to Gaucamole Vault Policies
resource "vault_jwt_auth_backend_role" "guacamole" {
  backend        = var.jwt_backend_path
  role_name      = "guacamole-role"
  token_policies = ["guacamole", "default"]

  # These 'claims' ensure ONLY your cluster can use this role
  bound_audiences = ["vault.io"]
  user_claim      = "nomad_job_id"
  role_type       = "jwt"
}

# 5. Create the Role that maps Nomad Identity to Authentik Vault Policies
resource "vault_jwt_auth_backend_role" "authentik" {
  backend        = var.jwt_backend_path
  role_name      = "authentik-role"
  token_policies = ["authentik", "default"]

  # These 'claims' ensure ONLY your cluster can use this role
  bound_audiences = ["vault.io"]
  user_claim      = "nomad_job_id"
  role_type       = "jwt"
}

# Create postgres user and password as secrets
resource "vault_kv_secret_v2" "postgres_system" {
  mount                = var.secret_mount_path
  name                 = "postgres/auth"

  data_json = jsonencode({
    username = var.postgres_root_user
    password = var.postgres_root_pw

    repl_user = var.postgres_repl_user
    repl_password = var.postgres_repl_pw

    rewind_user = var.postgres_rewind_user
    rewind_password = var.postgres_rewind_pw
  })
}

# Deploy Patroni cluster as a Nomad job
resource "nomad_job" "postgres" {
  jobspec = templatefile("${path.root}/templates/postgres-ha.hcl.tpl", {
    patroni_yaml = file("${path.root}/templates/patroni.yaml.tpl")
  })

  depends_on = [ vault_jwt_auth_backend_role.postgres_admin ]
  detach = false
}
