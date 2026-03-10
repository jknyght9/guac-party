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

# Nomad Management Role
resource "vault_nomad_secret_role" "management" {
    backend = vault_mount.nomad.path
    role = "management"
    type = "management"
    policies = ["postgres", "authentik", "guacamole"]
}

# Policy for shared Postgres database
resource "vault_policy" "postgres" {
    name = "postgres"
    policy = <<EOT
path "${vault_mount.secret.path}/data/postgres/*" {
  capabilities = ["read"]
}
EOT
}