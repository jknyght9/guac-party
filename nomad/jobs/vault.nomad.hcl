job "vault" {
  datacenters = ["dc1"]
  type        = "service"

  group "vault" {
    count = 3

    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    network {
      mode = "host"
      port "api" {
        static = 8200
      }
      port "cluster" {
        static = 8201
      }
    }

    volume "vault_data" {
      type   = "host"
      source = "vault"
    }

    task "vault" {
      driver = "docker"

      config {
        image = "hashicorp/vault:1.17"
        ports = ["api", "cluster"]
        privileged   = true 
        #allow_caps = ["IPC_LOCK"]
      #  volumes = [ "/opt/volumes/vault:/vault/data"]
        args = ["server", "-config=/local/vault.hcl"]
      }

      volume_mount {
        volume      = "vault_data"
        destination = "/vault/data"
      }

      template {
        data = <<-EOF
          ui            = true
          api_addr      = "http://{{ env "NOMAD_ADDR_api" }}"
          cluster_addr  = "https://{{ env "NOMAD_ADDR_cluster" }}"
          disable_mlock = true

          storage "raft" {
            path    = "/vault/data"
            node_id = "{{ env "NOMAD_ALLOC_ID" }}"

            {{ range nomadService "vault" }}
            retry_join {
              leader_api_addr = "http://{{ .Address }}:{{ .Port }}"
            }
            {{ end }}
          }

          listener "tcp" {
            address     = "0.0.0.0:8200"
            tls_disable = true
          }
        EOF

        destination = "local/vault.hcl"
      }

      env {
        VAULT_LOCAL_CONFIG = ""
        SKIP_CHOWN = "true"
        VAULT_ADDR = "https://127.0.0.1:8200"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name     = "vault"
        port     = "api"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.vault.rule=Host(`vault.${var.internal_domain}`)",
          "traefik.http.routers.vault.tls=true",
        ]

        check {
          type     = "http"
          path     = "/v1/sys/health?standbyok=true&uninitcode=200&sealedcode=200"
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
