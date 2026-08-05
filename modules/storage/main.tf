resource "random_string" "sa_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "this" {
  #checkov:skip=CKV_AZURE_59:Public network access must stay enabled -- Terraform runs from outside the VNet and needs to reach this account to create the container below; the IP allowlist in network_rules is the compensating control in place of disabling public access outright
  #checkov:skip=CKV_AZURE_33:Queue service isn't used anywhere in this project -- no containers, secrets, or app config reference Azure Queues, so logging for a service with zero traffic adds no value
  #checkov:skip=CKV2_AZURE_40:Disabling shared key auth requires Azure AD data-plane auth via a Storage Blob Data Contributor role assignment, which needs Microsoft.Authorization/roleAssignments/write -- excluded by Contributor-only KodeKloud playground sessions
  #checkov:skip=CKV2_AZURE_33:Private Endpoint for Storage deferred as a follow-up -- see the identical note on the Key Vault module
  #checkov:skip=CKV2_AZURE_1:Customer-managed key encryption needs this account's managed identity granted a Key Vault Crypto Service Encryption User role -- another role assignment blocked by the same Contributor-only constraint as above
  name                = "st${var.project_name}${random_string.sa_suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name

  account_tier = "Standard"

  # RAGRS instead of LRS: still within KodeKloud's allowed SKU list
  # (Standard_LRS, Standard_RAGRS -- GRS itself is not permitted), and
  # it satisfies CKV_AZURE_206's replication check by giving read
  # access to a geo-replicated secondary region, which plain LRS does
  # not.
  account_replication_type = "RAGRS"

  # Hardening: HTTPS-only, TLS 1.2 minimum, no public blob/container
  # access, no shared key access for apps that support Azure AD auth.
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true # see CKV2_AZURE_40 skip note above

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [var.private_subnet_id]

    # Same reasoning as the Key Vault module: service endpoints only
    # cover traffic from inside the VNet, not your local machine
    # running Terraform. Storage account IP rules want a bare IPv4
    # address rather than CIDR notation, so strip the /32 mask.
    ip_rules = [split("/", var.admin_cidr)[0]]
  }

  # Blob-level soft delete -- lets you recover an accidentally deleted
  # blob within the retention window. Fixes CKV2_AZURE_38.
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  # Time-limited SAS tokens: any SAS issued against this account stops
  # working after the configured period, capping the blast radius of a
  # leaked token. "Log" just audits tokens issued past the period
  # rather than hard-blocking them -- switch to "Log, Deny" for a harder
  # enforcement once you've confirmed nothing legitimately needs
  # longer-lived tokens. Fixes CKV2_AZURE_41.
  sas_policy {
    expiration_period = "01.00:00:00" # 1 day, format is DD.HH:MM:SS
    expiration_action = "Log"
  }

  tags = var.tags
}

resource "azurerm_storage_container" "app_data" {
  #checkov:skip=CKV2_AZURE_21:Blob read-request logging needs a Log Analytics Workspace + Diagnostic Setting -- monitoring/SRE scope (a later project in this series), not infra-provisioning scope, so deferred rather than bolted on here. Same reasoning as the identical skip on the parent storage account.
  name                  = "app-data"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}
