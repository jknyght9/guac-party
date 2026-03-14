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