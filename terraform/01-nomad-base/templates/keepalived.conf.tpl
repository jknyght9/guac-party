# Template file used by to install keepalived. Note that this file is not tf or hcl.
# This is purely Linux config file

vrrp_script check_traefik {
    # This script checks if Traefik is actually responding on port 80
    script "/usr/bin/curl -s -f http://localhost:8080/api/rawdata > /dev/null"
    interval 2  # Check every 2 seconds
    weight 20   # If it passes, add 20 to priority
}

vrrp_instance VI_1 {
    state BACKUP          # Start as BACKUP on all nodes to let priority decide
    interface eth0        # Double-check this matches your 'ip addr' (e.g., ens18)
    virtual_router_id 51  # Must be the same on all 3 nodes
    priority ${priority}          # Set to 100 on Node 1, 90 on Node 2, 80 on Node 3

    advert_int 1

    authentication {
        auth_type PASS
        auth_pass ${mgmt_passwd}  # Simple password for the nodes to trust each other
    }

    virtual_ipaddress {
        ${mgmt_virtual_ip}   # This is your new "Magic IP" for DNS
    }

    track_script {
        check_traefik
    }
}