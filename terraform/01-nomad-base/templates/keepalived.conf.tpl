# Template file used by to install keepalived. Note that this file is not tf or hcl.
# This is purely Linux config file
global_defs {
    script_user ubuntu
    enable_script_security
}
vrrp_script check_traefik {
    # This script checks if Traefik is actually responding on port 80
    script "/bin/sh -c '/usr/bin/curl -s -f http://127.0.0.1:8080/api/rawdata > /dev/null'"
    interval 2  # Check every 2 seconds
    weight 20   # If it passes, add 20 to priority

    init_wait 60
}

vrrp_instance VI_MGMT {
    state BACKUP          # Start as BACKUP on all nodes to let priority decide
    interface eth0        # MGMT interface
    virtual_router_id 51  # Must be the same on all 3 nodes
    priority ${priority}          # Set to 100 on Node 1, 90 on Node 2, 80 on Node 3

    advert_int 1

    authentication {
        auth_type PASS
        auth_pass ${mgmt_passwd}  # Simple password for the nodes to trust each other
    }

    virtual_ipaddress {
        ${mgmt_virtual_ip}  
    }

    track_script {
        check_traefik
    }
}

vrrp_instance VI_USER {
    state BACKUP          
    interface eth1        # User interface
    virtual_router_id 52  # MUST be different from VI_MGMT
    priority ${priority}  # Can use the same priority variable

    advert_int 1

    authentication {
        auth_type PASS
        auth_pass ${user_passwd} # Seperate password for user net just in case...
    }

    virtual_ipaddress {
        ${user_virtual_ip}  
    }

    track_script {
        # Both instances can share the same health check. 
        # If Traefik dies, the node drops both VIPs.
        check_traefik
    }
}