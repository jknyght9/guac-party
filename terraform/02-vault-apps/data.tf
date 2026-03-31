# Read state from 01-nomad-base
data "terraform_remote_state" "nomad-base" {
    backend = "local"

    config = {
        path = "../01-nomad-base/terraform.tfstate"
    }
}

# Local variables for Nomad Master IP
locals { # Use index [0] as the master node
    vault_address = values(data.terraform_remote_state.nomad-base.outputs.nomad_vm_ips)[0]
    vault_url = "http://${local.vault_address}:8200"

    postgres_root_user   = "admin_user"
    postgres_root_pw     = data.terraform_remote_state.nomad-base.outputs.postgres_root_pw

    postgres_repl_user   = "standby"
    postgres_repl_pw     = data.terraform_remote_state.nomad-base.outputs.postgres_repl_pw

    postgres_rewind_user = "rewind"
    postgres_rewind_pw   = data.terraform_remote_state.nomad-base.outputs.postgres_rewind_pw
}