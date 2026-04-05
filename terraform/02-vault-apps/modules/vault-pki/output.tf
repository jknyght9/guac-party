output "authentik_certificate" {
  value     = vault_pki_secret_backend_cert.authentik_internal.certificate
  description = "Certificate generated in Vault, to be loaded to Authentik in module user-apps"
  sensitive = true
}

output "authentik_private_key" {
  value     = vault_pki_secret_backend_cert.authentik_internal.private_key
  description = "Key generated in Vault, to be loaded to Authentik in module user-apps"
  sensitive = true
}