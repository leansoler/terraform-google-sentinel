output "control_plane_url" {
  description = "Public HTTPS URL of the Sentinel Control Plane."
  value       = module.sentinel.control_plane_url
}

output "agent_runner_job_name" {
  description = "Name of the Cloud Run Job configured with Direct VPC Egress."
  value       = module.sentinel.agent_runner_job_name
}
