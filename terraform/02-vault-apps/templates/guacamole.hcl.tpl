job "guacamole-cluster" {
  # 'system' ensures it runs on EVERY node in your cluster
  type = "system"

  # This is for testing, so I don't have to wait for each node to load.
  #constraint {
  #  attribute = "$${node.unique.name}"
  #  value = "saruman.internal"
  #}

  group "guacamole-stack" {
    vault {
      role = "guacamole-role"
      policies = ["guacamole"]
    }
    network {
      port "http_mgmt" {
        static = 8085
        to = 8080
        host_network = "management"
      }
      # This port is limited to the range interface eth2, i.e. 10.40.0.0/24
      # Firewall rules enforced at the hypervisior to only allow tcp 4822 between eth2 & eth0
      port "guacd_mgmt" {
        static = 4822
        host_network = "management"
      }
      #dns {
      #  servers = ["172.17.0.1"]
      #}
    }
    # Task 1: The Proxy Daemon (C-based)
    task "guacd" {
      driver = "docker"
      resources {
        cpu = 8000
        memory = 6144
      }
      config {
        image = "guacamole/guacd:latest"
        #network_mode = "host"
        # No ports block needed if using network mode 'host' or side-by-side
        ports = ["guacd_mgmt"]
      }
    }

    # Copy our local root CA to guacamole and use keytool to appened it to
    # A copy of the existing certificate store
    task "ca-inject" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image = "guacamole/guacamole:latest"
        entrypoint = ["/bin/sh"]
        
        args = ["-c", <<-EOT
          cp $JAVA_HOME/lib/security/cacerts $${NOMAD_ALLOC_DIR}/data/cacerts && \
          keytool -importcert -v -trustcacerts -alias "internal-ca" -file $${NOMAD_ALLOC_DIR}/data/root_ca.crt \
          -keystore $${NOMAD_ALLOC_DIR}/data/cacerts -storetype PKCS12 -storepass changeit -noprompt
          chmod 644 $${NOMAD_ALLOC_DIR}/data/cacerts     
          EOT
        ]
      }
      
      template {
        data = <<EOH
{{ with secret "pki_root/cert/ca_chain" }}{{ .Data.certificate }}{{ end }}
EOH
        destination = "$${NOMAD_ALLOC_DIR}/data/root_ca.crt"
      }
    }

    # Task 2: The Web UI (Java-based)
    task "guacamole" {
      driver = "docker"
      resources {
        cpu = 4000
        memory = 3072
      }
      config {
        image = "guacamole/guacamole:latest"
        ports = ["http_mgmt"]
        extra_hosts = ["authentik.internal:192.168.100.100"]
      }
      
      env {
        # Point to the guacd sitting right next to it
        GUACD_HOSTNAME = "$${NOMAD_IP_guacd_mgmt}" #"172.17.0.1"
        GUACD_PORT     = "$${NOMAD_PORT_guacd_mgmt}" #"4822"
        LOGBACK_LEVEL = "debug"
      }
      # Keep OPENID JWKS endpoint the same. Fetch sig from Authentik internally using the keys and CA from Vault
      template {
        data = <<EOH
{{ with secret "secret/data/guacamole/oidc" }}
WEBAPP_CONTEXT=ROOT
OPENID_AUTHORIZATION_ENDPOINT="https://authentik.eternal.rowdycon.com/application/o/authorize/"
OPENID_CLIENT_ID={{ .Data.data.client_id }}
OPENID_ISSUER="https://authentik.eternal.rowdycon.com/application/o/guacamole/"
OPENID_JWKS_ENDPOINT="https://authentik.internal/application/o/guacamole/jwks/"
OPENID_REDIRECT_URI="https://guacamole-{{env "attr.unique.consul.name" }}.eternal.rowdycon.com/"
OPENID_USERNAME_CLAIM_TYPE="preferred_username"
OPENID_ENABLED="true"
EXTENSION_PRIORITY="openid"
JAVA_OPTS="-Djavax.net.ssl.trustStore=/alloc/data/cacerts -Djavax.net.ssl.trustStoreType=PKCS12 -Djavax.net.ssl.trustStorePassword=changeit -Xms2g -Xmx2g"
{{ end }}
EOH
        destination = "secrets/oidc.env"
        env = true
      }

      template {
        # Database (Shared across all nodes)
        data = <<EOH
{{ with secret "secret/data/guacamole/auth" }}
POSTGRESQL_SSL_MODE="disable"
POSTGRESQL_ENABLED="true"
POSTGRESQL_HOSTNAME="${mgmt_virtual_ip}"
POSTGRESQL_DATABASE="{{ .Data.data.postgres_database }}"
POSTGRESQL_USERNAME="{{ .Data.data.postgres_username }}"
POSTGRESQL_PASSWORD="{{ .Data.data.postgres_password }}"
{{ end }}
EOH
        destination = "secrets/db.env"
        env = true
      }

      service {
        name = "guac-$${attr.unique.consul.name}"
        port = "http_mgmt"
        
        tags = [
          "traefik.enable=true",          
          # NODE-SPECIFIC URL (e.g., guacamole.saruman.internal)
          # Internal Routers
          "traefik.http.routers.guac-$${attr.unique.consul.name}.rule=Host(\"guacamole-$${attr.unique.consul.name}.internal\")",
          "traefik.http.routers.guac-$${attr.unique.consul.name}.entrypoints=websecure-mgmt,websecure-user",
          "traefik.http.routers.guac-$${attr.unique.consul.name}.service=guac-$${attr.unique.consul.name}-svc",
          "traefik.http.routers.guac-$${attr.unique.consul.name}.tls=true",

          # External Routers
          "traefik.http.routers.guac-$${attr.unique.consul.name}-ext.rule=Host(\"guacamole-$${attr.unique.consul.name}.eternal.rowdycon.com\")",          
          "traefik.http.routers.guac-$${attr.unique.consul.name}-ext.entrypoints=websecure-user-vip",
          "traefik.http.routers.guac-$${attr.unique.consul.name}-ext.service=guac-$${attr.unique.consul.name}-svc",
          "traefik.http.routers.guac-$${attr.unique.consul.name}-ext.tls=true",
          
          # Shared Service
          "traefik.http.services.guac-$${attr.unique.consul.name}-svc.loadbalancer.server.port=8085",
          #"traefik.http.services.guac-$${attr.unique.consul.name}-svc.loadbalancer.server.scheme=https",
          "traefik.http.services.guac-$${attr.unique.consul.name}-svc.loadbalancer.serversTransport=internal-secure@file",
          "traefik.http.services.guac-$${attr.unique.consul.name}-svc.loadbalancer.sticky=true",
          "traefik.http.services.guac-$${attr.unique.consul.name}-svc.loadbalancer.sticky.cookie.name=guac_session",          
        ]
      }
      service {
        name = "guac-cluster"
        port = "http_mgmt"

        tags = [
          "traefik.enable=true",
          # Cluster level domains
          # Intneral Routers
          "traefik.http.routers.guac-cluster.rule=Host(`guacamole.internal`)",
          "traefik.http.routers.guac-cluster.entrypoints=websecure-mgmt-vip,websecure-user-vip",
          "traefik.http.routers.guac-cluster.service=guacamole-cluster",
          "traefik.http.routers.guac-cluster.tls=true",

          # External Routers
          "traefik.http.routers.guac-cluster-ext.rule=Host(`guacamole.eternal.rowdycon.com`) || Host(`eternal.rowdycon.com`)",
          "traefik.http.routers.guac-cluster-ext.entrypoints=websecure-user-vip",
          "traefik.http.routers.guac-cluster-ext.service=guacamole-cluster",
          "traefik.http.routers.guac-cluster-ext.tls=true",
          
          # Shared Service
          "traefik.http.services.guacamole-cluster.loadbalancer.sticky=true",
          "traefik.http.services.guacamole-cluster.loadbalancer.sticky.cookie.name=guac_session"
        ]
      }
    }
  }
}