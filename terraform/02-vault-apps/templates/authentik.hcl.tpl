job "authentik" {
  datacenters = ["dc1"]
  type        = "system"

  # --- AUTHENTIK SERVER ---
  group "server" {
    
    network {
      mode = "host"
      port "http_mgmt" {
        static = 9000
        host_network = "management"
      }
      port "https_mgmt" {
        static = 9443
        host_network = "management"
      }
      port "health_mgmt" {
        static = 8000
        host_network = "management"
      }
    }   

    vault {
      role = "authentik-role"
      policies = ["authentik"]
    }
    service {
      name = "authentik"
      port = "https_mgmt"
      tags = [
        "traefik.enable=true",
        # Internal Routers
        "traefik.http.routers.authentik.entrypoints=websecure-mgmt-vip,websecure-user-vip",
        "traefik.http.routers.authentik.rule=Host(`authentik.internal`) || Host(`authentik.service.consul`)",        
        "traefik.http.routers.authentik.service=authentik",
        "traefik.http.routers.authentik.tls=true",

        # External Routers
        "traefik.http.routers.authentik-ext.entrypoints=websecure-user-vip",
        "traefik.http.routers.authentik-ext.rule=Host(`authentik.eternal.rowdycon.com`)",
        # Point this router to the same backend service defined below
        "traefik.http.routers.authentik-ext.service=authentik",
        "traefik.http.routers.authentik-ext.tls=true",
        
        "traefik.http.services.authentik.loadbalancer.server.scheme=https",
        "traefik.http.services.authentik.loadbalancer.serversTransport=internal-secure@file",
        # Enable Sticky Sessions via Cookies
        "traefik.http.services.authentik.loadbalancer.sticky=true",
        "traefik.http.services.authentik.loadbalancer.sticky.cookie.name=authentik_sticky",
        "traefik.http.services.authentik.loadbalancer.sticky.cookie.secure=true",
      ]

      check {
        type     = "http"
        port     = "http_mgmt"
        path     = "/-/health/live/"
        interval = "10s"
        timeout  = "2s"
      }
    }
    
    task "ca-inject" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image   = "alpine"
        command = "sh"
        args    = ["-c", <<-EOF
          apk add --no-cache ca-certificates &&
          sleep 1 &&
          cp /alloc/certs/root_ca.crt /usr/local/share/ca-certificates/internal-root-ca.crt &&
          update-ca-certificates &&
          mkdir /alloc/shared &&
          cp /etc/ssl/certs/ca-certificates.crt /alloc/shared/ca-certificates.crt
        EOF
        ]

        volumes = [
          "$${NOMAD_ALLOC_DIR}/certs:/incoming:ro",
          "$${NOMAD_ALLOC_DIR}/shared:/shared",
        ]
      }
      
      template {
        data = <<EOH
{{ with secret "pki_root/cert/ca_chain" }}{{ .Data.certificate }}{{ end }}
EOH
        destination = "$${NOMAD_ALLOC_DIR}/certs/root_ca.crt"
      }
    }

    task "server" {
      driver = "docker"

      resources {
        cpu = 4000
        memory = 2048
      }

      config {
        network_mode = "host"
        #dns_servers = ["172.17.0.1"]
        image = "ghcr.io/goauthentik/server:2026.2"
        args  = ["server"]

        volumes = [
          "/mnt/nomad-data/authentik/assets:/data/media",
        ]
      }
      

      template {
        data = <<EOH
{{ with secret "secret/data/authentik/auth" }}
AUTHENTIK_SECRET_KEY="{{ .Data.data.secret_key }}"
AUTHENTIK_POSTGRESQL__HOST="postgres.internal"
AUTHENTIK_POSTGRESQL__USER="{{ .Data.data.db_username }}"
AUTHENTIK_POSTGRESQL__PASSWORD="{{ .Data.data.db_password }}"
AUTHENTIK_POSTGRESQL__NAME="{{ .Data.data.db_name }}"
SSL_CERT_FILE="/alloc/shared/ca-certificates.crt"
REQUESTS_CA_BUNDLE="/alloc/shared/ca-certificates.crt"
CURL_CA_BUNDLE=/alloc/shared/ca-certificates.crt
AUTHENTIK_LISTEN__HTTP={{ env "NOMAD_IP_http_mgmt" }}:9000
AUTHENTIK_LISTEN__HTTPS={{ env "NOMAD_IP_https_mgmt" }}:9443
AUTHENTIK_LISTEN__METRICS={{ env "NOMAD_IP_http_mgmt" }}:9300
{{ end }}
EOH
        destination = "secrets/config.env"
        env         = true
      }
    }
  }

  # --- AUTHENTIK WORKER ---
  group "worker" {
    
    task "ca-inject" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image   = "alpine"
        command = "sh"
        args    = ["-c", <<-EOF
          apk add --no-cache ca-certificates &&
          sleep 1 &&
          cp /alloc/certs/root_ca.crt /usr/local/share/ca-certificates/internal-root-ca.crt &&
          update-ca-certificates &&
          mkdir /alloc/shared &&
          cp /etc/ssl/certs/ca-certificates.crt /alloc/shared/ca-certificates.crt
        EOF
        ]

        volumes = [
          "$${NOMAD_ALLOC_DIR}/certs:/incoming:ro",
          "$${NOMAD_ALLOC_DIR}/shared:/shared",
        ]
      }
      template {
        data = <<EOH
{{ with secret "pki_root/cert/ca_chain" }}{{ .Data.certificate }}{{ end }}
EOH
        destination = "$${NOMAD_ALLOC_DIR}/certs/root_ca.crt"
      }
    }
    
    task "worker" {
      driver = "docker"

      config {
        network_mode = "host"
        #dns_servers = ["172.17.0.1"]
        image = "ghcr.io/goauthentik/server:2026.2"
        args  = ["worker"]
        volumes = [
          "/mnt/nomad-data/authentik/assets:/data/media",
        ]
      }
      
      resources {
        cpu = 2000
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
AUTHENTIK_BOOTSTRAP_TOKEN="{{ .Data.data.admin_token }}"
SSL_CERT_FILE="/alloc/shared/ca-certificates.crt"
REQUESTS_CA_BUNDLE="/alloc/shared/ca-certificates.crt"
CURL_CA_BUNDLE=/alloc/shared/ca-certificates.crt
AUTHENTIK_LISTEN__HTTP={{ env "NOMAD_IP_http_mgmt" }}:9000
AUTHENTIK_LISTEN__HTTPS={{ env "NOMAD_IP_https_mgmt" }}:9443
AUTHENTIK_LISTEN__METRICS={{ env "NOMAD_IP_http_mgmt" }}:9300
{{ end }}
EOH
        destination = "secrets/config.env"
        env         = true
      }
    }
  }
}