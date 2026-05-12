# Overview
A SQL-based data engineering pipeline sourcing GCP Billing and Recommendations export table(s) in BigQuery to produce reporting-friendly summary tables from one or more billing accounts. Can be orchestrated 100% with Dataform scheduled Workflow/Release configurations, or call Dataform API to execute compilation and invocation via Composer/airflow, Cloud Run, Workflows, etc.

Output tables are designed to improve the analytics experience by reducing query costs and speeding up slow analysis, unlocking many queries unattainable by accounts with high activity. Also includes optional add-ons of anomaly detection with BQML, cloud run function to orchestrate alerting of anomalies to slack, email, etc with AI generated next steps, plus a suite of Looker Studio report templates. Core deployment in any FinOps related PSO project, but also useful outside the context of PSO.

This repository contains both the Dataform SQLX pipeline code and the Terraform module required to provision the Dataform environment in your GCP project.

# Goals
- No expensive matching rows/UPDATE operations. Always prune partitions. NO full table scans!
- Maintain a "report-friendly" GCP billing export, separate from the raw billing export
  - A similar schema to the raw export, but repartitioned and a generated PK
  - Perform insert-only operations from raw gcp billing export table as partitioned are available
- Process the minimum amount of usage_start_dates (partition column) when building the daily aggregate (reporting table)
  - Track the distinct usage_start_date values in raw PARTITIONDATES processed for each incremental run
  - Update daily aggregate table by deleting the incomplete/latest partition along with any that include usage_start_dates in the past. (Billing corrections, credits, etc.), then inserting the new updated partitions.

For more detailed design information, see the Pipeline and Dataform design docs.

# Implementation 
Two pathways, with or without using Terraform

## Prerequisites

1.  **GCP Project**: A GCP project where you want to transform your billing data.
2.  **GCP Billing Export**: Access to a raw billing export table (standard or detailed) in BigQuery (can be in the same project or a different one).
3.  **Git Provider**: A public or private Git repository (e.g., GitHub, GitLab) hosting your clone/fork of this `ccm-toolkit` repository.
4.  **Permissions**: Your deployment user must have Owner or Editor access to the target GCP project to perform manual actions or to run Terraform.

## Implementation (without Terraform)

Two parts. First, getting this solution code into your dataform. Second, making it work for your project.
### Installing in Dataform
1. Clone or fork this repository to an online git service that you own (e.g. a new repository in your company's github org or a gitlab already networked to your GCP project). This will become the remote repository backing up your updates to this solution. If this is not possible, the instructions below will not apply (i.e. don't just make a local clone).
1. [Open Dataform](https://console.cloud.google.com/bigquery/dataform) and create a new repository. Use the default service account and select any region.
1. Grant the permission required when prompted.
1. Don't create a workspace yet - instead, go to Settings and "Connect with git"
1. Choose the SSH option, and paste the ssh address of your online repository, e.g. `git@github.com:your_org_name_here/cloud-cost-management-toolkit.git`
1. Set the branch with which Dataform will synchronize, e.g. main. The clone in dataform will have multiple branches (called workspaces), but all merges to the remote will occur in this one branch.
1. Configure the deploy key for your remote repository. This will first require generating a ssh public-private key pair either with [these generic instructions](https://pagely.com/quickstart/firehose/ssh/mac/generating-key-pairs/#:~:text=So%20you%20need%20to%20generate,new%20public%20key%20to%20Atomic.) or [this has some extra steps for each git provider](https://docs.cloud.google.com/dataform/docs/connect-repository?_gl=1*yjwu1r*_ga*NTE4ODkxOTgwLjE3NDcyNTE4NDU.*_ga_WH2QY8WWF5*czE3Njc4OTUxNzkkbzg1JGcxJHQxNzY3ODk3MDU0JGo0MyRsMCRoMA..#github) - note that there are some unnecessary next steps after key generation in these instructions.
1. Upload the private key to [Secret Manager](https://console.cloud.google.com/security/secret-manager) and select it as the Secret. You'll also need to grant the "Secret Accessor" role to the Dataform service account (or, if you used a SA other than default in step 1, athorize that SA) either in the "Permissions" tab of the secret itself, or directly in [IAM](https://console.cloud.google.com/iam-admin/iam)
1. Upload the public ssh key to the online repository as a deploy key. Be sure to enable write access.
1. For the "SSH public host key value" use the correct key for your online remote. For github, one option that works well is `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl` (see [github doc](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)). Note, do not include "github.com" in this value

You should now be successfully connected to the remote, and all code will be copied to your project's dataform!

Next, create a seperate workspace for each collaborating developer. As other users push code from their workspace to the remote, your workspace will prompt you to pull those updates. 
- Each developer will need BigQuery Job User and Data Editor roles on the project
- Note these workspaces are local to dataform and will not have a copy in the remote. This seems to work fine in most cases. To interact with multiple remote branches, more than one dataform repository is needed and will duplicate the pipeline which is not desireable.

### Configuring for your project
These instructions assume your organization is already [exporting its billing data to BigQuery](https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery).
1. Rename template to workflow_settings.yaml in root directory.
1. Edit workflow_settings.yaml:
   1. Add a default (target) BigQuery project/dataset for Dataform's output tables and views
   1. Configure raw_billing_dataset, raw_billing_project and raw_billing_table_name with the location of your GCP billing export table setup via https://cloud.google.com/billing/docs/how-to/export-data-bigquery
1. Check the compiled version of full refresh for step 01_get_billing_data to estimate the cost of an initial load via dry run
   1. Adjust default_start_date in workflow_settings.yaml as needed, it will be used for full refreshes.
1. Check the default definition of "net cost" in the [03_reporting_view.sqlx](definitions/output/03_reporting_view.sqlx) file. All downstream use of net cost will leverage this definition. Alter it to conform to your organization's desire.
1. Update [03_build_labels.sqlx](definitions/output/03_build_labels.sqlx) to pivot your organization's label keys. This is done by changing the existing "WHERE" clause references to match your label keys. Add additional select clause references with the same format to pivot as many label keys as necessary. Do the same in the project labels and tags. System labels ought to be generic across GCP and can likely remain unchanged.
1. [Gmerril to revise this] Do something with the init tag

[Optional] If your organization has also enabled the [Recommendations Export](https://docs.cloud.google.com/recommender/docs/bq-export/export-recommendations-to-bq), then complete these additional steps.

1. In the workflow settings, uncomment and configure recommendations_table with name of your Recommendations export table setup via https://cloud.google.com/recommender/docs/bq-export/export-recommendations-to-bq


## Implementation (with Terraform)

### Phase 1: Infrastructure Provisioning (Terraform)

We use Terraform to provision the Dataform repository, the required Service Account, and the BigQuery dataset where the output tables will be created.

#### Step 1: Configure Terraform Variables
1.  Navigate to the `terraform/` directory.
2.  Copy the environment template to create your active `.tfvars` file:
    ```bash
    cp environments/nonprod.tfvars.template environments/nonprod.tfvars
    ```
3.  Configure the variables inside `environments/nonprod.tfvars`:
    ```hcl
    project_id             = "your-gcp-project-id"
    environment            = "np" # np for non-prod, pd for prod
    instance_id            = "" # leave blank if only handling one billing account/export
    region                 = "us-central1"
    location               = "US"
    raw_billing_project_id = "your-raw-billing-project-id"
    raw_billing_dataset_name = "your_raw_billing_dataset"
    raw_billing_table_name   = "gcp_billing_export_v1_XXXXXX_XXXXXX_XXXXXX"
    
    # Git Integration
    dataform_git_remote_url     = "git@github.com:your-org/ccm-toolkit.git"
    ```

#### Step 2: Run Terraform Apply
Execute the apply command pointing to your environment-specific variables:
```bash
cd terraform
terraform init
terraform apply -var-file=environments/nonprod.tfvars
```
This will create:
*   The BigQuery dataset `ccm_toolkit_<instance_id>` (e.g., `ccm_toolkit_account1`).
*   The Dataform Service Account (`gsvc-ccm-dataform-<environment>`) with appropriate BigQuery roles.
*   The GCP Dataform Repository connected to your Git remote.
*   An SSH Keypair in Secret Manager for secure Git mirroring.

### Step 3: Retrieve the Deploy Key
After a successful apply, Terraform will output the public SSH deploy key. Copy this string from your terminal:
```
dataform_git_public_deploy_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC..."
```

---

### Phase 2: Git Integration & Dataform Configuration

Now we link GCP Dataform to your Git provider and configure the pipeline parameters.

#### Step 1: Add Deploy Key to your Git Provider (e.g., GitHub)
1.  Go to your Git repository settings (e.g., on GitHub).
2.  Navigate to **Deploy keys**.
3.  Click **Add deploy key**.
4.  Paste the SSH public key retrieved in Phase 1, Step 3.
5.  **CRITICAL**: Check **"Allow write access"** (Dataform needs write access to push workspace changes back to your branch).

#### Step 2: Configure `workflow_settings.yaml`
1. The terraform apply will create a workflow_settings.yaml automatically (based on the variable settings in the tfvars file for the environment)! Simply commit and push that new file to the remote Git repository:
    ```bash
    git add workflow_settings.yaml
    git commit -m "Configure Dataform workflow settings for environment"
    git push origin main
    ```

---

### Phase 3: First Execution

1.  Open the **BigQuery -> Dataform** page in the Google Cloud Console.
2.  Open your repository (e.g., `ccm-dataform-repository-np`).
3.  Create or open a development workspace (e.g., `ccm-toolkit-oss-for-alert`).
4.  Click **Pull from Remote** to pull the latest configurations you pushed in Phase 2.
5.  Verify that the compilation status is **Green** (no compilation errors).
6.  Click **Start Execution** and select **All Actions**.
7.  Monitor the execution. Once completed, verify that the following tables have been successfully created and populated in your BigQuery output dataset (e.g., `gcp_billing_np`):
    *   `usage_partitioned_billing_export`
    *   `gcp_billing_export_daily_summary`
