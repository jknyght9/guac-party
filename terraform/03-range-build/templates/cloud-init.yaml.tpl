write-files:
  - path: /etc/dnsmasq.conf
    permissions: '0644'
    content: |
      ${indent(6, dnsmasq_conf)}
  - path: /etc/local.d/firewall.start
    permissions: '0744'
    content: |
      ${indent(6, setup_firewall)}

run-cmd:
  - rc-update add local default
  - rc-service local start
  - rc-service dnsmasq restart