# modules/hub-network/versions.tf: modules state what they need; the stack configures it.
# Every module has a file like this (tflint's recommended rules require the version lines).
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.70, < 5.0" }
    azapi   = { source = "azure/azapi", version = ">= 2.0, < 3.0" }
  }
}
