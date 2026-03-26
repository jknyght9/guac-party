variable "postgres_root_pw" {
    type = string
    description = "Root password of the postgres database"
}

variable "nomad_jwt_issuer" {
    type = string
    description = "URL to nomad from docker, i.e. 172.17.0.1"
}