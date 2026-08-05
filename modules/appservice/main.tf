resource "azurerm_service_plan" "this" {
  #checkov:skip=CKV_AZURE_225:Zone redundancy needs a Premium (v2/v3) App Service Plan tier; the KodeKloud playground only permits Free (F1) and Basic (B1) SKUs, so this is unreachable here -- would use Premium in a real subscription
  #checkov:skip=CKV_AZURE_211:This check requires Standard tier or higher; same platform constraint as above, the playground only allows F1/B1
  name                = "asp-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "B1"

  # B1 (Basic) supports up to 3 instances -- 2 gives basic failover
  # coverage without needing Standard/Premium tier or Autoscale (which
  # itself requires Standard+). Fixes CKV_AZURE_212.
  worker_count = 2

  tags = var.tags
}

resource "azurerm_linux_web_app" "this" {
  #checkov:skip=CKV_AZURE_13:App Service Authentication (Easy Auth) needs a registered Azure AD app as an identity provider -- an application-layer concern tied to real app code, not something this infra-only project can meaningfully configure yet
  #checkov:skip=CKV_AZURE_222:This App Service is intentionally the public-facing web tier by design (see README architecture diagram) -- disabling public network access would defeat exposing it via the public subnet/firewall/WAF chain
  #checkov:skip=CKV_AZURE_88:No persistent file storage requirement for this stateless web app -- Azure Files would be added only if/when the app needs a shared writable filesystem
  name                = "app-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.this.id
  tags                = var.tags

  https_only = true

  # These are top-level arguments on azurerm_linux_web_app, NOT nested
  # inside site_config -- an earlier version of this file had them
  # misplaced inside site_config, where Terraform's schema silently
  # doesn't recognize them in that position and Checkov's static check
  # (CKV_AZURE_17) correctly flagged them as effectively unset.
  client_certificate_enabled = true
  client_certificate_mode    = "Optional"

  # System-assigned managed identity lets the app authenticate to Key
  # Vault / Storage without any credential stored in app settings.
  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"

    # B1 tier supports always_on; Free (F1) does not -- if you ever
    # drop to F1 for cost reasons, remove this line first or apply
    # will fail.
    always_on = true

    http2_enabled = true

    # Assumes the app exposes a lightweight /health route returning
    # 200 OK -- update this path once real application code exists.
    health_check_path = "/health"

    application_stack {
      # Swap for your actual runtime, e.g. node_version = "20-lts"
      python_version = "3.11"
    }
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }
}
