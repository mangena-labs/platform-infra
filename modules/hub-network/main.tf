# modules/hub-network/main.tf
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags                = var.tags
}

# The subnet GitHub's runners plug into. It is "delegated": handed over to GitHub's service.
resource "azurerm_subnet" "runners" {
  name                 = "snet-github-runners"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.runner_subnet_prefix]

  delegation {
    name = "github-network-settings"
    service_delegation {
      name    = "GitHub.Network/networkSettings"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_network_security_group" "runners" {
  name                = "nsg-github-runners"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "runners" {
  subnet_id                 = azurerm_subnet.runners.id
  network_security_group_id = azurerm_network_security_group.runners.id
}

# New Azure networks have no automatic internet access, so runners get a NAT gateway
# (a fixed, shared exit to the internet) to reach GitHub, NuGet and registries.
resource "azurerm_public_ip" "nat" {
  name                = "pip-ng-hub-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_nat_gateway" "hub" {
  name                = "ng-hub-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "hub" {
  nat_gateway_id       = azurerm_nat_gateway.hub.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "runners" {
  subnet_id      = azurerm_subnet.runners.id
  nat_gateway_id = azurerm_nat_gateway.hub.id
}

# The Azure-side half of the GitHub link. GitHub reads its ID (GitHubId) in the manual step below.
resource "azapi_resource" "github_network_settings" {
  type                      = "GitHub.Network/networkSettings@2024-04-02"
  name                      = "ns-github-runners"
  parent_id                 = var.resource_group_id
  location                  = var.location
  schema_validation_enabled = false
  body = {
    properties = {
      businessId = var.github_business_id
      subnetId   = azurerm_subnet.runners.id
    }
  }
  response_export_values = ["tags"]
}
