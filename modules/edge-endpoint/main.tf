# modules/edge-endpoint/main.tf
locals {
  api_fqdn    = "${var.api_label}.${var.dns_zone_name}"    # api.mangena.online
  origin_fqdn = "${var.origin_label}.${var.dns_zone_name}" # origin-prod.mangena.online
}

# origin-<env>.mangena.online → the cluster gateway's public IP
resource "azurerm_dns_a_record" "origin" {
  name                = var.origin_label
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_resource_group
  ttl                 = 300
  records             = [var.origin_ip]
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "fde-orders-${var.environment}"
  cdn_frontdoor_profile_id = var.frontdoor_profile_id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "main" {
  name                     = "og-orders-${var.environment}"
  cdn_frontdoor_profile_id = var.frontdoor_profile_id
  session_affinity_enabled = false

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }
  # No health_probe block: with a single origin, Microsoft recommends turning probes off.
}

resource "azurerm_cdn_frontdoor_origin" "main" {
  name                           = "origin-orders-${var.environment}"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.main.id
  enabled                        = true
  host_name                      = local.origin_fqdn
  origin_host_header             = local.origin_fqdn
  http_port                      = 80
  https_port                     = 443
  certificate_name_check_enabled = true # Front Door checks the origin's certificate is genuine
  priority                       = 1
  weight                         = 1000
}

resource "azurerm_cdn_frontdoor_custom_domain" "api" {
  name                     = "cd-${replace(local.api_fqdn, ".", "-")}"
  cdn_frontdoor_profile_id = var.frontdoor_profile_id
  dns_zone_id              = var.dns_zone_id
  host_name                = local.api_fqdn

  tls {
    certificate_type    = "ManagedCertificate" # Front Door gets and renews the public certificate
    minimum_tls_version = "TLS12"
  }
}

# Proves to Front Door that we own the domain.
resource "azurerm_dns_txt_record" "validation" {
  name                = "_dnsauth.${var.api_label}"
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_resource_group
  ttl                 = 3600
  tags                = var.tags

  record {
    value = azurerm_cdn_frontdoor_custom_domain.api.validation_token
  }
}

resource "azurerm_cdn_frontdoor_route" "main" {
  name                            = "route-orders-${var.environment}"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.main.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.main.id]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.api.id]
  link_to_default_domain          = false
  supported_protocols             = ["Http", "Https"]
  https_redirect_enabled          = true        # http:// is redirected to https://
  forwarding_protocol             = "HttpsOnly" # Front Door → cluster is always encrypted
  patterns_to_match               = ["/*"]
  # No cache block: API responses are never cached.
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "api" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.api.id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.main.id]
}

# api.mangena.online → this Front Door endpoint
resource "azurerm_dns_cname_record" "api" {
  name                = var.api_label
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_resource_group
  ttl                 = 3600
  record              = azurerm_cdn_frontdoor_endpoint.main.host_name
  tags                = var.tags
  depends_on          = [azurerm_cdn_frontdoor_route.main]
}

# Put the WAF in front of this domain.
resource "azurerm_cdn_frontdoor_security_policy" "main" {
  name                     = "sp-orders-${var.environment}"
  cdn_frontdoor_profile_id = var.frontdoor_profile_id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = var.waf_policy_id
      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.api.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}
