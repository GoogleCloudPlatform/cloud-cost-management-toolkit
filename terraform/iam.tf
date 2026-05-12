############################################
# DATAFORM SPECIFIC IAM & SERVICE ACCOUNTS   #
############################################

# 1. Dataform Service Account
resource "google_service_account" "dataform" {
  account_id   = "gsvc-ccm-toolkit${var.instance_id == "" ? "" : "-${var.instance_id}"}"
  display_name = "CCM Dataform Service Account (${var.instance_id == "" ? "default" : var.instance_id})"
  description  = "Service account used by Dataform core pipeline to execute BigQuery jobs"
  project      = var.project_id
}

# 2. Project-Level IAM Roles for Dataform SA
# Grants access to run BQ jobs, read/write data, and read secrets (for Git integration)
resource "google_project_iam_member" "dataform_roles" {
  for_each = toset([
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/secretmanager.secretAccessor",
    "roles/bigquery.connectionUser"
  ])
  project = var.project_id
  role    = each.value
  member  = google_service_account.dataform.member
}

# 3. Impersonation Roles for Dataform Service Agent
# Allows the GCP-managed Dataform agent to run operations as our custom SA
resource "google_service_account_iam_member" "dataform_agent_impersonation" {
  service_account_id = google_service_account.dataform.id
  for_each = toset([
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.serviceAccountUser"
  ])
  role   = each.value
  member = "serviceAccount:service-${local.project_number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

# 4. External Project Data Access Permissions
# Grants Dataform SA access to read raw billing export in the source project
resource "google_project_iam_member" "dataform_source_billing_read" {
  project = var.raw_billing_project_id
  role    = "roles/bigquery.dataViewer"
  member  = google_service_account.dataform.member
}

# 5. IAM Propagation Wait
# Forces a 30-second pause after SA creation to prevent GaiID 404 race conditions during API binding
resource "time_sleep" "wait_for_dataform_iam" {
  create_duration = "30s"

  depends_on = [
    google_service_account.dataform
  ]
}
