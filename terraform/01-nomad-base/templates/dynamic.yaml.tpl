# Global TLS
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /etc/traefik/dynamic/certs/master.crt
        keyFile: /etc/traefik/dynamic/certs/master.key
# HTTP Routers and Services
http:
  serversTransports:
    internal-secure:
      insecureSkipVerify: true
      rootCAs:
        - "/etc/traefik/dynamic/certs/root_ca.crt"

  routers:
    # Traefik UI (Cluster Access)
    traefik-dashboard:
      rule: "Host(`traefik.internal`)"
      entryPoints: ["websecure-mgmt-vip"]
      tls: {}
      service: api@internal
    # Nomad UI (Direct Node Access)
    nomad-local-{{ env "attr.unique.consul.name" }}:
      rule: "Host(`nomad.{{ env "node.unique.name" }}`) || Host(`{{ env "node.unique.name" }}`)"
      entryPoints: ["websecure-mgmt"]
      tls: {}
      service: nomad-local

    # Vault (Direct Node Access)
    vault-local-{{ env "attr.unique.consul.name" }}:
      rule: "Host(`vault.{{ env "node.unique.name" }}`)"
      entryPoints: ["websecure-mgmt"]
      tls: {}
      service: vault-local

  services:
    # Maps to the local Nomad agent
    nomad-local:
      loadBalancer:
        servers:
          - url: "http://{{ env "NOMAD_IP_http_mgmt" }}:4646"
          
    # Maps to the local Vault agent
    vault-local:
      loadBalancer:
        servers:
          - url: "http://{{ env "NOMAD_IP_http_mgmt" }}:8200"

# TCP Routers and Services
tcp:
  routers:
    postgres:
      entryPoints: ["postgres-vip", "postgres-local"]
      rule: "HostSNI(`*`)"
      service: "postgres-master"

  services:
    postgres-master:
      loadBalancer:
        # Traefik resolves this via Consul DNS
        servers:
          - address: "master.postgres-cluster.service.consul:5433"