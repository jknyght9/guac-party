terraform {
  required_providers {
    nomad = {
        source = "hashicorp/nomad"
        version = "2.5.2"
    }
  }
}

provider "nomad" {
    address = local.nomad_address
}

resource "nomad_job" "vault" {
    jobspec = templatefile("${path.module}/jobs/vault.nomad.hcl.tpl", {
        nomad_ips = data.terraform_remote_state.nomad-base.outputs.nomad_vm_ips
        internal_domain = var.internal_domain
    })

    detach = false
}