# environments/dev/platform.tfvars
environment               = "dev"
short_code                = "dev"
vnet_cidr                 = "10.10.0.0/16"
kubernetes_version        = "1.36"
aks_sku_tier              = "Free"
system_vm_size            = "Standard_B2ms" # learning profile: small and cheap (full design: default D4ds_v5)
user_vm_size              = "Standard_B2ms"
aks_zones                 = [] # learning profile: B2ms has no zones in South Africa North on this subscription (full design: ["1", "2", "3"])
system_min_count          = 1
system_max_count          = 2
user_min_count            = 1
user_max_count            = 3
sql_sku_name              = "GP_S_Gen5_1"
sql_zone_redundant        = false
sql_long_term_retention   = false
sql_admin_group_object_id = "ef0d78c9-2bca-43c2-a09e-4fae107deea8"
log_retention_days        = 30
alert_email               = "mangenaashelly14@gmail.com"
pod_security_effect       = "audit"
tags = {
  owner       = "orders-team"
  cost_center = "CC-1042"
}
