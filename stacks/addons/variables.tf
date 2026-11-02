# stacks/addons/variables.tf
variable "environment" { type = string }
variable "subscription_id" { type = string }        # from the pipeline
variable "shared_subscription_id" { type = string } # from the pipeline
variable "envoy_gateway_version" { type = string }
variable "cert_manager_version" { type = string }
variable "envoy_replicas" { type = number }
variable "acme_email" { type = string }
variable "orders_quota" {
  type = object({
    requests_cpu    = string
    requests_memory = string
    limits_memory   = string
    pods            = number
  })
}
