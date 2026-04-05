# Enable nomad to use its own secret engine and tokens
resource "vault_policy" "nomad_server" {
    name = "nomad-server"
    policy = <<EOT
# Allow Nomad to use its own secret engine role
path "nomad/creds/${vault_nomad_secret_role.management.role}" {
  capabilities = ["read"]
}

# Allow Nomad to look up and renew its own token
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOT    
}

# Policy for shared Postgres database
resource "vault_policy" "postgres" {
    name = "postgres"
    policy = <<EOT
path "${var.secret_mount_path}/data/postgres/*" {
  capabilities = ["read"]
}

path "${var.secret_mount_path}/metadata/postgres/*" {
  capabilities = ["list"]
}

# Certs
path "pki_intermediate/issue/postgres-role" {
  capabilities = ["create", "update"]
}

path "pki_root/ca_chain" {
  capabilities = ["read"]
}
EOT
}

# Guacamole Policy
resource "vault_policy" "guacamole" {
  name   = "guacamole"
  policy = <<EOT
path "${var.secret_mount_path}/data/guacamole/*" {
  capabilities = ["read"]
}

path "${var.secret_mount_path}/metadata/guacamole/*" {
  capabilities = ["list"]
}

# Certs
path "pki_intermediate/issue/guacamole-role" {
  capabilities = ["create", "update"]
}

path "pki_root/ca_chain" {
  capabilities = ["read"]
}
EOT
}

# Authentik Policy
resource "vault_policy" "authentik" {
  name   = "authentik"
  policy = <<EOT
path "${var.secret_mount_path}/data/authentik/*" {
  capabilities = ["read"]
}

path "${var.secret_mount_path}/metadata/authentik/*" {
  capabilities = ["list"]
}

# Certs
path "pki_intermediate/issue/authentik-role" {
  capabilities = ["create", "update"]
}

path "pki_root/ca_chain" {
  capabilities = ["read"]
}
EOT
}