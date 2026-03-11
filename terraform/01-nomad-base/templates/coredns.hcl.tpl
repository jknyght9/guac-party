job "coredns" {
  datacenters = ["dc1"]
  type        = "system"

  group "dns" {
    network {
      # Use host DNS port
      port "dns" { static = 53 }
    }

    task "coredns" {
      driver = "docker"

      config {
        image = "coredns/coredns:latest"
        ports = ["dns"]
        network_mode = "host"
        args = ["-conf", "/local/Corefile"]
      }

      template {
        data = <<EOF
.:53 {
    # Wildcard for all internal traffic
    template ANY ANY ${internal_domain} {
        match ".*\.${internal_domain}\."
        answer "{{`{{ .Name }}`}} 60 IN A ${virtual_ip}"
        fallthrough
    }

    # Optional: Hardcoded node IPs for troubleshooting
    hosts {
        %{ for host in nomad_hosts ~}
        ${host}
        %{ endfor ~}
        fallthrough
    }

    forward . ${mgmt_gateway} 1.1.1.1
    cache 30
    log
    errors
}
EOF
        destination = "local/Corefile"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}