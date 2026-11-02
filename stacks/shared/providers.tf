# providers.tf
provider "azurerm" {
  features {}
  subscription_id                 = var.shared_subscription_id
  resource_provider_registrations = "none" # done once in bootstrap
  storage_use_azuread             = true
}

provider "azapi" {}
