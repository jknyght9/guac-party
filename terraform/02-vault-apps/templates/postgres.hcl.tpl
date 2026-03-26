vault {
    policies = ["postgres"]
    change_mode = "restart"
}

template {
  data = <<EOH
    {{ with secret "secret/data/postgres/root" }}
    DB_USER="{{ .Data.data.username }}"
    DB_PASS="{{ .Data.data.password }}"
    {{ end }}
  EOH
  destination = "local/secrets.env"
  env         = true
}