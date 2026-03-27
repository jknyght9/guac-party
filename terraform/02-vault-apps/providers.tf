provider "nomad" {
    address = "http://nomad.service.consul:4646"
}
provider "random" {}
provider "vault" {
    address = local.vault_url
}