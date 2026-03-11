#!/usr/bin/env bash
# Install Docker CE and HashiCorp Nomad on Ubuntu 24.04
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "=== Installing Docker CE ==="

# Add Docker GPG key and repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
apt-get install -y keepalived

systemctl enable docker
usermod -aG docker ubuntu

echo "=== Installing HashiCorp Nomad ==="

# Add HashiCorp GPG key and repository
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
chmod a+r /etc/apt/keyrings/hashicorp.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com \
  $(. /etc/os-release && echo "$VERSION_CODENAME") main" | \
  tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

apt-get update
apt-get install -y nomad

# Create Nomad directories
mkdir -p /opt/nomad/data
mkdir -p /etc/nomad.d

# Create host volume directories for persistent services
mkdir -p /opt/volumes/vault
mkdir -p /opt/volumes/authentik-db
mkdir -p /opt/volumes/guacamole-db

# Enable Nomad (config will be written by cloud-init at deploy time)
systemctl enable nomad

echo "=== Cleanup ==="
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*

echo "=== Setup complete ==="
docker --version
nomad version
