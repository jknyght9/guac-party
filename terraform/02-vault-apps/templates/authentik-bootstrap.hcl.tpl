job "authentik-bootstrap" {
  datacenters = ["dc1"]
  type        = "batch"

  # --- AUTHENTIK WORKER ---
  group "bootstrap" {
    
    count = 1 

    task "auth-init" {
      driver = "docker"

      config {
        network_mode = "host"
        image = "ghcr.io/goauthentik/server:2026.2"
        args  = ["migrate"]
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
AUTHENTIK_POSTGRESQL__PASSWORD="{{ .Data.data.db_password }}"
AUTHENTIK_POSTGRESQL__NAME="{{ .Data.data.db_name }}"
{{ end }}
EOH
        destination = "secrets/config.env"
        env         = true
      }
    }
  }
}