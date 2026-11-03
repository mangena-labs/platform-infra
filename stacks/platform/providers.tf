# stacks/platform/providers.tf
provider "azurerm" { # the environment's own subscription
  features {
    key_vault {
      purge_soft_delete_on_destroy = false # never permanently erase a vault
    }
  }
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  storage_use_azuread             = true
}

provider "azurerm" { # the Shared subscription (hub, DNS, ACR, Front Door)
  alias = "shared"
  features {}
  subscription_id                 = var.shared_subscription_id
  resource_provider_registrations = "none"
}
