job "authentik" {
  datacenters = ["dc1"]
  type        = "system"

  # --- AUTHENTIK SERVER ---
  group "server" {
    
    network {
      port "http" {
        static = 9000
      }
      port "health" {
        static = 8000
      }
    }   

    vault {
      role = "authentik-role"
      policies = ["authentik"]
    }
    service {
      name = "authentik"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.my-router.entrypoints=websecure",
        "traefik.http.routers.authentik.rule=Host(`authentik.internal`) || Host(`authentik.service.consul`)",
        # Enable Sticky Sessions via Cookies
        "traefik.http.services.authentik.loadbalancer.sticky=true",
        "traefik.http.services.authentik.loadbalancer.sticky.cookie.name=authentik_sticky",
        "traefik.http.services.authentik.loadbalancer.sticky.cookie.secure=true",
      ]

      check {
        type     = "http"
        path     = "/-/health/live/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "server" {
      driver = "docker"

      resources {
        cpu = 1000
        memory = 2048
      }

      config {
        network_mode = "host"
        #dns_servers = ["172.17.0.1"]
        image = "ghcr.io/goauthentik/server:2026.2"
        args  = ["server"]
      }

      template {
        data = <<EOH
{{ with secret "secret/data/authentik/auth" }}
AUTHENTIK_SECRET_KEY="{{ .Data.data.secret_key }}"
AUTHENTIK_POSTGRESQL__HOST="postgres.internal"
AUTHENTIK_POSTGRESQL__USER="{{ .Data.data.db_username }}"
AUTHENTIK_POSTGRESQL__PASSWORD="{{ .Data.data.db_password }}"
AUTHENTIK_POSTGRESQL__NAME="{{ .Data.data.db_name }}"
{{ end }}
EOH
        destination = "secrets/config.env"
        env         = true
      }
    }
  }

  # --- AUTHENTIK WORKER ---
  group "worker" {
    
    task "worker" {
      driver = "docker"

      config {
        network_mode = "host"
        #dns_servers = ["172.17.0.1"]
        image = "ghcr.io/goauthentik/server:2026.2"
        args  = ["worker"]
      }

      resources {
        cpu = 1000
        memory = 2048
      }

      vault {
        role = "authentik-role"
        policies = ["authentik"]
      }

      template {
        data = <<EOH
{{ with secret "secret/data/authentik/auth" }}
AUTHENTIK_SECRET_KEY="{{ .Data.data.secret_key }}"
AUTHENTIK_POSTGRESQL__HOST="postgres.internal"
AUTHENTIK_POSTGRESQL__USER="{{ .Data.data.db_username }}"
AUTHENTIK_POSTGRESQL__NAME="{{ .Data.data.db_name }}"
AUTHENTIK_POSTGRESQL__PASSWORD="{{ .Data.data.db_password }}"
AUTHENTIK_BOOTSTRAP_PASSWORD="{{ .Data.data.admin_password }}"
AUTHENTIK_BOOTSTRAP_EMAIL="{{ .Data.data.admin_email }}"
{{ end }}
EOH
        destination = "secrets/config.env"
        env         = true
      }
    }
  }
}