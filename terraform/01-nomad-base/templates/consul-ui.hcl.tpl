job "consul-ui-router" {
  datacenters = ["dc1"]
  type        = "system"

  group "registration" {
    network {
      port "http" {
        static = 8500
      }
    }
    task "noop" {
      driver = "docker"
      config {
        image   = "alpine:latest"
        command = "sleep"
        args    = ["infinity"]
      }

      service {
        name = "consul-ui"
        
        # Look for the localhost address.
        address = "${attr.unique.network.ip-address}"
        port    = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.consul.rule=Host(`consul.internal`) || Host(`consul.${node_name}.internal`)",
          "traefik.http.routers.consul.entrypoints=websecure",
          "traefik.http.services.consul.loadbalancer.server.port=8500"
        ]

        check {
          name     = "consul-leader-check"
          type     = "http"
          path     = "/v1/status/leader"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}