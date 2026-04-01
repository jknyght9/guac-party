job "guacamole-cluster" {
  # 'system' ensures it runs on EVERY node in your cluster
  type = "system"

  # This is for testing, so I don't have to wait for each node to load.
  constraint {
    attribute = "$${node.unique.name}"
    value = "saruman.internal"
  }

  group "guacamole-stack" {
    vault {
      role = "guacamole-role"
      policies = ["guacamole"]
    }
    network {
      port "http" {
        static = 8085
        to = 8080
      }
      dns {
        servers = ["172.17.0.1"]
      }
    }
    # Task 1: The Proxy Daemon (C-based)
    task "guacd" {
      driver = "docker"
      config {
        image = "guacamole/guacd:latest"
        network_mode = "host"
        # No ports block needed if using network mode 'host' or side-by-side
      }
    }

    # Task 2: The Web UI (Java-based)
    task "guacamole" {
      driver = "docker"
      config {
        image = "guacamole/guacamole:latest"
        ports = ["http"]
        dns_servers = ["172.17.0.1"]
      }
     
      env {
        # Point to the guacd sitting right next to it
        GUACD_HOSTNAME = "172.17.0.1"
        GUACD_PORT     = "4822"
        LOGBACK_LEVEL = "debug"
      }
      
      template {
        # Database (Shared across all nodes)
        data = <<EOH
{{ with secret "secret/data/guacamole/auth" }}
POSTGRESQL_SSL_MODE="disable"
POSTGRESQL_ENABLED="true"
POSTGRESQL_HOSTNAME="postgres.internal"
POSTGRESQL_DATABASE="{{ .Data.data.postgres_database }}"
POSTGRESQL_USERNAME="{{ .Data.data.postgres_username }}"
POSTGRESQL_PASSWORD="{{ .Data.data.postgres_password }}"
{{ end }}
EOH
        destination = "secrets/db.env"
        env = true
      }

      service {
        name = "guac-$${attr.unique.consul.name}"
        port = "http"
        
        tags = [
          "traefik.enable=true",          
          # NODE-SPECIFIC URL (e.g., guacamole.saruman.internal)
          "traefik.http.routers.guac-$${attr.unique.consul.name}.rule=Host(\"guacamole.$${attr.unique.consul.name}.internal\")",
          "traefik.http.routers.guac-$${attr.unique.consul.name}.entrypoints=websecure",
          "traefik.http.services.guac-$${attr.unique.consul.name}.loadbalancer.server.port=8085",          
          
          # Shared sticky backend
          "traefik.http.services.guac-$${attr.unique.consul.name}.loadbalancer.sticky=true",
          "traefik.http.services.guac-$${attr.unique.consul.name}.loadbalancer.sticky.cookie.name=guac_session"
        ]
      }
    }
  }
}