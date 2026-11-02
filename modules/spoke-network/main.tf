# modules/spoke-network/main.tf
resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.address_space, 6, 0)] # x.x.0.0/22 (1,000+ node addresses)
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-pe"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.address_space, 8, 8)] # x.x.8.0/24
}

# Peering is two one-way links: spoke → hub, and hub → spoke.
resource "azurerm_virtual_network_peering" "to_hub" {
  count                        = var.hub_peering_enabled ? 1 : 0
  name                         = "peer-${var.name}-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "from_hub" {
  count                        = var.hub_peering_enabled ? 1 : 0
  provider                     = azurerm.shared
  name                         = "peer-hub-to-${var.name}"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# Link this network to the shared private DNS zones.
resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  provider              = azurerm.shared
  for_each              = toset(var.private_dns_zone_names)
  name                  = "link-${var.name}"
  resource_group_name   = var.dns_resource_group_name
  private_dns_zone_name = each.key
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
}
