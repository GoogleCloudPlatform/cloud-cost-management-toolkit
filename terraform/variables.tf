#########################################
# DATAFORM CORE VARIABLES WITH DEFAULTS  #
#########################################

variable "project_id" {
  description = "The target GCP Project ID where Dataform is provisioned"
  type        = string
}

variable "environment" {
  description = "The environment suffix (e.g., np for non-prod, pd for prod)"
  type        = string
}

variable "instance_id" {
  description = "The unique identifier for this pipeline instance. It will be used as the suffix for the BigQuery dataset (ccm_toolkit_<instance_id>) and other resources to ensure uniqueness."
  type        = string
  default     = "np"
}

variable "region" {
  description = "The primary region for Dataform repository"
  type        = string
  default     = "us-central1"
}

variable "location" {
  description = "The location for the BigQuery billing dataset"
  type        = string
  default     = "US"
}

variable "deletion_protection" {
  description = "Enable/Disable deletion protection for BigQuery datasets"
  type        = bool
  default     = true
}

variable "enable_dataform_repo" {
  description = "Conditional flag to enable/disable the creation of the GCP Dataform Repository"
  type        = bool
  default     = true
}

variable "time_zone" {
  description = "The time zone for setting Dataform release and workflow cron schedules"
  type        = string
  default     = "America/Los_Angeles"
}

variable "raw_billing_project_id" {
  description = "The external GCP Project ID where the raw billing export table is hosted (needed to grant Dataform read access)"
  type        = string
}

variable "raw_billing_dataset_name" {
  description = "The external BigQuery dataset name containing raw billing exports (used for compilation overrides)"
  type        = string
}

variable "raw_billing_table_name" {
  description = "The external BigQuery table name containing raw billing exports (used for compilation overrides)"
  type        = string
}

variable "recommendations_table_name" {
  description = "The external BigQuery table name containing recommendations exports"
  type        = string
  default     = "recommendations_export"
}

variable "raw_azure_table_name" {
  description = "The external BigQuery table name containing raw Azure billing exports"
  type        = string
  default     = "azure_costs"
}

variable "raw_azure_dataset" {
  description = "The external BigQuery dataset name containing raw Azure billing exports"
  type        = string
  default     = "azure_billing"
}

variable "azure_advisor_table_name" {
  description = "The external BigQuery table name containing Azure Advisor exports"
  type        = string
  default     = "azure_advisor"
}

variable "enable_recommendations" {
  description = "Flag to enable or disable processing of recommendations"
  type        = bool
  default     = true
}

variable "enable_azure" {
  description = "Flag to enable or disable processing of Azure costs"
  type        = bool
  default     = false
}

#####################################
# DATAFORM GIT REMOTE MIRROR VARS   #
#####################################

variable "dataform_git_remote_url" {
  description = "The Git remote repository URL (e.g., git@github.com:org/repo.git). Required when enable_dataform_repo is true."
  type        = string
  default     = "" 
}

variable "dataform_git_default_branch" {
  description = "The target branch for the Git remote repository mirror"
  type        = string
  default     = "main"
}

variable "dataform_git_host_public_key" {
  description = "The public SSH host key string for your Git provider to prevent man-in-the-middle attacks."
  type        = string
  default     = ""
}

variable "dataform_workspace_name" {
  description = "The developer workspace branch name to provision natively in the Dataform repository"
  type        = string
  default     = "ccm-toolkit-main"
}

################################
# SENSITIVE/CREDENTIAL VARIABLES #
################################

variable "GIT_DATAFORM_SSH_PRIVATE_KEY" {
  description = "Optional: Github/Git private SSH key for Dataform remote repository (Sensitive)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "REPO_PUBLIC_SSH_KEY" {
  description = "Optional: Public SSH Key associated with the Git remote repository (Sensitive)"
  type        = string
  default     = ""
  sensitive   = true
}
