job "unbound" {
  datacenters = ["dc1"]
  type        = "system"

  constraint {
    operator = "distinct_hosts"
    value    = "true"
  }

  update {
    max_parallel = 1
    min_healthy_time = "10s"
  }

  group "dns" {
    network {
      port "dns" { static = 53 }
    }

    task "unbound" {
      driver = "docker"

      config {
        image = "mvance/unbound:1.21.1"
        network_mode = "host"
        volumes = [
          "local/unbound.conf:/opt/unbound/etc/unbound/unbound.conf"
        ]
      }

      template {
        data = <<EOH
${unbound_config}
EOH
        destination = "local/unbound.conf"
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}