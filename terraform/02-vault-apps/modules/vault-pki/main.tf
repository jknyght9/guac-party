# This module enables PKI secret engine, create a root CA, and then an intermediate CA
# Signs the intermediate with the root
#
# Enable PKI Secrets Engine (Root)
resource "vault_mount" "pki_root" {
  path                  = "pki_root"
  type                  = "pki"
  default_lease_ttl_seconds = 315360000 # 10 years
  max_lease_ttl_seconds     = 315360000
}

# Generate Root CA
resource "vault_pki_secret_backend_root_cert" "root_ca" {
  backend              = vault_mount.pki_root.path
  type                 = "internal"
  common_name          = "Internal Root CA"
  ttl                  = "315360000"
  format               = "pem"
}

# Enable PKI Secrets Engine (Intermediate)
resource "vault_mount" "pki_intermediate" {
  path                  = "pki_intermediate"
  type                  = "pki"
  default_lease_ttl_seconds = 157680000 # 5 years
  max_lease_ttl_seconds     = 157680000
}

# Create Intermediate CSR and sign it with Root
resource "vault_pki_secret_backend_intermediate_cert_request" "intermediate_csr" {
  backend     = vault_mount.pki_intermediate.path
  type        = "internal"
  common_name = "Internal Intermediate CA"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "intermediate_signed" {
  backend     = vault_mount.pki_root.path
  csr         = vault_pki_secret_backend_intermediate_cert_request.intermediate_csr.csr
  common_name = "Internal Intermediate CA"
  format      = "pem_bundle"
  ttl         = "157680000"
}

# Set the signed cert back to Intermediate
resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate_set" {
  backend     = vault_mount.pki_intermediate.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.intermediate_signed.certificate
}