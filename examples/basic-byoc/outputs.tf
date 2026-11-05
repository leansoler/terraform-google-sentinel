output "control_plane_url" {
  description = "Public HTTPS URL of the Sentinel Control Plane."
  value       = module.sentinel.control_plane_url
}

output "artifacts_bucket_name" {
  description = "GCS bucket storing Playwright traces, videos, and screenshots."
  value       = module.sentinel.artifacts_bucket_name
}
