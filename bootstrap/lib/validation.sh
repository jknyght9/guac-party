#!/usr/bin/env bash
# Pre-flight validation checks

validate_docker() {
  if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker is not installed or not in PATH."
    echo "Install Docker from https://docs.docker.com/get-docker/"
    return 1
  fi

  if ! docker info &>/dev/null; then
    echo "ERROR: Docker daemon is not running."
    echo "Start Docker and try again."
    return 1
  fi

  echo "OK: Docker is available."
}

validate_proxmox_nodes() {
  local nodes_csv="$1"
  local failed=0

  IFS=',' read -ra NODES <<< "$nodes_csv"
  for node in "${NODES[@]}"; do
    node="$(echo "$node" | xargs)" # trim whitespace
    if curl -sk --connect-timeout 5 "https://${node}:8006/api2/json/version" &>/dev/null; then
      echo "OK: ${node} reachable on port 8006."
    else
      echo "ERROR: Cannot reach ${node} on port 8006."
      failed=1
    fi
  done

  return $failed
}

run_preflight() {
  echo "=== Pre-flight checks ==="
  validate_docker
  validate_proxmox_nodes "$1"
  echo "=== All checks passed ==="
}
