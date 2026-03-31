datacenter = "dc1"
data_dir   = "/opt/consul/data"
node_name = "${replace(node_name, "/\\..*$/", "")}"
bind_addr  = "${bind_addr}"
client_addr = "0.0.0.0" # So Docker containers can reach it

server = true
bootstrap_expect = ${bootstrap_expect}

# Use the same retry_join logic from Nomad
retry_join = [%{ for i, ip in retry_join ~}"${ip}"%{ if i < length(retry_join) - 1 ~}, %{ endif ~}%{ endfor ~}]

advertise_addr = "${node_ip}"

# Important for Patroni/Vault integration
connect {
  enabled = true
}

ui_config {
  enabled = true
}