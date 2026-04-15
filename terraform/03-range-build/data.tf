# Read state from 02-nomad-base
data "terraform_remote_state" "vault-apps" {
    backend = "local"

    config = {
        path = "../02-vault-apps/terraform.tfstate"
    }
}

data "terraform_remote_state" "nomad-base" {
    backend = "local"

    config = {
        path = "../01-nomad-base/terraform.tfstate"
    }
}

locals {
  authentik_token_hex = data.terraform_remote_state.vault-apps.outputs.authentik_token_hex
  nomad_list          = data.terraform_remote_state.nomad-base.outputs.nomad_vm_ips
}