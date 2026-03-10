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
}