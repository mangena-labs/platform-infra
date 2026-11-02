# stacks/addons/main.tf
data "terraform_remote_state" "platform" {
  backend = "azurerm"
  config = {
    subscription_id      = var.shared_subscription_id
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stmangenatfstate01"
    container_name       = "tfstate"
    key                  = "${var.environment}/platform.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  p = data.terraform_remote_state.platform.outputs
}

provider "azurerm" {
  features {}
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}

data "azurerm_kubernetes_cluster" "this" {
  name                = local.p.aks_name
  resource_group_name = local.p.resource_group_name
}

# Helm talks to the cluster's API server: public with Entra-only login in the learning profile,
# private in the full design (reached from the hub runners)
# and logs in with an Entra token from kubelogin, using the pipeline's Azure login.
provider "helm" {
  kubernetes = {
    host                   = "https://${coalesce(data.azurerm_kubernetes_cluster.this.fqdn, data.azurerm_kubernetes_cluster.this.private_fqdn)}:443"
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      # 6dae42f8-… is the fixed ID of AKS's Entra login application.
      args = ["get-token", "--login", "azurecli", "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"]
    }
  }
}

# 1. Envoy Gateway (also installs the Gateway API resource types)
resource "helm_release" "envoy_gateway" {
  name             = "eg"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  version          = var.envoy_gateway_version
  namespace        = "envoy-gateway-system"
  create_namespace = true
  atomic           = true # if install fails, undo it
  wait             = true
  timeout          = 600
  values = [yamlencode({
    deployment = { replicas = 2 } # two copies of the controller
  })]
}

# 2. cert-manager, using Workload Identity to write DNS records in Azure DNS
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true
  atomic           = true
  wait             = true
  timeout          = 600
  values = [yamlencode({
    crds      = { enabled = true }
    podLabels = { "azure.workload.identity/use" = "true" }
    serviceAccount = {
      labels      = { "azure.workload.identity/use" = "true" }
      annotations = { "azure.workload.identity/client-id" = local.p.cert_manager_client_id }
    }
    config = {
      apiVersion       = "controller.config.cert-manager.io/v1alpha1"
      kind             = "ControllerConfiguration"
      enableGatewayAPI = true # issue certificates for Gateways automatically
    }
  })]
  depends_on = [helm_release.envoy_gateway] # Gateway API types must exist first
}

# 3. Our own platform configuration chart
resource "helm_release" "platform_config" {
  name      = "platform-config"
  chart     = "../../charts/platform-config"
  namespace = "envoy-gateway-system"
  atomic    = true
  wait      = true
  values = [yamlencode({
    originHost    = local.p.origin_host
    frontDoorOnly = try(local.p.front_door_enabled, true) # false in the learning profile
    gateway = {
      replicas      = var.envoy_replicas
      publicIpName  = local.p.gateway_public_ip_name
      resourceGroup = local.p.resource_group_name
    }
    acme = { email = var.acme_email }
    dns = {
      zoneName       = local.p.dns_zone_name
      resourceGroup  = local.p.dns_resource_group
      subscriptionId = var.shared_subscription_id
    }
    certManager = { clientId = local.p.cert_manager_client_id }
    appNamespaces = [{
      name  = "orders"
      quota = var.orders_quota
    }]
  })]
  depends_on = [helm_release.cert_manager] # the ClusterIssuer type must exist first
}
