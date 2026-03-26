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
path "${vault_mount.secret.path}/data/postgres/*" {
  capabilities = ["read"]
}

path "${vault_mount.secret.path}/metadata/postgres/*" {
  capabilities = ["list"]
}
EOT
}
