variable "leader_address" {
    type = string
    description = "IP Address of the first Nomad node"
}

variable "authentik_cert" {
    type = string
    description = "Certificate to load into Authentik, pulled from vault-pki"
    sensitive = true
}

variable "authentik_key" {
    type = string
    description = "Key to load into Authentik, pulled from vault-pki"
    sensitive = true
}

variable "authentik_token" {
    type = string
    description = "Authentik token"
    sensitive = true
}