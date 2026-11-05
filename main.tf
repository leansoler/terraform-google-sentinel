# ==============================================================================
# Sentinel Serverless Platform Core Runtime Module
# ==============================================================================
# This module encapsulates the unified Sentinel runtime environment:
# - Scale-to-zero Cloud Run Control Plane service
# - Ephemeral Cloud Run Job Agent Runner (with optional Direct VPC Egress)
# - Native Cloud Firestore database with (default) schema
# - GCS Artifacts bucket with 7d PASS / 30d FAIL retention lifecycles
# - Secret Manager secret & accessors
# - Least-privilege IAM service accounts
# - Cloud Billing Budget alerts & Pub/Sub circuit-breaker integration
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Enable Required GCP APIs
# ------------------------------------------------------------------------------
locals {
  # Strip optional leading "v" so both "0.1.0" and "v0.1.0" resolve cleanly to ":v0.1.0"
  normalized_sentinel_version = trimprefix(var.sentinel_version, "v")

  # Default container images to Sentinel's official Google Artifact Registry when not overridden
  effective_control_plane_image = coalesce(
    var.control_plane_image,
    "us-central1-docker.pkg.dev/sentinel-release/sentinel/control-plane:v${local.normalized_sentinel_version}"
  )

  effective_agent_runner_image = coalesce(
    var.agent_runner_image,
    "us-central1-docker.pkg.dev/sentinel-release/sentinel/agent-runner:v${local.normalized_sentinel_version}"
  )

  required_gcp_services = [
    "run.googleapis.com",
    "firestore.googleapis.com",
    "secretmanager.googleapis.com",
    "aiplatform.googleapis.com",
    "pubsub.googleapis.com",
    "cloudbilling.googleapis.com"
  ]
}

resource "google_project_service" "enabled_services" {
  for_each           = toset(local.required_gcp_services)
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# ------------------------------------------------------------------------------
# 2. Random Suffix for Globally Unique Bucket Names
# ------------------------------------------------------------------------------
resource "random_id" "suffix" {
  byte_length = 4
}

# ------------------------------------------------------------------------------
# 3. Service Accounts & Least-Privilege IAM Roles
# ------------------------------------------------------------------------------

# Service Account for Sentinel Control Plane HTTP Service
resource "google_service_account" "control_plane_sa" {
  project      = var.project_id
  account_id   = "sentinel-control-plane-sa"
  display_name = "Sentinel Control Plane Service Account"
  description  = "Dedicated identity for @sentinel/control-plane Cloud Run service"
}

# Service Account for Sentinel Browser Agent Runner (Cloud Run Job)
resource "google_service_account" "agent_runner_sa" {
  project      = var.project_id
  account_id   = "sentinel-agent-runner-sa"
  display_name = "Sentinel Agent Runner Service Account"
  description  = "Dedicated identity for @sentinel/agent-runner Cloud Run Job"
}

# Control Plane permissions:
# - Firestore access for tenant/project configs and test run tracking
# - Cloud Run Developer to invoke run.jobs.run via REST
# - Secret Manager Secret Accessor for webhook & tracker tokens
resource "google_project_iam_member" "control_plane_datastore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.control_plane_sa.email}"
}

resource "google_project_iam_member" "control_plane_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.control_plane_sa.email}"
}

resource "google_project_iam_member" "control_plane_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.control_plane_sa.email}"
}

resource "google_project_iam_member" "control_plane_aiplatform" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.control_plane_sa.email}"
}

# Allow Control Plane to execute Cloud Run Jobs as the Agent Runner identity
resource "google_service_account_iam_binding" "control_plane_acts_as_agent_runner" {
  service_account_id = google_service_account.agent_runner_sa.name
  role               = "roles/iam.serviceAccountUser"
  members = [
    "serviceAccount:${google_service_account.control_plane_sa.email}",
  ]
}

# Agent Runner permissions:
# - Vertex AI User for Stagehand Gemini LLM actions
# - Secret Manager Secret Accessor for persona credentials
resource "google_project_iam_member" "agent_runner_vertex_ai" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.agent_runner_sa.email}"
}

resource "google_project_iam_member" "agent_runner_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.agent_runner_sa.email}"
}

# ------------------------------------------------------------------------------
# 4. Google Cloud Storage (GCS) with Automated 7d/30d Retention Lifecycle
# ------------------------------------------------------------------------------
resource "google_storage_bucket" "artifacts" {
  project                     = var.project_id
  name                        = "sentinel-artifacts-${var.project_id}-${random_id.suffix.hex}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = false
  }

  # Lifecycle Rule 1: Delete passed test artifacts after 7 days
  lifecycle_rule {
    condition {
      age        = 7
      with_state = "ANY"
      matches_prefix = [
        "pass/",
        "passed/",
      ]
    }
    action {
      type = "Delete"
    }
  }

  # Lifecycle Rule 2: Delete failed run artifacts after 30 days (RCA retention)
  lifecycle_rule {
    condition {
      age        = 30
      with_state = "ANY"
    }
    action {
      type = "Delete"
    }
  }
}

# Grant Agent Runner read/write access to artifacts bucket
resource "google_storage_bucket_iam_member" "agent_runner_bucket_admin" {
  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.agent_runner_sa.email}"
}

# ------------------------------------------------------------------------------
# 5. Cloud Firestore Database (Native Mode)
# ------------------------------------------------------------------------------
resource "google_firestore_database" "default" {
  project                 = var.project_id
  name                    = "(default)"
  location_id             = var.region
  type                    = "FIRESTORE_NATIVE"
  delete_protection_state = "DELETE_PROTECTION_DISABLED"
  deletion_policy         = "DELETE"

  depends_on = [google_project_service.enabled_services]
}

# ------------------------------------------------------------------------------
# 6. Secret Manager for Webhook Signing and Integration Tokens
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret" "webhook_signing_secret" {
  project   = var.project_id
  secret_id = "sentinel-webhook-signing-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.enabled_services]
}

resource "google_secret_manager_secret_version" "webhook_signing_secret_v1" {
  secret      = google_secret_manager_secret.webhook_signing_secret.id
  secret_data = var.default_webhook_secret
}

# ------------------------------------------------------------------------------
# 7. Cloud Run Service: @sentinel/control-plane (Scale-to-Zero Default)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "control_plane" {
  project             = var.project_id
  name                = "sentinel-control-plane"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  labels = {
    "sentinel-version"          = replace(var.sentinel_version, ".", "-")
    "app-kubernetes-io-version" = replace(var.sentinel_version, ".", "-")
  }

  template {
    service_account = google_service_account.control_plane_sa.email

    labels = {
      "sentinel-version" = replace(var.sentinel_version, ".", "-")
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    dynamic "vpc_access" {
      for_each = var.vpc_subnetwork_name != null ? [1] : []
      content {
        network_interfaces {
          network    = var.vpc_network_name
          subnetwork = var.vpc_subnetwork_name
        }
        egress = "ALL_TRAFFIC"
      }
    }

    containers {
      image = local.effective_control_plane_image

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      ports {
        container_port = 8080
      }

      env {
        name  = "SENTINEL_GCP_PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "SENTINEL_GCP_REGION"
        value = var.region
      }

      env {
        name  = "SENTINEL_DEFAULT_TENANT_ID"
        value = var.default_tenant_id
      }

      env {
        name  = "SENTINEL_VERSION"
        value = var.sentinel_version
      }

      env {
        name  = "SENTINEL_ARTIFACTS_BUCKET"
        value = google_storage_bucket.artifacts.name
      }

      env {
        name  = "SENTINEL_AGENT_RUNNER_JOB_NAME"
        value = "sentinel-agent-runner"
      }

      env {
        name  = "ENABLE_DASHBOARD"
        value = var.enable_dashboard ? "true" : "false"
      }

      env {
        name = "SENTINEL_DEFAULT_WEBHOOK_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.webhook_signing_secret.secret_id
            version = "latest"
          }
        }
      }

      startup_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
        initial_delay_seconds = 2
        period_seconds        = 5
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
        period_seconds    = 10
        failure_threshold = 3
      }
    }
  }

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image,
    ]
  }
}

# Allow public or unauthenticated invocations for Webhook ingress
resource "google_cloud_run_service_iam_member" "control_plane_public_invoker" {
  project  = var.project_id
  service  = google_cloud_run_v2_service.control_plane.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ------------------------------------------------------------------------------
# 8. Cloud Run Job: @sentinel/agent-runner (Direct VPC Egress & Ephemeral Execution)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_job" "agent_runner" {
  project             = var.project_id
  name                = "sentinel-agent-runner"
  location            = var.region
  deletion_protection = false

  labels = {
    "sentinel-version"          = replace(var.sentinel_version, ".", "-")
    "app-kubernetes-io-version" = replace(var.sentinel_version, ".", "-")
  }

  template {
    task_count  = 1
    parallelism = 1

    template {
      service_account = google_service_account.agent_runner_sa.email
      timeout         = "300s" # 5-minute hard limit to prevent runaway loops
      max_retries     = 0      # QA verification runs must be deterministic without retrying failures

      dynamic "vpc_access" {
        for_each = var.vpc_subnetwork_name != null ? [1] : []
        content {
          network_interfaces {
            network    = var.vpc_network_name
            subnetwork = var.vpc_subnetwork_name
          }
          egress = "ALL_TRAFFIC"
        }
      }

      containers {
        image = local.effective_agent_runner_image

        resources {
          limits = {
            cpu    = "2"
            memory = "2Gi" # Ample memory for headless Chromium + Playwright
          }
        }

        env {
          name  = "SENTINEL_GCP_PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "SENTINEL_GCP_REGION"
          value = var.region
        }

        env {
          name  = "SENTINEL_ARTIFACTS_BUCKET"
          value = google_storage_bucket.artifacts.name
        }

        env {
          name  = "SENTINEL_CONTROL_PLANE_URL"
          value = google_cloud_run_v2_service.control_plane.uri
        }

        env {
          name  = "SENTINEL_VERSION"
          value = var.sentinel_version
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].template[0].containers[0].image,
    ]
  }
}

# ------------------------------------------------------------------------------
# 9. GCP Cloud Billing Budgets & Pub/Sub Circuit-Breaker Integration
# ------------------------------------------------------------------------------
resource "google_pubsub_topic" "budget_alerts" {
  project = var.project_id
  name    = "sentinel-budget-alerts"
}

# Allow Cloud Billing service account to publish budget events
resource "google_pubsub_topic_iam_member" "billing_pubsub_publisher" {
  count   = var.billing_account_id != null ? 1 : 0
  project = var.project_id
  topic   = google_pubsub_topic.budget_alerts.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:cloud-billing-pubsub@system.gserviceaccount.com"

  depends_on = [google_pubsub_topic.budget_alerts]
}

# Cloud Billing Budget resource
resource "google_billing_budget" "sentinel_budget" {
  count           = var.billing_account_id != null ? 1 : 0
  billing_account = var.billing_account_id
  display_name    = "Sentinel Serverless Monthly Spend Guardrail"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(floor(var.monthly_budget_amount_usd))
      nanos         = tostring(floor((var.monthly_budget_amount_usd - floor(var.monthly_budget_amount_usd)) * 1000000000))
    }
  }

  threshold_rules {
    threshold_percent = 0.50
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.80 # Soft cap: Sentinel shifts to SMOKE_ONLY
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.00 # Hard cap: Tripping circuit breaker blocks all non-essential runs
    spend_basis       = "CURRENT_SPEND"
  }

  all_updates_rule {
    pubsub_topic   = google_pubsub_topic.budget_alerts.id
    schema_version = "1.0"
  }
}
