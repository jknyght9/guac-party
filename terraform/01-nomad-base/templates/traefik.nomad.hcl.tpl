job "traefik" {
  datacenters = ["dc1"]
  type        = "system"

  group "traefik" {
    network {
      # --- Management Network (eth0) ---
      port "http_mgmt" {
        static = 80
        host_network = "management"
      }
      port "https_mgmt" {
        static = 443
        host_network = "management"
      }
      port "postgres_tcp" {
        static = 5432
        host_network = "management"
      }

      # --- User Network (eth1) ---
      port "http_user" {
        static = 80
        host_network = "public"
      }
      port "https_user" {
        static = 443
        host_network = "public"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3.6.9"
        ports        = ["http_mgmt", "https_mgmt", "postgres_tcp", "http_user", "https_user"]
        network_mode = "host"

        volumes = [
          "local/traefik.yaml:/etc/traefik/traefik.yaml",
          "/mnt/nomad-data/traefik/certs:/etc/traefik/dynamic/certs:ro",
          "local/dynamic.yaml:/etc/traefik/dynamic/dynamic.yaml",
        ]
      }

      # Main traefik.yaml
      template {
        data = <<-EOF
${traefik_yaml}
        EOF

        destination = "local/traefik.yaml"
      }

      # Dynamic file template
      # Used for certs and node level domains
      template {
        data = <<-EOF
${dynamic_yaml}
        EOF

        destination = "local/dynamic.yaml"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name     = "traefik"
        port     = "https_mgmt"
        provider = "nomad"

        check {
          type     = "tcp"
          #path     = "/api/overview"
          #port     = "http_mgmt"
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
        port = "http_mgmt"
        provider = "nomad"
        # The regex will handle nomad-[hostname].internal. Querying by hostname will be resolved to the node address from DNS.
        # Traefik just needs to know how handle the requests and pass to localhost correctly. 
        tags = [
          # Cluster Nomad domain
          "traefik.enable=true",
          "traefik.http.routers.nomad.rule=Host(`nomad.${internal_domain}`)",
          "traefik.http.routers.nomad.entrypoints=websecure-mgmt-vip",
          "traefik.http.routers.nomad.tls=true",
          "traefik.http.services.nomad.loadbalancer.server.port=4646",
        ]
      }

      # Traefik dashboard
      service {
        name     = "traefik-dashboard"
        port     = "http_mgmt"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.dashboard-mgmt.rule=Host(`traefik.${internal_domain}`)",
          "traefik.http.routers.dashboard-mgmt.entrypoints=websecure-mgmt-vip",
          "traefik.http.routers.dashboard-mgmt.tls=true",
          "traefik.http.routers.dashboard-mgmt.service=api@internal" 
        ]
      }
    }
  }
}