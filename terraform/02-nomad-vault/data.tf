# Read state from 01-nomad-base
data "terraform_remote_state" "nomad-base" {
    backend = "local"

    config = {
        path = "../01-nomad-base/terraform.tfstate"
    }
}

# Local variables for Nomad Master IP
locals {
    nomad_address = data.terraform_remote_state.nomad-base.outputs.nomad_addr
}