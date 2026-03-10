terraform {
  required_providers {
    nomad = {
        source = "hashicorp/nomad"
        version = "2.5.2"
    }
  }
}

resource "nomad_job" "vault" {
    jobspec = templatefile("${path.root}/templates/vault.nomad.hcl.tpl", {
        nomad_all_ips   = var.nomad_all_ips
        internal_domain = var.internal_domain
    })

    detach = false
}