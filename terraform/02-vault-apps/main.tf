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
    postgresql = {
      source  = "doctolib/postgresql"
      version = "2.26.2"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "2.5.2"
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
}

# Enable the kv secrets engine
resource "vault_mount" "secret" {
    path = "secret"
    type = "kv-v2"
    description = "Static secrets for Authentik, Gaucamole, and Postgres"
}

module "vault-policy" {
  source = "./modules/vault-policy"

  jwt_backend_path  = vault_jwt_auth_backend.nomad.path
  secret_mount_path = vault_mount.secret.path
  vault_nomad_path = vault_mount.nomad.path
  # These creds are pulled from layer01. They will not be recreated on a layer 02 apply
  postgres_root_user = local.postgres_root_user
  postgres_root_pw = local.postgres_root_pw

  postgres_repl_user = local.postgres_repl_user
  postgres_repl_pw = local.postgres_repl_pw

  postgres_rewind_user = local.postgres_rewind_user
  postgres_rewind_pw = local.postgres_rewind_pw
}

module "postgres-init" {
  source = "./modules/postgres-init"
  depends_on = [ module.vault-policy ]

  jwt_backend_path  = vault_jwt_auth_backend.nomad.path
  secret_mount_path = vault_mount.secret.path
  vault_nomad_path = vault_mount.nomad.path

  authentik_db_pw = random_password.authentik_db_pw.result
  authentik_secret_key = random_id.authentik_secret_key.b64_std

  guacamole_admin_pw = random_password.guacamole_admin_pw.result
  guacamole_db_pw = random_password.guacamole_db_pw.result

  bootstrap_email = var.authentik_bootstrap_email
  bootstrap_password = var.authentik_bootstrap_password
  bootstrap_token = random_bytes.authentik_token.hex
}

module "user-apps" {
  source = "./modules/user-apps"
  depends_on = [ module.postgres-init ]
  # Yes this says vault address, it is the 1st Nomad address
  leader_address = local.vault_address
}  

# Authentik recommends using 60 byte base64 for secret key
resource "random_id" "authentik_secret_key" {
    byte_length = 60
}

resource "random_password" "authentik_db_pw" {
  length = 24
  special = false
}

# 128 bit api key
resource "random_bytes" "authentik_token" {
  length = 16
}

resource "random_password" "guacamole_admin_pw" {
  length = 24
  special = false
}

resource "random_password" "guacamole_db_pw" {
  length = 24
  special = false
}