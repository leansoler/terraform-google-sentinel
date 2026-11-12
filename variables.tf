# ==============================================================================
# Sentinel Runtime Module — Variable Definitions
# ==============================================================================
# Official HashiCorp Terraform Registry Module: leansoler/sentinel/google
# ==============================================================================

variable "project_id" {
  description = "The GCP Project ID where Sentinel runtime resources are provisioned."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Invalid project_id: must be a valid GCP Project ID (6-30 lowercase letters, digits, or hyphens, starting with a letter)."
  }
}

variable "region" {
  description = "The GCP Region for Cloud Run, Cloud Run Jobs, Firestore, and GCS."
  type        = string
  default     = "us-central1"
}

variable "billing_account_id" {
  description = "The GCP Billing Account ID for Cloud Billing Budget guardrails. Optional if budget alerts are not managed via this stack."
  type        = string
  default     = null
}

variable "monthly_budget_amount_usd" {
  description = "Monthly maximum spend cap in USD for Sentinel GCP resources."
  type        = number
  default     = 100.0

  validation {
    condition     = var.monthly_budget_amount_usd > 0
    error_message = "monthly_budget_amount_usd must be a positive number greater than 0."
  }
}

variable "sentinel_version" {
  description = "Sentinel release version string (e.g. 0.1.0). Automatically determines default Artifact Registry image tags when control_plane_image or agent_runner_image are omitted."
  type        = string
  default     = "0.1.0" # x-release-please-version
}

variable "control_plane_image" {
  description = "Optional container image URI override for @sentinel/control-plane service. Defaults to us-central1-docker.pkg.dev/sentinel-release/sentinel/control-plane:v<sentinel_version>. Note: Customer GCP project requires roles/artifactregistry.reader on Sentinel's Artifact Registry (via ./infra/scripts/manage-customer-access.sh grant <PROJECT_NUMBER>)."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.control_plane_image == null || can(regex("^[a-z0-9._/-]+(:[a-zA-Z0-9._-]+|@sha256:[a-f0-9]{64})?$", var.control_plane_image))
    error_message = "Invalid control_plane_image URI format. Ensure a valid OCI image reference is provided and that your GCP Cloud Run Service Agent has roles/artifactregistry.reader permissions (contact Sentinel support or run ./infra/scripts/manage-customer-access.sh grant <PROJECT_NUMBER>)."
  }
}

variable "agent_runner_image" {
  description = "Optional container image URI override for @sentinel/agent-runner Cloud Run Job. Defaults to us-central1-docker.pkg.dev/sentinel-release/sentinel/agent-runner:v<sentinel_version>. Note: Customer GCP project requires roles/artifactregistry.reader on Sentinel's Artifact Registry (via ./infra/scripts/manage-customer-access.sh grant <PROJECT_NUMBER>)."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.agent_runner_image == null || can(regex("^[a-z0-9._/-]+(:[a-zA-Z0-9._-]+|@sha256:[a-f0-9]{64})?$", var.agent_runner_image))
    error_message = "Invalid agent_runner_image URI format. Ensure a valid OCI image reference is provided and that your GCP Cloud Run Service Agent has roles/artifactregistry.reader permissions (contact Sentinel support or run ./infra/scripts/manage-customer-access.sh grant <PROJECT_NUMBER>)."
  }
}

variable "default_tenant_id" {
  description = "Default tenant identifier for single-tenant or default-tenant setups."
  type        = string
  default     = "default"
}

variable "default_webhook_secret" {
  description = "Default secret for validating GitHub/Jira HMAC-SHA256 signatures."
  type        = string
  sensitive   = true
  default     = "sentinel-webhook-default-secret"
}

variable "vpc_network_name" {
  description = "Optional VPC Network name for Direct VPC Egress (internal staging testing)."
  type        = string
  default     = null
}

variable "vpc_subnetwork_name" {
  description = "Optional VPC Subnetwork name for Direct VPC Egress."
  type        = string
  default     = null
}

variable "enable_dashboard" {
  description = "Whether to mount the in-band Sentinel Web Dashboard on the Control Plane Cloud Run service."
  type        = bool
  default     = true
}
