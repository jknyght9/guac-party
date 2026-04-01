# PKI role for Authentik to access its keys and certs
resource "vault_pki_secret_backend_role" "authentik_role" {
  backend          = vault_mount.pki_intermediate.path
  name             = "authentik-role"
  ttl              = 86400    # 24h
  max_ttl          = 2592000  # 30 days
  allow_ip_sans    = true
  key_type = "rsa"
  key_bits = 4096
  allowed_domains  = ["internal", "consul"]
  allow_subdomains = true
}

# --- Leaf Certificate for Authentik (Cluster Alias) ---
resource "vault_pki_secret_backend_cert" "authentik_internal" {
  depends_on  = [ vault_pki_secret_backend_role.authentik_role ]
  backend     = vault_mount.pki_intermediate.path
  name        = vault_pki_secret_backend_role.authentik_role.name
  common_name = "authentik.internal"

  alt_names = [ "authentik.service.consul" ]
}
