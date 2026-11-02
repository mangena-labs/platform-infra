# modules/aks/main.tf
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  node_resource_group = "rg-${var.name}-nodes" # where AKS puts its VMs and disks
  dns_prefix          = "aks-${var.name}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  # Upgrades: patches applied automatically, but only in the maintenance windows below.
  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  # Security: private API server, Entra-only logins, passwordless workloads.
  private_cluster_enabled             = var.private_cluster # learning profile: false = public API, Entra login only
  private_cluster_public_fqdn_enabled = var.private_cluster # private: the name resolves publicly to a PRIVATE address
  local_account_disabled              = true
  oidc_issuer_enabled                 = true
  workload_identity_enabled           = true
  azure_policy_enabled                = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = var.tenant_id
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_vm_size
    vnet_subnet_id               = var.subnet_id
    zones                        = ["1", "2", "3"]
    auto_scaling_enabled         = true
    min_count                    = var.system_min_count
    max_count                    = var.system_max_count
    only_critical_addons_enabled = true # taints the pool so app pods stay off it
    temporary_name_for_rotation  = "systemtmp"
    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "172.16.0.0/16"
    dns_service_ip      = "172.16.0.10"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  workload_autoscaler_profile {
    keda_enabled = true # ready for queue-driven workers later
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+02:00"
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+02:00"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [default_node_pool[0].node_count] # the autoscaler owns this
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  mode                  = "User"
  vm_size               = var.user_vm_size
  vnet_subnet_id        = var.subnet_id
  zones                 = ["1", "2", "3"]
  auto_scaling_enabled  = true
  min_count             = var.user_min_count
  max_count             = var.user_max_count
  node_labels           = { workload = "apps" }
  tags                  = var.tags

  upgrade_settings {
    max_surge = "33%"
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

# Container Insights with managed identity needs a data collection rule.
resource "azurerm_monitor_data_collection_rule" "container_insights" {
  name                = "MSCI-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  destinations {
    log_analytics {
      workspace_resource_id = var.log_analytics_workspace_id
      name                  = "ciworkspace"
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerInsights-Group-Default"]
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = ["Microsoft-ContainerInsights-Group-Default"]
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Off"
          enableContainerLogV2   = true
        }
      })
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "container_insights" {
  name                    = "ContainerInsightsExtension"
  target_resource_id      = azurerm_kubernetes_cluster.main.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.container_insights.id
}
