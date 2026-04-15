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
  - path: /etc/consul.d/consul.hcl
    permissions: "0644"
    content: |
      ${indent(6, consul_config)}
  - path: /etc/keepalived/keepalived.conf
    permissions: "0644"
    content: |
      ${indent(6, keepalived_config)}
  - path: /etc/systemd/resolved.conf
    permissions: "0644"
    content: |
      ${indent(6, resolved_config)}
  - path: /etc/docker/daemon.json
    permissions: "0644"
    content: |
      ${indent(6, docker_daemon_json)}
  - path: /etc/ssh/sshd_config
    permissions: "0644"
    content: |
      ${indent(6, sshd_config)}

runcmd:
  - systemctl restart nomad
  - systemctl enable nomad
  - systemctl restart consul
  - systemctl enable consul
  - systemctl restart keepalived
  - systemctl enabled keepalived
  - systemctl restart systemd-resolved
  - systemctl restart docker
  - systemctl restart sshd