# environments/dev/addons.tfvars
environment           = "dev"
envoy_gateway_version = "v1.9.3"  # pin the current 1.x release
cert_manager_version  = "v1.21.3" # pin the current supported release
envoy_replicas        = 1         # learning profile (full design: 2–3)
acme_email            = "mangenaashelly14@gmail.com"
orders_quota = {
  requests_cpu    = "2"
  requests_memory = "4Gi"
  limits_memory   = "8Gi"
  pods            = 20
}
