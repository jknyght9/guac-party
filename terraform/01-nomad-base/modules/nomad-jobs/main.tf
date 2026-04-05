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
        internal_domain   = var.internal_domain
        traefik_yaml      = templatefile("${path.root}/templates/traefik.yaml.tpl", {
          user_virtual_ip = var.user_virtual_ip
          mgmt_virtual_ip = var.mgmt_virtual_ip
        })
        dynamic_yaml     = templatefile("${path.root}/templates/dynamic.yaml.tpl", {
          user_virtual_ip = var.user_virtual_ip
          mgmt_virtual_ip = var.mgmt_virtual_ip
        })
    })

    detach = false
}

resource "nomad_job" "unbound-mgmt" {
    jobspec = templatefile("${path.root}/templates/unbound-mgmt.hcl.tpl", {
        # Here we do a double template file. The inner template passed our variables to the .conf for unbound
        # Then that is passed as a single variable to the nomad hcl.tpl
        unbound_config = templatefile("${path.root}/templates/unbound-mgmt.conf.tpl", {
            internal_domain = var.internal_domain
            node_records = var.unbound_node_records
            mgmt_ip = var.mgmt_subnet_cidr
            mgmt_gateway = var.mgmt_gateway
            virtual_ip = var.mgmt_virtual_ip
        })
    })
    detach = false
}

resource "nomad_job" "unbound-user" {
    jobspec = templatefile("${path.root}/templates/unbound-user.hcl.tpl", {
        # Here we do a double template file. The inner template passed our variables to the .conf for unbound
        # Then that is passed as a single variable to the nomad hcl.tpl
        unbound_config = templatefile("${path.root}/templates/unbound-user.conf.tpl", {
            internal_domain = var.internal_domain
            node_records = var.unbound_node_records
            mgmt_gateway = var.mgmt_gateway
            user_ip = var.user_subnet_cidr
            virtual_ip = var.user_virtual_ip
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