#cloud-config
hostname: ${hostname}
fqdn: ${hostname}.localdomain
manage_etc_hosts: true

users:
  - name: ubuntu
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ssh_public_key}
    groups: [docker]

write_files:
  - path: /etc/nomad.d/nomad.hcl
    permissions: "0644"
    content: |
      ${indent(6, nomad_config)}

runcmd:
  - systemctl restart nomad
  - systemctl enable nomad
