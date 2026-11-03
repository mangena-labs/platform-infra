# modules/monitoring/variables.tf
variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "alert_email" { type = string }
variable "retention_days" { type = number }
variable "tags" { type = map(string) }
