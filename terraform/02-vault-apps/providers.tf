provider "nomad" {
    address = "http://nomad.service.consul:4646"
}
provider "random" {}
provider "vault" {
    address = local.vault_url
}

provider "postgresql" {
  host     = "master.postgres-cluster.service.consul"
  port     = 5432
  database = "postgres"
  username = local.postgres_root_user
  password = local.postgres_root_pw
  sslmode  = "disable"
  connect_timeout = 15
}