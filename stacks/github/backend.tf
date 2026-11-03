# stacks/github/backend.tf
terraform {
  backend "azurerm" {
    subscription_id      = "f8527497-4ad7-4f18-bce9-718323915256"
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stmangenatfstate01"
    container_name       = "tfstate"
    key                  = "github.tfstate"
    use_azuread_auth     = true
  }
}
