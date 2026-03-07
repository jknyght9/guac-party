datacenter = "dc1"
data_dir   = "/opt/nomad/data"
name       = "${node_name}"
bind_addr  = "${bind_addr}"

advertise {
  http = "${bind_addr}"
  rpc  = "${bind_addr}"
  serf = "${bind_addr}"
}

server {
  enabled          = true
  bootstrap_expect = ${bootstrap_expect}

  server_join {
    retry_join = [%{ for i, ip in retry_join ~}"${ip}"%{ if i < length(retry_join) - 1 ~}, %{ endif ~}%{ endfor ~}]
  }
}

client {
  enabled = true

  host_volume "vault" {
    path      = "/opt/volumes/vault"
    read_only = false
  }

  host_volume "authentik-db" {
    path      = "/opt/volumes/authentik-db"
    read_only = false
  }

  host_volume "guacamole-db" {
    path      = "/opt/volumes/guacamole-db"
    read_only = false
  }
}

plugin "docker" {
  config {
    allow_privileged = true

    volumes {
      enabled = true
    }
  }
}
