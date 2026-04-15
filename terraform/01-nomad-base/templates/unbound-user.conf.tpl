server:
    # Bind ONLY to the User Network IP
    interface: {{ env "NOMAD_IP_dns_user" }}
    interface: ${virtual_ip}
    port: 53
    
    # Only allow the User VLAN to query this instance
    access-control: 10.30.0.0/24 allow
    # Block everything else explicitly
    access-control: 0.0.0.0/0 refuse

    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    interface-automatic: no

    hide-identity: yes
    hide-version: yes

    local-zone: "${internal_domain}." transparent

    # User VIP Records
    # These point to the Traefik listener on eth1 (VLAN 30)
    local-data: "traefik.${internal_domain}. IN A ${virtual_ip}"
    local-data: "authentik.${internal_domain}. IN A ${virtual_ip}"
    local-data: "guacamole.${internal_domain}. IN A ${virtual_ip}"
    local-data: "guacamole.${internal_domain}. IN A ${virtual_ip}"

# Forward everything else to your Management DNS or upstream
forward-zone:
    name: "."
    # If mgmt_gateway is your UniFi router, it can handle recursion
    forward-addr: ${mgmt_gateway}