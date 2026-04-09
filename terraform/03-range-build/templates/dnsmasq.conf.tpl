# Bind LAN interface
interface=eth1
bind-interfaces

# Disable DNS resolver
port=0


# This tells dnsmasq what subnet to serve, but the 'static' flag prevents a dynamic pool.
dhcp-range=192.168.30.0,static,255.255.255.0

# Network Options Pushed to the Client
# Option 3 is the Default Gateway (Point this to the Alpine router's eth1 IP)
dhcp-option=3,192.168.30.1

# Set LAN address as DNS server. This will not resolve, but
# Applications do not like DHCP DNS being empty
dhcp-option=192.168.30.1

# Format: dhcp-host=<MAC_ADDRESS>,<STATIC_IP>,<HOSTNAME>,<LEASE_TIME>
dhcp-host=${windows_mac},192.168.1.200,windows-target,infinite