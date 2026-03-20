server:

    interface: 0.0.0.0
    port: 53
    
    access-control: 127.0.0.0/8 allow
    access-control: 192.168.0.0/16 allow
    access-control: 172.16.0.0/12 allow # Docker Bridge

    # General Tweaks for Recursion
    do-ip4: yes
    do-udp: yes
    do-tcp: yes

    # Allow unbound to automatically pickup virtual_ip as assigned
    interface-automatic: yes

    # Hide identity for security
    hide-identity: yes
    hide-version: yes

    # Authoriatize over the *.{internal_tld}
    local-zone: "${internal_domain}." transparent

    # Node specific 
    %{ for entry in node_records ~}
local-data: "${split(" ", entry)[0]} IN A ${split(" ", entry)[1]}"
    local-zone: "${split(" ", entry)[0]}" redirect
    local-data: "${split(" ", entry)[0]} IN A ${split(" ", entry)[1]}"
    %{ endfor ~} 

    # Wildcard-ish catch-all for the VIP
    # Unbound doesn't do regex wildcards easily, so we define the primary services
    local-data: "vault.${internal_domain}. IN A ${virtual_ip}"
    local-data: "nomad.${internal_domain}. IN A ${virtual_ip}"
    local-data: "traefik.${internal_domain}. IN A ${virtual_ip}"

# Upstream Recursion
forward-zone:
    name: "."
    forward-addr: ${mgmt_gateway}
    forward-addr: 1.1.1.1
    forward-addr: 8.8.8.8