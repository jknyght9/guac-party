variable "jwt_backend_path" {
    type = string
    description = "The JWT path Vault will query Nomad for, i.e. 127.0.0.1:4646"
}

variable "secret_mount_path" {
    type = string
    description = "The path to mount secrets in Vault, i.e. secrets"
}

variable "vault_nomad_path" {
    type = string
    description = "Mount path for Nomad secret engine in vault, i.e. nomad"
}

# ===Authentik variables===
variable "authentik_secret_key" {
    type = string
    description = "Authentik secret key"
}
variable "authentik_db_pw" {
    type = string
    description = "Authentik password to postgresql"
}

variable "authentik_email_pw" {
    type = string
    description = "Email password idek"
}
# =========================

# ===Guacamole variables===
variable "guacamole_db_pw" {
    type = string
    description = "Gaucamole password to postgresql"
}

variable "guacamole_admin_pw" {
    type = string
    description = "Admin password for Gaucamole"
}
# =========================