terraform {
  experiments = [module_variable_optional_attrs]
}

###########################################
# DATAFORM OPEN SOURCE REPOSITORY MODULE  #
###########################################

# Provisions a GCP Dataform Repository.
# Designed to be generic and community-ready: supports local-only repos or remote Git (SSH).
resource "google_dataform_repository" "dataform_repository" {
  provider = google-beta

  project         = var.project_id
  region          = var.region
  name            = var.repository_name
  display_name    = var.repository_display_name
  deletion_policy = "FORCE" # Force destroy repo on tear-down for cleanup agility
  service_account = var.dataform_service_account_email

  # Dynamic block: Only provisioned if a git_remote_url is supplied
  dynamic "git_remote_settings" {
    for_each = var.git_remote_url != "" ? [1] : []
    content {
      url            = var.git_remote_url
      default_branch = var.git_default_branch

      # Nested Dynamic block: Only provisioned if a secret version ID for private key is supplied
      dynamic "ssh_authentication_config" {
        for_each = var.git_ssh_secret_version_id != "" ? [1] : []
        content {
          user_private_key_secret_version = var.git_ssh_secret_version_id
          host_public_key                 = var.git_host_public_key
        }
      }
    }
  }

  dynamic "workspace_compilation_overrides" {
    for_each = var.workspace_compilation_overrides != null ? [var.workspace_compilation_overrides] : []
    content {
      default_database = workspace_compilation_overrides.value.default_database
      schema_suffix    = lookup(workspace_compilation_overrides.value, "schema_suffix", null)
      table_prefix     = lookup(workspace_compilation_overrides.value, "table_prefix", null)
    }
  }
}

# Provisions Release Configurations (Compilation Settings/Environments) linked to the repo
resource "google_dataform_repository_release_config" "release_config" {
  provider = google-beta

  for_each = var.release_configs

  project    = var.project_id
  region     = var.region
  repository = google_dataform_repository.dataform_repository.name
  
  name          = each.value.name
  git_commitish = each.value.git_commitish
  cron_schedule = lookup(each.value, "cron_schedule", null)
  time_zone     = lookup(each.value, "time_zone", null)

  dynamic "code_compilation_config" {
    for_each = each.value.vars != null ? [each.value.vars] : []
    content {
      # Injects compilation variables (overrides workflow_settings.yaml vars)
      vars = code_compilation_config.value
    }
  }

  depends_on = [
    google_dataform_repository.dataform_repository
  ]
}

# Provisions Workflow Configurations (Schedules/Invocations) linked to release configs
resource "google_dataform_repository_workflow_config" "workflow_config" {
  provider = google-beta

  for_each = var.workflow_configs

  project    = var.project_id
  region     = var.region
  repository = google_dataform_repository.dataform_repository.name
  
  name           = each.value.name
  # Maps the workflow to its respective release config via key lookup
  release_config = google_dataform_repository_release_config.release_config[each.value.release_key].id
  cron_schedule  = lookup(each.value, "cron_schedule", null)
  time_zone      = lookup(each.value, "time_zone", null)

  dynamic "invocation_config" {
    for_each = each.value.service_account != null ? [each.value.service_account] : []
    content {
      # Service Account override for invocation execution if different from repo default
      service_account = invocation_config.value
    }
  }

  depends_on = [
    google_dataform_repository.dataform_repository,
    google_dataform_repository_release_config.release_config
  ]
}
