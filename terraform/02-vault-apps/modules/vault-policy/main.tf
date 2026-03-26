# 1. Renewing token for Nomad
resource "vault_token" "nomad_mgmt" {
    policies = ["nomad-server", "authentik", "postgres"]
    renewable = true
    no_parent = true
    period = "24h"
}

# 2. Enable Nomad secret engine
resource "vault_mount" "nomad" {
  path = "nomad"
  type = "nomad"
}

# 3. Nomad Management Role
resource "vault_nomad_secret_role" "management" {
  backend = vault_mount.nomad.path
  role    = "management-role"
  type    = "management"
}

# 4. Enable the jwt access using Nomad's jwks keys and url for bound_issuer
resource "vault_jwt_auth_backend" "nomad" {
  description        = "JWT Auth for Nomad Workloads"
  path               = "jwt-nomad"
  jwks_url           =  "${var.nomad_jwt_issuer}/.well-known/jwks.json"
  bound_issuer       = var.nomad_jwt_issuer
}

# 5. Create the Role that maps Nomad Identity to Vault Policies
resource "vault_jwt_auth_backend_role" "postgres_admin" {
  backend        = vault_jwt_auth_backend.nomad.path
  role_name      = "postgres-admin-role"
  token_policies = ["postgres", "default"]

  # These 'claims' ensure ONLY your cluster can use this role
  bound_audiences = ["vault.io"]
  user_claim      = "nomad_job_id"
  role_type       = "jwt"
}

# 6. Enable the kv secrets engine
resource "vault_mount" "secret" {
    path = "secret"
    type = "kv-v2"
    description = "Static secrets for Authentik, Gaucamole, and Postgres"
}

# Create postgres user and password as secrets
resource "vault_kv_secret_v2" "postgres_test" {
  mount                = vault_mount.secret.path
  name                 = "postgres/test-user"
  data_json = jsonencode({
    username = "admin_user"
    password = var.postgres_root_pw
  })
}