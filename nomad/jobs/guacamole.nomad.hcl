job "guacamole" {
  datacenters = ["dc1"]
  type        = "service"

  group "guacamole" {
    count = 2

    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    network {
      port "web" {
        to = 8080
      }
      port "guacd" {
        to = 4822
      }
      port "db" {
        to = 5432
      }
    }

    volume "guacamole_db" {
      type   = "host"
      source = "guacamole-db"
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
        volume      = "guacamole_db"
        destination = "/var/lib/postgresql/data"
      }

      vault {
        policies = ["guacamole"]
      }

      template {
        data = <<-EOF
          {{ with secret "secret/data/guacamole/db" }}
          POSTGRES_DB=guacamole_db
          POSTGRES_USER=guacamole
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
        name     = "guacamole-db"
        port     = "db"
        provider = "nomad"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "3s"
        }
      }
    }

    # guacd sidecar (Guacamole daemon)
    task "guacd" {
      driver = "docker"
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image = "guacamole/guacd:1.6.0"
        ports = ["guacd"]
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name     = "guacd"
        port     = "guacd"
        provider = "nomad"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "3s"
        }
      }
    }

    # DB init (runs once before web app starts)
    task "db-init" {
      driver = "docker"
      lifecycle {
        hook = "prestart"
      }

      config {
        image   = "guacamole/guacamole:1.5.5"
        command = "/bin/sh"
        args    = ["-c", "/opt/guacamole/bin/initdb.sh --postgresql > /tmp/initdb.sql && PGPASSWORD=$POSTGRESQL_PASSWORD psql -h ${NOMAD_ADDR_db} -U guacamole -d guacamole_db -f /tmp/initdb.sql || true"]
      }

      vault {
        policies = ["guacamole"]
      }

      template {
        data = <<-EOF
          {{ with secret "secret/data/guacamole/db" }}
          POSTGRESQL_PASSWORD={{ .Data.data.password }}
          {{ end }}
        EOF

        destination = "secrets/db.env"
        env         = true
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }

    # Guacamole web application
    task "guacamole" {
      driver = "docker"

      config {
        image = "guacamole/guacamole:1.5.5"
        ports = ["web"]
      }

      vault {
        policies = ["guacamole"]
      }

      template {
        data = <<-EOF
          GUACD_HOSTNAME={{ env "NOMAD_IP_guacd" }}
          GUACD_PORT={{ env "NOMAD_PORT_guacd" }}

          {{ with secret "secret/data/guacamole/db" }}
          POSTGRESQL_HOSTNAME={{ env "NOMAD_IP_db" }}
          POSTGRESQL_PORT={{ env "NOMAD_PORT_db" }}
          POSTGRESQL_DATABASE=guacamole_db
          POSTGRESQL_USER=guacamole
          POSTGRESQL_PASSWORD={{ .Data.data.password }}
          {{ end }}
        EOF

        destination = "secrets/guac.env"
        env         = true
      }

      # OIDC config -- uncomment after Authentik is configured
      # template {
      #   data = <<-EOF
      #     {{ with secret "secret/data/guacamole/oidc" }}
      #     OPENID_AUTHORIZATION_ENDPOINT=https://authentik.DOMAIN/application/o/authorize/
      #     OPENID_JWKS_ENDPOINT=https://authentik.DOMAIN/application/o/guacamole/jwks/
      #     OPENID_ISSUER=https://authentik.DOMAIN/application/o/guacamole/
      #     OPENID_CLIENT_ID={{ .Data.data.client_id }}
      #     OPENID_REDIRECT_URI=https://guacamole.DOMAIN/
      #     {{ end }}
      #   EOF
      #
      #   destination = "secrets/oidc.env"
      #   env         = true
      # }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name     = "guacamole"
        port     = "web"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.guacamole.rule=Host(`guacamole.${var.internal_domain}`)",
          "traefik.http.routers.guacamole.tls=true",
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "15s"
          timeout  = "5s"
        }
      }
    }
  }
}

variable "internal_domain" {
  type    = string
  default = "internal"
}
