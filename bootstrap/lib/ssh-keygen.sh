#!/usr/bin/env bash
# Generate SSH key pair for Nomad VM access

generate_ssh_key() {
  local secrets_dir="$1"
  local key_path="${secrets_dir}/id_ed25519"

  if [[ -f "$key_path" ]]; then
    echo "SSH key already exists at ${key_path}, skipping generation."
    export SSH_PUBLIC_KEY
    SSH_PUBLIC_KEY="$(cat "${key_path}.pub")"
    return 0
  fi

  echo "Generating ED25519 SSH key pair..."
  ssh-keygen -t ed25519 -f "$key_path" -N "" -C "guac-party-automation"

  chmod 600 "$key_path"
  chmod 644 "${key_path}.pub"

  export SSH_PUBLIC_KEY
  SSH_PUBLIC_KEY="$(cat "${key_path}.pub")"
  echo "OK: SSH key pair generated at ${key_path}"
}
