# modules/aks/variables.tf
variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "kubernetes_version" { type = string }
variable "sku_tier" { type = string }      # Free or Standard
variable "private_cluster" { type = bool } # false in the learning profile
variable "subnet_id" { type = string }
variable "system_vm_size" { type = string }
variable "system_min_count" { type = number }
variable "system_max_count" { type = number }
variable "user_vm_size" { type = string }
variable "user_min_count" { type = number }
variable "user_max_count" { type = number }
variable "log_analytics_workspace_id" { type = string }
variable "tags" { type = map(string) }
