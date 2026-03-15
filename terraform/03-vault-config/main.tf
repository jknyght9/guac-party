terraform {
  required_providers {
    vault = {
        source = "hashicorp/vault"
        version = "5.7.0"
    }
    random = {
        source = "hashicorp/random"
        version = "3.8.1"
    }
  }
}

provider "vault" {
    address = local.vault_url
}

provider "random" {}

data "vault_auth_backend" "token" {
    path = "token"
}

resource "vault_mount" "secret" {
    path = "secret"
    type = "kv-v2"
    description = "Static secrets for Authentik, Gaucamole, and Postgres"
}

# Enable nomad secret engine
resource "vault_mount" "nomad" {
    path = "nomad"
    type = "nomad"
    description = "Nomad secret engine for issuing workload tokens"
}

# 1. Enable JWT Authentication
resource "vault_jwt_auth_backend" "nomad" {
  description        = "JWT Auth for Nomad Workloads"
  path               = "jwt-nomad"
  oidc_discovery_url = "http://192.168.100.87:4646"
  bound_issuer       = "http://127.0.0.1:4646"
}

# 2. Create the Role that maps Nomad Identity to Vault Policies
resource "vault_jwt_auth_backend_role" "nomad_default" {
  backend        = vault_jwt_auth_backend.nomad.path
  role_name      = "vault_default" # This matches the 'identity' in your error log
  token_policies = ["postgres"]

  # These 'claims' ensure ONLY your cluster can use this role
  bound_audiences = ["vault.io"]
  user_claim      = "/nomad_job_id"
  role_type       = "jwt"
}