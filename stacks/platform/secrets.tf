# stacks/platform/secrets.tf: secrets are generated, never typed by a person
resource "random_password" "webhook_signing_key" {
  length  = 64
  special = false
}

# tflint-ignore: azurerm_resources_missing_prevent_destroy # Terraform recreates the value; Key Vault purge protection keeps deleted versions for 90 days
resource "azurerm_key_vault_secret" "webhook_signing_key" {
  name         = "Webhooks--SigningKey" # becomes config key Webhooks:SigningKey in .NET
  value        = random_password.webhook_signing_key.result
  key_vault_id = module.keyvault.id
  content_type = "text/plain"
  depends_on   = [time_sleep.rbac_propagation]
}

# tflint-ignore: azurerm_resources_missing_prevent_destroy # Terraform recreates the value; Key Vault purge protection keeps deleted versions for 90 days
resource "azurerm_key_vault_secret" "app_insights" {
  name         = "AzureMonitor--ConnectionString" # read by the Azure Monitor OpenTelemetry package
  value        = module.monitoring.app_insights_connection_string
  key_vault_id = module.keyvault.id
  content_type = "text/plain"
  depends_on   = [time_sleep.rbac_propagation]
}
