scope: postgres-cluster
namespace: /db/
name: {{ env "node.unique.name" }}

consul:
  host: 127.0.0.1:8500
  register_service: true

restapi:
  listen: 0.0.0.0:8008
  connect_address: {{ env "attr.unique.network.ip-address" }}:8008

postgresql:
  listen: 0.0.0.0:5433
  connect_address: {{ env "attr.unique.network.ip-address" }}:5433
  data_dir: /data/postgres/base
  bin_dir: /usr/lib/postgresql/16/bin
  
  authentication:
    {{ with secret "secret/data/postgres/auth" }}
    superuser:
      username: {{ .Data.data.username }}
      password: {{ .Data.data.password }}
    replication:
      username: {{ .Data.data.repl_user }}
      password: {{ .Data.data.repl_password }}
    rewind:
      username: {{ .Data.data.rewind_user }}
      password: {{ .Data.data.rewind_password }}
    {{ end }}

  pg_hba:
    - host replication standby 127.0.0.1/32 md5
    - host replication standby ::1/128 md5
    - host replication standby 192.168.100.0/24 md5
    - host all all 192.168.100.0/24 md5
    - host all all 192.168.90.0/24 md5
    - local all all trust
    - host all all 127.0.0.1/32 md5

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    postgresql:
      use_pg_rewind: true
      parameters:
        wal_level: logical
        max_connections: 100
  init:
    data_init:
      auth:
        {{- with secret "secret/data/postgres/auth" -}}
        superuser:
          username: {{ .Data.data.username }}
          password: {{ .Data.data.password }}
        {{- end -}}