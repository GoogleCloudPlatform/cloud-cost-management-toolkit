#########################################
# DATAFORM OSS MODULE VARIABLE DEFINITIONS #
#########################################

variable "project_id" {
  description = "The target GCP Project ID"
  type        = string
}

variable "region" {
  description = "The regional location for the Dataform repository"
  type        = string
}

variable "repository_name" {
  description = "The name of the Dataform repository resource"
  type        = string
}

variable "repository_display_name" {
  description = "The friendly display name for the Dataform repository"
  type        = string
  default     = null
}

variable "dataform_service_account_email" {
  description = "The Service Account email used by Dataform to execute BigQuery jobs on behalf of the workflow"
  type        = string
}

variable "workspace_compilation_overrides" {
  # Safely redirects development workspace compilations to dev/sandbox environments to protect production.
  description = "Optional: Workspace compilation overrides configuration (database, schema_suffix, table_prefix)"
  type = object({
    default_database = string
    schema_suffix    = optional(string)
    table_prefix     = optional(string)
  })
  default = null
}

# --- Git Remote Settings (Dynamic Blocks) ---
variable "git_remote_url" {
  description = "The Git remote repository URL (HTTPS or SSH). "
  type        = string
  default     = ""
}

variable "git_default_branch" {
  description = "The default branch for the Git remote repository"
  type        = string
  default     = "main"
}

variable "git_ssh_secret_version_id" {
  description = "Optional: The full Secret Manager secret version ID containing the private SSH key for Git authentication"
  type        = string
  default     = ""
}

variable "git_host_public_key" {
  description = "Optional: The public SSH host key for the Git provider (e.g., github.com public key)"
  type        = string
  default     = ""
}

# --- Release and Workflow Configurations Maps ---
variable "release_configs" {
  description = "A map of Dataform Release Configurations to provision. Key is an arbitrary identifier."
  type = map(object({
    name          = string
    git_commitish = string
    cron_schedule = optional(string)
    time_zone     = optional(string)
    vars          = optional(map(string)) # Code compilation variables (workflow settings variables override)
  }))
  default = {}
}

variable "workflow_configs" {
  description = "A map of Dataform Workflow Configurations (Schedules) to provision. Key is an arbitrary identifier."
  type = map(object({
    name            = string
    release_key     = string # Must match a key in the release_configs map
    cron_schedule   = optional(string)
    time_zone       = optional(string)
    service_account = optional(string) # Invocation service account override
  }))
  default = {}
}
