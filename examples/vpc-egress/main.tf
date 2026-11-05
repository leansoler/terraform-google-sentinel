# ==============================================================================
# Example: BYOC Deployment with Direct VPC Egress (Private VPC Staging)
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
  billing_account_id        = var.billing_account_id
  monthly_budget_amount_usd = var.monthly_budget_amount_usd
  default_tenant_id         = var.default_tenant_id
  default_webhook_secret    = var.default_webhook_secret

  # Connect Cloud Run & Agent Runner directly to private VPC subnet:
  vpc_network_name    = var.vpc_network_name
  vpc_subnetwork_name = var.vpc_subnetwork_name
}
