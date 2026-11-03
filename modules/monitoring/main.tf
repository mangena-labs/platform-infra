# modules/monitoring/main.tf
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = var.tags
}

resource "azurerm_monitor_action_group" "oncall" {
  name                = "ag-${var.name}-oncall"
  resource_group_name = var.resource_group_name
  short_name          = "oncall"
  tags                = var.tags

  email_receiver {
    name                    = "oncall"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# Alert 1: customers are getting errors.
resource "azurerm_monitor_metric_alert" "failed_requests" {
  name                = "alert-failed-requests-${var.name}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "More than 25 failed requests in 5 minutes"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 25
  }

  action {
    action_group_id = azurerm_monitor_action_group.oncall.id
  }
}

# Alert 2: the API is slow.
resource "azurerm_monitor_metric_alert" "slow_requests" {
  name                = "alert-slow-requests-${var.name}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Average response time above 1 second for 10 minutes"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 1000 # milliseconds
  }

  action {
    action_group_id = azurerm_monitor_action_group.oncall.id
  }
}

# Alert 3: pods keep crashing (reads Container Insights data with a KQL query).
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "pod_restarts" {
  name                 = "alert-pod-restarts-${var.name}"
  resource_group_name  = var.resource_group_name
  location             = var.location
  scopes               = [azurerm_log_analytics_workspace.main.id]
  description          = "A pod in the orders namespace restarted more than 3 times"
  severity             = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"
  tags                 = var.tags

  criteria {
    query                   = <<-KQL
      KubePodInventory
      | where Namespace == "orders"
      | summarize Restarts = max(PodRestartCount) by Name
      | where Restarts > 3
    KQL
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0
  }

  action {
    action_groups = [azurerm_monitor_action_group.oncall.id]
  }
}
