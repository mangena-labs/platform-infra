# modules/spoke-network/outputs.tf
output "vnet_id" { value = azurerm_virtual_network.spoke.id }
output "aks_subnet_id" { value = azurerm_subnet.aks.id }
output "private_endpoint_subnet_id" { value = azurerm_subnet.private_endpoints.id }
