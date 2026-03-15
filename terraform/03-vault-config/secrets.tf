resource "random_password" "postgres_root_pw" {
    length = 18
    special = true
    override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "Authentik_db_pw" {
    length = 18
    special = true
    override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "vault_generic_secret" "postgres_root" {
    path = "${vault_mount.secret.path}/postgres/root"

    data_json = jsonencode({
        username = "postgres"
        password = random_password.postgres_root_pw.result
    })
}

resource "vault_generic_secret" "authentik_db" {
    path = "${vault_mount.secret.path}/postgres/authentik"

    data_json = jsonencode({
        username = "postgres"
        password = random_password.Authentik_db_pw.result
    })
}

# Renewing token for Nomad
resource "vault_token" "nomad_mgmt" {
    policies = ["nomad-server", "authentik", "postgres"]
    renewable = true
    no_parent = true
    period = "24h"
}