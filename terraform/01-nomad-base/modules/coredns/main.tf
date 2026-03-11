resource "nomad_job" "coredns" {
    jobspec = templatefile("${path.root}/templates/coredns.hcl.tpl", {
        internal_domain = var.internal_domain
        nomad_hosts = var.nomad_hosts
        mgmt_gateway = var.mgmt_gateway
        virtual_ip = var.virtual_ip
    })
    detach = false
}