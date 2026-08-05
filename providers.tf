terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    random  = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # -----------------------------------------------------------------------
  # Remote state backend -- azurerm, using PARTIAL configuration.
  #
  # Values are intentionally left blank here and supplied at `terraform
  # init` time via -backend-config flags (or a gitignored backend.hcl
  # file). Two reasons this has to work this way in this environment:
  #
  #   1. The storage account backing this state must exist BEFORE
  #      `terraform init` runs -- Terraform can't use a resource from
  #      its own config as its own backend (chicken-and-egg). It has to
  #      be created manually via Azure CLI first (see README).
  #   2. KodeKloud playgrounds don't allow creating additional resource
  #      groups, so the state storage account has to live in your one
  #      existing playground RG -- whose name changes every session --
  #      rather than a fixed "rg-tfstate" group.
  # -----------------------------------------------------------------------
  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  # -----------------------------------------------------------------------
  # By default the azurerm provider tries to auto-register every resource
  # provider it knows about (dozens -- BotService, Databricks, HealthcareApis,
  # etc., almost all unrelated to this project). Provider registration
  # (Microsoft.X/register/action) is a subscription-level admin operation
  # that Contributor-only playground sessions don't include, so it fails
  # the moment `plan` or `apply` tries to run it.
  #
  # Setting this to `true` skips that step entirely. It's safe here
  # because the providers this project actually needs (Microsoft.Network,
  # Microsoft.Compute, Microsoft.Storage, Microsoft.KeyVault, Microsoft.Web)
  # come pre-registered on essentially every Azure subscription, including
  # KodeKloud playgrounds, by default.
  # -----------------------------------------------------------------------
  skip_provider_registration = true
}
