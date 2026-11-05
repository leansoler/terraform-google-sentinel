# ==============================================================================
# Sentinel Google Cloud Monitoring & Alerting Policies (Runtime Module)
# ==============================================================================

# 1. Alert Policy: Cloud Run Job High Failure Rate
resource "google_monitoring_alert_policy" "agent_runner_failure_rate" {
  project      = var.project_id
  display_name = "Sentinel Agent Runner Job High Failure Rate"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Run Job execution failure rate > 20% in 5m"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_job\" AND metric.type = \"run.googleapis.com/job/completed_execution_count\" AND metric.labels.result = \"failed\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.20

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

# 2. Alert Policy: Control Plane High HTTP 5xx Error Rate
resource "google_monitoring_alert_policy" "control_plane_http_errors" {
  project      = var.project_id
  display_name = "Sentinel Control Plane HTTP 5xx Alert"
  combiner     = "OR"

  conditions {
    display_name = "Control Plane HTTP 5xx responses detected"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""
      duration        = "180s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5.0

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}
