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

    task "vault" {
      driver = "docker"

      config {
        image = "hashicorp/vault:1.21.3"
        ports = ["api", "cluster"]
        
        cap_add = ["IPC_LOCK"] 
        
        volumes = ["/opt/vault/data:/vault/data"]
        
        args = ["server", "-config=/local/vault.hcl"]
      }

      template {
        data = <<-EOF
          ui            = true
          api_addr      = "http://{{ env "NOMAD_ADDR_api" }}"
          cluster_addr  = "https://{{ env "NOMAD_ADDR_cluster" }}"
          
          # We keep this true because IPC_LOCK handles it, or you can disable it if testing
          disable_mlock = true 

          # The Raft Configuration
          storage "raft" {
            path    = "/vault/data"
            
            # Nomad injects the exact host name (e.g., nomad-pve1) here
            node_id = "{{ env "node.unique.name" }}"

            # Terraform dynamically loops over your IPs to generate these blocks!
            %{ for ip in nomad_all_ips }
            retry_join {
              leader_api_addr = "http://${ip}:8200"
            }
            %{ endfor }
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
        SKIP_CHOWN         = "true"
        VAULT_ADDR         = "http://127.0.0.1:8200"
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
          "traefik.http.routers.vault.rule=Host(`vault.${internal_domain}`)",
          "traefik.http.routers.vault.tls=true", # Ensure Traefik handles the certs
        ]

        # This health check is for Vault HA
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