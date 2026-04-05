datacenter = "dc1"
data_dir   = "/opt/nomad/data"
name       = "${node_name}"
#bind_addr  = "${bind_addr} 127.0.0.1"

# Each nomad node will point internally at its own vault instance
vault {
  enabled = true
  address = "http://${node_name}:8200"
  task_token_ttl = "1h"
  
  default_identity {
    aud = ["vault.io"]
    ttl = "1h"
  }
}

addresses {
  http = "${bind_addr} 127.0.0.1"
  rpc  = "${bind_addr}"
  serf = "${bind_addr}"
}

consul {
  address = "127.0.0.1:8500"
}

server {
  enabled          = true
  bootstrap_expect = ${bootstrap_expect}

  server_join {
    retry_join = [%{ for i, ip in retry_join ~}"${ip}"%{ if i < length(retry_join) - 1 ~}, %{ endif ~}%{ endfor ~}]
  }
  oidc_issuer = "http://${bind_addr}:4646"

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

  # Define different network namespaces for each interface
  host_network "management" {
    interface = "eth0"
  }
  host_network "public" {
    interface = "eth1"
  }
  host_network "range" {
    interface = "eth2"
  }
}

plugin "docker" {
  config {
    allow_privileged = true

    volumes {
      enabled = true
    }

    allow_caps = [
      "audit_write", "chown", "dac_override", "fowner", "fsetid", "kill", "mknod", 
      "net_bind_service", "setfcap", "setgid", "setpcap", "setuid", "sys_chroot", 
      "ipc_lock"
    ]
  }
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}