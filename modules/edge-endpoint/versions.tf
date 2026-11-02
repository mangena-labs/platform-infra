# modules/edge-endpoint/versions.tf: modules state what they need; the stack configures it.
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.70, < 5.0" }
  }
}
