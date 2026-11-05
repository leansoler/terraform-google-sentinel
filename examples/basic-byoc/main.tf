# ==============================================================================
# Example: Turnkey Basic BYOC Deployment
# ==============================================================================
# In your own repository, replace `source = "../.."` with:
#   source  = "leansoler/sentinel/google"
#   version = "~> 0.1"
# ==============================================================================

module "sentinel" {
  source = "../.."

  project_id                = var.project_id
  region                    = var.region
  sentinel_version          = var.sentinel_version
  monthly_budget_amount_usd = var.monthly_budget_amount_usd
  default_webhook_secret    = var.default_webhook_secret
  enable_dashboard          = var.enable_dashboard
}
