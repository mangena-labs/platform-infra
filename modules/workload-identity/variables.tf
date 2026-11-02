# modules/workload-identity/variables.tf
variable "name" { type = string } # e.g. id-orders-api-prod
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "oidc_issuer_url" { type = string }
variable "namespace" { type = string }
variable "service_account" { type = string }
variable "tags" { type = map(string) }
