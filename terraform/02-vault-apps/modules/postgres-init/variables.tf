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

variable "bootstrap_password" {
    type = string
    description = "Password for the Authentik admin user"
    sensitive = true
}

variable "bootstrap_email" {
    type = string
    description = "Email address for Authentik admin user"
}

variable "bootstrap_token" {
    type = string
    description = "API token to load into Authentik during bootstrap"
    sensitive = true
}
# =========================

# ===Guacamole variables===
variable "guacamole_db_pw" {
    type = string
    description = "Gaucamole password to postgresql"
}

variable "guacamole_admin_user" {
    type = string
    description = "Postgres username for Guacamole"
}

variable "guacamole_admin_pw" {
    type = string
    description = "Admin password for Gaucamole"
}

variable "leader_address" {
    type = string
    description = "IP Address of the first Nomad node"
}
# =========================