# modules/spoke-network/versions.tf
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = ">= 4.70, < 5.14"
      configuration_aliases = [azurerm.shared] # the caller must hand over a Shared-subscription provider
    }
  }
}
