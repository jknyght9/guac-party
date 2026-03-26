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

provider "random" {}
provider "vault" {
    address = local.vault_url
}

locals {
  postgres_root_pw = random_password.postgres_root_pw.result
  # Authentik_db_pw  = random_password.Authentik_db_pw.result
}

module "vault-policy" {
  source = "./modules/vault-policy"

  nomad_jwt_issuer = "http://172.17.0.1:4646"

  postgres_root_pw = local.postgres_root_pw
}



resource "random_password" "postgres_root_pw" {
    length = 18
    special = true
    override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "Authentik_db_pw" {
    length = 18
    special = true
    override_special = "!#$%&*()-_=+[]{}<>:?"
}
