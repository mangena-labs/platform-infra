# modules/workload-identity/outputs.tf
output "name" { value = azurerm_user_assigned_identity.this.name }
output "client_id" { value = azurerm_user_assigned_identity.this.client_id }
output "principal_id" { value = azurerm_user_assigned_identity.this.principal_id }
