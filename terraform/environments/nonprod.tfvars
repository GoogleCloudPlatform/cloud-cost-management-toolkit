###################################
# NON-PRODUCTION ENVIRONMENT VARS #
###################################

project_id             = "bondok-playground-indef"
environment            = "np"                 # np for non-prod (dev/staging)
instance_id            = ""                   # Limit 12 characters! Can be left blank.
                                              # Set instance_id for each of multiple billing accounts. If only handling one billing export, leave it blank.
region                 = "us-central1"        # Regional compute location 
location               = "US"                 # Multi-regional BigQuery location - must be same for each instance_id to support unioning in a MV
time_zone              = "America/Los_Angeles" # Time zone for cron schedules
deletion_protection    = false                # Set to false in dev for clean teardowns

# --- Source Billing Data Context ---
raw_billing_project_id = "bondok-playground-indef"
raw_billing_dataset_name = "billing_export"
raw_billing_table_name   = "gcp_billing_export_v1_019340_EEE2B1_B51057"

# --- Recommendations & Azure Configuration ---
recommendations_table_name = "recommendations_export"
raw_azure_table_name       = "azure_costs"
raw_azure_dataset          = "azure_billing"
azure_advisor_table_name   = "azure_advisor"
enable_recommendations     = false #if false, can skip recommendations related config
enable_azure               = false #if false, can skip azure related config

# --- Git Repository Configuration (Optional) ---
enable_dataform_repo         = true
dataform_git_remote_url      = "git@github.com:bondok-gcp/cloud-cost-management-toolkit.git"
dataform_git_default_branch  = "main"
dataform_git_host_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
# This is the correct git host public key for all github.com repositories. 
# Reference: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
dataform_workspace_name      = "ccm-toolkit-main" 
