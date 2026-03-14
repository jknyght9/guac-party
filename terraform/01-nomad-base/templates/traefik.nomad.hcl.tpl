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
      port "api" {
        static = 8080
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
            -subj "/CN=*.${internal_domain}" \
            -addext "subjectAltName=DNS:*.${internal_domain},DNS:${internal_domain}"
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
        image        = "traefik:v3.6.9"
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
                address: "http://localhost:4646"
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
          port     = "api"
          interval = "10s"
          timeout  = "3s"
        }
      }
      
      # --- Services ---
      # Here we define some base level routes for Traefik such as its dashboard
      # And Nomads dashboard.

      # Nomad dashboard
      service {
        name = "nomad-ui"
        port = "api"
        provider = "nomad"
        # The regex will handle nomad-[hostname].internal. Querying by hostname will be resolved to the node address from DNS.
        # Traefik just needs to know how handle the requests and pass to localhost correctly. 
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.nomad.rule=Host(`nomad.${internal_domain}`) || HostRegexp(`nomad-[a-zA-Z0-9-]+\\.${internal_domain}`)",
          "traefik.http.routers.nomad.entrypoints=websecure",
          "traefik.http.routers.nomad.tls=true",
          "traefik.http.services.nomad.loadbalancer.server.port=4646"
        ]
      }

      # Traefik dashboard
      service {
        name     = "traefik-dashboard"
        port     = "dashboard"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.dashboard.rule=Host(`traefik.${internal_domain}`)",
          "traefik.http.routers.dashboard.entrypoints=websecure",
          "traefik.http.routers.dashboard.tls=true",
          "traefik.http.routers.dashboard.service=api@internal" 
        ]
      }
    }
  }
}