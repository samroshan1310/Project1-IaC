# Automated Cloud Infrastructure Provisioning with Terraform & CI/CD

**Project 1** of a 5-project Azure Cloud/DevSecOps portfolio series. Provisions a
multi-tier Azure environment for a simulated financial application — networking,
compute, storage, and secrets management — entirely through Infrastructure as Code,
with security scanning gated into the CI/CD pipeline.

## Architecture

```
                        ┌─────────────────────────────┐
                        │      Resource Group         │
                        │                              │
   Internet ──HTTPS──▶  │  ┌────────────┐              │
                        │  │  Public     │  NSG: allow  │
                        │  │  Subnet     │  443 only    │
                        │  │ (App Svc)   │              │
                        │  └────────────┘              │
                        │                              │
                        │  ┌────────────┐  NSG: SSH     │
                        │  │  Private   │  from admin   │
                        │  │  Subnet    │  CIDR only    │
                        │  │ (VM, SA)   │  + NAT GW     │
                        │  │            │  egress only  │
                        │  └────────────┘              │
                        │                              │
                        │  Key Vault (RBAC, purge      │
                        │  protection, network-        │
                        │  restricted to private snet) │
                        └─────────────────────────────┘
```

## What's provisioned

| Resource | Hardening applied |
|---|---|
| VNet + public/private subnets | Network segmentation, service endpoints to Storage/Key Vault |
| NSGs (public + private) | Deny-all default; SSH restricted to `admin_cidr`, never `0.0.0.0/0` |
| NAT Gateway | Outbound-only internet access for the private subnet |
| Linux VM | No public IP; password sourced from Key Vault, not hardcoded |
| Key Vault | RBAC authorization (no legacy access policies), purge protection, network ACL deny-by-default |
| Storage Account | HTTPS-only, TLS 1.2 minimum, no public blob access, GRS replication |
| App Service | HTTPS-only, TLS 1.2 minimum, FTP disabled, system-assigned managed identity (no credentials in app settings) |

## Repo structure

```
.
├── main.tf                  # Root module wiring everything together
├── variables.tf / outputs.tf
├── providers.tf              # azurerm + backend config
├── terraform.tfvars.example
├── modules/
│   ├── network/              # VNet, subnets, NSGs, NAT Gateway
│   ├── keyvault/              # RBAC Key Vault + secret
│   ├── compute/                # Hardened VM
│   ├── storage/                 # Hardened storage account
│   └── appservice/               # App Service Plan + Web App
└── .github/workflows/
    └── terraform-cicd.yml      # validate → security scan → plan → approval gate → apply
```

## Pipeline stages

1. **Validate** — `terraform fmt -check`, `terraform validate`, `tflint`
2. **Security scan** — Checkov and tfsec, both **hard-fail** the build on findings (no `soft_fail`). Results uploaded as SARIF to the GitHub Security tab.
3. **Plan** — authenticates to Azure, produces a plan artifact
4. **Apply** — gated behind a GitHub Environment (`production`) requiring manual reviewer approval; applies the exact plan artifact from step 3, so nothing drifts between what was approved and what gets deployed

## KodeKloud playground service constraints

Per [KodeKloud's published Azure Playground limits](https://kodekloud.com/cloud-playgrounds/azure#Azure-Playground), this repo is built to comply with:

| Constraint | How this repo complies |
|---|---|
| No additional resource groups can be created | `main.tf` uses `data "azurerm_resource_group"` against your pre-existing playground RG, never `resource "azurerm_resource_group"` |
| Supported regions: West US, East US, Central US, South Central US only | Region is inherited from the existing resource group's location — never hardcoded elsewhere |
| Cannot create/modify role assignments or elevate access | Key Vault uses access policies (`enable_rbac_authorization = false`), not `azurerm_role_assignment` |
| Key Vault: Purge Protection must be **disabled** | `purge_protection_enabled = false` (see comment in `modules/keyvault/main.tf` — flip to `true` outside the sandbox) |
| Storage Account SKUs: Standard_LRS, Standard_RAGRS only (no GRS) | `account_replication_type = "LRS"` |
| VM SKUs: Standard_B1s, Standard_B2s, Standard_D2s_v3, Standard_DS1_v2 | Default `vm_size = "Standard_B1s"` |
| No Premium disk SKUs, max 128GB | `os_disk.storage_account_type = "Standard_LRS"`, default image disk size well under the limit |
| App Service Plan SKUs: Free (F1), Basic (B1) only | `azurerm_service_plan.sku_name = "B1"` |

## Checkov findings: what was fixed vs. deliberately skipped

A local `checkov -d .` scan initially found 30 failed checks. Here's the breakdown
after remediation:

**Fixed (real hardening improvements):**

| Check | Fix |
|---|---|
| CKV_AZURE_50 | Added `allow_extension_operations = false` on the VM — closes off arbitrary VM extension execution |
| CKV_AZURE_114 / CKV_AZURE_41 | Key Vault secret now has `content_type` and a static `expiration_date` |
| CKV_AZURE_206 | Storage account switched from LRS to RAGRS (still within KodeKloud's allowed SKUs) |
| CKV2_AZURE_38 / CKV2_AZURE_41 | Added blob soft-delete (`delete_retention_policy`) and a SAS token expiration policy |
| App Service: CKV_AZURE_214, 18, 65, 66, 63, 17 | Added `always_on`, `http2_enabled`, logging (`detailed_error_messages`, `failed_request_tracing`, `http_logs`), and client certificate support |
| App Service: CKV_AZURE_213 | Added `health_check_path` (assumes the app will expose `/health`) |

**Deliberately skipped, with `#checkov:skip` comments explaining why** (each one
documented at the point of use in the relevant module):

| Check | Why it's blocked |
|---|---|
| CKV_AZURE_1, 178, 149 | Password auth is intentional for this project's Key Vault demo — see `modules/compute/main.tf` |
| CKV_AZURE_110, 42 | Purge Protection is a *prohibited* feature in the KodeKloud playground |
| CKV_AZURE_225, 211 | Need Premium/Standard tier App Service Plan; playground only allows Free/Basic |
| CKV_AZURE_13 | App Service Authentication needs a real Azure AD app registration — application-layer, not infra |
| CKV_AZURE_222 | This App Service is intentionally the public-facing tier by design |
| CKV_AZURE_88 | No persistent file storage need for this stateless app |
| CKV_AZURE_59, CKV2_AZURE_40 | Both need either a Private Endpoint or an Azure AD data-plane role assignment — the latter is blocked by Contributor-only lab permissions |
| CKV2_AZURE_32, 33 | Private Endpoints for Key Vault/Storage — a good next step, deferred as a follow-up rather than bolted on here |
| CKV2_AZURE_1 | Customer-managed key encryption needs a role assignment blocked the same way |
| CKV2_AZURE_21 | Blob read-logging needs a Log Analytics Workspace + Diagnostic Setting — monitoring/SRE scope (a later project in this series), not infra provisioning |

The pattern across nearly every skip: either a **platform-imposed constraint** (lab
tier/feature restrictions) or a **missing role-assignment permission** that a
Contributor-only sandbox session can't grant. None are "ignored because they're
annoying" — each has a specific, stated reason, which is the difference between
suppressing a scanner and actually reasoning about risk.

## Bootstrapping remote state (do this once, before `terraform init`)

This repo's backend is `azurerm`, configured as a **partial backend** (see
`providers.tf`) — the storage account and resource group aren't hardcoded, because:

- Terraform needs the state backend to exist *before* `init` runs — it can't use a
  resource created by this same config as its own backend. The storage account has
  to be created manually, first, outside Terraform.
- KodeKloud playgrounds don't allow creating additional resource groups, so the state
  storage account has to live in your one existing playground RG rather than a fixed
  name.

**One-time setup per playground session:**

```bash
# 1. Find your existing RG and its region
az group list -o table
az group show --name <your-existing-rg> --query location -o tsv

# 2. Create the state storage account (name must be globally unique across
#    all of Azure, lowercase, 3-24 chars, no dashes -- add a random suffix)
az storage account create \
  --name sttfstate<yourinitials><4digits> \
  --resource-group <your-existing-rg> \
  --location <region-from-step-1> \
  --sku Standard_LRS

# 3. Create the blob container that will hold the state file
az storage container create \
  --name tfstate \
  --account-name sttfstate<yourinitials><4digits> \
  --auth-mode login
```

Then copy `backend.hcl.example` to `backend.hcl` and fill in the subscription ID
(`az account show --query id -o tsv`), resource group, storage account name, and
access key (`az storage account keys list --account-name <name> --resource-group
<rg> --query "[0].value" -o tsv`). Initialize with:

```bash
terraform init -backend-config=backend.hcl
```

## Running this against a KodeKloud Azure playground

**Important lab constraint:** KodeKloud playground users are typically granted
**Contributor only** on the subscription. Contributor deliberately excludes
`Microsoft.Authorization/roleAssignments/write` — the permission needed to create a
Service Principal's role assignment, or to grant any Azure RBAC role to anyone
(including yourself). This is intentional sandbox hardening, not a bug, and no amount
of retrying `az ad sp create-for-rbac` will get past it.

Two consequences, and how this repo is built to handle both:

1. **Key Vault** uses the **access-policy model** (`enable_rbac_authorization = false`),
   not Azure RBAC. Granting access-policy permissions is a property write on the vault
   itself (`Microsoft.KeyVault/vaults/write`), which Contributor *does* include — so
   secrets work fully under a Contributor-only session, with no security trade-off.
2. **The GitHub Actions pipeline's `apply` job still needs its own Service Principal**
   (via the `azure/login` action) to authenticate non-interactively. Creating *that* SP
   requires the same `roleAssignments/write` permission the playground denies. There's
   no way around this — an automated pipeline fundamentally needs a durable identity
   with subscription-level access, and a Contributor-only lab user can't grant one.

**So, two tracks, depending on what you're demonstrating:**

### Track A — Deploy locally against the playground (works fully, right now)

Use your own logged-in `az` session as the Terraform identity. No SP needed.

1. **Launch the playground**, note the subscription ID.
2. **Authenticate and target the subscription:**
   ```bash
   az login
   az account set --subscription "<playground-subscription-id>"
   ```
3. **Find your pre-existing resource group** (playgrounds don't allow creating new ones):
   ```bash
   az group list -o table
   ```
4. **Get your own public IP** for the `admin_cidr` variable:
   ```bash
   curl -s ifconfig.me
   ```
5. **Copy `terraform.tfvars.example` to `terraform.tfvars`** and fill in `existing_resource_group_name` (from step 3) and `admin_cidr` (from step 4). No `pipeline_object_id` needed — the vault access policy is granted automatically to whichever identity runs `terraform apply`, via `data.azurerm_client_config.current.object_id`.
6. **Run it** (using the `backend.hcl` you set up in the bootstrap step above):
   ```bash
   terraform init -backend-config=backend.hcl
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```
7. **Verify in the Azure portal**: resource group, VNet/subnets, NSGs, VM (private IP only), Key Vault (check the access policy under Access Configuration), storage account, App Service. Screenshot each — this is your interview evidence.
8. **Run the security scans locally too**, since the `security_scan` GitHub Actions job doesn't need any Azure credentials at all — it's static analysis of the `.tf` files:
   ```bash
   checkov -d .
   tfsec .
   ```
9. **Destroy before the session ends:**
   ```bash
   terraform destroy -var-file=terraform.tfvars
   ```

### Track B — Demonstrate the CI/CD pipeline itself

The `validate` and `security_scan` jobs in `.github/workflows/terraform-cicd.yml`
need **no Azure credentials at all** — push this repo to GitHub and they'll run
end-to-end for real, giving you a genuine, screenshot-able Checkov/tfsec gate.

The `plan`/`apply` jobs (which do need `AZURE_CREDENTIALS`) will only run fully
end-to-end against a subscription where you can create an SP with a role assignment
— a personal Azure free-tier subscription, or a work subscription where an admin
grants you `User Access Administrator` scoped to a resource group. That's a
legitimate, common real-world split (sandbox for hands-on learning, a
persistent subscription for the full CI/CD story), and it's a good one to be able
to explain plainly in an interview rather than glossing over.

## Known, documented security exceptions

- `modules/compute/main.tf` sets `disable_password_authentication = false` with an
  explicit `#checkov:skip` comment. This is intentional to demonstrate Key Vault
  secret retrieval end-to-end; the VM has no public IP and SSH is restricted to
  `admin_cidr` at the NSG layer as compensating controls. Production posture would
  switch to SSH key-based auth instead.

## Local development

```bash
terraform init
terraform fmt -recursive
terraform validate
checkov -d .
tfsec .
terraform plan -var-file=terraform.tfvars
```
