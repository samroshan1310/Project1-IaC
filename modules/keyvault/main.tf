resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_key_vault" "this" {
  #checkov:skip=CKV_AZURE_110:Purge Protection is a *prohibited* feature in the KodeKloud playground (must be disabled per their published service limits) -- a hard platform constraint, not a judgment call. Production deployments should set this true
  #checkov:skip=CKV_AZURE_42:Same root cause as CKV_AZURE_110 -- this check wants purge protection (or the recovery guarantee it provides) enabled, which the lab disallows. Soft delete at 7 days (the max allowed here) is the compensating control
  #checkov:skip=CKV2_AZURE_32:Private Endpoint for Key Vault is a genuine improvement deferred as a follow-up -- KodeKloud playgrounds do support Private DNS Zones so it's feasible, just out of scope for Project 1's first pass; IP-restricted network ACLs are the interim control
  name                = "kv-${var.project_name}-${random_string.kv_suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  # -------------------------------------------------------------------
  # Access-policy model instead of Azure RBAC.
  #
  # RBAC (enable_rbac_authorization = true) is the generally-recommended
  # model, but every grant under it is an azurerm_role_assignment, which
  # calls Microsoft.Authorization/roleAssignments/write. Sandbox/lab
  # subscriptions (e.g. KodeKloud playgrounds) typically grant users
  # Contributor only, which explicitly excludes that action -- by
  # design, so lab users can't self-escalate. Access policies are a
  # property update on the vault resource itself
  # (Microsoft.KeyVault/vaults/write), which Contributor does include,
  # so this model works in permission-restricted sandboxes without any
  # security trade-off on the vault's actual protection.
  # -------------------------------------------------------------------
  enable_rbac_authorization = false

  # Soft delete is required (min 7 days) by both good practice and the
  # KodeKloud playground's own rules. Purge protection, however, is a
  # *prohibited* feature in the playground -- it must be disabled, so
  # unlike soft delete this is a hard platform constraint, not a
  # judgment call. Production deployments outside the sandbox should
  # set purge_protection_enabled = true.
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [var.private_subnet_id]

    # Service endpoints only cover traffic that originates INSIDE the
    # VNet's private subnet -- they don't help a local `terraform
    # apply` running on your own machine, which is outside Azure
    # entirely. Without this, Terraform itself gets 403 ForbiddenByFirewall
    # trying to write the secret below. ip_rules takes CIDR notation,
    # so admin_cidr (already used for the VM's NSG rule) works directly.
    ip_rules = [var.admin_cidr]
  }

  tags = var.tags
}

# Grants the operator running Terraform (you, via az login) permission
# to write/read secrets. This replaces the old SP-based role assignment.
resource "azurerm_key_vault_access_policy" "admin" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = var.tenant_id
  object_id    = var.admin_object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "vm-admin-password"
  value        = var.vm_admin_password
  key_vault_id = azurerm_key_vault.this.id

  # A label for what the secret contains -- not the actual value's
  # format, just metadata other engineers (or you, in six months) can
  # read without opening the secret itself.
  content_type = "text/plain; purpose=vm-admin-password"

  # A static date rather than timeadd(timestamp(), ...) -- using the
  # live timestamp() function here would make Terraform show a diff
  # on every single plan/apply forever, since the "current time" never
  # matches what's in state. Bump this manually on rotation instead.
  expiration_date = var.secret_expiration_date

  depends_on = [azurerm_key_vault_access_policy.admin]
}
