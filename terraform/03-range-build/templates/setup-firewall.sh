#!/bin/sh

# WAN eth0
# LAN eth1

# FLUSH EXISTING RULES
iptables -F
iptables -t nat -F

# Default Policies: Drop All
iptables -P INPUT DROP
iptables -P FORWARD DROP
# Allow Outbound
iptables -P OUTPUT ACCEPT

# Basic State Tracking
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Block Outbound Traffic from LAN to WAN (eth1 -> eth0)
iptables -A FORWARD -i eth1 -o eth0 -j DROP

# Ingress DNAT - Port Forward GUACAMOLE RDP
# Kali
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 3389 -j DNAT --to-destination 192.168.30.55:3389
# Windows
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 3390 -j DNAT --to-destination 192.168.30.215:3389

# Allow Forwarding RDP
iptables -A FORWARD -i eth0 -o eth1 -p tcp -d 192.168.30.55 --dport 3389 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -p tcp -d 192.168.30.215 --dport 3389 -j ACCEPT

# Enable NAT
sysctl net.ipv4.ip_forward=1
