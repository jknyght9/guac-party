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

locals {
  nomad_jwt_issuer = "http://172.17.0.1:4646"
}

# Enable Nomad secret engine
resource "vault_mount" "nomad" {
  path = "nomad"
  type = "nomad"
}

# Enable the jwt access using Nomad's jwks keys and url for bound_issuer
resource "vault_jwt_auth_backend" "nomad" {
  description        = "JWT Auth for Nomad Workloads"
  path               = "jwt-nomad"
  jwks_url           =  "${local.nomad_jwt_issuer}/.well-known/jwks.json"
  bound_issuer       = local.nomad_jwt_issuer

  lifecycle {
    prevent_destroy = false
  }
}

# Enable the kv secrets engine
resource "vault_mount" "secret" {
    path = "secret"
    type = "kv-v2"
    description = "Static secrets for Authentik, Gaucamole, and Postgres"
}

module "vault-policy" {
  source = "./modules/vault-policy"

  vault_backend_dependency = vault_jwt_auth_backend.nomad

  jwt_backend_path  = vault_jwt_auth_backend.nomad.path
  secret_mount_path = vault_mount.secret.path
  vault_nomad_path = vault_mount.nomad.path

  postgres_root_pw = random_password.postgres_root_pw.result
  postgres_repl_pw = random_password.postgres_repl_pw.result
  postgres_rewind_pw = random_password.postgres_rewind_pw.result
}



resource "random_password" "postgres_root_pw" {
    length = 18
    special = true
    override_special = "!#%&*()-_=+[]<>:?"
}
resource "random_password" "postgres_repl_pw" {
    length = 18
    special = true
    override_special = "!#%&*()-_=+[]<>:?"
}

resource "random_password" "postgres_rewind_pw" {
    length = 18
    special = true
    override_special = "!#%&*()-_=+[]<>:?"
}

resource "random_password" "Guacamole_pw" {
  length = 18
  special = true
  override_special = "!#%&*()-_=+[]<>:?" 
}

resource "random_password" "Authentik_db_pw" {
    length = 18
    special = true
    override_special = "!#%&*()-_=+[]<>:?"
}
