variable "postgres_root_user" {
    type = string
    description = "Root username of postgres data"
}
variable "postgres_root_pw" {
    type = string
    description = "Root password of the postgres database"
}

variable "postgres_repl_user" {
    type = string
    description = "Replicate username"
}
variable "postgres_repl_pw" {
    type = string
    description = "Replicate password of the postgres database"
}

variable "postgres_rewind_user" {
    type = string
    description = "Rewind user of postgres database, used to rejoin cluster"
}
variable "postgres_rewind_pw" {
    type = string
    description = "Rewind password of the postgres database"
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