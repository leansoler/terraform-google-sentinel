# ==============================================================================
# Sentinel Runtime Module — Output Definitions
# ==============================================================================

output "control_plane_url" {
  description = "Public HTTPS URI of the Sentinel Control Plane Cloud Run service."
  value       = google_cloud_run_v2_service.control_plane.uri
}

output "agent_runner_job_name" {
  description = "Name of the provisioned Cloud Run Job for browser agent workers."
  value       = google_cloud_run_v2_job.agent_runner.name
}

output "artifacts_bucket_name" {
  description = "Name of the provisioned GCS bucket with 7d/30d retention lifecycle policies."
  value       = google_storage_bucket.artifacts.name
}

output "budget_alerts_pubsub_topic" {
  description = "Pub/Sub topic ID receiving Cloud Billing Budget alerts at 50%, 80%, and 100%."
  value       = google_pubsub_topic.budget_alerts.id
}

output "control_plane_service_account_email" {
  description = "Email of the Sentinel Control Plane service account."
  value       = google_service_account.control_plane_sa.email
}

output "agent_runner_service_account_email" {
  description = "Email of the Sentinel Agent Runner service account."
  value       = google_service_account.agent_runner_sa.email
}

output "sentinel_version" {
  description = "Sentinel component release version deployed in this environment."
  value       = var.sentinel_version
}

output "control_plane_image" {
  description = "Resolved container image URI deployed for the Sentinel Control Plane service."
  value       = local.effective_control_plane_image
}

output "agent_runner_image" {
  description = "Resolved container image URI deployed for the Sentinel Agent Runner job."
  value       = local.effective_agent_runner_image
}
