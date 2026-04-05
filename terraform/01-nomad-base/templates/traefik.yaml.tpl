entryPoints:
  # Management addresses
  web-mgmt:
    address: "{{ env "NOMAD_IP_http_mgmt" }}:80"
    http:
      redirections:
        entryPoint:
          to: websecure-mgmt
          scheme: https
  websecure-mgmt:
    address: "{{ env "NOMAD_IP_https_mgmt" }}:443"
    http:
      tls: {}
  # Management Virtual IP
  web-mgmt-vip:
    address: "${mgmt_virtual_ip}:80"
    http:
      redirections:
        entryPoint:
          to: websecure-mgmt-vip
          scheme: https
  websecure-mgmt-vip:
    address: "${mgmt_virtual_ip}:443"
    http:
      tls: {}
  # User addresses
  web-user:
    address: "{{ env "NOMAD_IP_http_user" }}:80"
    http:
      redirections:
        entryPoint:
          to: websecure-user
          scheme: https
  websecure-user:
    address: "{{ env "NOMAD_IP_https_user" }}:443"
    http:
      tls: {}
  web-user-vip:
    address: "${user_virtual_ip}:80"
    http:
      redirections:
        entryPoint:
          to: websecure-user-vip
          scheme: https
  websecure-user-vip:
    address: "${user_virtual_ip}:443"
    http:
      tls: {}
  postgres-tcp: 
    address: "{{ env "NOMAD_IP_postgres_tcp" }}:5432"

api:
  dashboard: true
  insecure: true

providers:
  nomad:
    endpoint:
      address: "http://localhost:4646"
    exposedByDefault: false
  consulCatalog:
    endpoint:
      address: "http://localhost:8500"
    exposedByDefault: false

  # Look here for dynamic configuration changes
  file:
    directory: "/etc/traefik/dynamic/"
    watch: true

log:
  level: INFO

accessLog: {}