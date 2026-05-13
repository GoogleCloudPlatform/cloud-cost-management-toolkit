terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
  }
}

#################################
# BIGQUERY DATASET CREATION      #
#################################

# Provisions the dataset where Dataform will write its output summaries/tables.
# Owned by this module to ensure standalone deployability.
resource "google_bigquery_dataset" "gcp_billing" {
  dataset_id                  = local.gcp_billing_dataset_id
  friendly_name               = local.gcp_billing_dataset_id
  description                 = "Dataset holding open-source Dataform pipeline outputs (${var.environment})"
  location                    = var.location
  project                     = var.project_id
  delete_contents_on_destroy = !var.deletion_protection

  labels = {
    environment = var.environment
    component   = "bigquery"
  }
}

#################################################
# AUTOMATED WORKFLOW SETTINGS GENERATION        #
#################################################

# Generates workflow_settings.yaml dynamically to avoid duplication of variables.
resource "local_file" "workflow_settings" {
  content  = templatefile("${path.module}/templates/workflow_settings.yaml.tpl", {
    project_id             = var.project_id
    dataset_id             = local.gcp_billing_dataset_id
    location               = var.location
    raw_billing_project    = var.raw_billing_project_id
    raw_billing_dataset    = var.raw_billing_dataset_name
    raw_billing_table_name = var.raw_billing_table_name
    recommendations_table_name = var.recommendations_table_name
    raw_azure_table_name       = var.raw_azure_table_name
    raw_azure_dataset          = var.raw_azure_dataset
    azure_advisor_table_name   = var.azure_advisor_table_name
    enable_recommendations     = var.enable_recommendations
    enable_azure               = var.enable_azure
  })
  filename = "${path.module}/../workflow_settings.yaml"
}

#################################
# DATAFORM REPOSITORY CALL      #
#################################

module "dataform_oss" {
  source = "./modules/gcp_dataform_oss"
  
  count  = var.enable_dataform_repo ? 1 : 0

  project_id              = var.project_id
  region                  = var.region
  repository_name         = "ccm-dataform-repository${var.instance_id == "" ? "" : "-${var.instance_id}"}"
  repository_display_name = "CCM Dataform Core Repository (${var.instance_id == "" ? "default" : var.instance_id})"
  dataform_service_account_email   = local.dataform_sa_email

  # Git Integration SSH Parameters
  git_remote_url     = var.dataform_git_remote_url
  git_default_branch = var.dataform_git_default_branch
  
  # Binds directly to our Secret Manager version resource below
  git_ssh_secret_version_id = var.enable_dataform_repo ? google_secret_manager_secret_version.git_ssh_key_version[0].id : ""
  git_host_public_key       = var.dataform_git_host_public_key

  release_configs  = local.dataform_release_configs
  workflow_configs = local.dataform_workflow_configs

  # Dynamic Workspace Compilation Overrides: Automatically segregates local development branches
  workspace_compilation_overrides = {
    default_database = var.project_id
    schema_suffix    = var.environment
  }

  # Enforce dynamic wait to ensure SA propagation is complete
  depends_on = [
    time_sleep.wait_for_dataform_iam,
    google_bigquery_dataset.gcp_billing
  ]
}

# ============================================================================
# SSH KEYPAIR & SECRET MANAGER AUTOMATION
# ============================================================================

resource "tls_private_key" "dataform_git_key" {
  count = var.enable_dataform_repo ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_secret_manager_secret" "git_ssh_key" {
  count = var.enable_dataform_repo ? 1 : 0

  secret_id = "ccm-dataform-git-ssh-key${var.instance_id == "" ? "" : "-${var.instance_id}"}"
  project   = var.project_id

  labels = {
    environment = var.environment
    component   = "dataform"
  }

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "git_ssh_key_version" {
  count = var.enable_dataform_repo ? 1 : 0

  secret      = google_secret_manager_secret.git_ssh_key[0].id
  secret_data = tls_private_key.dataform_git_key[0].private_key_openssh
}

# Enables GCP Dataform Service Agent Identity
resource "google_project_service_identity" "dataform_agent" {
  provider = google-beta
  project  = var.project_id
  service  = "dataform.googleapis.com"
}

# Grant Dataform Service Agent access to read Secret private key
resource "google_secret_manager_secret_iam_member" "dataform_agent_secret_access" {
  count = var.enable_dataform_repo ? 1 : 0

  project   = var.project_id
  secret_id = google_secret_manager_secret.git_ssh_key[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_project_service_identity.dataform_agent.email}"
}

# ============================================================================
# CORE DATAFORM OPERATIONAL LOCALS
# ============================================================================

locals {
  dataform_release_configs = {
    core_release = {
      name          = "ccm_core_release_config${var.instance_id == "" ? "" : "_${var.instance_id}"}"
      git_commitish = var.dataform_git_default_branch
      time_zone     = var.time_zone
      vars          = {
        gcp_project_id         = var.project_id
        gcp_dataset_id         = local.gcp_billing_dataset_id
        raw_billing_project    = var.raw_billing_project_id
        raw_billing_dataset    = var.raw_billing_dataset_name
        raw_billing_table_name = var.raw_billing_table_name
      }            
      cron_schedule = null 
    }
  }

  dataform_workflow_configs = {
    core_workflow = {
      name            = "ccm_core_workflow_config${var.instance_id == "" ? "" : "_${var.instance_id}"}"
      release_key     = "core_release" 
      time_zone       = var.time_zone
      service_account = local.dataform_sa_email 
      cron_schedule   = null 
    }
  }
}

# ============================================================================
# AUTOMATED WORKSPACE BOOTSTRAP (REST WORKAROUND)
# ============================================================================

# When this infrastructure was designed, the official Terraform Google Provider did not have a native resource for creating Dataform Workspaces (development branches).
# While Terraform could create the Repository, Release Configs, and Workflow Schedules, it had no native way to click the "Create Workspace" button for developers.
# To bridge this gap, this code uses a null_resource to bypass Terraform's limitations and make a direct HTTP REST API call to Google Cloud to provision the workspace.

resource "null_resource" "dataform_workspace_bootstrap" {
  count = var.enable_dataform_repo ? 1 : 0

  triggers = {
    workspace_name = var.dataform_workspace_name
    repo_id        = module.dataform_oss[0].repository_id
  }

  provisioner "local-exec" {
    command = <<EOT
      TOKEN=$(/usr/bin/gcloud auth print-access-token)
      curl -s -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        "https://dataform.googleapis.com/v1beta1/${self.triggers.repo_id}/workspaces?workspaceId=${self.triggers.workspace_name}"
    EOT
  }

  depends_on = [
    module.dataform_oss,
    google_secret_manager_secret_iam_member.dataform_agent_secret_access
  ]
}
