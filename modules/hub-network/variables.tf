# modules/hub-network/variables.tf
variable "resource_group_name" { type = string }
variable "resource_group_id" { type = string }
variable "location" { type = string }
variable "name_suffix" { type = string }
variable "address_space" { type = list(string) }
variable "runner_subnet_prefix" { type = string }
variable "github_business_id" { type = string }
variable "tags" { type = map(string) }
