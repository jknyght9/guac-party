terraform {
  required_providers {
    nomad = {
        source = "hashicorp/nomad"
        version = "2.5.2"
    }
  }
}

resource "nomad_job" "traefik" {
    jobspec = templatefile("${path.root}/templates/traefik.nomad.hcl.tpl", {
        internal_domain = var.internal_domain
    })

    detach = false
}