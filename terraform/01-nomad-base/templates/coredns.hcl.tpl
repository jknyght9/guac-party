job "coredns" {
  datacenters = ["dc1"]
  type        = "system"

  group "dns" {
    network {
      # Use host DNS port
      port "dns" { static = 53 }
    }
    # This fixes some issues where Nomad would spit out errors about port 53 being used
    # It still spits out the errors but slightly less.
    update {
      max_parallel = 1
      health_check = "checks"
      min_healthy_time = "5s"
      healthy_deadline = "2m"
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