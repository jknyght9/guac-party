# Guac-Party

HA Apache Guacamole on Proxmox via Nomad.

Deploys a full remote-access stack — Guacamole, Authentik (SSO), Traefik (reverse proxy), and Vault (secrets) — as Nomad jobs across a Proxmox cluster. One interactive bootstrap script takes a brand-new cluster from zero to running services.

```
Proxmox Cluster (N nodes, same L2) 
  +-- Node 1: Nomad VM -- Vault | Traefik | Unbound | Keepalived | Postgres | Guacamole | Authentik
  +-- Node 2: Nomad VM -- Vault | Traefik | Unbound | Keepalived | Postgres | Guacamole | Authentik
  +-- Node N: Nomad VM -- Vault | Traefik | Unbound | Keepalived | Postgres | Guacamole | Authentik
```

## Prerequisites

- **Docker** on the admin workstation (the only local dependency)
- A **Proxmox cluster** (1+ nodes) with root access for initial setup
- All Proxmox nodes on the **same L2 network**
- A free IP range on the management network for Nomad VMs
- Manually generated VM templates for Kali, Windows XP, and Alpine

## Quick Start

### 1. Bootstrap

The bootstrap script is interactive — it prompts for node addresses, credentials, and network configuration, then creates environment files, ssh keys, Proxmox Terraform role with API token.

#### Notice
The bootstrap script has not been fully updated to reflect the most recent changes of this project. It should still correctly build the Nomad VM using Packer, generate the Terraform API access and generate environment files. But the prompts and final environment files have been fully updated due to other development priorities. 
It will still get you most of the way started, but be sure to review the .example files for missing componenets.

```bash
./bootstrap/bootstrap.sh
```

This will:
- Create a Proxmox automation user (`terraform@pve`) with an API token
- Generate an SSH key pair
- Build a VM template via Packer (Ubuntu 24.04 + Docker + Nomad)
- Output next steps

### 2. Deploy Services

#### 2.1 Layer 01
After running the bootstrap script you should be able to generate this first layer using
``` bash
./docker/terraform.sh init  -chdir=01-nomad-base
./docker/terraform.sh apply -chdir=01-nomad-base --var-file=../global.tfvars
```
This will create the base Nomad machines on N number of nodes with Vault, Traefik, DNS, and Keepalived on each
While possible to initialze Vault from it's web UI, it is highly recommended to initialize through the command line. navigate to the Nomad web UI and use the exec button to get a shell on a Vault instance.
```bash
vault operator init -key-shares=1 -key-threshold=1
```
Save the root token and unseal key somewhere safe. The root token will need to be added to the .env file for the project. It is used by Terraform later on. It is safe to unseal Vault from the web UI using the unseal key from earlier unseal each instance using:
```bash
vault operator unseal
```

#### 2.2 Layer 02
At this point you should have successfully created layer 01, unsealed each Vault instance, and added the Vault rook token to the .env file. This layer creates the Postgres HA database, Vault roles and policies for Nomad and various other services, and PKI. Deploys Guacamole and Authentik, with an OIDC application from Authentik to Guacamole.
``` bash
./docker/terraform.sh init  -chdir=02-user-apps
./docker/terraform.sh apply -chdir=02-user-apps --var-file=../global.tfvars
```

#### 2.3 Layer 03
This layer will build the cyber ranges. Due to development constraints Windows, Kali and Alpine were not built using Packer, and you will need to provide your own VM templates. Reach out to me if you would like more information. Terraform expects the VM templates to follow this format:
6X00 - Windows XP virtual machine.   X denotes the index of a given node starting at 1
7X00 - Alpine Linux virtual machine. X denotes the index of a given node starting at 1
8X00 - Kali Linux virtual machine.   X denotes the index of a given node starting at 1

Each node expects of copy of the VM templates. This allows for thin clones on each node, where only the deltas are written to disk. This enables my scaleable architecture, where a range can be cloned in a matter of seconds compared to minutes copying the entire VM disk. 

Once these requriments are met build the layer using
``` bash
./docker/terraform.sh init  -chdir=03-range-build
./docker/terraform.sh apply -chdir=03-range-build --var-file=../global.tfvars
```

### 3. Final steps
Included in this project are a handful of scripts using the same environemnt file designed to help administer the range.
#### 3.1 Base snapshot
After building the range snapshot a base state of every range using:
```bash
./snappshot_ranges.sh
```
This script can be run multiple times, if you build 20 ranges, snapshot, add another 20, and snapshot again. It will fill your Proxmox logs with errors about duplicate snapshot ranges for the first 20, but this can safely be ignored. There is a 1 second delay between each snapshot command to prevent disk errors that occur when attempting to snapshot each range at the same time. This does mean at 50 users you must wait about ~4 minutes for the snapshots to complete. Future work can be done to check HTTP return codes, a 5XX means the snapshot already exists and the sleep can be skipped, a 200 means the snapshot is in progress and will sleep 1 second.

#### 3.2 Rollback a specific range
Using the rollback_range.sh we can restore a single range to it's base state captured in the previous script.
```bash
./rollback_range.sh $1
```
$1 is the range_id, 1, 12, 43, etc

#### 3.3 Clean the entire range
If you want to quickly return the entire range to it's default state post snapshot use the clean_ranges script.
```bash
./clean_ranges.sh
```
This will restore the range to a blank state rapidly. Tested with ~55 ranges taking less than a minute.

## Project Structure

```
bootstrap/              Interactive setup (Proxmox user, SDN, SSH keys)
  bootstrap.sh          Main entry point
  lib/                  Shell libraries (validation, prompts, API, etc.)
  secrets/              Generated credentials (gitignored)
docker/                 Container wrappers for Terraform, Packer, Nomad CLI
packer/ubuntu-nomad/    VM template: Ubuntu 24.04 + Docker CE + Nomad + Consul
terraform/              Infrastructure: Divied into layers built on top of each other
  01-nomad-base/        Creates Nomad cluster from template created with Packer. Starts several jobs on each node, DNS, Traefik for proxying and Vault for secrets management. Adds an additional 50gb disk to each Nomad VM. Reduces clone times by keeping root disk minimal. Disk is partioned in 2 parts, first to extend the root LVM and second to add shared gluster storage. Builds Nomad VMs with Virtual IP's for automatic fail over.

  02-vault-apps/        Runs after Vault is initialized (remote exec through Nomad to provision) and each Vault is unsealed. Generates HA Postgres database with Consul used for finding the current leader. Then runs a single Authentik bootstrap container to build the database, and on exit brings up all instances of Authentik worker and server containers. Guacamole is also created at this time using the same Postgres instance as Authentik. Also initializes PKI inside of Vault for internal use. Including creating a root CA, signing custom TLS certs and distributing the root CA + generated certs to services such as Authentik, Guacamole, and Traefik. Also creates Guacamole app inside Authentik and maps the default Authentik admin "akadmin" as a Guacamole administrator account.

  03-range-build/       Using outputs from the previous layer iteritaively generates N number of ranges, defined by the number of users in workshop_users.auto.tfvars. Creates Authentik user with password, creates respective Guacamole user, and assigns the users range to their account based on range_id.
docs/                   Detailed architecture docs
```

## Using the Docker Wrappers

No tools need to be installed locally besides Docker. The wrapper scripts mount the project into the appropriate HashiCorp container:

```bash
# Terraform
./docker/terraform.sh init
./docker/terraform.sh plan -chdir=01-nomad-base --var-file=../global.tfvars
./docker/terraform.sh apply -chdir=01-nomad-base --var-file=../global.tfvars

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

| Component  | Strategy |
|------------|----------|
| Nomad      | Server+client on every node. Raft consensus tolerates `(N-1)/2` failures. Configured with interfaces     |
|            | defined as User, Management, or Range net for isolation.                                                 |
| Vault      | 3 instances with Raft storage. Automatic leader election. Nomad communicates to its local                |
|            | Vault instance, skipping cross network traffic.                                                          |
| Traefik    | System job on every node. Virtual IP is used for user access. Load balances users traffic and loads      |
|            | certificates generated using Vault's PKI engine, as well as manually created certs.                      |
| Unbound    | DNS with entries for both cluster level and node level domains on both the management and user networks. | 
|            | Runs on every node                                                                                       |
| Keepalived | Creates a virtual IP on both management and user network side. Allows for addressing the cluster with a  |
|            | single IP address. Less port forwarding and automatic health checks using Traefik's API                  |
| Postgres/  | High availability database, copy is created on each node. Uses Patroni's intergration with Consul        |
| Patroni    | for leader election. Supports replication and rewind, allowing a downed instance to be brought back.     |
|            | Is TCP proxied with Traefik transparent to downstream applications                                       |
| Guacamole  | Guacamole webserver and Guacd run on every node. During layer 03 Guacamole connections are mapped        |
|            | correctly to the Guacad instance running locally to each range. Uses HA Postgres                         |
| Authentik  | Worker and server instance run on every node, acts as OIDC provider for Guacamole. Stores uses sessions  |
|            | In Postgres and is stateless, meaning any user can enter through any node once authenticated             |


## Cyber Range Layout
Each N number of cyber ranges are spread evenly across I number of nodes defined in your variables file. During build time the physical node they reside on is remembered and used later for Guacamole optimizations. Each range shares the same L2 network bridges in Proxmox. The WAN bridge for Alpine starts with addresses at .101 and incremenets for each range id. The shared LAN bridge has every VM keep the same IP schema, but uses tagged VLANs in Proxmox to isolate each range without needing to create a new L2 bridge for each.
### Target - Windows XP - 192.168.30.215/24
https://archive.org/details/WinXPProSP3x86

Using the ISO provided by Microsoft we install Windows XP and a single VM and manually apply changes to make the machine vulnerable to Eternal Blue. User account created will be 'hackme' with password 'hackme'. Some manual command line configuring is required to both enable the built in Administrator account, and disable admin privileges for hackme user.
Provided in docs will be a pdf with instructions to make Windows vulnerable to Eternal Blue. 
Due to time constraints some documentation relating to removing admin privileges and enabling remote desktop are missing. Reach out to me for guidance.
### Attack - Kali - 192.168.30.55/24
This is a standard Kali machine with minimal additional configuration. The primary change made is installing, enabling and configuring XRDP to start on boot. This is how a user will connect to their Kali instance.

### Router - Alpine - 192.168.30.1/24
Alpine is configured by installing DNSMASQ, and changing it priority to as late as possible in the boot process. 
And injecting our shell script to configure our firewall rules.

IPTABLES is used to configure network isolation from our ranges to the internet while allowing from remote desktop (RDP) traffic in. The script can be found in ./terraform/03-range-build/templates/setup-firewall.sh.

It drops any outbound traffic, allows destination NAT of RDP to Windows and Kali, and allows both machines to request DHCP leases from DNSMASQ.


DNSMASQ serves as the DHCP server for the range, using MAC addresses generated during the range build to assign static DHCP leases.

Windows XP does not support cloud init or SYSPREP so assigning an IP address at build time is not feasible.
Kali caused significant headaches when using cloud init to assign an IP. For this reason it also has it address assigned using DNSMASQ.

Since we rely on DNSMASQ for DHCP we must wait for Alpine to start before building Kali and Windows. This saves us from an akward period where Kali and/or Windows are up but unreachable because DNSMASQ was not started when they requested leases.

## Further Reading

- [Architecture details](docs/architecture.md) — Not up to date, but still relavant
- [Windows XP Setup](docs/vulnchecklist.pdf) — Setup guide pdf for making XP vulnerable
- [Windows Notes](docs/windows%20notes) — Ad hoc notes I took during installation of Windows XP, as well as additional instructions for password cracking bonus.
- [Presentation Slides](docs/Eternal-family.pdf) — Slides used during my presentation at RowdyCon 2026
