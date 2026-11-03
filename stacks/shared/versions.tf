# stacks/shared/versions.tf
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.70" } # any 4.x from 4.70; never 5.x by surprise
    azapi   = { source = "azure/azapi", version = "~> 2.0" }
  }
}
