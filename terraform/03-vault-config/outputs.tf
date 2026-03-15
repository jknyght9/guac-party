output "nomad_management_token" {
  value     = vault_token.nomad_mgmt.client_token
  sensitive = true
}