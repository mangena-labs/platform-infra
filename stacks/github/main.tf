# stacks/github/main.tf
locals {
  app_envs = var.environments

  # Status checks that must be green before a PR can merge (job names from the workflows).
  required_checks = {
    "platform-infra" = ["validate", "plan-gate"]
    "orders-api"     = ["build-test", "image", "analyze"]
  }

  # Infra repo environments: which need a human approval.
  infra_envs = merge(
    { "shared" = true, "github-settings" = true },
    { for env in var.environments : env => env == "prod" } # only prod's apply needs an approval
  )
}

data "github_team" "platform" { slug = "platform-team" }
data "github_team" "approvers" { slug = "orders-approvers" }

# ---------- 1. Protect main in both repos ----------
resource "github_repository_ruleset" "main" {
  for_each    = local.required_checks
  name        = "protect-main"
  repository  = each.key
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion                = true # main can't be deleted
    non_fast_forward        = true # no force-push
    required_linear_history = true # squash or rebase merges only
    required_signatures     = true # commits must be signed

    pull_request {
      required_approving_review_count   = 1
      require_code_owner_review         = true # CODEOWNERS must approve their areas
      dismiss_stale_reviews_on_push     = true # new commits need a fresh approval
      require_last_push_approval        = true
      required_review_thread_resolution = true
    }

    required_status_checks {
      strict_required_status_checks_policy = true # branch must be up to date with main
      dynamic "required_check" {
        for_each = each.value
        content {
          context = required_check.value
        }
      }
    }
  }
}

# ---------- 2. Environments with approvals ----------
resource "github_repository_environment" "infra" {
  for_each            = local.infra_envs
  repository          = "platform-infra"
  environment         = each.key
  prevent_self_review = true

  dynamic "reviewers" {
    for_each = each.value ? [1] : []
    content {
      teams = [data.github_team.platform.id]
    }
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true # only the branch listed below (main) can use these environments
  }
}

resource "github_repository_environment" "app" {
  for_each            = toset(local.app_envs)
  repository          = "orders-api"
  environment         = each.key
  prevent_self_review = true

  dynamic "reviewers" {
    for_each = each.key == "prod" ? [1] : []
    content {
      teams = [data.github_team.approvers.id]
    }
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

# Only main may deploy to these environments, matching the OIDC subjects Azure trusts.
resource "github_repository_environment_deployment_policy" "infra_main" {
  for_each       = local.infra_envs
  repository     = "platform-infra"
  environment    = github_repository_environment.infra[each.key].environment
  branch_pattern = "main"
}

resource "github_repository_environment_deployment_policy" "app_main" {
  for_each       = toset(local.app_envs)
  repository     = "orders-api"
  environment    = github_repository_environment.app[each.key].environment
  branch_pattern = "main"
}

resource "github_repository_dependabot_security_updates" "all" {
  for_each   = local.required_checks
  repository = each.key
  enabled    = true
}

# ---------- 3. Publish platform values to the app's environments ----------
data "terraform_remote_state" "platform" {
  for_each = var.publish_app_variables ? toset(local.app_envs) : toset([])
  backend  = "azurerm"
  config = {
    subscription_id      = var.shared_subscription_id
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stmangenatfstate01"
    container_name       = "tfstate"
    key                  = "${each.key}/platform.tfstate"
    use_azuread_auth     = true
  }
}

data "azurerm_user_assigned_identity" "deploy" {
  for_each            = toset(local.app_envs)
  name                = "id-gh-deploy-${each.key}"
  resource_group_name = "rg-identities"
}

locals {
  app_var_values = {
    for env, s in data.terraform_remote_state.platform : env => {
      AZURE_SUBSCRIPTION_ID     = s.outputs.subscription_id
      DEPLOY_CLIENT_ID          = data.azurerm_user_assigned_identity.deploy[env].client_id
      AKS_NAME                  = s.outputs.aks_name
      AKS_RESOURCE_GROUP        = s.outputs.resource_group_name
      API_HOST                  = s.outputs.api_host
      ORIGIN_HOST               = s.outputs.origin_host
      ORDERS_API_CLIENT_ID      = s.outputs.api_client_id
      ORDERS_MIGRATOR_CLIENT_ID = s.outputs.migrator_client_id
      FRONT_DOOR_ID             = s.outputs.frontdoor_id
      KEY_VAULT_URI             = s.outputs.key_vault_uri
      SQL_SERVER_FQDN           = s.outputs.sql_server_fqdn
      SQL_DATABASE              = s.outputs.sql_database_name
    }
  }

  # Flatten to one entry per variable: "prod/AKS_NAME" = { env, name, value }
  app_vars = merge({}, [
    for env, vars in local.app_var_values : {
      for name, value in vars : "${env}/${name}" => { env = env, name = name, value = value }
      if value != "" # GitHub rejects empty variables (FRONT_DOOR_ID when there's no Front Door)
    }
  ]...)
}

resource "github_actions_environment_variable" "app" {
  for_each      = local.app_vars
  repository    = "orders-api"
  environment   = github_repository_environment.app[each.value.env].environment
  variable_name = each.value.name
  value         = each.value.value
}
