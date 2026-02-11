job "traefik" {
  datacenters = ["dc1"]
  type        = "system"

  group "traefik" {
    network {
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "dashboard" {
        static = 8081
      }
    }

    # Generate self-signed TLS certificate before Traefik starts
    task "generate-certs" {
      driver = "docker"
      lifecycle {
        hook = "prestart"
      }

      config {
        image   = "alpine:3.20"
        command = "/bin/sh"
        args    = ["-c", <<-SCRIPT
          apk add --no-cache openssl
          mkdir -p /alloc/certs
          openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
            -keyout /alloc/certs/default.key \
            -out /alloc/certs/default.crt \
            -days 3650 -nodes \
            -subj "/CN=*.${var.internal_domain}" \
            -addext "subjectAltName=DNS:*.${var.internal_domain},DNS:${var.internal_domain}"
        SCRIPT
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3.2"
        ports        = ["http", "https", "dashboard"]
        network_mode = "host"

        volumes = [
          "local/traefik.yaml:/etc/traefik/traefik.yaml",
          "../alloc/certs:/certs:ro",
        ]
      }

      template {
        data = <<-EOF
          entryPoints:
            web:
              address: ":80"
              http:
                redirections:
                  entryPoint:
                    to: websecure
                    scheme: https
            websecure:
              address: ":443"
              http:
                tls: {}
            dashboard:
              address: ":8081"

          api:
            dashboard: true
            insecure: true

          providers:
            nomad:
              endpoint:
                address: "http://127.0.0.1:4646"
              exposedByDefault: false

          tls:
            stores:
              default:
                defaultCertificate:
                  certFile: /certs/default.crt
                  keyFile: /certs/default.key

          log:
            level: INFO

          accessLog: {}
        EOF

        destination = "local/traefik.yaml"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name     = "traefik"
        port     = "https"
        provider = "nomad"

        check {
          type     = "http"
          path     = "/api/overview"
          port     = "dashboard"
          interval = "10s"
          timeout  = "3s"
        }
      }
    }
  }
}

variable "internal_domain" {
  type    = string
  default = "internal"
}
