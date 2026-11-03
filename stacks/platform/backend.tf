# stacks/platform/backend.tf: deliberately empty; each environment's backend.hcl fills it in
terraform {
  backend "azurerm" {}
}
