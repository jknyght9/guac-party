job "authentik" {
  datacenters = ["dc1"]
  type        = "service"

  group "authentik" {
    count = 1

    network {
      port "http" {
        to = 9000
      }
      port "db" {
        to = 5432
      }
    }

    volume "authentik_db" {
      type   = "host"
      source = "authentik-db"
    }

    # PostgreSQL sidecar
    task "postgres" {
      driver = "docker"
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image = "postgres:16-alpine"
        ports = ["db"]
      }

      volume_mount {
        volume      = "authentik_db"
        destination = "/var/lib/postgresql/data"
      }

      vault {
        policies = ["authentik"]
      }

      template {
        data = <<-EOF
          {{ with secret "secret/data/authentik/db" }}
          POSTGRES_DB=authentik
          POSTGRES_USER=authentik
          POSTGRES_PASSWORD={{ .Data.data.password }}
          {{ end }}
        EOF

        destination = "secrets/db.env"
        env         = true
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name     = "authentik-db"
        port     = "db"
        provider = "nomad"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "3s"
        }
      }
    }

    # Authentik server
    task "server" {
      driver = "docker"

      config {
        image   = "ghcr.io/goauthentik/server:2025.2"
        ports   = ["http"]
        command = "server"
      }

      vault {
        policies = ["authentik"]
      }

      template {
        data = <<-EOF
          {{ with secret "secret/data/authentik/db" }}
          AUTHENTIK_POSTGRESQL__HOST={{ env "NOMAD_ADDR_db" }}
          AUTHENTIK_POSTGRESQL__NAME=authentik
          AUTHENTIK_POSTGRESQL__USER=authentik
          AUTHENTIK_POSTGRESQL__PASSWORD={{ .Data.data.password }}
          {{ end }}
          {{ with secret "secret/data/authentik/secret" }}
          AUTHENTIK_SECRET_KEY={{ .Data.data.key }}
          {{ end }}
        EOF

        destination = "secrets/authentik.env"
        env         = true
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name     = "authentik"
        port     = "http"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.authentik.rule=Host(`authentik.${var.internal_domain}`)",
          "traefik.http.routers.authentik.tls=true",
        ]

        check {
          type     = "http"
          path     = "/-/health/live/"
          interval = "15s"
          timeout  = "5s"
        }
      }
    }

    # Authentik worker
    task "worker" {
      driver = "docker"

      config {
        image   = "ghcr.io/goauthentik/server:2025.2"
        command = "worker"
      }

      vault {
        policies = ["authentik"]
      }

      template {
        data = <<-EOF
          {{ with secret "secret/data/authentik/db" }}
          AUTHENTIK_POSTGRESQL__HOST={{ env "NOMAD_ADDR_db" }}
          AUTHENTIK_POSTGRESQL__NAME=authentik
          AUTHENTIK_POSTGRESQL__USER=authentik
          AUTHENTIK_POSTGRESQL__PASSWORD={{ .Data.data.password }}
          {{ end }}
          {{ with secret "secret/data/authentik/secret" }}
          AUTHENTIK_SECRET_KEY={{ .Data.data.key }}
          {{ end }}
        EOF

        destination = "secrets/authentik.env"
        env         = true
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }
}

variable "internal_domain" {
  type    = string
  default = "internal"
}
