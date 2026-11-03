# stacks/platform/variables.tf
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}
variable "short_code" { type = string }             # dev / stg / prd
variable "subscription_id" { type = string }        # from the pipeline (TF_VAR_…)
variable "shared_subscription_id" { type = string } # from the pipeline
variable "tenant_id" { type = string }              # from the pipeline
variable "location" {
  type    = string
  default = "southafricanorth"
}
variable "name_suffix" {
  type    = string
  default = "san"
}
variable "vnet_cidr" { type = string }
variable "kubernetes_version" { type = string }
variable "aks_sku_tier" { type = string }
variable "system_vm_size" {
  type    = string
  default = "Standard_D4ds_v5"
}
variable "aks_zones" {
  type    = list(string)
  default = ["1", "2", "3"] # learning profile: [] in dev/staging tfvars
}
variable "system_min_count" { type = number }
variable "system_max_count" { type = number }
variable "user_vm_size" {
  type    = string
  default = "Standard_D4ds_v5"
}
variable "user_min_count" { type = number }
variable "user_max_count" { type = number }
variable "sql_sku_name" { type = string }
variable "sql_zone_redundant" { type = bool }
variable "sql_long_term_retention" { type = bool }
variable "sql_admin_group_object_id" { type = string }
variable "log_retention_days" { type = number }
variable "alert_email" { type = string }
variable "pod_security_effect" {
  type = string
  validation {
    condition     = contains(["audit", "deny"], var.pod_security_effect)
    error_message = "pod_security_effect must be audit or deny."
  }
}
variable "aks_reader_group_object_id" {
  type    = string
  default = "" # optional: an Entra group of engineers who may VIEW the cluster
}
variable "tags" {
  type    = map(string)
  default = {}
}
