variable "project_id" {
  description = "Customer GCP Project ID where Sentinel is deployed."
  type        = string
}

variable "region" {
  description = "GCP Region for Cloud Run, Firestore, and GCS."
  type        = string
  default     = "us-central1"
}

variable "sentinel_version" {
  description = "Sentinel release version."
  type        = string
  default     = "0.1.0" # x-release-please-version
}

variable "billing_account_id" {
  description = "Optional GCP Billing Account ID for budget guardrails."
  type        = string
  default     = null
}

variable "monthly_budget_amount_usd" {
  description = "Monthly spend guardrail in USD."
  type        = number
  default     = 250.0
}

variable "default_tenant_id" {
  description = "Default tenant workspace ID."
  type        = string
  default     = "default"
}

variable "default_webhook_secret" {
  description = "HMAC-SHA256 signing secret for incoming webhooks."
  type        = string
  sensitive   = true
  default     = "sec_replace_with_a_secure_random_string"
}

variable "vpc_network_name" {
  description = "VPC Network name or self-link for Direct VPC Egress."
  type        = string
}

variable "vpc_subnetwork_name" {
  description = "VPC Subnetwork name or self-link for Direct VPC Egress."
  type        = string
}
