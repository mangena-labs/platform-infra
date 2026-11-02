# modules/hub-network/outputs.tf
output "vnet_id" { value = azurerm_virtual_network.hub.id }
output "vnet_name" { value = azurerm_virtual_network.hub.name }
output "github_network_settings_id" { value = azapi_resource.github_network_settings.output.tags.GitHubId }
