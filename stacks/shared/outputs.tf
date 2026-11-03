output "private_networking" { value = var.private_networking }
output "hub_vnet_id" { value = try(module.hub_network[0].vnet_id, "") }
output "hub_vnet_name" { value = try(module.hub_network[0].vnet_name, "") }
output "hub_resource_group_name" { value = try(azurerm_resource_group.hub[0].name, "") }
output "private_dns_zone_ids" { value = { for k, z in azurerm_private_dns_zone.zones : k => z.id } }
output "dns_resource_group_name" { value = azurerm_resource_group.dns.name }
output "dns_zone_name" { value = azurerm_dns_zone.public.name }
output "dns_zone_id" { value = azurerm_dns_zone.public.id }
output "dns_name_servers" { value = azurerm_dns_zone.public.name_servers }
output "acr_id" { value = azurerm_container_registry.shared.id }
output "acr_login_server" { value = azurerm_container_registry.shared.login_server }
output "front_door_enabled" { value = var.front_door_enabled }
output "frontdoor_profile_id" { value = try(azurerm_cdn_frontdoor_profile.main[0].id, "") }
output "frontdoor_id" { value = try(azurerm_cdn_frontdoor_profile.main[0].resource_guid, "") }
output "waf_policy_id" { value = try(azurerm_cdn_frontdoor_firewall_policy.main[0].id, "") }
output "github_network_settings_id" { value = try(module.hub_network[0].github_network_settings_id, "") }
