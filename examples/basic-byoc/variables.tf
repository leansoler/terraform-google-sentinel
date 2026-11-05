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
  description = "Sentinel release version (automatically selects matching Artifact Registry images)."
  type        = string
  default     = "0.1.0"
}

variable "monthly_budget_amount_usd" {
  description = "Monthly spend guardrail in USD."
  type        = number
  default     = 100.0
}

variable "default_webhook_secret" {
  description = "HMAC-SHA256 signing secret for incoming GitHub/Jira webhooks."
  type        = string
  sensitive   = true
  default     = "sec_replace_with_a_secure_random_string"
}

variable "enable_dashboard" {
  description = "Enable the embedded /dashboard UI on Control Plane."
  type        = bool
  default     = true
}
