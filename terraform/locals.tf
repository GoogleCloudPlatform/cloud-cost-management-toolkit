locals {
  # Fetch project details dynamically
  project_id     = var.project_id
  project_number = data.google_project.project.number

  # Service Account emails
  dataform_sa_email = "gsvc-ccm-toolkit${var.instance_id == "" ? "" : "-${var.instance_id}"}@${var.project_id}.iam.gserviceaccount.com"

  # BigQuery Dataset configuration for Dataform Output
  gcp_billing_dataset_id = "ccm_toolkit${var.instance_id == "" ? "" : "_${var.instance_id}"}"
}

# Dynamic lookup of project number to avoid hardcoding
data "google_project" "project" {
  project_id = var.project_id
}
