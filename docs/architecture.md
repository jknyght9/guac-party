# Guac-Party Architecture

# NOTICE
This section of documentation is largely dated, but kept for archival purposes. It can be a good starting point,
but much of it is no longer in line with the current architecture

HA Apache Guacamole on Proxmox via Nomad.

## Overview

```
Admin Workstation (Docker only)
  |
  |-- bootstrap.sh (interactive setup)
  |-- docker/packer.sh   -> VM template build
  |-- docker/terraform.sh -> Nomad VM deployment
  |-- docker/nomad.sh     -> Job submission
  |
  v
Proxmox Cluster (N nodes, same L2)
  |
  +-- Node 1: Nomad VM (server+client)
  |     +-- Traefik (system job - every node)
  |     +-- Vault / Authentik / Guacamole (service jobs)
  |
  +-- Node 2: Nomad VM (server+client)
  |     +-- Traefik (system job)
  |     +-- Vault / Authentik / Guacamole (service jobs)
  |
  +-- Node N: ...
  |
  +-- SDN Simple Zone: "guestzone" (isolated VNet for guest VMs)
```

## Networking

All Nomad VMs sit on the management network (e.g. `vmbr0`, `192.168.1.0/24`). Each Proxmox node gets one Nomad VM with a static IP.

A separate SDN Simple zone (`guestzone`) with its own VNet and subnet (`10.10.0.0/24`) is provisioned for future guest VMs (out of scope for this project).

### Service Routing

Traefik runs as a Nomad **system job** on every node, binding ports 80 (HTTP), 443 (HTTPS), and 8081 (dashboard).

Traefik discovers services via the **Nomad native service discovery** provider. Each service registers itself with Traefik tags that define `Host()` routing rules:

| Service    | Hostname                  | Port  |
|------------|--------------------------|-------|
| Vault      | `vault.internal`         | 443   |
| Authentik  | `authentik.internal`     | 443   |
| Guacamole  | `guacamole.internal`     | 443   |
| Traefik UI | Any node IP              | 8081  |

Point DNS (or `/etc/hosts`) for `*.internal` to any Nomad VM IP. Traefik handles routing.

### TLS

Self-signed certificates are used by default. Traefik serves a wildcard `*.internal` cert. Upgrade to an internal CA or ACME as needed.

## Services

### Vault

- **Type**: Nomad service job, `count = 3`
- **Storage**: Raft integrated storage (HA across nodes)
- **Persistence**: Nomad host volumes at `/opt/volumes/vault`
- **Bootstrap**: Must be manually initialized and unsealed after first deploy

### Traefik

- **Type**: Nomad system job (runs on every node)
- **Discovery**: Nomad native provider (no Consul needed)
- **Ports**: 80 (redirect to 443), 443 (HTTPS), 8081 (dashboard)

### Authentik

- **Type**: Nomad service job
- **Components**: PostgreSQL sidecar + server + worker
- **Version**: 2025.2+ (no Redis dependency)
- **Secrets**: Pulled from Vault via `template` blocks

### Guacamole

- **Type**: Nomad service job, `count = 2` (HA)
- **Components**: PostgreSQL sidecar + guacd sidecar + web app
- **DB Init**: Uses official `initdb.sh` script
- **SSO**: OIDC integration with Authentik (configured post-deploy)

## Deployment Order

1. **Bootstrap**: `bootstrap/bootstrap.sh`
   - Creates Proxmox user/role/token
   - Sets up SDN
   - Builds VM template (Packer)
   - Deploys Nomad VMs (Terraform)

2. **Services**: `nomad/deploy.sh`
   - Vault (init + unseal + store secrets)
   - Traefik
   - Authentik (configure OIDC provider for Guacamole)
   - Guacamole (enable OIDC after Authentik is ready)

## SSO Setup (Post-Deploy)

1. Access Authentik at `https://authentik.internal/if/flow/initial-setup/`
2. Create admin account
3. Create an **OAuth2/OpenID Provider** named `guacamole`:
   - Client type: Confidential
   - Redirect URI: `https://guacamole.internal/`
   - Note the Client ID and Client Secret
4. Create an **Application** linked to the provider
5. Store OIDC credentials in Vault:
   ```bash
   vault kv put secret/guacamole/oidc client_id=<id>
   ```
6. Uncomment the OIDC template block in `nomad/jobs/guacamole.nomad.hcl`
7. Update the domain placeholders and re-deploy:
   ```bash
   nomad job run nomad/jobs/guacamole.nomad.hcl
   ```

## HA Behavior

- **Nomad**: Server+client on every node. Raft consensus tolerates `(N-1)/2` failures.
- **Vault**: Raft HA with 3+ nodes. One active, rest standby. Automatic leader election.
- **Guacamole**: `count = 2` with `distinct_hosts` constraint. Traefik load-balances.
- **Traefik**: System job on every node. DNS round-robin or any node IP works.
- **Authentik**: Single instance (stateless server/worker). PostgreSQL sidecar for state. Scale `count` as needed.

## Secrets Management

All secrets are stored in HashiCorp Vault (KV v2) and injected into Nomad jobs via `vault` stanzas and `template` blocks.

| Secret Path                  | Contents                  | Used By    |
|-----------------------------|---------------------------|------------|
| `secret/authentik/db`       | `password`                | Authentik  |
| `secret/authentik/secret`   | `key`                     | Authentik  |
| `secret/guacamole/db`       | `password`                | Guacamole  |
| `secret/guacamole/oidc`     | `client_id`               | Guacamole  |

Each service has a minimal Vault policy granting read-only access to its own secret paths.
