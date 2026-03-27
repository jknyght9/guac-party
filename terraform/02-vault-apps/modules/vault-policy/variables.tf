variable "postgres_root_pw" {
    type = string
    description = "Root password of the postgres database"
}

variable "postgres_repl_pw" {
    type = string
    description = "Root password of the postgres database"
}

variable "postgres_rewind_pw" {
    type = string
    description = "Root password of the postgres database"
}

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

variable "vault_backend_dependency" {
  type    = any
  default = null
  description = "A helper variable to force dependency on the JWT backend"
}