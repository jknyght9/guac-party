output "authentik_token_hex" {
  value     = random_bytes.authentik_token.hex
  sensitive = true
}