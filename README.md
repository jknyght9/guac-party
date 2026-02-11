# Guac-Party

HA Apache Guacamole on Proxmox via Nomad.

Deploys a full remote-access stack — Guacamole, Authentik (SSO), Traefik (reverse proxy), and Vault (secrets) — as Nomad jobs across a Proxmox cluster. One interactive bootstrap script takes a brand-new cluster from zero to running services.

```
Admin Workstation (Docker only)
  |
  |-- bootstrap.sh        -> Proxmox user/role/SDN setup
  |-- docker/packer.sh    -> VM template (Ubuntu + Docker + Nomad)
  |-- docker/terraform.sh -> One Nomad VM per Proxmox node
  |-- nomad/deploy.sh     -> Vault -> Traefik -> Authentik -> Guacamole
  |
  v
Proxmox Cluster (N nodes, same L2)
  +-- Node 1: Nomad VM -- Traefik | Vault | Authentik | Guacamole
  +-- Node 2: Nomad VM -- Traefik | Vault | Guacamole
  +-- Node N: Nomad VM -- Traefik | Vault | ...
```

## Prerequisites

- **Docker** on the admin workstation (the only local dependency)
- A **Proxmox cluster** (1+ nodes) with root access for initial setup
- All Proxmox nodes on the **same L2 network**
- A free IP range on the management network for Nomad VMs

## Quick Start

### 1. Bootstrap

The bootstrap script is interactive — it prompts for node addresses, credentials, and network configuration, then handles everything else.

```bash
./bootstrap/bootstrap.sh
```

This will:
- Create a Proxmox automation user (`terraform@pve`) with an API token
- Configure an SDN Simple zone for guest VMs
- Generate an SSH key pair
- Build a VM template via Packer (Ubuntu 24.04 + Docker + Nomad)
- Deploy one Nomad VM per Proxmox node via Terraform
- Output next steps

### 2. Deploy Services

After bootstrap completes and the Nomad cluster forms (~60 seconds):

```bash
export NOMAD_ADDR=http://<first-nomad-vm-ip>:4646
./nomad/deploy.sh
```

The deploy script runs jobs in order with health checks and pauses for manual steps:

1. **Vault** — deploys, then prompts you to initialize and unseal
2. **Traefik** — reverse proxy with self-signed TLS on every node
3. **Authentik** — SSO provider, then prompts you to create an OIDC provider
4. **Guacamole** — remote access gateway (HA, 2 instances)

### 3. Access Services

Point DNS (or `/etc/hosts`) for `*.internal` to any Nomad VM IP:

| Service | URL |
|---------|-----|
| Guacamole | `https://guacamole.internal` |
| Authentik | `https://authentik.internal` |
| Vault | `https://vault.internal` |
| Traefik Dashboard | `http://<any-node-ip>:8081` |

## Vault Setup

After `deploy.sh` starts Vault, initialize and configure it:

```bash
export VAULT_ADDR=http://<any-nomad-ip>:8200

# Initialize (save the unseal key and root token!)
vault operator init -key-shares=1 -key-threshold=1

# Unseal (repeat on each node if needed)
vault operator unseal <unseal-key>

# Login and enable secrets engine
vault login <root-token>
vault secrets enable -path=secret kv-v2

# Store service secrets
vault kv put secret/authentik/db password=$(openssl rand -hex 16)
vault kv put secret/authentik/secret key=$(openssl rand -hex 32)
vault kv put secret/guacamole/db password=$(openssl rand -hex 16)

# Create per-service policies
vault policy write authentik - <<'EOF'
path "secret/data/authentik/*" { capabilities = ["read"] }
EOF

vault policy write guacamole - <<'EOF'
path "secret/data/guacamole/*" { capabilities = ["read"] }
EOF
```

## SSO Setup

After Authentik is running:

1. Open `https://authentik.internal/if/flow/initial-setup/` and create an admin account
2. Create an **OAuth2/OpenID Provider** named `guacamole`:
   - Client type: Confidential
   - Redirect URI: `https://guacamole.internal/`
3. Create an **Application** linked to the provider
4. Store the client ID in Vault:
   ```bash
   vault kv put secret/guacamole/oidc client_id=<id-from-authentik>
   ```
5. Uncomment the OIDC template block in `nomad/jobs/guacamole.nomad.hcl`, update the domain placeholders, and re-deploy:
   ```bash
   ./docker/nomad.sh job run nomad/jobs/guacamole.nomad.hcl
   ```

## Project Structure

```
bootstrap/              Interactive setup (Proxmox user, SDN, SSH keys)
  bootstrap.sh          Main entry point
  lib/                  Shell libraries (validation, prompts, API, etc.)
  secrets/              Generated credentials (gitignored)
docker/                 Container wrappers for Terraform, Packer, Nomad CLI
packer/ubuntu-nomad/    VM template: Ubuntu 24.04 + Docker CE + Nomad
terraform/              Infrastructure: SDN module + Nomad VM module
  modules/proxmox-sdn/  SDN Simple zone, VNet, subnet
  modules/nomad-node/   One VM per Proxmox node (cloud-init + Nomad config)
  templates/            Cloud-init and Nomad HCL templates
nomad/                  Service deployment
  deploy.sh             Ordered deployment with health checks
  jobs/                 Vault, Traefik, Authentik, Guacamole job specs
docs/                   Detailed architecture docs
```

## Using the Docker Wrappers

No tools need to be installed locally besides Docker. The wrapper scripts mount the project into the appropriate HashiCorp container:

```bash
# Terraform
./docker/terraform.sh init
./docker/terraform.sh plan
./docker/terraform.sh apply

# Packer
./docker/packer.sh init /workspace/packer/ubuntu-nomad
./docker/packer.sh build /workspace/packer/ubuntu-nomad

# Nomad CLI
./docker/nomad.sh server members
./docker/nomad.sh job status
./docker/nomad.sh job run nomad/jobs/traefik.nomad.hcl
```

The wrappers load credentials from `.env` (generated by bootstrap) and forward relevant environment variables into the container.

## High Availability

| Component | Strategy |
|-----------|----------|
| Nomad | Server+client on every node. Raft consensus tolerates `(N-1)/2` failures. |
| Vault | 3 instances with Raft storage. Automatic leader election. |
| Guacamole | 2 instances on distinct hosts. Traefik load-balances. |
| Traefik | System job on every node. Any node IP routes to all services. |
| Authentik | Single instance by default. Scale `count` as needed. |

## Technology Choices

| Component | Choice | Why |
|-----------|--------|-----|
| Terraform provider | `bpg/proxmox` ~> 0.70 | Actively maintained, full SDN support. |
| SDN | Simple zone | All nodes on same L2. No VXLAN overhead. |
| Service discovery | Nomad native | Built-in since Nomad 1.3+. No Consul needed. |
| Secrets | Vault on Nomad (Raft) | HA, native Nomad integration. |
| SSO | Authentik via OIDC | Well-documented Guacamole integration. No Redis since 2025.2. |
| TLS | Self-signed wildcard | Internal-only. Swap for ACME or internal CA later. |

## Further Reading

- [Architecture details](docs/architecture.md) — networking, service routing, secrets management, HA behavior
