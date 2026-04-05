# PKI role for Postgres to access its keys and certs
resource "vault_pki_secret_backend_role" "postgres_role" {
  backend          = vault_mount.pki_intermediate.path
  name             = "postgres-role"
  ttl              = 86400    # 24h
  max_ttl          = 2592000  # 30 days
  allow_ip_sans    = true
  key_type = "rsa"
  key_bits = 4096
  allowed_domains  = ["internal", "consul"]
  allow_subdomains = true
}


# --- Leaf Certificate for Postgres (Cluster Alias) ---
resource "vault_pki_secret_backend_cert" "postgres_internal" {
  depends_on  = [vault_pki_secret_backend_role.postgres_role]
  backend     = vault_mount.pki_intermediate.path
  name        = vault_pki_secret_backend_role.postgres_role.name
  common_name = "postgres.internal"
  
  alt_names = [
    "*.postgres-cluster.service.consul"
  ]
}
