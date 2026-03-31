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

resource "nomad_job" "unbound" {
    jobspec = templatefile("${path.root}/templates/unbound.hcl.tpl", {
        # Here we do a double template file. The inner template passed our variables to the .conf for unbound
        # Then that is passed as a single variable to the nomad hcl.tpl
        unbound_config = templatefile("${path.root}/templates/unbound.conf.tpl", {
            internal_domain = var.internal_domain
            node_records = var.unbound_node_records
            mgmt_gateway = var.mgmt_gateway
            virtual_ip = var.virtual_ip
        })
    })
    detach = false
}

resource "nomad_job" "vault" {
    jobspec = templatefile("${path.root}/templates/vault.nomad.hcl.tpl", {
        # Only inform vault of the nomad records, avoids repeated addresses
        node_records   = [ for r in var.unbound_node_records : r ]
        internal_domain = var.internal_domain
    })

    detach = false
}

resource "nomad_job" "consul-ui" {
    jobspec = templatefile("${path.root}/templates/consul-ui.hcl.tpl", {})
    detach = false
}